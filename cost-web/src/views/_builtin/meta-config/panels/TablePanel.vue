<script setup lang="ts">
import { ref, onMounted, watch, inject } from 'vue';
import type { Ref } from 'vue';
import { NButton, NSpace, NPopconfirm, NModal, NDataTable, useMessage } from 'naive-ui';
import type { DataTableColumns, DataTableRowKey } from 'naive-ui';
import { AgGridVue } from 'ag-grid-vue3';
import type { GridApi, GridReadyEvent, ColDef, CellValueChangedEvent } from 'ag-grid-community';
import {
  fetchAllTableMeta, saveTableMeta, deleteTableMeta,
  fetchColumnsByTableId, saveColumnMeta, deleteColumnMeta,
  fetchViewColumns, fetchTablesByPageCode
} from '@/service/api/meta-config';

const message = useMessage();
const filterState = inject<Ref<{ tab: string; pageCode: string } | null>>('filterState');

// ==================== 上半区: 表元数据 ====================
const tableGridApi = ref<GridApi | null>(null);
const tableRows = ref<any[]>([]);
const selectedTable = ref<any>(null);

const tableColDefs: ColDef[] = [
  { field: 'id', headerName: 'ID', width: 70, editable: false },
  { field: 'tableCode', headerName: 'tableCode', width: 140, editable: true },
  { field: 'tableName', headerName: '表名称', width: 140, editable: true },
  { field: 'queryView', headerName: 'queryView', width: 180, editable: true },
  { field: 'targetTable', headerName: 'targetTable', width: 180, editable: true },
  { field: 'sequenceName', headerName: '序列名', width: 160, editable: true },
  { field: 'pkColumn', headerName: '主键列', width: 100, editable: true },
  { field: 'parentTableCode', headerName: '父表Code', width: 130, editable: true },
  { field: 'parentFkColumn', headerName: '外键列', width: 120, editable: true }
];

// ==================== 下半区: 列元数据 ====================
const colGridApi = ref<GridApi | null>(null);
const colRows = ref<any[]>([]);
const selectedCol = ref<any>(null);

const colColDefs: ColDef[] = [
  { field: 'id', headerName: 'ID', width: 70, editable: false },
  { field: 'fieldName', headerName: 'fieldName', width: 120, editable: true },
  { field: 'columnName', headerName: 'columnName', width: 120, editable: true },
  { field: 'queryColumn', headerName: 'queryColumn', width: 140, editable: true },
  { field: 'targetColumn', headerName: 'targetColumn', width: 130, editable: true },
  { field: 'headerText', headerName: '列标题', width: 120, editable: true },
  {
    field: 'dataType', headerName: '数据类型', width: 100, editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: ['text', 'number', 'date', 'select', 'checkbox'] }
  },
  { field: 'displayOrder', headerName: '排序', width: 70, editable: true, cellDataType: 'number' },
  {
    field: 'sortable', headerName: '可排序', width: 80, editable: true,
    cellRenderer: 'agCheckboxCellRenderer', cellEditor: 'agCheckboxCellEditor',
    valueGetter: (p: any) => p.data?.sortable === 1,
    valueSetter: (p: any) => { p.data.sortable = p.newValue ? 1 : 0; return true; }
  },
  {
    field: 'filterable', headerName: '可筛选', width: 80, editable: true,
    cellRenderer: 'agCheckboxCellRenderer', cellEditor: 'agCheckboxCellEditor',
    valueGetter: (p: any) => p.data?.filterable === 1,
    valueSetter: (p: any) => { p.data.filterable = p.newValue ? 1 : 0; return true; }
  },
  {
    field: 'isVirtual', headerName: '虚拟列', width: 80, editable: true,
    cellRenderer: 'agCheckboxCellRenderer', cellEditor: 'agCheckboxCellEditor',
    valueGetter: (p: any) => p.data?.isVirtual === 1,
    valueSetter: (p: any) => { p.data.isVirtual = p.newValue ? 1 : 0; return true; }
  },
  { field: 'dictType', headerName: '字典类型', width: 120, editable: true }
];

const defaultColDef: ColDef = { sortable: true, resizable: true, flex: 0, suppressHeaderMenuButton: true };

async function loadTables() {
  try {
    const res = await fetchAllTableMeta();
    tableRows.value = res || [];
    setTimeout(() => tableGridApi.value?.autoSizeAllColumns(), 100);
  } catch { message.error('加载表元数据失败'); }
}

async function loadColumns(tableMetadataId: number) {
  try {
    const res = await fetchColumnsByTableId(tableMetadataId);
    colRows.value = res || [];
    setTimeout(() => colGridApi.value?.autoSizeAllColumns(), 100);
  } catch { message.error('加载列元数据失败'); }
}

