<template>
  <div class="meta-grid" @contextmenu.prevent="onContextMenu">
    <!-- 标题栏 -->
    <div class="meta-grid-header">
      <div class="meta-grid-header-left">
        <NInput
          v-model:value="quickFilterText"
          placeholder="全文搜索..."
          clearable
          size="small"
          class="quick-filter-input"
          @update:value="onQuickFilterChange"
        >
          <template #prefix>
            <span class="i-carbon-search text-14px" />
          </template>
        </NInput>
        <NButton v-if="isMasterGrid" size="small" @click="showAdvancedSearch = true">
          高级查询
        </NButton>
      </div>
      <div class="meta-grid-header-right">
        <span v-if="isMasterGrid" class="selection-info">选中 {{ selectedCount }} 项</span>
        <span v-else class="current-master">当前: {{ currentMasterLabel }}</span>
        <span class="total-info">共 {{ totalCount }} 条</span>
      </div>
    </div>

    <!-- 表格标题 -->
    <div class="meta-grid-title">{{ gridTitle }}</div>

    <!-- AG Grid -->
    <div :style="{ height: gridHeight + 'px', width: '100%' }">
      <AgGridVue
        ref="gridRef"
        style="height: 100%; width: 100%"
        :theme="theme"
        :columnDefs="columnDefs"
        :rowData="rowData"
        :defaultColDef="defaultColDef"
        :rowSelection="rowSelection"
        @grid-ready="onGridReady"
        @selection-changed="onSelectionChanged"
        @cell-clicked="onCellClicked"
      />
    </div>

    <!-- 右键菜单 -->
    <NDropdown
      :show="showContextMenu"
      :x="contextMenuX"
      :y="contextMenuY"
      :options="contextMenuOptions"
      placement="bottom-start"
      @clickoutside="showContextMenu = false"
      @select="onContextMenuSelect"
    />

    <!-- 高级查询弹窗 -->
    <NModal v-model:show="showAdvancedSearch" preset="card" title="高级查询" style="width: 600px">
      <NForm :model="advancedForm" label-placement="left" :label-width="80">
        <NGrid :cols="2" :x-gap="12" :y-gap="8">
          <NFormItemGi v-for="col in allSearchableColumns" :key="col.fieldName" :label="col.headerText">
            <NInput
              v-if="col.dataType === 'text'"
              v-model:value="advancedForm[col.fieldName]"
              :placeholder="'请输入' + col.headerText"
              clearable
              size="small"
            />
            <NInputNumber
              v-else-if="col.dataType === 'number'"
              v-model:value="advancedForm[col.fieldName]"
              :placeholder="'请输入' + col.headerText"
              clearable
              size="small"
              class="w-full"
            />
            <NDatePicker
              v-else-if="col.dataType === 'date'"
              v-model:value="advancedForm[col.fieldName]"
              type="date"
              clearable
              size="small"
              class="w-full"
            />
          </NFormItemGi>
        </NGrid>
      </NForm>
      <template #footer>
        <NSpace justify="end">
          <NButton size="small" @click="handleResetAdvanced">重置</NButton>
          <NButton type="primary" size="small" @click="handleAdvancedSearch">查询</NButton>
        </NSpace>
      </template>
    </NModal>

    <!-- Lookup 弹窗 -->
    <MetaLookup ref="lookupRef" :config="currentLookupConfig" @select="onLookupSelect" />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, reactive, h } from 'vue';
import { AgGridVue } from 'ag-grid-vue3';
import { ModuleRegistry, AllCommunityModule, themeQuartz } from 'ag-grid-community';
import type { GridApi, ColDef, CellClickedEvent } from 'ag-grid-community';
import { NInput, NButton, NModal, NForm, NFormItemGi, NGrid, NInputNumber, NDatePicker, NSpace, NDropdown, useMessage, useDialog } from 'naive-ui';
import { fetchDynamicData, deleteDynamicData } from '@/service/api';
import MetaLookup from './MetaLookup.vue';

if (!(window as any).__AG_GRID_REGISTERED__) {
  ModuleRegistry.registerModules([AllCommunityModule]);
  (window as any).__AG_GRID_REGISTERED__ = true;
}

const theme = themeQuartz;
const message = useMessage();
const dialog = useDialog();

const props = defineProps<{
  config: Api.Metadata.PageComponent;
  pageContext: any;
}>();

const emit = defineEmits<{
  create: [];
  edit: [row: any];
}>();

const gridApi = ref<GridApi>();
const rowData = ref<any[]>([]);
const quickFilterText = ref('');
const showAdvancedSearch = ref(false);
const advancedForm = reactive<Record<string, any>>({});
const totalCount = ref(0);

// 右键菜单状态
const showContextMenu = ref(false);
const contextMenuX = ref(0);
const contextMenuY = ref(0);

