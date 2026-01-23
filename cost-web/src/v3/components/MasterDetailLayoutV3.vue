<template>
  <div class="master-detail-layout-v3">
    <div class="master-panel">
      <AgGridVue
        class="ag-theme-quartz master-grid"
        :rowData="masterRowData"
        :columnDefs="masterColumnDefs"
        :defaultColDef="defaultColDef"
        :getRowId="getMasterRowId"
        :getRowClass="getRowClass"
        :rowSelection="rowSelection"
        :autoSizeStrategy="autoSizeStrategy"
        :getContextMenuItems="getMasterContextMenuItems"
        :masterDetail="hasDetailTabs"
        :detailRowAutoHeight="false"
        :getRowHeight="getRowHeight"
        :keepDetailRows="hasDetailTabs"
        :detailCellRenderer="hasDetailTabs ? DetailRowRendererV3 : undefined"
        :context="gridContext"
        :rowHeight="rowHeight"
        :headerHeight="headerHeight"
        :undoRedoCellEditing="true"
        :undoRedoCellEditingLimit="20"
        v-bind="masterGridRuntimeOptions"
        @grid-ready="handleMasterGridReady"
        @row-group-opened="onDetailRowOpened"
        @cell-editing-started="onCellEditingStarted"
        @cell-editing-stopped="onCellEditingStopped"
        @cell-value-changed="onMasterCellValueChanged"
        @cell-clicked="onMasterCellClicked"
        @filter-changed="onFilterChanged"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { AgGridVue } from 'ag-grid-vue3';
import DetailRowRendererV3 from '@/v3/components/detail/DetailRowRendererV3.vue';
import { useMasterGridBindings } from '@/v3/composables/meta-v3/useMasterGridBindings';
import { useGridContextMenu } from '@/v3/composables/meta-v3/useGridContextMenu';

const props = defineProps<{ runtime: any }>();

const runtime = props.runtime;
const {
  masterRows,
  masterColumnDefs,
  detailColumnsByTab,
  detailCache,
  pageConfig,
  masterRowClassGetter,
  detailRowClassGetterByTab,
  masterGridOptions,
  detailGridOptionsByTab,
  detailGridApisByTab,
  masterContextMenu,
  detailContextMenuByTab,
  masterRowEditableRules,
  masterRowClassRules,
  applyGridConfig,
  loadDetailData,
  addMasterRow,
  deleteMasterRow,
  addDetailRow,
  deleteDetailRow,
  copyMasterRow,
  copyDetailRow,
  markFieldChange,
  runDetailCalc,
  recalcAggregates,
  onDetailCellClicked,
  save,
  saveGridConfig
} = runtime;

const editingState = ref(false);
const detailViewMode = ref<'tab' | 'stack'>('stack');

const detailFeatureEnabled = computed(() => runtime?.features?.detailTabs !== false);
const hasDetailTabs = computed(() => detailFeatureEnabled.value && (pageConfig.value?.tabs?.length || 0) > 0);
const detailTabs = computed(() => pageConfig.value?.tabs || []);

const masterGridOptionsValue = computed(() => masterGridOptions?.value || null);

// 判断是否服务端模式
const isServerSideMode = computed(() => {
  const type = masterGridOptionsValue.value?.rowModelType;
  return type === 'serverSide' || type === 'infinite';
});

// 只有客户端模式才传 rowData
const masterRowData = computed(() => isServerSideMode.value ? undefined : masterRows.value);

const dataSource = computed(() => {
  const rowModelType = masterGridOptionsValue.value?.rowModelType;
  if (rowModelType === 'serverSide') {
    return runtime?.createServerSideDataSource?.({ pageSize: masterGridOptionsValue.value?.cacheBlockSize });
  }
  if (rowModelType === 'infinite') {
    return runtime?.createMasterDataSource?.({ pageSize: masterGridOptionsValue.value?.cacheBlockSize });
  }
  return null;
});

const {
  cellClassRules,
  defaultColDef,
  gridOptions: masterGridRuntimeOptions,
  autoSizeStrategy,
  rowSelection,
  rowHeight,
  headerHeight,
  getRowId: getMasterRowId,
  getRowClass,
  getContextMenuItems: getMasterContextMenuItems,
  onGridReady: onMasterGridReady,
  onCellEditingStarted,
  onCellEditingStopped,
  onCellValueChanged: onMasterCellValueChanged,
  onCellClicked: onMasterCellClicked,
  onFilterChanged
} = useMasterGridBindings({
  runtime,
  isUserEditing: editingState,
  metaRowClassGetter: masterRowClassGetter?.value,
  gridOptions: masterGridOptionsValue.value,
  contextMenuConfig: masterContextMenu,
  rowEditableRules: masterRowEditableRules?.value,
  rowClassRules: masterRowClassRules?.value,
  dataSource: dataSource.value
});