function onTableGridReady(params: GridReadyEvent) { tableGridApi.value = params.api; params.api.autoSizeAllColumns(); }
function onColGridReady(params: GridReadyEvent) { colGridApi.value = params.api; params.api.autoSizeAllColumns(); }

function onTableSelectionChanged() {
  const rows = tableGridApi.value?.getSelectedRows() || [];
  selectedTable.value = rows[0] || null;
  if (selectedTable.value?.id) {
    loadColumns(selectedTable.value.id);
  } else {
    colRows.value = [];
  }
}

function onTableRowClicked(event: any) {
  if (event.node?.data) {
    event.node.setSelected(true, true);
  }
}

function onColSelectionChanged() {
  const rows = colGridApi.value?.getSelectedRows() || [];
  selectedCol.value = rows[0] || null;
}

function onColRowClicked(event: any) {
  if (event.node?.data) {
    event.node.setSelected(true, true);
  }
}

// ---- 表操作 ----
function addTable() {
  const newRow = { _isNew: true, id: null, tableCode: '', tableName: '', queryView: '', targetTable: '', sequenceName: '', pkColumn: 'ID', parentTableCode: '', parentFkColumn: '' };
  tableRows.value = [...tableRows.value, newRow];
  setTimeout(() => {
    const idx = tableRows.value.length - 1;
    tableGridApi.value?.ensureIndexVisible(idx);
    tableGridApi.value?.startEditingCell({ rowIndex: idx, colKey: 'tableCode' });
  }, 100);
}

async function saveTable() {
  const dirtyRows = tableRows.value.filter(r => r._dirty || r._isNew);
  if (dirtyRows.length === 0) { message.info('没有需要保存的修改'); return; }
  for (const row of dirtyRows) {
    if (!row.tableCode || !row.tableName) { message.warning('tableCode和表名称不能为空'); return; }
  }
  try {
    await Promise.all(dirtyRows.map(r => saveTableMeta(r)));
    message.success(`已保存 ${dirtyRows.length} 条表记录`);
    await loadTables();
  } catch { message.error('保存失败'); }
}

async function removeTable() {
  if (!selectedTable.value) return;
  if (selectedTable.value._isNew) {
    tableRows.value = tableRows.value.filter(r => r !== selectedTable.value);
    return;
  }
  try {
    await deleteTableMeta(selectedTable.value.id);
    message.success('删除成功');
    await loadTables();
    colRows.value = [];
  } catch { message.error('删除失败'); }
}

// ---- 列操作 ----
function addColumn() {
  if (!selectedTable.value?.id) { message.warning('请先选中一个表'); return; }
  const newRow = {
    _isNew: true, id: null, tableMetadataId: selectedTable.value.id,
    fieldName: '', columnName: '', queryColumn: '', targetColumn: '',
    headerText: '', dataType: 'text', displayOrder: 0,
    sortable: 1, filterable: 1, isVirtual: 0, dictType: ''
  };
  colRows.value = [...colRows.value, newRow];
  setTimeout(() => {
    const idx = colRows.value.length - 1;
    colGridApi.value?.ensureIndexVisible(idx);
    colGridApi.value?.startEditingCell({ rowIndex: idx, colKey: 'fieldName' });
  }, 100);
}

async function saveColumn() {
  const dirtyRows = colRows.value.filter(r => r._dirty || r._isNew);
  if (dirtyRows.length === 0) { message.info('没有需要保存的修改'); return; }
  for (const row of dirtyRows) {
    if (!row.fieldName || !row.columnName) { message.warning('fieldName和columnName不能为空'); return; }
  }
  try {
    await Promise.all(dirtyRows.map(r => saveColumnMeta(r)));
    message.success(`已保存 ${dirtyRows.length} 条列记录`);
    if (selectedTable.value?.id) await loadColumns(selectedTable.value.id);
  } catch { message.error('保存失败'); }
}

async function removeColumn() {
  if (!selectedCol.value) return;
  if (selectedCol.value._isNew) {
    colRows.value = colRows.value.filter(r => r !== selectedCol.value);
    return;
  }
  try {
    await deleteColumnMeta(selectedCol.value.id);
    message.success('删除成功');
    if (selectedTable.value?.id) await loadColumns(selectedTable.value.id);
  } catch { message.error('删除失败'); }
}

function markDirty(event: CellValueChangedEvent) {
  if (event.data) event.data._dirty = true;
}

// ---- 从视图结构新增列（弹窗多选） ----
const showViewColModal = ref(false);
const viewColLoading = ref(false);
const viewColRows = ref<any[]>([]);
const viewColCheckedKeys = ref<DataTableRowKey[]>([]);
const targetTableCols = new Set<string>();

