<template>
  <div class="master-detail-page-v2">
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
        :masterDetail="hasDetailTabs"
        :keepDetailRows="hasDetailTabs"
        :detailRowAutoHeight="hasDetailTabs"
        :detailCellRendererParams="hasDetailTabs ? summaryDetailParams : null"
        :undoRedoCellEditing="true"
        :undoRedoCellEditingLimit="20"
        :rowHeight="rowHeight"
        :headerHeight="headerHeight"
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
import LookupDialog from '@/components/meta-v4/LookupDialog.vue';
import type { PageComponentWithRules } from '@/composables/meta-v2/types';
import { useNestedDetailParams } from '@/composables/meta-v2/useNestedDetailParams';
import { useMasterGridBindings } from '@/composables/meta-v2/useMasterGridBindings';
import { useGridContextMenu } from '@/composables/meta-v2/useGridContextMenu';

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
  save
} = runtime;

const hasDetailTabs = computed(() => (pageConfig.value?.tabs?.length || 0) > 0);

const editingState = ref(false);
const {
  cellClassRules,
  defaultColDef,
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
  onCellClicked: onMasterCellClicked
} = useMasterGridBindings({ runtime, isUserEditing: editingState });

const { getDetailContextMenuItems } = useGridContextMenu({
  addMasterRow,
  deleteMasterRow,
  copyMasterRow,
  addDetailRow,
  deleteDetailRow,
  copyDetailRow,
  save
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

const { summaryDetailParams } = useNestedDetailParams({
  pageConfig,
  detailColumnsByTab,
  detailCache,
  loadDetailData,
  cellClassRules,
  getRowClass,
  getDetailContextMenuItems,
  onCellEditingStarted,
  onCellEditingStopped,
  onDetailCellValueChanged,
  onDetailCellClicked
});

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
:deep(.cell-user-changed) { background-color: #d4edda !important; }
:deep(.cell-calc-changed) { background-color: #fff3cd !important; }
:deep(.cell-new) { background-color: #cce5ff !important; }
:deep(.cell-deleted) { background-color: #f8d7da !important; text-decoration: line-through; }
:deep(.row-deleted) { opacity: 0.5; }
:deep(.row-new) { font-style: italic; }
:deep(.ag-header-cell-label) { white-space: normal !important; line-height: 1.2; }
:deep(.ag-header-cell) { height: auto !important; }
</style>
