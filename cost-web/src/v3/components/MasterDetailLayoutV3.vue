<template>
  <div class="master-detail-layout-v3">
    <!-- 工具栏 -->
    <div v-if="toolbarItems.length > 0" class="toolbar-container">
      <NSpace>
        <NButton
          v-for="item in toolbarItems"
          :key="item.action"
          :type="item.type || 'default'"
          :disabled="item.disabled"
          size="small"
          @click="handleToolbarClick(item)"
        >
          {{ item.label }}
        </NButton>
      </NSpace>
    </div>

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
            :key="'split-master-grid'"
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
          :detailRowClassByTab="mergedDetailRowClassByTab"
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
        :key="'master-detail-grid'"
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
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { AgGridVue } from 'ag-grid-vue3';
import { NSplit, NSpace, NButton, useDialog } from 'naive-ui';
import DetailRowRendererV3 from '@/v3/components/detail/DetailRowRendererV3.vue';
import DetailPanelV3 from '@/v3/components/detail/DetailPanelV3.vue';
import { useMasterGridBindings } from '@/v3/composables/meta-v3/useMasterGridBindings';
import { useGridContextMenu } from '@/v3/composables/meta-v3/useGridContextMenu';
import { handleToolbarAction } from '@/v3/composables/meta-v3/useToolbarAction';
import { useThemeStore } from '@/store/modules/theme';
import { ensureRowKey } from '@/v3/logic/calc-engine';
import { buildRowClassCallback, buildRowEditableCallback } from '@/v3/composables/meta-v3/usePageRules';

const props = defineProps<{ runtime: any }>();

const dialog = useDialog();

const themeStore = useThemeStore();
const runtime = props.runtime;

// 🔍 调试：监控可能导致 Grid 重置的属性变化
watch(() => runtime.masterColumnDefs?.value, (newVal, oldVal) => {
  if (newVal !== oldVal) {
    console.warn('[DEBUG] masterColumnDefs changed!', { newLength: newVal?.length, oldLength: oldVal?.length });
  }
}, { deep: false });

const {
  masterColumnDefs,
  detailColumnsByTab,
  detailCache,
  getMasterRowById,
  pageConfig,
  masterRowClassGetter,
  detailRowClassGetterByTab,
  detailRowClassRulesByTab,
  detailRowEditableRulesByTab,
  masterGridOptions,
  detailGridOptionsByTab,
  detailGridApisByTab,
  masterContextMenu,
  detailContextMenuByTab,
  masterRowEditableRules,
  masterRowClassRules,
  masterToolbar,
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
  executeAction,
  activeMasterRowKey: runtimeActiveMasterRowKey
} = runtime;

const editingState = ref(false);

// 工具栏
const toolbarItems = computed(() => {
  const toolbar = masterToolbar?.value;
  if (!toolbar?.items) return [];
  return toolbar.items.filter((item: any) => item.visible !== false);
});

async function handleToolbarClick(item: any) {
  await handleToolbarAction(item, {
    getSelectedRow: () => {
      const api = masterGridApi?.value;
      const selectedRows = api?.getSelectedRows?.() || [];
      return selectedRows[0] || null;
    },
    executeAction,
    dialog
  });
}

// 使用全局主题设置的detailViewMode
const detailViewMode = computed(() => themeStore.detailViewMode);

// 使用全局主题设置的masterDetailMode
const masterDetailMode = computed(() => themeStore.masterDetailMode);

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
// 使用全局主题设置判断是否为分屏模式
const isSplitMode = computed(() => masterDetailMode.value === 'split');

// 合并明细表行样式：列元数据 rulesConfig + T_COST_PAGE_RULE ROW_CLASS
const mergedDetailRowClassByTab = computed(() => {
  const result: Record<string, ((params: any) => string | undefined) | undefined> = {};
  const tabs = pageConfig.value?.tabs || [];
  for (const tab of tabs) {
    const metaGetter = detailRowClassGetterByTab?.value?.[tab.key];
    const rules = detailRowClassRulesByTab?.value?.[tab.key] || [];
    const ruleGetter = buildRowClassCallback(rules);
    
    if (!metaGetter && !ruleGetter) {
      result[tab.key] = undefined;
    } else {
      result[tab.key] = (params: any) => {
        const classes: string[] = [];
        const metaClass = metaGetter?.(params);
        if (metaClass) classes.push(metaClass);
        const ruleClass = ruleGetter?.(params);
        if (ruleClass) classes.push(ruleClass);
        return classes.length > 0 ? classes.join(' ') : undefined;
      };
    }
  }
  return result;
});

// 从表行编辑权限检查（用于控制删除）
const detailRowEditableByTab = computed(() => {
  const result: Record<string, ((row: any) => boolean) | undefined> = {};
  const tabs = pageConfig.value?.tabs || [];
  for (const tab of tabs) {
    const rules = detailRowEditableRulesByTab?.value?.[tab.key] || [];
    console.log(`[DEBUG] detailRowEditableByTab - tab: ${tab.key}, rules:`, rules);
    const callback = buildRowEditableCallback(rules);
    result[tab.key] = callback ? (row: any) => callback({ data: row }) : undefined;
  }
  console.log('[DEBUG] detailRowEditableByTab result:', Object.keys(result).map(k => `${k}: ${result[k] ? 'has callback' : 'undefined'}`));
  return result;
});
const activeMasterId = ref<number | null>(null);
const activeMasterRowKey = ref<string | null>(null);

const masterGridOptionsValue = computed(() => masterGridOptions?.value || null);

// 确保 dataSource 只创建一次，避免因响应式重新计算导致 AG Grid 重置
let cachedDataSource: any = null;
function getDataSource() {
  if (!cachedDataSource) {
    cachedDataSource = runtime?.createServerSideDataSource?.({ pageSize: masterGridOptionsValue.value?.cacheBlockSize });
  }
  return cachedDataSource;
}

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
  dataSource: getDataSource(),
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
  detailMenuByTab: detailContextMenuByTab,
  isDetailRowEditableByTab: detailRowEditableByTab,
  notifyError: (msg: string) => window.$message?.error(msg)
});

const masterGridApi = ref<any>(null);

function handleMasterGridReady(event: any) {
  console.log('[DEBUG] handleMasterGridReady called, isSplitMode:', isSplitMode.value);
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
    detailRowClassByTab: mergedDetailRowClassByTab,
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

.toolbar-container {
  padding: 4px 0;
  flex-shrink: 0;
}

.split-container {
  flex: 1;
  min-height: 0;
}

.master-panel {
  flex: 1;
  min-height: 0;
  height: 100%;
}

.master-grid {
  width: 100%;
  height: 100%;
}
</style>