const viewColTableColumns: DataTableColumns = [
  { type: 'selection' },
  { title: 'COLUMN_NAME', key: 'COLUMN_NAME', width: 200 },
  { title: 'DATA_TYPE', key: 'DATA_TYPE', width: 120 },
  { title: 'DATA_LENGTH', key: 'DATA_LENGTH', width: 100 },
  { title: 'DATA_PRECISION', key: 'DATA_PRECISION', width: 120 },
  { title: 'DATA_SCALE', key: 'DATA_SCALE', width: 100 },
  { title: 'COLUMN_ID', key: 'COLUMN_ID', width: 100 }
];

/** Oracle DATA_TYPE -> 前端 dataType 映射 */
function mapOracleType(oracleType: string): string {
  if (!oracleType) return 'text';
  const t = oracleType.toUpperCase();
  if (t.includes('NUMBER') || t.includes('FLOAT') || t.includes('DECIMAL') || t.includes('INTEGER')) return 'number';
  if (t.includes('DATE') || t.includes('TIMESTAMP')) return 'date';
  return 'text';
}

/** COLUMN_NAME -> camelCase fieldName */
function toCamelCase(col: string): string {
  return col.toLowerCase().replace(/_([a-z])/g, (_, c) => c.toUpperCase());
}

async function openViewColModal() {
  if (!selectedTable.value?.id) { message.warning('请先选中一个表'); return; }
  const viewName = selectedTable.value.queryView;
  if (!viewName) { message.warning('当前表未配置 queryView'); return; }
  showViewColModal.value = true;
  viewColLoading.value = true;
  viewColCheckedKeys.value = [];
  targetTableCols.clear();
  try {
    const [viewRes, targetRes] = await Promise.all([
      fetchViewColumns(viewName),
      selectedTable.value.targetTable ? fetchViewColumns(selectedTable.value.targetTable) : Promise.resolve([])
    ]);
    (targetRes || []).forEach((r: any) => targetTableCols.add((r.COLUMN_NAME || '').toUpperCase()));
    const existingCols = new Set(colRows.value.map((c: any) => (c.columnName || '').toUpperCase()));
    const auditCols = new Set(['CREATE_TIME', 'UPDATE_TIME', 'CREATE_BY', 'UPDATE_BY', 'DELETED']);
    viewColRows.value = (viewRes || [])
      .filter((r: any) => {
        const col = (r.COLUMN_NAME || '').toUpperCase();
        return !existingCols.has(col) && !auditCols.has(col);
      })
      .map((r: any) => ({ ...r, _key: r.COLUMN_NAME }));
  } catch {
    message.error('查询视图列失败');
    viewColRows.value = [];
  } finally {
    viewColLoading.value = false;
  }
}

function confirmAddViewCols() {
  if (!viewColCheckedKeys.value.length) { message.warning('请至少选择一列'); return; }
  const existingOrder = colRows.value.length;
  const selected = viewColRows.value.filter(r => viewColCheckedKeys.value.includes(r._key));
  const newRows = selected.map((r, i) => {
    const colName = r.COLUMN_NAME;
    const inTarget = targetTableCols.has((colName || '').toUpperCase());
    return {
      _isNew: true,
      id: null,
      tableMetadataId: selectedTable.value.id,
      fieldName: toCamelCase(colName),
      columnName: colName,
      queryColumn: inTarget ? colName : '',
      targetColumn: inTarget ? colName : '',
      headerText: colName,
      dataType: mapOracleType(r.DATA_TYPE),
      displayOrder: existingOrder + i + 1,
      sortable: 1,
      filterable: 1,
      isVirtual: inTarget ? 0 : 1,
      dictType: ''
    };
  });
  colRows.value = [...colRows.value, ...newRows];
  showViewColModal.value = false;
  message.success(`已添加 ${newRows.length} 列，请编辑后保存`);
}

// ---- 拖动调整大小 ----
const topHeight = ref(300);
let startY = 0;
let startHeight = 0;

function onResizeStart(e: MouseEvent) {
  startY = e.clientY;
  startHeight = topHeight.value;
  document.addEventListener('mousemove', onResizeMove);
  document.addEventListener('mouseup', onResizeEnd);
  document.body.style.cursor = 'row-resize';
  document.body.style.userSelect = 'none';
}

function onResizeMove(e: MouseEvent) {
  const delta = e.clientY - startY;
  topHeight.value = Math.max(80, startHeight + delta);
}

function onResizeEnd() {
  document.removeEventListener('mousemove', onResizeMove);
  document.removeEventListener('mouseup', onResizeEnd);
  document.body.style.cursor = '';
  document.body.style.userSelect = '';
}

onMounted(() => {
  // 如果是跳转过来的，不加载全量，由 watch 处理
  if (filterState?.value?.tab === 'table') return;
  loadTables();
});

