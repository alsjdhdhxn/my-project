<template>
  <div 
    ref="containerRef"
    class="meta-grid" 
    :style="{ height: height }" 
    tabindex="0" 
    @keydown="onKeyDown"
    @mouseenter="onMouseEnter"
  >
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
      @cell-editing-stopped="onCellEditingStopped"
      @cell-clicked="onCellClicked"
    />
    
    <!-- Lookup 弹窗 -->
    <MetaLookup ref="lookupRef" :config="currentLookupConfig" @select="onLookupSelect" />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { AgGridVue } from 'ag-grid-vue3';
import { ModuleRegistry, AllCommunityModule, themeQuartz } from 'ag-grid-community';
import type { GridApi, ColDef, CellValueChangedEvent, GetRowIdParams, CellClassParams, CellClickedEvent } from 'ag-grid-community';
import type { GridStore } from '@/composables/useGridStore';
import type { CalcEngine } from '@/composables/useCalcEngine';
import MetaLookup from '@/components/meta/MetaLookup.vue';

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
  /** 新增行默认值 */
  defaultNewRow?: Record<string, any>;
  /** 新增后聚焦的字段 */
  firstEditableField?: string;
  /** 列元数据（用于 Lookup 配置） */
  columnMeta?: Api.Metadata.ColumnMetadata[];
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
  (e: 'rowAdded', row: any): void;
  (e: 'rowsDeleted', rows: any[]): void;
}>();

const theme = themeQuartz;
const gridApi = ref<GridApi>();
const containerRef = ref<HTMLElement>();

// Lookup 相关
const lookupRef = ref<InstanceType<typeof MetaLookup>>();
const currentLookupConfig = ref({ tableCode: '', displayField: '', mapping: {}, title: '' });
const currentLookupRowId = ref<any>(null);

// 鼠标进入时自动聚焦
function onMouseEnter() {
  containerRef.value?.focus();
}

// 列定义（添加单元格样式）
const columnDefs = computed<ColDef[]>(() => {
  return props.columns.map(col => {
    const lookupConfig = getLookupConfig(col.field || '');
    return {
      ...col,
      cellStyle: lookupConfig ? getLookupCellStyle : (col.cellStyle || getCellStyle),
      editable: lookupConfig ? false : col.editable // Lookup 列不可直接编辑
    };
  });
});

// 获取 Lookup 配置
function getLookupConfig(fieldName: string) {
  if (!props.columnMeta || !fieldName) return null;
  const col = props.columnMeta.find(c => c.fieldName === fieldName);
  if (!col?.rulesConfig) return null;
  try {
    const rules = JSON.parse(col.rulesConfig);
    return rules.lookup || null;
  } catch {
    return null;
  }
}

// Lookup 单元格样式
function getLookupCellStyle(params: CellClassParams) {
  const baseStyle = getCellStyle(params) || {};
  return { ...baseStyle, cursor: 'pointer', color: '#1890ff' };
}

// 行数据
const rowData = computed(() => props.store.visibleRows.value);

// 监听 store 数据变化，自动刷新 Grid
// 使用 visibleRows 的 JSON 序列化作为依赖，确保任何数据变化都能触发
watch(
  () => JSON.stringify(props.store.visibleRows.value),
  () => {
    if (gridApi.value) {
      // 使用 applyTransaction 更新，保持选中状态
      const currentRows = props.store.visibleRows.value;
      gridApi.value.setGridOption('rowData', [...currentRows]);
      // 强制刷新所有单元格样式
      gridApi.value.refreshCells({ force: true });
    }
  }
);

