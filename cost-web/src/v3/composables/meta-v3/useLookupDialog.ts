import { type Ref, type ShallowRef, nextTick, ref } from 'vue';
import type { GridApi } from 'ag-grid-community';
import type { LookupRule } from '@/v3/composables/meta-v3/useMetaColumns';
import { type RowData, ensureRowKey } from '@/v3/logic/calc-engine';
import { forEachDetailGridApi } from '@/v3/composables/meta-v3/detail-grid-apis';

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
  getMasterRowById: (masterId: number) => RowData | null;
  getMasterRowByRowKey: (rowKey: string) => RowData | null;
  detailCache: Map<string, Record<string, RowData[]>>;
  masterGridApi: ShallowRef<GridApi | null>;
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
    getMasterRowById,
    getMasterRowByRowKey,
    detailCache,
    masterGridApi,
    masterLookupRules,
    detailLookupRulesByTab,
    markFieldChange,
    runMasterCalc,
    runDetailCalc,
    recalcAggregates,
    broadcastToDetail,
    detailGridApisByTab,
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

  function applyLookupFillData(row: RowData, fillData: Record<string, any>): string[] {
    const changedFields: string[] = [];

    Object.entries(fillData).forEach(([field, value]) => {
      const targetField = String(field || '').trim();
      if (!targetField) return;
      const nextValue = value === undefined ? null : value;
      if (row[targetField] === nextValue) return;

      const oldValue = row[targetField];
      row[targetField] = nextValue;
      markFieldChange(row, targetField, oldValue, nextValue, 'user');
      changedFields.push(targetField);
    });

    return changedFields;
  }

  function findDetailLookupRow(rows: RowData[], rowId: number | null, rowKey: string | null) {
    if (rowKey) {
      return rows.find(candidate => String(ensureRowKey(candidate)) === rowKey) ?? null;
    }
    if (rowId != null) {
      return rows.find(candidate => candidate.id === rowId) ?? null;
    }
    return null;
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
      const row = (rowKey ? getMasterRowByRowKey(rowKey) : null) ?? (rowId != null ? getMasterRowById(rowId) : null);
      if (row) {
        const targetRowKey = ensureRowKey(row);
        const node = masterGridApi.value?.getRowNode(String(targetRowKey));
        const changedFields = applyLookupFillData(row, fillData);
        if (changedFields.length > 0) {
          if (node) {
            masterGridApi.value?.refreshCells({ rowNodes: [node], force: true });
            const calcChanged = runMasterCalc(node, row) || [];
            if (broadcastToDetail && row.id != null) {
              const triggerFields = [...changedFields, ...calcChanged].filter(Boolean);
              broadcastToDetail(row.id, row, triggerFields);
            }
          } else {
            masterGridApi.value?.refreshCells({ force: true });
          }
        }
      }
    } else {
      const tabKey = currentLookupTabKey.value;
      for (const [masterRowKey, tabData] of detailCache.entries()) {
        const rows = tabData[tabKey];
        if (!rows) continue;
        const row = findDetailLookupRow(rows, rowId, rowKey);
        if (row) {
          const detailRowKey = ensureRowKey(row);
          const masterRow = getMasterRowByRowKey(masterRowKey);
          const masterId = masterRow?.id;
          if (masterId == null) break;
          const changedFields = applyLookupFillData(row, fillData);
          forEachDetailGridApi({
            masterGridApi,
            detailGridApisByTab,
            masterRowKey,
            tabKey,
            callback: api =>
              applyLookupToDetailGrid({
                api,
                row,
                detailRowKey,
                masterId,
                tabKey,
                masterRowKey,
                changedFields
              })
          });
          if (changedFields.length > 0) {
            recalcAggregates(masterId, masterRowKey);
          }
          break;
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