// 从页面管理跳转过来时，后端直接查关联的表
watch(() => filterState?.value, async (state) => {
  if (!state || state.tab !== 'table') return;
  const pageCode = state.pageCode;
  try {
    const tables = await fetchTablesByPageCode(pageCode);
    if (!tables.length) { message.warning(`pageCode="${pageCode}" 未关联任何表`); return; }
    tableRows.value = tables;
    setTimeout(() => {
      tableGridApi.value?.autoSizeAllColumns();
      const firstNode = tableGridApi.value?.getDisplayedRowAtIndex(0);
      if (firstNode) {
        firstNode.setSelected(true);
        selectedTable.value = firstNode.data;
        if (firstNode.data?.id) loadColumns(firstNode.data.id);
      }
    }, 150);
  } catch { message.error('查询关联表失败'); }
}, { immediate: true });
</script>

<template>
  <div class="panel-container">
    <!-- 上半区: 表元数据 -->
    <div class="section" :style="{ flex: `0 0 ${topHeight}px` }">
      <div class="section-toolbar">
        <NSpace size="small">
          <NButton size="small" type="primary" @click="addTable">新增</NButton>
          <NPopconfirm @positive-click="removeTable">
            <template #trigger>
              <NButton size="small" type="error" :disabled="!selectedTable">删除</NButton>
            </template>
            确定删除？
          </NPopconfirm>
          <NButton size="small" @click="saveTable">保存</NButton>
          <NButton size="small" quaternary @click="loadTables">刷新</NButton>
        </NSpace>
      </div>
      <div class="grid-wrapper">
        <AgGridVue
          class="ag-theme-quartz"
          style="width: 100%; height: 100%"
          :rowData="tableRows"
          :columnDefs="tableColDefs"
          :defaultColDef="defaultColDef"
          :rowSelection="{ mode: 'singleRow', checkboxes: false }"
          :cellSelection="true"
          @grid-ready="onTableGridReady"
          @selection-changed="onTableSelectionChanged"
          @row-clicked="onTableRowClicked"
          @cell-value-changed="markDirty"
        />
      </div>
    </div>

    <!-- 拖动条 -->
    <div class="resizer" @mousedown="onResizeStart" />

    <!-- 下半区: 列元数据 -->
    <div class="section" style="flex: 1">
      <div class="section-toolbar">
        <NSpace size="small">
          <NButton size="small" type="primary" @click="openViewColModal" :disabled="!selectedTable?.id || !selectedTable?.queryView">新增列</NButton>
          <NPopconfirm @positive-click="removeColumn">
            <template #trigger>
              <NButton size="small" type="error" :disabled="!selectedCol">删除列</NButton>
            </template>
            确定删除？
          </NPopconfirm>
          <NButton size="small" @click="saveColumn">保存列</NButton>
        </NSpace>
      </div>
      <div class="grid-wrapper">
        <AgGridVue
          class="ag-theme-quartz"
          style="width: 100%; height: 100%"
          :rowData="colRows"
          :columnDefs="colColDefs"
          :defaultColDef="defaultColDef"
          :rowSelection="{ mode: 'singleRow', checkboxes: false }"
          :cellSelection="true"
          @grid-ready="onColGridReady"
          @selection-changed="onColSelectionChanged"
          @row-clicked="onColRowClicked"
          @cell-value-changed="markDirty"
        />
      </div>
    </div>

    <!-- 从视图新增列弹窗 -->
    <NModal
      v-model:show="showViewColModal"
      preset="card"
      title="从视图选择列"
      :style="{ width: '720px' }"
      :mask-closable="true"
    >
      <NDataTable
        :columns="viewColTableColumns"
        :data="viewColRows"
        :row-key="(r: any) => r._key"
        :loading="viewColLoading"
        v-model:checked-row-keys="viewColCheckedKeys"
        :max-height="400"
        size="small"
      />
      <template #footer>
        <NSpace justify="end">
          <NButton size="small" @click="showViewColModal = false">取消</NButton>
          <NButton size="small" type="primary" @click="confirmAddViewCols" :disabled="!viewColCheckedKeys.length">
            确定添加 ({{ viewColCheckedKeys.length }})
          </NButton>
        </NSpace>
      </template>
    </NModal>
  </div>
</template>

<style scoped>
.panel-container {
  display: flex;
  flex-direction: column;
  height: 100%;
}
.section {
  display: flex;
  flex-direction: column;
  min-height: 80px;
  overflow: hidden;
}
.section-toolbar {
  flex-shrink: 0;
  padding: 4px 0;
}
.grid-wrapper {
  flex: 1;
  min-height: 0;
}
.resizer {
  flex-shrink: 0;
  height: 6px;
  cursor: row-resize;
  background: #e8e8e8;
  border-radius: 3px;
  margin: 2px 0;
  transition: background 0.2s;
}
.resizer:hover {
  background: #4096ff;
}
</style>
