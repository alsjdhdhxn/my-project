<template>
  <div class="meta-tabs">
    <div class="tabs-grids">
      <div
        v-for="tab in visibleTabs"
        :key="tab.key"
        class="tab-grid-wrapper"
      >
        <div class="tab-header">{{ tab.title }}</div>
        <AgGridVue
          class="ag-theme-alpine"
          style="width: 100%; height: calc(100% - 28px)"
          :rowData="getTabRows(tab.key)"
          :columnDefs="getTabColumns(tab)"
          :defaultColDef="defaultColDef"
          :getRowId="getRowId"
          :getRowClass="getRowClass"
          :rowSelection="detailRowSelection"
          @grid-ready="(e) => onGridReady(tab.key, e)"
          @cell-value-changed="(e) => onCellValueChanged(tab.key, e)"
          @cell-clicked="(e) => onCellClicked(tab.key, e)"
          @cell-editing-started="(e) => onCellEditingStarted(tab.key, e)"
          @cell-editing-stopped="(e) => onCellEditingStopped(tab.key, e)"
        />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, shallowReactive, watch } from 'vue';
import { AgGridVue } from 'ag-grid-vue3';
import { ModuleRegistry, AllCommunityModule } from 'ag-grid-community';
import type { GridApi, ColDef, GridReadyEvent, CellValueChangedEvent, CellEditingStartedEvent, CellEditingStoppedEvent, CellClickedEvent } from 'ag-grid-community';
import type { TabConfig } from '@/logic/calc-engine';
import type { MasterDetailStore } from '@/store/modules/master-detail';
import { getCellClassRules } from '@/composables/useGridAdapter';

// 注册 AG Grid 模块（全局只注册一次）
if (!(window as any).__AG_GRID_REGISTERED__) {
  ModuleRegistry.registerModules([AllCommunityModule]);
  (window as any).__AG_GRID_REGISTERED__ = true;
}

// ==================== Props ====================

const props = defineProps<{
  tabs: TabConfig[];
  visibleKeys: Set<string>;
  store: MasterDetailStore;
  detailColumnDefs: ColDef[];
  defaultColDef: ColDef;
  getRowClass?: (params: any) => string | undefined;
}>();

const emit = defineEmits<{
  (e: 'cell-value-changed', payload: { tabKey: string; rowId: number; field: string; value: any }): void;
  (e: 'cell-clicked', payload: { tabKey: string; rowId: number; field: string; data: any }): void;
}>();

// ==================== Constants ====================

const detailRowSelection = { mode: 'multiRow', checkboxes: true, enableClickSelection: true } as const;

// ==================== State ====================

const gridApis = shallowReactive(new Map<string, GridApi>());

// ==================== Computed ====================

const visibleTabs = computed(() =>
  props.tabs.filter(tab => props.visibleKeys.has(tab.key))
);

// ==================== Methods ====================

function getRowId(params: any) {
  return String(params.data?.id);
}

function getTabRows(tabKey: string) {
  return props.store.detailRowsByTab[tabKey] || [];
}

function getTabColumns(tab: TabConfig): ColDef[] {
  // 根据 tab.columns 过滤列
  if (!tab.columns || tab.columns.length === 0) {
    return props.detailColumnDefs;
  }

  return props.detailColumnDefs
    .filter(col => tab.columns.includes(col.field as string))
    .map(col => ({
      ...col,
      cellClassRules: getCellClassRules()
    }));
}

// ==================== Event Handlers ====================

function onGridReady(tabKey: string, params: GridReadyEvent) {
  gridApis.set(tabKey, params.api);
}

function onCellValueChanged(tabKey: string, event: CellValueChangedEvent) {
  const field = event.colDef.field;
  const rowId = event.data?.id;

  if (!field || rowId == null) return;

  emit('cell-value-changed', {
    tabKey,
    rowId,
    field,
    value: event.newValue
  });

  // 刷新当前单元格样式（因为 _changeType 是在值变化后才设置的）
  const api = gridApis.get(tabKey);
  if (api && event.node) {
    api.refreshCells({
      rowNodes: [event.node],
      columns: [field],
      force: true
    });
  }
}

function onCellEditingStarted(_tabKey: string, _event: CellEditingStartedEvent) {
  // 可扩展：记录编辑状态
}

function onCellEditingStopped(_tabKey: string, _event: CellEditingStoppedEvent) {
  // 可扩展：清除编辑状态
}

function onCellClicked(tabKey: string, event: CellClickedEvent) {
  const field = event.colDef.field;
  const rowId = event.data?.id;
  
  if (!field || rowId == null) return;
  
  emit('cell-clicked', {
    tabKey,
    rowId,
    field,
    data: event.data
  });
}

// ==================== Watch ====================

// 监听 detailRows 变化，更新 Grid 数据
watch(
  () => props.store.detailRows,
  () => {
    gridApis.forEach((api, tabKey) => {
      const rows = props.store.detailRowsByTab[tabKey] || [];
      api.setGridOption('rowData', rows);
    });
  },
  { deep: true }
);

// 监听 updateVersion 变化，刷新单元格样式
watch(
  () => props.store.updateVersion,
  () => {
    gridApis.forEach(api => api.refreshCells({ force: true }));
  }
);

// ==================== Expose ====================

defineExpose({
  gridApis,
  refreshTab(tabKey: string) {
    gridApis.get(tabKey)?.refreshCells({ force: true });
  },
  refreshAll() {
    gridApis.forEach(api => api.refreshCells({ force: true }));
  }
});
</script>

<style scoped>
.meta-tabs {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.tabs-grids {
  flex: 1;
  min-height: 0;
  display: flex;
  gap: 1px;
  background: #e8e8e8;
}

.tab-grid-wrapper {
  flex: 1;
  min-width: 0;
  background: #fff;
  display: flex;
  flex-direction: column;
}

.tab-header {
  height: 28px;
  line-height: 28px;
  padding: 0 12px;
  font-weight: 500;
  font-size: 13px;
  color: #333;
  background: #fafafa;
  border-bottom: 1px solid #e8e8e8;
}

/* 表头自动换行 */
.tab-grid-wrapper :deep(.ag-header-cell-label) {
  white-space: normal !important;
  word-wrap: break-word;
  line-height: 1.4;
  display: flex;
  align-items: center;
  justify-content: center;
  text-align: center;
}

.tab-grid-wrapper :deep(.ag-header-cell) {
  padding-top: 4px;
  padding-bottom: 4px;
}

.tab-grid-wrapper :deep(.ag-header-cell-text) {
  white-space: normal !important;
  word-wrap: break-word;
  overflow: visible !important;
}
</style>
