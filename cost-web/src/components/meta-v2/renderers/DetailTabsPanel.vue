<template>
  <div class="detail-tabs-panel">
    <NTabs v-model:value="activeTab" type="segment" size="small">
      <NTab v-for="tab in tabs" :key="tab.key" :name="tab.key" :tab="tab.title" />
    </NTabs>
    <div class="detail-grid">
      <AgGridVue
        v-if="activeTab"
        class="ag-theme-quartz"
        style="width: 100%; height: 100%"
        :rowData="currentRows"
        :columnDefs="currentColumns"
        :defaultColDef="defaultColDef"
        :getRowId="getRowId"
        :getRowClass="currentRowClass"
        :rowSelection="rowSelection"
        :getContextMenuItems="contextMenuItems"
        :rowHeight="28"
        :headerHeight="28"
        v-bind="currentGridOptions"
        @grid-ready="onGridReady"
        @cell-value-changed="onCellValueChanged"
        @cell-clicked="onCellClicked"
        @cell-editing-started="onCellEditingStarted"
        @cell-editing-stopped="onCellEditingStopped"
      />
      <div v-else class="detail-empty">请选择主表记录</div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { AgGridVue } from 'ag-grid-vue3';
import { NTabs, NTab } from 'naive-ui';
import type { ColDef, GridReadyEvent } from 'ag-grid-community';
import type { TabConfig, RowData } from '@/logic/calc-engine';
import { autoSizeColumnsOnReady, buildGridRuntimeOptions, type ResolvedGridOptions } from '@/composables/meta-v2/grid-options';
import { isFlagTrue } from '@/composables/meta-v2/cell-style';

const props = defineProps<{
  tabs: TabConfig[];
  activeMasterId: number | null;
  detailCache: Map<number, Record<string, RowData[]>>;
  detailColumnsByTab: Record<string, ColDef[]>;
  detailRowClassByTab?: Record<string, ((params: any) => string | undefined) | undefined>;
  detailGridOptionsByTab?: Record<string, ResolvedGridOptions>;
  cellClassRules: ColDef['cellClassRules'];
  applyGridConfig?: (gridKey: string, api: any, columnApi: any) => void;
  onDetailCellValueChanged: (event: any, masterId: number, tabKey: string) => void;
  onDetailCellClicked: (event: any, masterId: number, tabKey: string) => void;
  onCellEditingStarted: () => void;
  onCellEditingStopped: () => void;
  loadDetailData: (masterId: number) => Promise<void>;
  registerDetailGridApi: (tabKey: string, api: any) => void;
  getDetailContextMenuItems: (masterId: number, tabKey: string) => (params: any) => any[];
}>();

const activeTab = ref<string>('');
const gridApis = ref<Record<string, any>>({});

watch(
  () => props.tabs,
  (tabs) => {
    if (!tabs || tabs.length === 0) {
      activeTab.value = '';
      return;
    }
    if (!activeTab.value || !tabs.some(tab => tab.key === activeTab.value)) {
      activeTab.value = tabs[0].key;
    }
  },
  { immediate: true }
);

watch(
  () => props.activeMasterId,
  async (masterId) => {
    if (masterId == null) return;
    if (!props.detailCache.get(masterId)) {
      await props.loadDetailData(masterId);
    }
    updateGridRows();
  }
);

watch(activeTab, () => updateGridRows());

const rowSelection = { mode: 'multiRow', checkboxes: false, enableClickSelection: true } as const;

const currentColumns = computed(() => props.detailColumnsByTab[activeTab.value] || []);
const currentGridOptions = computed(() =>
  buildGridRuntimeOptions(props.detailGridOptionsByTab?.[activeTab.value])
);
const currentRows = computed(() => {
  if (props.activeMasterId == null) return [];
  return props.detailCache.get(props.activeMasterId)?.[activeTab.value] || [];
});

const defaultColDef = computed<ColDef>(() => ({
  sortable: true,
  filter: true,
  resizable: true,
  editable: true,
  cellClassRules: props.cellClassRules
}));

const currentRowClass = computed(() => {
    const metaRowClass = props.detailRowClassByTab?.[activeTab.value];
    return (params: any): string | undefined => {
      const classes: string[] = [];
      if (isFlagTrue(params.data?._isDeleted)) classes.push('row-deleted');
      if (isFlagTrue(params.data?._isNew)) classes.push('row-new');
      const metaClass = metaRowClass?.(params);
      if (metaClass) classes.push(metaClass);
      return classes.length > 0 ? classes.join(' ') : undefined;
    };
  });

const contextMenuItems = computed(() => {
  if (props.activeMasterId == null || !activeTab.value) return () => [];
  return props.getDetailContextMenuItems(props.activeMasterId, activeTab.value);
});

function getRowId(params: any) {
  return String(params.data?.id ?? '');
}

function updateGridRows() {
  if (!props.activeMasterId || !activeTab.value) return;
  const api = gridApis.value[activeTab.value];
  const rows = props.detailCache.get(props.activeMasterId)?.[activeTab.value] || [];
  api?.setGridOption?.('rowData', rows);
}

function onGridReady(event: GridReadyEvent) {
  gridApis.value[activeTab.value] = event.api;
  props.registerDetailGridApi(activeTab.value, event.api);
  const tab = props.tabs.find(t => t.key === activeTab.value);
  if (tab?.initialSort && tab.initialSort.length > 0) {
    event.api.applyColumnState({
      state: tab.initialSort,
      defaultState: { sort: null }
    });
  }
  const gridOptions = props.detailGridOptionsByTab?.[activeTab.value];
  if (gridOptions?.autoSizeColumns) {
    autoSizeColumnsOnReady(event.api, currentColumns.value, gridOptions);
  }
}

function onCellValueChanged(event: any) {
  if (props.activeMasterId == null || !activeTab.value) return;
  props.onDetailCellValueChanged(event, props.activeMasterId, activeTab.value);
}

function onCellClicked(event: any) {
  if (props.activeMasterId == null || !activeTab.value) return;
  props.onDetailCellClicked(event, props.activeMasterId, activeTab.value);
}

function onCellEditingStarted() {
  props.onCellEditingStarted();
}

function onCellEditingStopped() {
  props.onCellEditingStopped();
}
</script>

<style scoped>
.detail-tabs-panel {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.detail-grid {
  flex: 1;
  min-height: 0;
  padding-top: 8px;
}

.detail-empty {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: #999;
  font-size: 13px;
}
</style>
