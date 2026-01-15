<template>
  <div class="master-detail-page-v2">
    <NSplit
      v-if="isSplitMode && hasDetailTabs"
      direction="vertical"
      :default-size="splitConfig.defaultSize"
      :min="splitConfig.min"
      :max="splitConfig.max"
      class="split-container"
    >
      <template #1>
        <div class="grid-container">
          <AgGridVue
            class="ag-theme-quartz"
            style="width: 100%; height: 100%"
            :rowData="masterRows"
            :columnDefs="masterColumnDefs"
            :defaultColDef="defaultColDef"
            :getRowId="getMasterRowId"
            :getRowClass="getRowClass"
            :rowSelection="rowSelection"
            :autoSizeStrategy="autoSizeStrategy"
            :getContextMenuItems="getMasterContextMenuItems"
            :rowHeight="rowHeight"
            :headerHeight="headerHeight"
            :undoRedoCellEditing="true"
            :undoRedoCellEditingLimit="20"
            v-bind="masterGridRuntimeOptions"
            @grid-ready="onMasterGridReady"
            @selection-changed="onMasterSelectionChanged"
            @cell-editing-started="onCellEditingStarted"
            @cell-editing-stopped="onCellEditingStopped"
            @cell-value-changed="onMasterCellValueChanged"
            @cell-clicked="onMasterCellClicked"
          />
        </div>
      </template>
      <template #2>
        <DetailTabsPanel
          :tabs="pageConfig?.tabs || []"
          :activeMasterId="activeMasterId"
          :detailCache="detailCache"
          :detailColumnsByTab="detailColumnsByTab"
          :detailRowClassByTab="detailRowClassGetterByTab"
          :detailGridOptionsByTab="detailGridOptionsByTab"
          :applyGridConfig="applyGridConfig"
          :onDetailCellValueChanged="onDetailCellValueChanged"
          :onDetailCellClicked="onDetailCellClicked"
          :onCellEditingStarted="onCellEditingStarted"
          :onCellEditingStopped="onCellEditingStopped"
          :loadDetailData="loadDetailData"
          :registerDetailGridApi="registerDetailGridApi"
          :getDetailContextMenuItems="getDetailContextMenuItems"
          :cellClassRules="cellClassRules"
        />
      </template>
    </NSplit>

    <div v-else class="grid-container">
      <AgGridVue
        class="ag-theme-quartz"
        style="width: 100%; height: 100%"
        :rowData="masterRows"
        :columnDefs="masterColumnDefs"
        :defaultColDef="defaultColDef"
        :getRowId="getMasterRowId"
        :getRowClass="getRowClass"
        :rowSelection="rowSelection"
        :autoSizeStrategy="autoSizeStrategy"
        :getContextMenuItems="getMasterContextMenuItems"
        :masterDetail="hasDetailTabs"
        :keepDetailRows="hasDetailTabs"
        :detailRowAutoHeight="hasDetailTabs"
        :detailCellRendererParams="hasDetailTabs ? summaryDetailParams : null"
        :undoRedoCellEditing="true"
        :undoRedoCellEditingLimit="20"
        :rowHeight="rowHeight"
        :headerHeight="headerHeight"
        v-bind="masterGridRuntimeOptions"
        @grid-ready="onMasterGridReady"
        @cell-editing-started="onCellEditingStarted"
        @cell-editing-stopped="onCellEditingStopped"
        @cell-value-changed="onMasterCellValueChanged"
        @cell-clicked="onMasterCellClicked"
      />
    </div>

    <LookupDialog
      v-if="currentLookupRule"
      ref="lookupDialogRef"
      :lookupCode="currentLookupRule.lookupCode"
      :mapping="currentLookupRule.mapping"
      @select="onLookupSelect"
      @cancel="onLookupCancel"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { AgGridVue } from 'ag-grid-vue3';
