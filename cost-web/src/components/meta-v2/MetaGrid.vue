<template>
  <div class="meta-grid" :style="{ height: height }">
    <AgGridVue
      style="height: 100%; width: 100%"
      :theme="theme"
      :columnDefs="columnDefs"
      :rowData="rowData"
      :defaultColDef="defaultColDef"
      :rowSelection="rowSelectionConfig"
      :getRowId="getRowId"
      @grid-ready="onGridReady"
      @selection-changed="onSelectionChanged"
      @cell-value-changed="onCellValueChanged"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { AgGridVue } from 'ag-grid-vue3';
import { ModuleRegistry, AllCommunityModule, themeQuartz } from 'ag-grid-community';
import type { GridApi, ColDef, CellValueChangedEvent, GetRowIdParams, CellClassParams } from 'ag-grid-community';
import type { GridStore } from '@/composables/useGridStore';
import type { CalcEngine } from '@/composables/useCalcEngine';

// 注册 AG Grid 模块（全局只注册一次）
if (!(window as any).__AG_GRID_REGISTERED__) {
  ModuleRegistry.registerModules([AllCommunityModule]);
  (window as any).__AG_GRID_REGISTERED__ = true;
}

const props = withDefaults(defineProps<{
  /** 列定义 */
  columns: ColDef[];
  /** 数据存储 */
  store: GridStore;
  /** 计算引擎（可选） */
  calcEngine?: CalcEngine;
  /** 高度 */
  height?: string;
  /** 主键字段 */
  pkField?: string;
  /** 是否启用选择 */
  selectable?: boolean;
  /** 选择模式 */
  selectionMode?: 'single' | 'multi';
  /** 是否显示复选框 */
  showCheckbox?: boolean;
}>(), {
  height: '100%',
  pkField: 'id',
  selectable: true,
  selectionMode: 'single',
  showCheckbox: false
});

const emit = defineEmits<{
  (e: 'ready', api: GridApi): void;
  (e: 'selectionChanged', rows: any[]): void;
  (e: 'cellChanged', params: { field: string; rowId: any; oldValue: any; newValue: any; data: any }): void;
}>();

const theme = themeQuartz;
const gridApi = ref<GridApi>();

// 列定义（添加单元格样式）
const columnDefs = computed<ColDef[]>(() => {
  return props.columns.map(col => ({
    ...col,
    cellStyle: col.cellStyle || getCellStyle
  }));
});

// 行数据
const rowData = computed(() => props.store.visibleRows.value);

// 监听 store 数据变化，自动刷新 Grid
watch(() => props.store.rows.value, () => {
  if (gridApi.value) {
    gridApi.value.setGridOption('rowData', [...props.store.visibleRows.value]);
  }
}, { deep: true });

// 默认列配置
const defaultColDef: ColDef = {
  resizable: true,
  sortable: true
};

// 行选择配置
const rowSelectionConfig = computed(() => {
  if (!props.selectable) return undefined;
  return {
    mode: props.selectionMode === 'multi' ? 'multiRow' : 'singleRow',
    checkboxes: props.showCheckbox,
    enableClickSelection: true
  } as const;
});

// 获取行ID
function getRowId(params: GetRowIdParams) {
  return String(params.data[props.pkField]);
}

// 单元格样式（变更追踪）
function getCellStyle(params: CellClassParams) {
  const changeType = params.data?._changeType?.[params.colDef?.field || ''];
  if (changeType === 'user') return { backgroundColor: '#e6ffe6' };
  if (changeType === 'cascade') return { backgroundColor: '#fffde6' };
  return null;
}

// Grid 就绪
function onGridReady(params: { api: GridApi }) {
  gridApi.value = params.api;
  emit('ready', params.api);
}

// 选择变化
function onSelectionChanged() {
  const selected = gridApi.value?.getSelectedRows() || [];
  emit('selectionChanged', selected);
}

// 单元格值变化
function onCellValueChanged(event: CellValueChangedEvent) {
  const field = event.colDef.field;
  const rowId = event.data?.[props.pkField];
  
  if (!field || rowId === undefined || rowId === null) return;

  // 同步到 store（store 是数据源）
  props.store.markChange(rowId, field, 'user');
  
  // 触发计算引擎（会更新 store 中的计算字段）
  if (props.calcEngine) {
    props.calcEngine.onFieldChange(rowId, field);
  }

  // 从 store 获取最新数据，同步回 AG Grid
  const row = props.store.getRow(rowId);
  if (row && gridApi.value) {
    // 用 store 数据更新 AG Grid（包含 _changeType）
    gridApi.value.applyTransaction({ update: [row] });
    // 强制刷新单元格样式
    const rowNode = gridApi.value.getRowNode(String(rowId));
    if (rowNode) {
      gridApi.value.refreshCells({ rowNodes: [rowNode], force: true });
    }
  }

  emit('cellChanged', {
    field,
    rowId,
    oldValue: event.oldValue,
    newValue: event.newValue,
    data: event.data
  });
}

// 刷新行
function refreshRow(rowId: any) {
  const row = props.store.getRow(rowId);
  if (row && gridApi.value) {
    // 先更新数据
    gridApi.value.applyTransaction({ update: [row] });
    // 强制刷新单元格样式
    const rowNode = gridApi.value.getRowNode(String(rowId));
    if (rowNode) {
      gridApi.value.refreshCells({ rowNodes: [rowNode], force: true });
    }
  }
}

// 刷新所有行
function refreshAll() {
  if (gridApi.value) {
    // 使用 applyTransaction 强制刷新所有行
    const rows = props.store.visibleRows.value;
    gridApi.value.applyTransaction({ update: rows });
  }
}

// 前端搜索
function quickFilter(text: string) {
  gridApi.value?.setGridOption('quickFilterText', text);
}

// 暴露方法
defineExpose({
  gridApi,
  refreshRow,
  refreshAll,
  quickFilter
});
</script>

<style scoped>
.meta-grid {
  width: 100%;
  overflow: hidden;
}
</style>
