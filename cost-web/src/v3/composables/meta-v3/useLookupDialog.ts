import { type Ref, nextTick, ref } from 'vue';
import type { LookupRule } from '@/v3/composables/meta-v3/useMetaColumns';
import { type RowData, ensureRowKey } from '@/v3/logic/calc-engine';
import type { RowFieldChange } from '@/v3/composables/meta-v3/row-patch';

type MarkFieldChange = (row: RowData, field: string, oldValue: any, newValue: any, type: 'user' | 'calc') => void;

type RunMasterCalc = (node: any, row: RowData, valueOverrides?: Record<string, any>) => string[] | void;

type RunDetailCalc = (
  node: any,
  api: any,
  row: RowData,
  masterId: number,
  tabKey: string,
  masterRowKey?: string,
  changedFields?: string | string[],
  valueOverrides?: Record<string, any>
) => string[] | void;

type RecalcAggregates = (masterId: number, masterRowKey?: string) => void;

type BroadcastToDetail = (masterId: number, row: RowData, changedFields?: string | string[]) => Promise<void>;

type LookupDialogExpose = { open: () => void };

export function useLookupDialog(params: {
  applyMasterPatch: (rowId: number | null, rowKey: string | null, patch: Record<string, any>) => {
    row: RowData;
    rowKey: string;
    node: any;
    changes: RowFieldChange[];
  } | null;
  applyDetailPatch: (
    tabKey: string,
    rowId: number | null,
    rowKey: string | null,
    patch: Record<string, any>
  ) => {
    row: RowData;
    masterId: number;
    masterRowKey: string;
    detailRowKey: string;
    changes: RowFieldChange[];
    applyToGrids: (callback: (api: any, node: any) => void) => void;
  } | null;
  masterLookupRules: Ref<LookupRule[]>;
  detailLookupRulesByTab: Ref<Record<string, LookupRule[]>>;
  markFieldChange: MarkFieldChange;
  runMasterCalc: RunMasterCalc;
  runDetailCalc: RunDetailCalc;
  recalcAggregates: RecalcAggregates;
  broadcastToDetail?: BroadcastToDetail;
  detailGridApisByTab?: Ref<Record<string, any>>;
  isRowEditable?: (row: RowData) => boolean;
  isDetailRowEditable?: (row: RowData, tabKey: string) => boolean;
}) {
  const {
    applyMasterPatch,
    applyDetailPatch,
    masterLookupRules,
    detailLookupRulesByTab,
    markFieldChange,
    runMasterCalc,
    runDetailCalc,
    recalcAggregates,
    broadcastToDetail,
    isRowEditable,
    isDetailRowEditable
  } = params;

  const lookupDialogRef = ref<LookupDialogExpose | null>(null);
  const currentLookupRule = ref<LookupRule | null>(null);
  const currentLookupRowId = ref<number | null>(null);
  const currentLookupRowKey = ref<string | null>(null);
  const currentLookupRowData = ref<RowData | null>(null);
  const currentLookupCellValue = ref<any>(null);
  const currentLookupIsMaster = ref<boolean>(true);
  const currentLookupTabKey = ref<string>('');

  function resetLookupState() {
    currentLookupRule.value = null;
    currentLookupRowId.value = null;
    currentLookupRowKey.value = null;
    currentLookupRowData.value = null;
    currentLookupCellValue.value = null;
  }

  function applyMarkedChanges(row: RowData, changes: RowFieldChange[]) {
    changes.forEach(change => {
      markFieldChange(row, change.field, change.oldValue, change.newValue, 'user');
    });
    return changes.map(change => change.field);
  }

  function applyLookupToDetailGrid(params: {
    api: any;
    row: RowData;
    detailRowKey: string;
    masterId: number;
    tabKey: string;
    masterRowKey: string;
    changedFields: string[];
  }) {
    const { api, row, detailRowKey, masterId, tabKey, masterRowKey, changedFields } = params;
    const node =
      api?.getRowNode?.(String(detailRowKey)) ??
      (() => {
        let matchedNode: any = null;
        api?.forEachNode?.((candidate: any) => {
          if (!matchedNode && candidate?.data?._rowKey === detailRowKey) {
            matchedNode = candidate;
          }
        });
        return matchedNode;
      })();

    if (node && changedFields.length > 0) {
      runDetailCalc(node, api, row, masterId, tabKey, masterRowKey, changedFields);
    }
    api?.refreshCells?.({ force: true });
  }

  async function onMasterCellClicked(event: any) {
    if (event.node?.rowPinned) return;
    const field = event.colDef?.field;
    const rowData = event.data;
    if (!field || !rowData) return;

    const rule = masterLookupRules.value.find(r => r.columnName === field);
    if (!rule) return;

    if (isRowEditable && !isRowEditable(rowData) && !rule.noFillback) return;

    currentLookupRule.value = rule;
    currentLookupRowId.value = rowData.id;
    currentLookupRowKey.value = ensureRowKey(rowData);
    currentLookupRowData.value = rowData;
    currentLookupCellValue.value = rowData[field];
    currentLookupIsMaster.value = true;
    currentLookupTabKey.value = '';
    await nextTick();
    lookupDialogRef.value?.open();
  }

  async function onDetailCellClicked(event: any, _masterId: number, tabKey: string) {
    if (event.node?.rowPinned) return;
    const field = event.colDef?.field;
    const rowData = event.data;
    if (!field || !rowData) return;

    const rule = detailLookupRulesByTab.value[tabKey]?.find(r => r.columnName === field);
    if (!rule) return;

    if (isDetailRowEditable && !isDetailRowEditable(rowData, tabKey) && !rule.noFillback) return;

    currentLookupRule.value = rule;
    currentLookupRowId.value = rowData.id;
    currentLookupRowKey.value = ensureRowKey(rowData);
    currentLookupRowData.value = rowData;
    currentLookupCellValue.value = rowData[field];
    currentLookupIsMaster.value = false;
    currentLookupTabKey.value = tabKey;
    await nextTick();
    lookupDialogRef.value?.open();
  }

  function onLookupSelect(fillData: Record<string, any>) {
    if (currentLookupRule.value?.noFillback) {
      resetLookupState();
      return;
    }

    const rowId = currentLookupRowId.value;
    const rowKey = currentLookupRowKey.value;
    if (rowId == null && !rowKey) return;

    if (currentLookupIsMaster.value) {
      const result = applyMasterPatch(rowId, rowKey, fillData);
      if (result) {
        const changedFields = applyMarkedChanges(result.row, result.changes);
        if (changedFields.length > 0 && result.node) {
          const calcChanged = runMasterCalc(result.node, result.row) || [];
          if (broadcastToDetail && result.row.id != null) {
            const triggerFields = [...changedFields, ...calcChanged].filter(Boolean);
            broadcastToDetail(result.row.id, result.row, triggerFields);
          }
        }
      }
    } else {
      const tabKey = currentLookupTabKey.value;
      const result = applyDetailPatch(tabKey, rowId, rowKey, fillData);
      if (result) {
        const changedFields = applyMarkedChanges(result.row, result.changes);
        result.applyToGrids((api, node) =>
          applyLookupToDetailGrid({
            api,
            row: result.row,
            detailRowKey: result.detailRowKey,
            masterId: result.masterId,
            tabKey,
            masterRowKey: result.masterRowKey,
            changedFields
          })
        );
        if (changedFields.length > 0) {
          recalcAggregates(result.masterId, result.masterRowKey);
        }
      }
    }

    resetLookupState();
  }

  function onLookupCancel() {
    resetLookupState();
  }

  return {
    lookupDialogRef,
    currentLookupRule,
    currentLookupRowId,
    currentLookupRowKey,
    currentLookupRowData,
    currentLookupCellValue,
    currentLookupIsMaster,
    currentLookupTabKey,
    onMasterCellClicked,
    onDetailCellClicked,
    onLookupSelect,
    onLookupCancel
  };
}
