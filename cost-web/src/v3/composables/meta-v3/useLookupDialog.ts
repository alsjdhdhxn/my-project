import { ref, type Ref, type ShallowRef } from 'vue';
import type { GridApi } from 'ag-grid-community';
import type { LookupRule } from '@/composables/useMetaColumns';
import { ensureRowKey, type RowData } from '@/v3/logic/calc-engine';

type MarkFieldChange = (row: RowData, field: string, oldValue: any, newValue: any, type: 'user' | 'calc') => void;

type RunMasterCalc = (node: any, row: RowData) => void;

type RunDetailCalc = (node: any, api: any, row: RowData, masterId: number, tabKey: string, masterRowKey?: string) => void;

type RecalcAggregates = (masterId: number, masterRowKey?: string) => void;

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
  detailGridApisByTab?: Ref<Record<string, any>>;
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
    detailGridApisByTab
  } = params;

  const lookupDialogRef = ref<LookupDialogExpose | null>(null);
  const currentLookupRule = ref<LookupRule | null>(null);
  const currentLookupRowId = ref<number | null>(null);
  const currentLookupIsMaster = ref<boolean>(true);
  const currentLookupTabKey = ref<string>('');

  function onMasterCellClicked(event: any) {
    const field = event.colDef?.field;
    const rowData = event.data;
    if (!field || !rowData) return;
    const rule = masterLookupRules.value.find(r => r.fieldName === field);
    if (!rule) return;
    currentLookupRule.value = rule;
    currentLookupRowId.value = rowData.id;
    currentLookupIsMaster.value = true;
    currentLookupTabKey.value = '';
    lookupDialogRef.value?.open();
  }

  function onDetailCellClicked(event: any, _masterId: number, tabKey: string) {
    const field = event.colDef?.field;
    const rowData = event.data;
    if (!field || !rowData) return;
    const rule = detailLookupRulesByTab.value[tabKey]?.find(r => r.fieldName === field);
    if (!rule) return;
    currentLookupRule.value = rule;
    currentLookupRowId.value = rowData.id;
    currentLookupIsMaster.value = false;
    currentLookupTabKey.value = tabKey;
    lookupDialogRef.value?.open();
  }

  function onLookupSelect(fillData: Record<string, any>) {
    if (!currentLookupRowId.value) return;
    const rowId = currentLookupRowId.value;

    if (currentLookupIsMaster.value) {
      const row = getMasterRowById(rowId);
      if (row) {
        const rowKey = ensureRowKey(row);
        const node = masterGridApi.value?.getRowNode(String(rowKey));
        for (const [field, value] of Object.entries(fillData)) {
          if (row[field] !== value) {
            const oldValue = row[field];
            row[field] = value;
            markFieldChange(row, field, oldValue, value, 'user');
          }
        }
        if (node) {
          masterGridApi.value?.refreshCells({ rowNodes: [node], force: true });
          runMasterCalc(node, row);
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
          for (const [field, value] of Object.entries(fillData)) {
            if (row[field] !== value) {
              const oldValue = row[field];
              row[field] = value;
              markFieldChange(row, field, oldValue, value, 'user');
            }
          }
          const splitDetailApi = detailGridApisByTab?.value?.[tabKey];
          if (splitDetailApi) {
            const node = splitDetailApi.getRowNode?.(String(rowId));
            if (node) {
              runDetailCalc(node, splitDetailApi, row, masterId, tabKey, masterRowKey);
            }
            splitDetailApi.refreshCells?.({ force: true });
          } else {
            const secondLevelInfo = masterGridApi.value?.getDetailGridInfo(`detail_${masterRowKey}`);
            if (secondLevelInfo?.api) {
              secondLevelInfo.api.forEachDetailGridInfo((detailInfo: any) => {
                if (detailInfo.id?.includes(tabKey)) {
                  detailInfo.api.forEachNode((node: any) => {
                    if (node.data?.id === rowId) {
                      runDetailCalc(node, detailInfo.api, row, masterId, tabKey, masterRowKey);
                    }
                  });
                  detailInfo.api.refreshCells({ force: true });
                }
              });
            }
          }
          recalcAggregates(masterId, masterRowKey);
          break;
        }
      }
    }

    currentLookupRule.value = null;
    currentLookupRowId.value = null;
  }

  function onLookupCancel() {
    currentLookupRule.value = null;
    currentLookupRowId.value = null;
  }

  return {
    lookupDialogRef,
    currentLookupRule,
    currentLookupRowId,
    currentLookupIsMaster,
    currentLookupTabKey,
    onMasterCellClicked,
    onDetailCellClicked,
    onLookupSelect,
    onLookupCancel
  };
}
