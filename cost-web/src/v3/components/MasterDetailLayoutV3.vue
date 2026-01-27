<template>
  <div class="master-detail-layout-v3">
    <NSplit
      v-if="isSplitMode && hasDetailTabs"
      direction="vertical"
      :default-size="splitConfig.defaultSize"
      :min="splitConfig.min"
      :max="splitConfig.max"
      class="split-container"
    >
      <template #1>
        <div class="master-panel">
          <AgGridVue
            class="ag-theme-quartz master-grid"
            :columnDefs="masterColumnDefs"
            :defaultColDef="defaultColDef"
            :getRowId="getMasterRowId"
            :getRowClass="getRowClass"
            :rowSelection="rowSelection"
            :autoSizeStrategy="autoSizeStrategy"
            :getContextMenuItems="getMasterContextMenuItems"
            :masterDetail="false"
            :detailRowAutoHeight="false"
            :getRowHeight="getRowHeight"
            :keepDetailRows="false"
            :detailCellRenderer="undefined"
            :context="gridContext"
            :rowHeight="rowHeight"
            :headerHeight="headerHeight"
            :undoRedoCellEditing="true"
            :undoRedoCellEditingLimit="20"
            v-bind="masterGridRuntimeOptions"
            @grid-ready="handleMasterGridReady"
            @selection-changed="onSelectionChanged"
            @row-group-opened="onDetailRowOpened"
            @cell-editing-started="onCellEditingStarted"
            @cell-editing-stopped="onCellEditingStopped"
            @cell-value-changed="onMasterCellValueChanged"
            @cell-clicked="onMasterCellClicked"
            @filter-changed="onFilterChanged"
          />
        </div>
      </template>
      <template #2>
        <DetailPanelV3
          :tabs="detailTabs"
          :activeMasterId="activeMasterId"
          :activeMasterRowKey="activeMasterRowKey"
          :detailCache="detailCache"
          :detailColumnsByTab="detailColumnsByTab"
          :detailRowClassByTab="detailRowClassGetterByTab"
          :detailGridOptionsByTab="detailGridOptionsByTab"
          :cellClassRules="cellClassRules"
          :applyGridConfig="applyGridConfig"
          :onDetailCellValueChanged="onDetailCellValueChanged"
          :onDetailCellClicked="onDetailCellClicked"
          :onCellEditingStarted="onCellEditingStarted"
          :onCellEditingStopped="onCellEditingStopped"
          :loadDetailData="loadDetailData"
          :registerDetailGridApi="registerDetailGridApi"
          :unregisterDetailGridApi="unregisterDetailGridApi"
          :getDetailContextMenuItems="getDetailContextMenuItems"
          :refreshDetailRowHeight="refreshDetailRowHeight"
          :defaultViewMode="'stack'"
          :viewMode="detailViewMode"
        />
      </template>
    </NSplit>

    <div v-else class="master-panel">
      <AgGridVue
        class="ag-theme-quartz master-grid"
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
import { NSplit, useDialog } from 'naive-ui';
import DetailRowRendererV3 from '@/v3/components/detail/DetailRowRendererV3.vue';
import DetailPanelV3 from '@/v3/components/detail/DetailPanelV3.vue';
import { useMasterGridBindings } from '@/v3/composables/meta-v3/useMasterGridBindings';
import { useGridContextMenu } from '@/v3/composables/meta-v3/useGridContextMenu';
import { useThemeStore } from '@/store/modules/theme';
import { ensureRowKey } from '@/v3/logic/calc-engine';

const props = defineProps<{ runtime: any }>();

const dialog = useDialog();

const themeStore = useThemeStore();
const runtime = props.runtime;
const {
  masterColumnDefs,
  detailColumnsByTab,
  detailCache,
  getMasterRowById,
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
  saveGridConfig,
  activeMasterRowKey: runtimeActiveMasterRowKey
} = runtime;

const editingState = ref(false);

// 使用全局主题设置的detailViewMode
const detailViewMode = computed(() => themeStore.detailViewMode);

