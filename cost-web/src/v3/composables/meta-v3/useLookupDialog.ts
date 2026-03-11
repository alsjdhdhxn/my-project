import { type Ref, type ShallowRef, nextTick, ref } from 'vue';
import type { GridApi } from 'ag-grid-community';
import type { LookupRule } from '@/composables/useMetaColumns';
import { type RowData, ensureRowKey } from '@/v3/logic/calc-engine';

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
  const currentLookupRowData = ref<RowData | null>(null);
  const currentLookupCellValue = ref<any>(null);
  const currentLookupIsMaster = ref<boolean>(true);
  const currentLookupTabKey = ref<string>('');

  function normalizeFieldToken(field?: string | null): string {
    return String(field || '')
      .trim()
      .replace(/[^a-zA-Z0-9]/g, '')
      .toLowerCase();
  }

  function resolveTargetField(row: RowData, field?: string | null): string {
    const rawField = String(field || '').trim();
    if (!rawField) return rawField;

    const originalValues = Reflect.get(row, '_originalValues') as Record<string, any> | undefined;
    const originalKeys = Object.keys(originalValues || {}).filter(key => !key.startsWith('_'));
    const rowKeys = Object.keys(row).filter(key => !key.startsWith('_'));
    const candidateKeys = originalKeys.length > 0 ? originalKeys : rowKeys;

    if (candidateKeys.includes(rawField)) return rawField;

    const upperField = rawField.toUpperCase();
    if (candidateKeys.includes(upperField)) return upperField;

    const token = normalizeFieldToken(rawField);
    if (!token) return rawField;

    const matchedKey = candidateKeys.find(key => normalizeFieldToken(key) === token);
    return matchedKey || rawField;
  }

  function resetLookupState() {
    currentLookupRule.value = null;
    currentLookupRowId.value = null;
    currentLookupRowData.value = null;
    currentLookupCellValue.value = null;
  }

  function applyLookupFillData(row: RowData, fillData: Record<string, any>): string[] {
    const changedFields: string[] = [];

    Object.entries(fillData).forEach(([field, value]) => {
      const targetField = resolveTargetField(row, field);
      if (!targetField) return;
      if (row[targetField] === value) return;

      const oldValue = row[targetField];
      row[targetField] = value;
      markFieldChange(row, targetField, oldValue, value, 'user');
      changedFields.push(targetField);
    });

    return changedFields;
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

    if (!currentLookupRowId.value) return;
    const rowId = currentLookupRowId.value;

    if (currentLookupIsMaster.value) {
      const row = getMasterRowById(rowId);
      if (row) {
        const rowKey = ensureRowKey(row);
        const node = masterGridApi.value?.getRowNode(String(rowKey));
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
        const row = rows.find(r => r.id === rowId);
        if (row) {
          const masterRow = getMasterRowByRowKey(masterRowKey);
          const masterId = masterRow?.id;
          if (masterId == null) break;
          const changedFields = applyLookupFillData(row, fillData);

          const splitDetailApi = detailGridApisByTab?.value?.[tabKey];
          if (splitDetailApi) {
            const node = splitDetailApi.getRowNode?.(String(rowId));
            if (node && changedFields.length > 0) {
              runDetailCalc(node, splitDetailApi, row, masterId, tabKey, masterRowKey, changedFields);
            }
            splitDetailApi.refreshCells?.({ force: true });
          } else {
            const secondLevelInfo = masterGridApi.value?.getDetailGridInfo(`detail_${masterRowKey}`);
            if (secondLevelInfo?.api) {
              secondLevelInfo.api.forEachDetailGridInfo((detailInfo: any) => {
                if (detailInfo.id?.includes(tabKey)) {
                  detailInfo.api.forEachNode((node: any) => {
                    if (node.data?.id === rowId && changedFields.length > 0) {
                      runDetailCalc(node, detailInfo.api, row, masterId, tabKey, masterRowKey, changedFields);
                    }
                  });
                  detailInfo.api.refreshCells({ force: true });
                }
              });
            }
          }
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