const masterGridKey = computed(() => {
  const key = runtime?.masterGridKey?.value ?? runtime?.masterGridKey;
  return key && String(key).trim().length > 0 ? key : 'masterGrid';
});

const { getDetailContextMenuItems } = useGridContextMenu({
  addMasterRow,
  deleteMasterRow,
  copyMasterRow,
  addDetailRow,
  deleteDetailRow,
  copyDetailRow,
  save,
  saveGridConfig,
  detailMenuByTab: detailContextMenuByTab
});

function handleMasterGridReady(event: any) {
  onMasterGridReady(event);
  applyGridConfig?.(masterGridKey.value, event.api, event.columnApi);
}

function onDetailCellValueChanged(event: any, masterId: number, tabKey: string) {
  const field = event.colDef?.field;
  const row = event.data;
  if (!field || !masterId) return;

  const changeType = editingState.value ? 'user' : 'calc';
  markFieldChange(row, field, event.oldValue, event.newValue, changeType);
  event.api?.refreshCells({ rowNodes: [event.node], columns: [field], force: true });

  if (editingState.value) {
    runDetailCalc(event.node, event.api, row, masterId, tabKey);
    recalcAggregates(masterId);
  }
}

function registerDetailGridApi(tabKey: string, api: any) {
  if (!detailGridApisByTab?.value) return;
  detailGridApisByTab.value[tabKey] = api;
}

function unregisterDetailGridApi(tabKey: string, api: any) {
  if (!detailGridApisByTab?.value) return;
  if (detailGridApisByTab.value[tabKey] === api) {
    delete detailGridApisByTab.value[tabKey];
  }
}

const gridContext = {
  detailPanelContext: {
    tabs: detailTabs,
    detailCache,
    detailColumnsByTab,
    detailRowClassByTab: detailRowClassGetterByTab,
    detailGridOptionsByTab,
    cellClassRules,
    applyGridConfig,
    onDetailCellValueChanged,
    onDetailCellClicked,
    onCellEditingStarted,
    onCellEditingStopped,
    loadDetailData,
    registerDetailGridApi,
    unregisterDetailGridApi,
    getDetailContextMenuItems,
    defaultViewMode: 'stack',
    detailViewMode,
    setDetailViewMode
  }
};

function getRowHeight(params: any): number | undefined {
  if (!params.node?.detail) return undefined;
  // detail行撑满屏幕，只预留主表一行高度
  const maxHeight = window.innerHeight - 100;
  return maxHeight;
}

function onDetailRowOpened(event: any) {
  if (!event?.node?.expanded || !event?.node?.master) return;
  const masterIdRaw = event.node?.data?.id;
  const masterId = typeof masterIdRaw === 'number' ? masterIdRaw : Number(masterIdRaw);
  if (!Number.isNaN(masterId) && !detailCache.get(masterId)) {
    loadDetailData(masterId);
  }
  const api = event.api;
  
  // 将当前行滚动到顶部
  const rowIndex = event.node.rowIndex;
  if (rowIndex != null) {
    api?.ensureIndexVisible(rowIndex, 'top');
  }
  
  // 折叠其他展开的行
  api?.forEachNode?.((node: any) => {
    if (!node?.master) return;
    if (node !== event.node && node.expanded) {
      node.setExpanded(false);
    }
  });
}

function setDetailViewMode(mode: 'tab' | 'stack') {
  detailViewMode.value = mode;
}

function onKeyDown(event: KeyboardEvent) {
  if (event.ctrlKey && event.key === 's') {
    event.preventDefault();
    save();
  }
}

onMounted(() => {
  document.addEventListener('keydown', onKeyDown);
});

onUnmounted(() => {
  document.removeEventListener('keydown', onKeyDown);
});
</script>

<style scoped>
.master-detail-layout-v3 {
  height: 100%;
  padding: 12px;
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
}

.master-panel {
  flex: 1;
  min-height: 0;
}

.master-grid {
  width: 100%;
  height: 100%;
}
</style>