// Lookup 相关
const lookupRef = ref<InstanceType<typeof MetaLookup>>();
const currentLookupConfig = ref({ tableCode: '', displayField: '', mapping: {} });
const currentLookupRowIndex = ref<number>(-1);

const contextMenuOptions = computed(() => [
  { label: '新增', key: 'create', icon: renderIcon('i-carbon-add') },
  { label: '编辑', key: 'edit', icon: renderIcon('i-carbon-edit'), disabled: selectedCount.value === 0 },
  { label: '删除', key: 'delete', icon: renderIcon('i-carbon-trash-can'), disabled: selectedCount.value === 0 },
  { type: 'divider', key: 'd1' },
  { label: '刷新', key: 'refresh', icon: renderIcon('i-carbon-refresh') }
]);

function renderIcon(iconClass: string) {
  return () => h('span', { class: iconClass });
}

const gridConfig = computed(() => {
  try {
    return JSON.parse(props.config.componentConfig || '{}');
  } catch {
    return {};
  }
});

const gridHeight = computed(() => gridConfig.value.height || 300);
const gridTitle = computed(() => gridConfig.value.title || props.config.refTableCode || '');

const metadata = computed(() => props.pageContext.metadata[props.config.refTableCode || '']);
const isDetailGrid = computed(() => !!metadata.value?.parentTableCode);
const isMasterGrid = computed(() => {
  const currentTableCode = props.config.refTableCode;
  if (!currentTableCode) return false;
  for (const key in props.pageContext.metadata) {
    if (props.pageContext.metadata[key]?.parentTableCode === currentTableCode) return true;
  }
  return false;
});
const parentFkColumn = computed(() => metadata.value?.parentFkColumn);

const rowSelection = computed(() => {
  if (isMasterGrid.value) {
    return { mode: 'singleRow', checkboxes: false, enableClickSelection: true } as const;
  }
  return { mode: 'multiRow', checkboxes: true, enableClickSelection: true } as const;
});

const selectedCount = computed(() => props.pageContext.selectedRows[props.config.componentKey]?.length || 0);

const currentMasterLabel = computed(() => {
  const masterGridKey = gridConfig.value.masterGrid || findMasterGridKey();
  const selected = props.pageContext.selectedRows[masterGridKey];
  if (selected?.length) {
    return selected[0].orderNo || selected[0].code || selected[0].id || '-';
  }
  return '-';
});

// 解析列的 rulesConfig
function parseRulesConfig(col: Api.Metadata.ColumnMetadata) {
  try {
    return JSON.parse(col.rulesConfig || '{}');
  } catch {
    return {};
  }
}

// 生成列定义，支持 lookup 类型
const columnDefs = computed<ColDef[]>(() => {
  if (!metadata.value?.columns) return [];
  return metadata.value.columns
    .filter(col => col.fieldName !== 'id' && col.fieldName !== 'orderId')
    .sort((a, b) => a.displayOrder - b.displayOrder)
    .map(col => {
      const rules = parseRulesConfig(col);
      const colDef: ColDef = {
        field: col.fieldName,
        headerName: col.headerText,
        width: col.width || 120,
        sortable: true,
        filter: col.searchable,
        editable: col.editable && !rules.lookup // lookup 列不直接编辑
      };
      // 如果是 lookup 类型，添加样式标识
      if (rules.lookup) {
        colDef.cellClass = 'lookup-cell';
        colDef.cellStyle = { cursor: 'pointer', color: '#1890ff' };
      }
      return colDef;
    });
});

// 获取列的 lookup 配置
function getLookupConfig(fieldName: string) {
  const col = metadata.value?.columns?.find((c: Api.Metadata.ColumnMetadata) => c.fieldName === fieldName);
  if (!col) return null;
  const rules = parseRulesConfig(col);
  return rules.lookup || null;
}

const allSearchableColumns = computed(() => {
  const cols: Api.Metadata.ColumnMetadata[] = [];
  for (const key in props.pageContext.metadata) {
    const meta = props.pageContext.metadata[key];
    if (meta?.columns) {
      meta.columns.filter((c: Api.Metadata.ColumnMetadata) => c.searchable).forEach((c: Api.Metadata.ColumnMetadata) => {
        cols.push({ ...c, headerText: `${meta.tableName}-${c.headerText}` });
      });
    }
  }
  return cols;
});

const defaultColDef: ColDef = { resizable: true, sortable: true };

function onGridReady(params: { api: GridApi }) {
  gridApi.value = params.api;
  props.pageContext.refresh[props.config.componentKey] = loadData;
}

function onSelectionChanged() {
  props.pageContext.selectedRows[props.config.componentKey] = gridApi.value?.getSelectedRows() || [];
}

