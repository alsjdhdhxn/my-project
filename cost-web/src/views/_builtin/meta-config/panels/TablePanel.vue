<script setup lang="ts">
import { onBeforeUnmount, ref } from 'vue';
import { NButton, NDataTable, NModal, NPopconfirm, NSpace } from 'naive-ui';
import { AgGridVue } from 'ag-grid-vue3';
import { useTablePanelState } from './table-panel/useTablePanelState';

const {
  tableRows,
  selectedTable,
  tableColDefs,
  colRows,
  colColDefs,
  defaultColDef,
  canImportColumns,
  hasSelectedTable,
  hasSelectedColumn,
  loadTables,
  addTable,
  removeTable,
  saveTable,
  addColumn,
  removeColumn,
  saveColumn,
  markDirty,
  onTableGridReady,
  onTableSelectionChanged,
  onTableRowClicked,
  onColGridReady,
  onColSelectionChanged,
  onColRowClicked,
  showViewColModal,
  viewColLoading,
  viewColRows,
  viewColCheckedKeys,
  viewColTableColumns,
  openViewColModal,
  closeViewColModal,
  confirmAddViewCols
} = useTablePanelState();

const topHeight = ref(300);
let startY = 0;
let startHeight = 0;

function onResizeMove(event: MouseEvent) {
  topHeight.value = Math.max(80, startHeight + event.clientY - startY);
}

function onResizeEnd() {
  document.removeEventListener('mousemove', onResizeMove);
  document.removeEventListener('mouseup', onResizeEnd);
  document.body.style.cursor = '';
  document.body.style.userSelect = '';
}

function onResizeStart(event: MouseEvent) {
  startY = event.clientY;
  startHeight = topHeight.value;
  document.addEventListener('mousemove', onResizeMove);
  document.addEventListener('mouseup', onResizeEnd);
  document.body.style.cursor = 'row-resize';
  document.body.style.userSelect = 'none';
}

onBeforeUnmount(onResizeEnd);
</script>

<template>
  <div class="panel-container">
    <div class="section" :style="{ flex: `0 0 ${topHeight}px` }">
      <div class="section-toolbar">
        <NSpace size="small">
          <NButton size="small" type="primary" @click="addTable">新增</NButton>
          <NPopconfirm @positive-click="removeTable">
            <template #trigger>
              <NButton size="small" type="error" :disabled="!hasSelectedTable">删除</NButton>
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
          :row-data="tableRows"
          :column-defs="tableColDefs"
          :default-col-def="defaultColDef"
          :suppress-scroll-on-new-data="true"
          :row-selection="{ mode: 'singleRow', checkboxes: false }"
          :cell-selection="true"
          @grid-ready="onTableGridReady"
          @selection-changed="onTableSelectionChanged"
          @row-clicked="onTableRowClicked"
          @cell-value-changed="markDirty"
        />
      </div>
    </div>

    <div class="resizer" @mousedown="onResizeStart" />

    <div class="section" style="flex: 1">
      <div class="section-toolbar">
        <NSpace size="small">
          <NButton size="small" type="primary" :disabled="!canImportColumns" @click="openViewColModal">
            从视图导入列
          </NButton>
          <NButton size="small" :disabled="!selectedTable?.id" @click="addColumn">新增手工列</NButton>
          <NPopconfirm @positive-click="removeColumn">
            <template #trigger>
              <NButton size="small" type="error" :disabled="!hasSelectedColumn">删除列</NButton>
            </template>
            确定删除？
          </NPopconfirm>
          <NButton size="small" @click="saveColumn">保存列</NButton>
          <span class="legend-item legend-invalid">红: 失效列</span>
          <span class="legend-item legend-virtual">黄: 虚拟列</span>
        </NSpace>
      </div>

      <div class="grid-wrapper">
        <AgGridVue
          class="ag-theme-quartz"
          style="width: 100%; height: 100%"
          :row-data="colRows"
          :column-defs="colColDefs"
          :default-col-def="defaultColDef"
          :suppress-scroll-on-new-data="true"
          :row-selection="{ mode: 'singleRow', checkboxes: false }"
          :cell-selection="true"
          @grid-ready="onColGridReady"
          @selection-changed="onColSelectionChanged"
          @row-clicked="onColRowClicked"
          @cell-value-changed="markDirty"
        />
      </div>
    </div>

    <NModal
      v-model:show="showViewColModal"
      preset="card"
      title="从视图选择列"
      :style="{ width: '720px' }"
      :mask-closable="true"
    >
      <NDataTable
        v-model:checked-row-keys="viewColCheckedKeys"
        :columns="viewColTableColumns"
        :data="viewColRows"
        :row-key="(row: any) => row._key"
        :loading="viewColLoading"
        :max-height="400"
        size="small"
      />

      <template #footer>
        <NSpace justify="end">
          <NButton size="small" @click="closeViewColModal">取消</NButton>
          <NButton size="small" type="primary" :disabled="!viewColCheckedKeys.length" @click="confirmAddViewCols">
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

.legend-item {
  display: inline-flex;
  align-items: center;
  padding: 0 8px;
  border-radius: 4px;
  font-size: 12px;
  line-height: 28px;
}

.legend-invalid {
  background: #fff1f0;
  color: #cf1322;
}

.legend-virtual {
  background: #fffbe6;
  color: #ad6800;
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