const detailFeatureEnabled = computed(() => runtime?.features?.detailTabs !== false);
const hasDetailTabs = computed(() => detailFeatureEnabled.value && (pageConfig.value?.tabs?.length || 0) > 0);
const detailTabs = computed(() => pageConfig.value?.tabs || []);
const detailLayoutMode = computed(() => runtime?.detailLayoutMode?.value ?? runtime?.detailLayoutMode ?? 'nested');
const splitConfig = computed(() => {
  const config = runtime?.detailSplitConfig?.value ?? runtime?.detailSplitConfig ?? {};
  return {
    defaultSize: config?.defaultSize ?? 0.5,
    min: config?.min ?? 0.2,
    max: config?.max ?? 0.8
  };
});
const isSplitMode = computed(() => detailLayoutMode.value === 'split');
const activeMasterId = ref<number | null>(null);
const activeMasterRowKey = ref<string | null>(null);

const masterGridOptionsValue = computed(() => masterGridOptions?.value || null);

const dataSource = computed(() => {
  return runtime?.createServerSideDataSource?.({ pageSize: masterGridOptionsValue.value?.cacheBlockSize });
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
  onFilterChanged,
  onSelectionChanged
} = useMasterGridBindings({
  runtime,
  isUserEditing: editingState,
  metaRowClassGetter: masterRowClassGetter?.value,
  gridOptions: masterGridOptionsValue.value,
  contextMenuConfig: masterContextMenu,
  rowEditableRules: masterRowEditableRules?.value,
  rowClassRules: masterRowClassRules?.value,
  dataSource: dataSource.value,
  onSelectionChanged: async (rows) => {
    if (!isSplitMode.value || !hasDetailTabs.value) return;
    const selected = rows?.[0];
    const nextId = selected?.id ?? null;
    const nextRowKey = selected ? ensureRowKey(selected) : null;
    activeMasterId.value = typeof nextId === 'number' ? nextId : (nextId != null ? Number(nextId) : null);
    activeMasterRowKey.value = nextRowKey ? String(nextRowKey) : null;
    if (runtimeActiveMasterRowKey) {
      runtimeActiveMasterRowKey.value = activeMasterRowKey.value;
    }
    if (activeMasterId.value == null) return;
    if (!activeMasterRowKey.value) return;
    if (!detailCache.get(activeMasterRowKey.value)) {
      await loadDetailData(activeMasterId.value, activeMasterRowKey.value);
    }
  }
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

const masterGridApi = ref<any>(null);

function handleMasterGridReady(event: any) {
  masterGridApi.value = event.api;
  onMasterGridReady(event);
  applyGridConfig?.(masterGridKey.value, event.api, event.columnApi);
}

// 刷新detail行高度
function refreshDetailRowHeight() {
  masterGridApi.value?.resetRowHeights();
}

function onDetailCellValueChanged(event: any, masterId: number, tabKey: string, masterRowKey?: string) {
  const field = event.colDef?.field;
  const row = event.data;
  if (!field || !masterId) return;

  const changeType = editingState.value ? 'user' : 'calc';
  markFieldChange(row, field, event.oldValue, event.newValue, changeType);
  event.api?.refreshCells({ rowNodes: [event.node], columns: [field], force: true });

  if (editingState.value) {
    const resolvedRowKey = masterRowKey ?? activeMasterRowKey.value ?? undefined;
    runDetailCalc(event.node, event.api, row, masterId, tabKey, resolvedRowKey);
    recalcAggregates(masterId, resolvedRowKey);
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
    refreshDetailRowHeight,
    defaultViewMode: 'stack',
    detailViewMode
  }
};

function getRowHeight(params: any): number | undefined {
  if (!params.node?.detail) return undefined;
  
  const masterRowKey = params.node?.data?._rowKey ? String(params.node?.data?._rowKey) : null;
  const tabs = detailTabs.value || [];
  const tabCount = tabs.length || 1;
  const rowHeight = 28;
  const headerHeight = 28;
  const gap = 16;
  const padding = 80;
  const minRows = 2;
  
  // 可用总高度
  const availableHeight = window.innerHeight - 100 - padding - (gap * (tabCount - 1));
  // 每个子表最大可用高度
  const maxGridHeight = Math.floor(availableHeight / tabCount);
  // 每个子表最小高度 = 表头 + 2行
  const minGridHeight = headerHeight + rowHeight * minRows;
  
  // 计算所有子表的总高度
  const cached = masterRowKey ? detailCache.get(masterRowKey) : undefined;
  let totalHeight = padding;
  
  for (let i = 0; i < tabs.length; i++) {
    const tabKey = tabs[i].key;
    const rows = cached?.[tabKey] || [];
    // 实际内容高度 + 少量余量
    const contentHeight = headerHeight + Math.max(rows.length, minRows) * rowHeight + 20;
    // 限制在最小和最大之间
    const gridHeight = Math.max(minGridHeight, Math.min(contentHeight, maxGridHeight));
    totalHeight += gridHeight;
    if (i < tabs.length - 1) totalHeight += gap;
  }
  
  // 最大不超过屏幕高度 - 100
  const maxContainerHeight = window.innerHeight - 100;
  return Math.min(totalHeight, maxContainerHeight);
}

// 检测指定主表行及其子表是否有未保存的修改
function hasUnsavedChanges(masterId: number): boolean {
  // 检查主表行
  const masterRow = getMasterRowById?.(masterId);
  if (masterRow && (masterRow._isNew || masterRow._isDeleted || masterRow._dirtyFields)) {
    return true;
  }
  
  // 检查子表
  const masterRowKey = masterRow ? ensureRowKey(masterRow) : null;
  const cached = masterRowKey ? detailCache.get(masterRowKey) : undefined;
  if (cached) {
    for (const rows of Object.values(cached)) {
      for (const row of rows as any[]) {
        if (row._isNew || row._isDeleted || row._dirtyFields) {
          return true;
        }
      }
    }
  }
  
  return false;
}

// 获取当前展开行的masterId
function getExpandedMasterId(api: any): number | null {
  let expandedMasterId: number | null = null;
  api?.forEachNode?.((node: any) => {
    if (node?.master && node.expanded) {
      expandedMasterId = node.data?.id;
    }
  });
  return expandedMasterId;
}

function onDetailRowOpened(event: any) {
  if (isSplitMode.value) return;
  if (!event?.node?.master) return;
  
  const masterIdRaw = event.node?.data?.id;
  const masterId = typeof masterIdRaw === 'number' ? masterIdRaw : Number(masterIdRaw);
  const api = event.api;
  const currentNode = event.node;
  
  // 如果是收起操作，不做处理
  if (!currentNode.expanded) return;
  
  // 检查是否有其他展开的行
  let expandedNode: any = null;
  api?.forEachNode?.((node: any) => {
    if (node?.master && node !== currentNode && node.expanded) {
      expandedNode = node;
    }
  });
  
  if (expandedNode) {
    const expandedMasterId = expandedNode.data?.id;
    
    // 先收起当前行（阻止本次展开）
    currentNode.setExpanded(false);
    
    // 检查原展开行是否有未保存的修改
    if (hasUnsavedChanges(expandedMasterId)) {
      dialog.warning({
        title: '提示',
        content: '当前数据有未保存的修改，是否保存？',
        positiveText: '保存',
        negativeText: '稍后保存',
        onPositiveClick: async () => {
          await save();
          // 保存后收起旧行，展开新行
          expandedNode.setExpanded(false);
          setTimeout(() => {
            currentNode.setExpanded(true);
          }, 50);
        },
        onNegativeClick: () => {
          // 不保存，直接收起旧行，展开新行
          expandedNode.setExpanded(false);
          setTimeout(() => {
            currentNode.setExpanded(true);
          }, 50);
        }
      });
      return;
    }
    
    // 没有修改，直接收起旧行，展开新行
    expandedNode.setExpanded(false);
    setTimeout(() => {
      currentNode.setExpanded(true);
    }, 50);
    return;
  }
  
  // 将当前行滚动到顶部
  const rowIndex = currentNode.rowIndex;
  if (rowIndex != null) {
    api?.ensureIndexVisible(rowIndex, 'top');
  }
  
  // 加载数据，完成后刷新行高
  const masterRowKey = currentNode?.data ? String(ensureRowKey(currentNode.data)) : null;
  if (!Number.isNaN(masterId) && masterRowKey && !detailCache.get(masterRowKey)) {
    loadDetailData(masterId, masterRowKey).then(() => {
      // 数据加载完成后重新计算行高
      api?.resetRowHeights();
    });
  }
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
  width: 100%;
  height: 100%;
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
}

.split-container {
  height: 100%;
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