function onQuickFilterChange(value: string) {
  gridApi.value?.setGridOption('quickFilterText', value);
}

// 单元格点击 - 处理 Lookup
function onCellClicked(event: CellClickedEvent) {
  const fieldName = event.colDef.field;
  if (!fieldName) return;
  
  const lookupConfig = getLookupConfig(fieldName);
  if (lookupConfig) {
    currentLookupConfig.value = lookupConfig;
    currentLookupRowIndex.value = event.rowIndex ?? -1;
    lookupRef.value?.open();
  }
}

// Lookup 选择回调
function onLookupSelect(data: Record<string, any>) {
  if (currentLookupRowIndex.value < 0) return;
  
  const rowNode = gridApi.value?.getDisplayedRowAtIndex(currentLookupRowIndex.value);
  if (rowNode) {
    // 更新行数据
    const updatedData = { ...rowNode.data, ...data };
    rowNode.setData(updatedData);
    // 同步到 rowData
    const idx = rowData.value.findIndex(r => r.id === updatedData.id);
    if (idx >= 0) rowData.value[idx] = updatedData;
  }
}

// 右键菜单
function onContextMenu(e: MouseEvent) {
  e.preventDefault();
  showContextMenu.value = true;
  contextMenuX.value = e.clientX;
  contextMenuY.value = e.clientY;
}

function onContextMenuSelect(key: string) {
  showContextMenu.value = false;
  switch (key) {
    case 'create':
      emit('create');
      break;
    case 'edit':
      handleEdit();
      break;
    case 'delete':
      handleDelete();
      break;
    case 'refresh':
      loadData();
      break;
  }
}

function handleEdit() {
  const selected = props.pageContext.selectedRows[props.config.componentKey];
  if (selected?.length === 1) {
    emit('edit', selected[0]);
  } else {
    message.warning('请选择一条数据');
  }
}

async function handleDelete() {
  const selected = props.pageContext.selectedRows[props.config.componentKey];
  if (!selected?.length) {
    message.warning('请选择要删除的数据');
    return;
  }
  dialog.warning({
    title: '确认删除',
    content: `确定删除选中的 ${selected.length} 条数据？`,
    positiveText: '确定',
    negativeText: '取消',
    onPositiveClick: async () => {
      const tableCode = props.config.refTableCode;
      if (!tableCode) return;
      for (const row of selected) {
        await deleteDynamicData(tableCode, row.id);
      }
      message.success('删除成功');
      loadData();
    }
  });
}

function handleAdvancedSearch() {
  showAdvancedSearch.value = false;
  loadData();
}

function handleResetAdvanced() {
  Object.keys(advancedForm).forEach(k => (advancedForm[k] = undefined));
}

async function loadData() {
  if (!props.config.refTableCode) return;
  const params: Record<string, any> = { ...advancedForm };

  if (isDetailGrid.value && parentFkColumn.value) {
    const masterGridKey = gridConfig.value.masterGrid || findMasterGridKey();
    const selectedMaster = props.pageContext.selectedRows[masterGridKey];
    if (!selectedMaster?.length) {
      rowData.value = [];
      totalCount.value = 0;
      return;
    }
    params[parentFkColumn.value] = selectedMaster[0].id;
  }

  const { data, error } = await fetchDynamicData(props.config.refTableCode, params);
  if (!error && data) {
    rowData.value = data.list || [];
    totalCount.value = data.total || 0;
    if (!isDetailGrid.value && rowData.value.length > 0) {
      setTimeout(() => gridApi.value?.getDisplayedRowAtIndex(0)?.setSelected(true), 0);
    }
  }
}

function findMasterGridKey(): string {
  for (const key in props.pageContext.refresh) {
    if (key.toLowerCase().includes('master')) return key;
  }
  return 'masterGrid';
}

watch(() => metadata.value, (meta) => {
  if (meta && !meta.parentTableCode && gridApi.value) loadData();
}, { immediate: true });

watch(() => {
  if (!isDetailGrid.value) return null;
  const masterGridKey = gridConfig.value.masterGrid || findMasterGridKey();
  return props.pageContext.selectedRows[masterGridKey];
}, (newVal) => {
  if (isDetailGrid.value && newVal !== null) loadData();
}, { deep: true });
</script>

<style scoped>
.meta-grid {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.meta-grid-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 4px 0;
}
.meta-grid-header-left {
  display: flex;
  align-items: center;
  gap: 8px;
}
.quick-filter-input {
  width: 200px;
}
.meta-grid-header-right {
  display: flex;
  align-items: center;
  gap: 12px;
  font-size: 12px;
  color: #666;
}
.meta-grid-title {
  font-size: 14px;
  font-weight: 500;
  padding: 4px 0;
  border-bottom: 1px solid #e8e8e8;
}
</style>
