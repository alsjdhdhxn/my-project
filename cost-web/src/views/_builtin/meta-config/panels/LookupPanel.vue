<script setup lang="ts">
import { ref, onMounted, inject, watch } from 'vue';
import type { Ref } from 'vue';
import { NButton, NSpace, NPopconfirm, useMessage } from 'naive-ui';
import { AgGridVue } from 'ag-grid-vue3';
import type { GridApi, GridReadyEvent, ColDef, CellValueChangedEvent } from 'ag-grid-community';
import { fetchAllLookupConfigs, saveLookupConfig, deleteLookupConfig, fetchLookupCodesByPageCode } from '@/service/api/meta-config';

const message = useMessage();
const filterState = inject<Ref<{ tab: string; pageCode: string } | null>>('filterState');
const gridApi = ref<GridApi | null>(null);
const rowData = ref<any[]>([]);
const selectedRow = ref<any>(null);

const columnDefs: ColDef[] = [
  { field: 'id', headerName: 'ID', width: 70, editable: false },
  { field: 'lookupCode', headerName: 'lookupCode', width: 140, editable: true },
  { field: 'lookupName', headerName: '名称', width: 140, editable: true },
  { field: 'dataSource', headerName: '数据源', width: 200, editable: true },
  {
    field: 'displayColumns', headerName: '显示列(JSON)', flex: 1, editable: true,
    cellEditor: 'agLargeTextCellEditor', cellEditorPopup: true
  },
  { field: 'valueField', headerName: 'valueField', width: 120, editable: true },
  { field: 'labelField', headerName: 'labelField', width: 120, editable: true }
];

const defaultColDef: ColDef = { sortable: true, resizable: true, flex: 0, suppressHeaderMenuButton: true };

async function loadData() {
  try {
    const res = await fetchAllLookupConfigs();
    rowData.value = res || [];
    setTimeout(() => gridApi.value?.autoSizeAllColumns(), 100);
  } catch { message.error('加载Lookup配置失败'); }
}

function onGridReady(params: GridReadyEvent) { gridApi.value = params.api; params.api.autoSizeAllColumns(); }

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

function handleAdd() {
  const newRow = {
    _isNew: true, id: null,
    lookupCode: '', lookupName: '', dataSource: '',
    displayColumns: '[]', valueField: '', labelField: ''
  };
  rowData.value = [...rowData.value, newRow];
  setTimeout(() => {
    const idx = rowData.value.length - 1;
    gridApi.value?.ensureIndexVisible(idx);
    gridApi.value?.startEditingCell({ rowIndex: idx, colKey: 'lookupCode' });
  }, 100);
}

async function handleSave() {
  const row = selectedRow.value;
  if (!row) { message.warning('请先选中一行'); return; }
  if (!row.lookupCode || !row.lookupName) { message.warning('lookupCode和名称不能为空'); return; }
  try {
    await saveLookupConfig(row);
    message.success('保存成功');
    await loadData();
  } catch { message.error('保存失败'); }
}

async function handleDelete() {
  if (!selectedRow.value) return;
  if (selectedRow.value._isNew) {
    rowData.value = rowData.value.filter(r => r !== selectedRow.value);
    return;
  }
  try {
    await deleteLookupConfig(selectedRow.value.id);
    message.success('删除成功');
    await loadData();
  } catch { message.error('删除失败'); }
}

function markDirty(event: CellValueChangedEvent) {
  if (event.data) event.data._dirty = true;
}

onMounted(() => {
  if (filterState?.value?.tab === 'lookup') return;
  loadData();
});

// 从目录管理跳转过来时，按 lookupCode 过滤
watch(() => filterState?.value, async (state) => {
  if (!state || state.tab !== 'lookup') return;
  const pageCode = state.pageCode;
  try {
    const [allData, codes] = await Promise.all([
      fetchAllLookupConfigs(),
      fetchLookupCodesByPageCode(pageCode)
    ]);
    if (!codes.length) { message.warning(`pageCode="${pageCode}" 未关联任何Lookup`); return; }
    const codeSet = new Set(codes);
    rowData.value = (allData || []).filter((r: any) => codeSet.has(r.lookupCode));
    setTimeout(() => gridApi.value?.autoSizeAllColumns(), 100);
  } catch { message.error('查询关联Lookup失败'); }
}, { immediate: true });
</script>

<template>
  <div class="panel-container">
    <div class="toolbar">
      <NSpace>
        <NButton size="small" type="primary" @click="handleAdd">新增</NButton>
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
        :rowSelection="{ mode: 'singleRow', checkboxes: false }"
        @grid-ready="onGridReady"
        @selection-changed="onSelectionChanged"
        @row-clicked="onRowClicked"
        @cell-value-changed="markDirty"
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
