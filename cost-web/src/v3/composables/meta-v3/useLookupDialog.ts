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
      currentLookupRule.value = null;
      currentLookupRowId.value = null;
      currentLookupRowData.value = null;
      currentLookupCellValue.value = null;
      return;
    }

    if (!currentLookupRowId.value) return;
    const rowId = currentLookupRowId.value;

    if (currentLookupIsMaster.value) {
      const row = getMasterRowById(rowId);
      if (row) {
        const rowKey = ensureRowKey(row);
        const node = masterGridApi.value?.getRowNode(String(rowKey));
        const changedFields: string[] = [];
        for (const [field, value] of Object.entries(fillData)) {
          if (row[field] !== value) {
            const oldValue = row[field];
            row[field] = value;
            markFieldChange(row, field, oldValue, value, 'user');
            changedFields.push(field);
          }
        }
        if (node) {
          masterGridApi.value?.refreshCells({ rowNodes: [node], force: true });
          if (changedFields.length > 0) {
            const calcChanged = runMasterCalc(node, row) || [];
            if (broadcastToDetail && row.id != null) {
              const triggerFields = [...changedFields, ...calcChanged].filter(Boolean);
              broadcastToDetail(row.id, row, triggerFields);
            }
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
          const changedFields: string[] = [];
          for (const [field, value] of Object.entries(fillData)) {
            if (row[field] !== value) {
              const oldValue = row[field];
              row[field] = value;
              markFieldChange(row, field, oldValue, value, 'user');
              changedFields.push(field);
            }
          }

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

    currentLookupRule.value = null;
    currentLookupRowId.value = null;
    currentLookupRowData.value = null;
    currentLookupCellValue.value = null;
  }

  function onLookupCancel() {
    currentLookupRule.value = null;
    currentLookupRowId.value = null;
    currentLookupRowData.value = null;
    currentLookupCellValue.value = null;
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