import { NSplit } from 'naive-ui';
import LookupDialog from '../../meta-v4/LookupDialog.vue';
import DetailTabsPanel from '@/components/meta-v2/renderers/DetailTabsPanel.vue';
import type { PageComponentWithRules } from '@/composables/meta-v2/types';
import { useNestedDetailParams } from '@/composables/meta-v2/useNestedDetailParams';
import { useMasterGridBindings } from '@/composables/meta-v2/useMasterGridBindings';
import { useGridContextMenu } from '@/composables/meta-v2/useGridContextMenu';
import { isFlagTrue } from '@/composables/meta-v2/cell-style';

const props = defineProps<{
  component: PageComponentWithRules;
  runtime: any;
}>();

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
  detailLayoutMode,
  detailSplitConfig,
  detailGridApisByTab,
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
  lookupDialogRef,
  currentLookupRule,
  onDetailCellClicked,
  onLookupSelect,
  onLookupCancel,
  save,
  saveGridConfig
} = runtime;

const hasDetailTabs = computed(() => (pageConfig.value?.tabs?.length || 0) > 0);
const isSplitMode = computed(() => detailLayoutMode?.value === 'split');
const splitConfig = computed(() => ({
  defaultSize: detailSplitConfig?.value?.defaultSize ?? 0.5,
  min: detailSplitConfig?.value?.min ?? 0.2,
  max: detailSplitConfig?.value?.max ?? 0.8
}));
const activeMasterId = ref<number | null>(null);
const editingState = ref(false);
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
  onSelectionChanged: onMasterSelectionChanged,
  onCellEditingStarted,
  onCellEditingStopped,
  onCellValueChanged: onMasterCellValueChanged,
  onCellClicked: onMasterCellClicked
} = useMasterGridBindings({
  runtime,
  isUserEditing: editingState,
  metaRowClassGetter: masterRowClassGetter?.value,
  gridOptions: masterGridOptions?.value,
  onSelectionChanged: async (rows) => {
    const selected = rows?.[0];
    activeMasterId.value = selected?.id ?? null;
    if (activeMasterId.value == null) return;
    if (!detailCache.get(activeMasterId.value)) {
      await loadDetailData(activeMasterId.value);
    }
  }
});

const { getDetailContextMenuItems } = useGridContextMenu({
  addMasterRow,
  deleteMasterRow,
  copyMasterRow,
  addDetailRow,
  deleteDetailRow,
  copyDetailRow,
  save,
  saveGridConfig
});

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

const detailBaseRowClass = (params: any): string | undefined => {
  if (isFlagTrue(params.data?._isDeleted)) return 'row-deleted';
  if (isFlagTrue(params.data?._isNew)) return 'row-new';
  return undefined;
};

const { summaryDetailParams } = useNestedDetailParams({
  pageConfig,
  detailColumnsByTab,
  detailCache,
  loadDetailData,
  cellClassRules,
  getRowClass: detailBaseRowClass,
  detailRowClassByTab: detailRowClassGetterByTab,
  detailGridOptionsByTab,
  applyGridConfig,
  getDetailContextMenuItems,
  onCellEditingStarted,
  onCellEditingStopped,
  onDetailCellValueChanged,
  onDetailCellClicked
});

function registerDetailGridApi(tabKey: string, api: any) {
  if (!detailGridApisByTab?.value) return;
  detailGridApisByTab.value[tabKey] = api;
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
.master-detail-page-v2 { width: 100%; height: 100%; display: flex; flex-direction: column; }
.grid-container { flex: 1; min-height: 0; }
.split-container { height: 100%; }
:deep(.cell-new) { background-color: #0b3d91 !important; color: #ffffff; }
:deep(.cell-user-changed) { background-color: #b7f4b3 !important; color: #1a1a1a !important; }
:deep(.cell-calc-changed) { background-color: #fff2a8 !important; color: #1a1a1a !important; }
:deep(.cell-deleted) { background-color: #f8d7da !important; text-decoration: line-through; }
:deep(.row-deleted) { opacity: 0.5; }
:deep(.row-new) { background-color: #0b3d91; color: #ffffff; font-style: italic; }
:deep(.ag-header-cell-label) { white-space: normal !important; line-height: 1.2; }
:deep(.ag-header-cell) { height: auto !important; }
</style>