// 默认列配置
const defaultColDef: ColDef = {
  resizable: true,
  sortable: true,
  wrapHeaderText: true,
  autoHeaderHeight: true
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

// 键盘事件处理
function onKeyDown(event: KeyboardEvent) {
  // Ctrl+Enter 新增行（不需要焦点，只要在 Grid 容器内就行）
  if (event.ctrlKey && event.key === 'Enter') {
    event.preventDefault();
    handleAdd();
    return;
  }
  
  // 以下操作需要 Grid 有焦点
  if (!gridApi.value?.getFocusedCell()) return;
  
  // 检查是否在编辑状态
  const isEditing = gridApi.value.getEditingCells().length > 0;
  
  // Delete 删除选中行（非编辑状态）
  if (event.key === 'Delete' && !isEditing) {
    const selectedRows = gridApi.value.getSelectedRows();
    if (selectedRows.length > 0) {
      event.preventDefault();
      handleDelete(selectedRows);
    }
  }
}

// 内部新增行处理
function handleAdd() {
  const newRow = props.store.addRow(props.defaultNewRow || {});
  refreshAll();
  
  // 聚焦到新行
  setTimeout(() => {
    if (gridApi.value) {
      const rowNode = gridApi.value.getRowNode(String(newRow[props.pkField]));
      if (rowNode) {
        gridApi.value.ensureIndexVisible(rowNode.rowIndex!);
        rowNode.setSelected(true);
        
        // 如果指定了首个可编辑字段，聚焦并开始编辑
        if (props.firstEditableField) {
          gridApi.value.setFocusedCell(rowNode.rowIndex!, props.firstEditableField);
          gridApi.value.startEditingCell({ rowIndex: rowNode.rowIndex!, colKey: props.firstEditableField });
        }
      }
    }
  }, 50);
  
  emit('rowAdded', newRow);
}

// 内部删除行处理
function handleDelete(rows: any[]) {
  if (rows.length === 0) return;
  
  rows.forEach(row => {
    props.store.deleteRow(row[props.pkField]);
  });
  
  refreshAll();
  emit('rowsDeleted', rows);
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

// 编辑停止时刷新样式
function onCellEditingStopped(event: any) {
  const rowId = event.data?.[props.pkField];
  const colId = event.column?.getId();
  
  if (rowId !== undefined && rowId !== null && colId && gridApi.value) {
    const rowNode = gridApi.value.getRowNode(String(rowId));
    if (rowNode) {
      // 强制刷新该单元格的样式（必须加 force: true）
      gridApi.value.refreshCells({
        rowNodes: [rowNode],
        columns: [colId],
        force: true
      });
    }
  }
}

// 单元格点击 - 处理 Lookup
function onCellClicked(event: CellClickedEvent) {
  const fieldName = event.colDef.field;
  if (!fieldName) return;

  const lookupConfig = getLookupConfig(fieldName);
  if (lookupConfig) {
    currentLookupConfig.value = lookupConfig;
    currentLookupRowId.value = event.data?.[props.pkField];
    lookupRef.value?.open();
  }
}

// Lookup 选择回调
function onLookupSelect(data: Record<string, any>) {
  if (currentLookupRowId.value === null || currentLookupRowId.value === undefined) return;

  const row = props.store.getRow(currentLookupRowId.value);
  if (!row) return;

  const changedFields: string[] = [];

  // 先把所有字段都更新到 store
  for (const [targetField, newValue] of Object.entries(data)) {
    const oldValue = row[targetField];
    if (oldValue !== newValue) {
      props.store.updateField(currentLookupRowId.value, targetField, newValue);
      props.store.markChange(currentLookupRowId.value, targetField, 'user');
      changedFields.push(targetField);
    }
  }

  // 刷新 Grid 显示
  if (gridApi.value) {
    const updatedRow = props.store.getRow(currentLookupRowId.value);
    if (updatedRow) {
      gridApi.value.applyTransaction({ update: [updatedRow] });
      const rowNode = gridApi.value.getRowNode(String(currentLookupRowId.value));
      if (rowNode) {
        gridApi.value.refreshCells({ rowNodes: [rowNode], force: true });
      }
    }
  }

  // 触发计算引擎（所有字段更新完后再统一触发）
  if (props.calcEngine && changedFields.length > 0) {
    // 只需触发一次，传入任意一个变更字段即可触发级联计算
    // 但为了确保所有依赖都被触发，逐个调用
    changedFields.forEach(field => {
      props.calcEngine!.onFieldChange(currentLookupRowId.value, field);
    });
    
    // 再次刷新 Grid（计算后数据可能变化）
    if (gridApi.value) {
      const finalRow = props.store.getRow(currentLookupRowId.value);
      if (finalRow) {
        gridApi.value.applyTransaction({ update: [finalRow] });
        const rowNode = gridApi.value.getRowNode(String(currentLookupRowId.value));
        if (rowNode) {
          gridApi.value.refreshCells({ rowNodes: [rowNode], force: true });
        }
      }
    }
  }

  // 通知外部（用于聚合计算等）
  changedFields.forEach(field => {
    emit('cellChanged', {
      field,
      rowId: currentLookupRowId.value,
      oldValue: row[field],
      newValue: data[field],
      data: props.store.getRow(currentLookupRowId.value)
    });
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
    // 保存当前选中的行ID
    const selectedIds = gridApi.value.getSelectedRows().map(r => r[props.pkField]);
    
    const rows = props.store.visibleRows.value;
    gridApi.value.setGridOption('rowData', [...rows]);
    
    // 恢复选中状态
    if (selectedIds.length > 0) {
      setTimeout(() => {
        gridApi.value?.forEachNode(node => {
          if (selectedIds.includes(node.data?.[props.pkField])) {
            node.setSelected(true);
          }
        });
      }, 0);
    }
  }
}

// 添加行到 Grid
function addRow(row: any) {
  if (gridApi.value) {
    gridApi.value.applyTransaction({ add: [row] });
  }
}

// 从 Grid 删除行
function removeRow(rowId: any) {
  if (gridApi.value) {
    const rowNode = gridApi.value.getRowNode(String(rowId));
    if (rowNode) {
      gridApi.value.applyTransaction({ remove: [rowNode.data] });
    }
  }
}

// 获取选中行
function getSelectedRows(): any[] {
  return gridApi.value?.getSelectedRows() || [];
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
  addRow,
  removeRow,
  getSelectedRows,
  quickFilter
});
</script>

<style scoped>
.meta-grid {
  width: 100%;
  overflow: hidden;
}

/* 表头自动换行 */
.meta-grid :deep(.ag-header-cell-label) {
  white-space: normal !important;
  word-wrap: break-word;
  line-height: 1.4;
  display: flex;
  align-items: center;
  justify-content: center;
  text-align: center;
}

.meta-grid :deep(.ag-header-cell) {
  padding-top: 4px;
  padding-bottom: 4px;
}

/* 表头文字容器 */
.meta-grid :deep(.ag-header-cell-text) {
  white-space: normal !important;
  word-wrap: break-word;
  overflow: visible !important;
}

/* Lookup 单元格样式 */
.meta-grid :deep(.lookup-cell) {
  cursor: pointer;
  color: #1890ff;
}

.meta-grid :deep(.lookup-cell:hover) {
  text-decoration: underline;
}
</style>
