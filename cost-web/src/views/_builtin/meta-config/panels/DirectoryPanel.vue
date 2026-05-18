<script setup lang="ts">
import { computed, inject, onMounted, ref } from 'vue';
import { NButton, NModal, NPopconfirm, NSpace, useDialog, useMessage } from 'naive-ui';
import { AgGridVue } from 'ag-grid-vue3';
import type {
  CellValueChangedEvent,
  ColDef,
  GetContextMenuItemsParams,
  GetDataPath,
  GridApi,
  GridReadyEvent
} from 'ag-grid-community';
import { deleteResource, fetchAllResources, saveResource } from '@/service/api/meta-config';
import { cascadeDeletePage } from '@/service/api/wizard';
import WizardPanel from './WizardPanel.vue';

const message = useMessage();
const dialog = useDialog();
const navigateTo = inject<(tab: string, pageCode: string) => void>('navigateTo')!;
const gridApi = ref<GridApi | null>(null);
const rawData = ref<any[]>([]);
const selectedRow = ref<any>(null);
const loading = ref(false);

// 页面向导弹窗
const showWizard = ref(false);
const wizardParentId = ref<number | null>(null);
const wizardParentName = ref('');

function openWizard() {
  // 默认归属菜单 = 当前选中的 DIRECTORY 节点，或选中行的父级
  if (selectedRow.value?.resourceType === 'DIRECTORY') {
    wizardParentId.value = selectedRow.value.id;
    wizardParentName.value = selectedRow.value.resourceName || '';
  } else if (selectedRow.value?.parentId) {
    wizardParentId.value = selectedRow.value.parentId;
    const parent = rawData.value.find(r => r.id === selectedRow.value.parentId);
    wizardParentName.value = parent?.resourceName || '';
  } else {
    // 顶级 PAGE 或未选中 → 默认根目录
    wizardParentId.value = -1;
    wizardParentName.value = '根目录（顶级）';
  }
  showWizard.value = true;
}

function onWizardSuccess() {
  showWizard.value = false;
  loadData(); // 刷新目录树
}

// 构建树路径：每行需要一个 string[] 路径，AG Grid Tree Data 用它来构建层级
const rowData = computed(() => {
  const idMap = new Map<number, any>();
  for (const r of rawData.value) {
    idMap.set(r.id, r);
  }
  return rawData.value.map(r => {
    const path: string[] = [];
    let cur = r;
    const visited = new Set<number>();
    while (cur) {
      if (visited.has(cur.id)) break;
      visited.add(cur.id);
      path.unshift(String(cur.id));
      cur = cur.parentId ? idMap.get(cur.parentId) : null;
    }
    return { ...r, _treePath: path };
  });
});

const getDataPath: GetDataPath = (data: any) => data._treePath;

const autoGroupColumnDef: ColDef = {
  headerName: '名称',
  width: 260,
  editable: true,
  field: 'resourceName',
  cellRendererParams: {
    suppressCount: true
  }
};

const columnDefs: ColDef[] = [
  { field: 'id', headerName: 'ID', width: 70, editable: false },
  {
    field: 'resourceType',
    headerName: '类型',
    width: 110,
    editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: ['DIRECTORY', 'PAGE'] }
  },
  { field: 'pageCode', headerName: 'pageCode', width: 140, editable: true },
  {
    field: 'isHardcoded',
    headerName: '硬编码',
    width: 80,
    editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: [0, 1] },
    valueFormatter: (p: any) => (p.value === 1 ? '是' : '否')
  },
  { field: 'icon', headerName: '图标', width: 140, editable: true },
  { field: 'route', headerName: '路由', width: 160, editable: true },
  { field: 'parentId', headerName: '父级ID', width: 90, editable: true, cellDataType: 'number' },
  { field: 'sortOrder', headerName: '排序', width: 70, editable: true, cellDataType: 'number' }
];

const defaultColDef: ColDef = {
  sortable: true,
  resizable: true,
  flex: 0,
  suppressHeaderMenuButton: true
};

async function loadData() {
  loading.value = true;
  try {
    rawData.value = await fetchAllResources();
    setTimeout(() => gridApi.value?.autoSizeAllColumns(), 100);
  } catch (e) {
    message.error('加载失败');
  } finally {
    loading.value = false;
  }
}

function onGridReady(params: GridReadyEvent) {
  gridApi.value = params.api;
  params.api.autoSizeAllColumns();
}

function onSelectionChanged() {
  const rows = gridApi.value?.getSelectedRows() || [];
  selectedRow.value = rows[0] || null;
}

function onRowClicked(event: any) {
  if (event.node?.data) {
    selectedRow.value = event.node.data;
    event.node.setSelected(true, true);
  }
}

function handleAddDirectory() {
  const parentId =
    selectedRow.value?.resourceType === 'DIRECTORY' ? selectedRow.value.id : selectedRow.value?.parentId || null;
  const newRow = {
    _isNew: true,
    id: Date.now(),
    resourceName: '新目录',
    resourceType: 'DIRECTORY',
    pageCode: '',
    isHardcoded: 0,
    icon: 'mdi:folder',
    route: '',
    parentId,
    sortOrder: 0
  };
  rawData.value = [...rawData.value, newRow];
  expandAndShow(newRow.id);
}

