<script setup lang="ts">
import { ref, onMounted, computed, inject } from 'vue';
import { NButton, NSpace, NPopconfirm, useMessage } from 'naive-ui';
import { AgGridVue } from 'ag-grid-vue3';
import type { GridApi, GridReadyEvent, ColDef, CellValueChangedEvent, GetDataPath, GetContextMenuItemsParams } from 'ag-grid-community';
import { fetchAllResources, saveResource, deleteResource } from '@/service/api/meta-config';

const message = useMessage();
const navigateTo = inject<(tab: string, pageCode: string) => void>('navigateTo')!;
const gridApi = ref<GridApi | null>(null);
const rawData = ref<any[]>([]);
const selectedRow = ref<any>(null);
const loading = ref(false);

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
    field: 'resourceType', headerName: '类型', width: 110, editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: ['DIRECTORY', 'PAGE'] }
  },
  { field: 'pageCode', headerName: 'pageCode', width: 140, editable: true },
  {
    field: 'isHardcoded', headerName: '硬编码', width: 80, editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: [0, 1] },
    valueFormatter: (p: any) => p.value === 1 ? '是' : '否'
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
  const parentId = selectedRow.value?.resourceType === 'DIRECTORY'
    ? selectedRow.value.id
    : selectedRow.value?.parentId || null;
  const newRow = {
    _isNew: true, id: Date.now(),
    resourceName: '新目录', resourceType: 'DIRECTORY',
    pageCode: '', isHardcoded: 0, icon: 'mdi:folder',
    route: '', parentId, sortOrder: 0
  };
  rawData.value = [...rawData.value, newRow];
  expandAndShow(newRow.id);
}

function handleAddPage() {
  const parentId = selectedRow.value?.resourceType === 'DIRECTORY'
    ? selectedRow.value.id
    : selectedRow.value?.parentId || null;
  const newRow = {
    _isNew: true, id: Date.now(),
    resourceName: '新页面', resourceType: 'PAGE',
    pageCode: '', isHardcoded: 0, icon: 'mdi:file-document',
    route: '', parentId, sortOrder: 0
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
  gridApi.value?.forEachNode(node => { if (node.data?._dirty || node.data?._isNew) dirtyRows.push(node.data); });
  if (dirtyRows.length === 0) { message.info('没有需要保存的修改'); return; }
  for (const row of dirtyRows) {
    if (!row.resourceName) { message.warning('名称不能为空'); return; }
  }
  try {
    await Promise.all(dirtyRows.map(r => {
      const toSave = { ...r };
      delete toSave._treePath;
      if (toSave._isNew) { delete toSave.id; delete toSave._isNew; delete toSave._dirty; }
      return saveResource(toSave);
    }));
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
  try {
    await deleteResource(selectedRow.value.id);
    message.success('删除成功');
    await loadData();
  } catch (e) {
    message.error('删除失败');
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
        <NButton size="small" type="primary" @click="handleAddDirectory">新增目录</NButton>
        <NPopconfirm @positive-click="handleDelete">
          <template #trigger>
            <NButton size="small" type="error" :disabled="!selectedRow">删除</NButton>
          </template>
          确定删除选中记录？
        </NPopconfirm>
        <NButton size="small" @click="handleSave">保存</NButton>
        <NButton size="small" quaternary @click="loadData">刷新</NButton>
      </NSpace>
    </div>
    <div class="grid-wrapper">
      <AgGridVue
        class="ag-theme-quartz"
        style="width: 100%; height: 100%"
        :rowData="rowData"
        :columnDefs="columnDefs"
        :defaultColDef="defaultColDef"
        :suppressScrollOnNewData="true"
        :treeData="true"
        :getDataPath="getDataPath"
        :autoGroupColumnDef="autoGroupColumnDef"
        :groupDefaultExpanded="0"
        :rowSelection="{ mode: 'singleRow', checkboxes: false }"
        :getRowId="(params: any) => String(params.data.id)"
        :cellSelection="true"
        :getContextMenuItems="getContextMenuItems"
        @grid-ready="onGridReady"
        @selection-changed="onSelectionChanged"
        @row-clicked="onRowClicked"
        @cell-value-changed="onCellValueChanged"
      />
    </div>
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