function handleAddPage() {
  const parentId =
    selectedRow.value?.resourceType === 'DIRECTORY' ? selectedRow.value.id : selectedRow.value?.parentId || null;
  const newRow = {
    _isNew: true,
    id: Date.now(),
    resourceName: '新页面',
    resourceType: 'PAGE',
    pageCode: '',
    isHardcoded: 0,
    icon: 'mdi:file-document',
    route: '',
    parentId,
    sortOrder: 0
  };
  rawData.value = [...rawData.value, newRow];
  expandAndShow(newRow.id);
}

/** 展开树并滚动到新行，但不自动选中（避免连续新增套娃） */
function expandAndShow(id: number) {
  setTimeout(() => {
    gridApi.value?.expandAll();
    const rowNode = gridApi.value?.getRowNode(String(id));
    if (rowNode) {
      gridApi.value?.ensureNodeVisible(rowNode);
    }
  }, 100);
}

async function handleSave() {
  const dirtyRows: any[] = [];
  gridApi.value?.forEachNode(node => {
    if (node.data?._dirty || node.data?._isNew) dirtyRows.push(node.data);
  });
  if (dirtyRows.length === 0) {
    message.info('没有需要保存的修改');
    return;
  }
  for (const row of dirtyRows) {
    if (!row.resourceName) {
      message.warning('名称不能为空');
      return;
    }
  }
  try {
    await Promise.all(
      dirtyRows.map(r => {
        const toSave = { ...r };
        delete toSave._treePath;
        if (toSave._isNew) {
          delete toSave.id;
          delete toSave._isNew;
          delete toSave._dirty;
        }
        return saveResource(toSave);
      })
    );
    message.success(`已保存 ${dirtyRows.length} 条记录`);
    await loadData();
  } catch (e) {
    message.error('保存失败');
  }
}

async function handleDelete() {
  if (!selectedRow.value) return;
  if (selectedRow.value._isNew) {
    rawData.value = rawData.value.filter(r => r.id !== selectedRow.value.id);
    return;
  }

  const row = selectedRow.value;
  const pageCode = row.pageCode;

  // 如果是 PAGE 类型且有 pageCode，询问是否级联删除
  if (row.resourceType === 'PAGE' && pageCode) {
    dialog.warning({
      title: '删除确认',
      content: `是否删除页面「${row.resourceName}」及其相关的所有元数据（表、列、组件、规则、权限）？`,
      positiveText: '删除全部',
      negativeText: '取消',
      onPositiveClick: async () => {
        try {
          await cascadeDeletePage(pageCode);
          message.success('页面及相关元数据已全部删除');
          await loadData();
        } catch (e: any) {
          message.error(e?.message || '删除失败');
        }
      }
    });
  } else {
    // DIRECTORY 或无 pageCode 的资源，只删资源本身
    try {
      await deleteResource(row.id);
      message.success('删除成功');
      await loadData();
    } catch (e) {
      message.error('删除失败');
    }
  }
}

function onCellValueChanged(event: CellValueChangedEvent) {
  if (event.data) event.data._dirty = true;
}

// ---- 右键菜单（AG Grid 自带） ----
function getContextMenuItems(params: GetContextMenuItemsParams) {
  const row = params.node?.data;
  const pageCode = row?.pageCode;
  if (!pageCode) return [];
  return [
    { name: '跳转到 审批流配置', action: () => navigateTo('approval', pageCode) },
    { name: '跳转到 页面管理', action: () => navigateTo('page', pageCode) },
    { name: '跳转到 表管理', action: () => navigateTo('table', pageCode) },
    { name: '跳转到 Lookup管理', action: () => navigateTo('lookup', pageCode) }
  ];
}

onMounted(loadData);
</script>

<template>
  <div class="panel-container">
    <div class="toolbar">
      <NSpace>
        <NButton size="small" type="primary" @click="openWizard">新增页面（向导）</NButton>
        <NButton size="small" type="error" :disabled="!selectedRow" @click="handleDelete">删除</NButton>
        <NButton size="small" @click="handleSave">保存</NButton>
        <NButton size="small" quaternary @click="loadData">刷新</NButton>
      </NSpace>
    </div>
    <div class="grid-wrapper">
      <AgGridVue
        class="ag-theme-quartz"
        style="width: 100%; height: 100%"
        :row-data="rowData"
        :column-defs="columnDefs"
        :default-col-def="defaultColDef"
        :suppress-scroll-on-new-data="true"
        :tree-data="true"
        :get-data-path="getDataPath"
        :auto-group-column-def="autoGroupColumnDef"
        :group-default-expanded="0"
        :row-selection="{ mode: 'singleRow', checkboxes: false }"
        :get-row-id="(params: any) => String(params.data.id)"
        :cell-selection="true"
        :get-context-menu-items="getContextMenuItems"
        @grid-ready="onGridReady"
        @selection-changed="onSelectionChanged"
        @row-clicked="onRowClicked"
        @cell-value-changed="onCellValueChanged"
      />
    </div>
    <!-- 页面向导弹窗 -->
    <NModal
      v-model:show="showWizard"
      preset="card"
      title="页面创建向导"
      :style="{ width: '900px', maxHeight: '85vh' }"
      :body-style="{ overflow: 'auto' }"
      :mask-closable="false"
    >
      <WizardPanel
        :default-parent-id="wizardParentId"
        :default-parent-name="wizardParentName"
        @success="onWizardSuccess"
      />
    </NModal>
  </div>
</template>

<style scoped>
.panel-container {
  display: flex;
  flex-direction: column;
  height: 100%;
  gap: 8px;
}
.toolbar {
  flex-shrink: 0;
  padding: 4px 0;
}
.grid-wrapper {
  flex: 1;
  min-height: 0;
}
</style>
