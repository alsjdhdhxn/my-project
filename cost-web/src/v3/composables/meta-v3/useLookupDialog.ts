import { ref, nextTick, type Ref, type ShallowRef } from 'vue';
import type { GridApi } from 'ag-grid-community';
import type { LookupRule } from '@/composables/useMetaColumns';
import { ensureRowKey, type RowData } from '@/v3/logic/calc-engine';

type MarkFieldChange = (row: RowData, field: string, oldValue: any, newValue: any, type: 'user' | 'calc') => void;

type RunMasterCalc = (node: any, row: RowData) => void;

type RunDetailCalc = (node: any, api: any, row: RowData, masterId: number, tabKey: string, masterRowKey?: string) => void;

type RecalcAggregates = (masterId: number, masterRowKey?: string) => void;

type BroadcastToDetail = (masterId: number, row: RowData, changedFields?: string | string[]) => Promise<void>;

type LookupDialogExpose = { open: () => void };

/** 检查回填字段是否会触发计算规则 */
function shouldTriggerCalc(changedFields: string[], calcRules: any[]): boolean {
  if (!calcRules || calcRules.length === 0) return false;
  for (const rule of calcRules) {
    // 单公式模式
    if (rule.triggerFields?.some((f: string) => changedFields.includes(f))) {
      return true;
    }
    // 多公式模式
    if (rule.formulas) {
      for (const formula of Object.values(rule.formulas) as any[]) {
        if (formula.triggerFields?.some((f: string) => changedFields.includes(f))) {
          return true;
        }
      }
    }
  }
  return false;
}

/** 检查回填字段是否会触发聚合规则（需要广播到主表） */
function shouldTriggerAgg(changedFields: string[], aggRules: any[]): boolean {
  if (!aggRules || aggRules.length === 0) return false;
  for (const rule of aggRules) {
    // 检查 sourceField 是否在变化字段中
    if (rule.sourceField && changedFields.includes(rule.sourceField)) {
      return true;
    }
    // 检查 expression 中是否包含变化字段（简单检查）
    if (rule.expression) {
      for (const field of changedFields) {
        if (rule.expression.includes(field)) {
          return true;
        }
      }
    }
  }
  return false;
}

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
  broadcastFields?: Ref<string[]>;
  detailGridApisByTab?: Ref<Record<string, any>>;
  isRowEditable?: (row: RowData) => boolean;
  isDetailRowEditable?: (row: RowData, tabKey: string) => boolean;
  masterCalcRules?: Ref<any[]>;
  detailCalcRulesByTab?: Ref<Record<string, any[]>>;
  compiledAggRules?: Ref<any[]>;
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
    broadcastFields,
    detailGridApisByTab,
    isRowEditable,
    isDetailRowEditable,
    masterCalcRules,
    detailCalcRulesByTab,
    compiledAggRules
  } = params;

  const lookupDialogRef = ref<LookupDialogExpose | null>(null);
  const currentLookupRule = ref<LookupRule | null>(null);
  const currentLookupRowId = ref<number | null>(null);
  const currentLookupRowData = ref<RowData | null>(null);
  const currentLookupCellValue = ref<any>(null);
  const currentLookupIsMaster = ref<boolean>(true);
  const currentLookupTabKey = ref<string>('');

  async function onMasterCellClicked(event: any) {
    // 汇总行不响应点击
    if (event.node?.rowPinned) return;
    const field = event.colDef?.field;
    const rowData = event.data;
    if (!field || !rowData) return;
    
    const rule = masterLookupRules.value.find(r => r.fieldName === field);
    if (!rule) return;
    
    // 检查行是否可编辑（noFillback 模式下允许弹窗查看）
    if (isRowEditable && !isRowEditable(rowData) && !rule.noFillback) return;
    
    currentLookupRule.value = rule;
    currentLookupRowId.value = rowData.id;
    currentLookupRowData.value = rowData;
    currentLookupCellValue.value = rowData[field];
    currentLookupIsMaster.value = true;
    currentLookupTabKey.value = '';
    // 等待 Vue 渲染，确保 LookupDialog 的 props（lookupCode）已更新
    await nextTick();
    lookupDialogRef.value?.open();
  }

  async function onDetailCellClicked(event: any, _masterId: number, tabKey: string) {
    // 汇总行不响应点击
    if (event.node?.rowPinned) return;
    const field = event.colDef?.field;
    const rowData = event.data;
    if (!field || !rowData) return;
    
    const rule = detailLookupRulesByTab.value[tabKey]?.find(r => r.fieldName === field);
    if (!rule) return;
    
    // 检查行是否可编辑（noFillback 模式下允许弹窗查看）
    if (isDetailRowEditable && !isDetailRowEditable(rowData, tabKey) && !rule.noFillback) return;
    
    currentLookupRule.value = rule;
    currentLookupRowId.value = rowData.id;
    currentLookupRowData.value = rowData;
    currentLookupCellValue.value = rowData[field];
    currentLookupIsMaster.value = false;
    currentLookupTabKey.value = tabKey;
    // 等待 Vue 渲染，确保 LookupDialog 的 props（lookupCode）已更新
    await nextTick();
    lookupDialogRef.value?.open();
  }

  function onLookupSelect(fillData: Record<string, any>) {
    // noFillback 模式下不执行回填
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
        // 收集实际变化的字段
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
          // 只有当回填字段会触发计算时才调用计算
          const calcRules = masterCalcRules?.value || [];
          if (changedFields.length > 0 && shouldTriggerCalc(changedFields, calcRules)) {
            runMasterCalc(node, row);
          }
          // 检查是否需要广播到明细（回填字段在 broadcastFields 中）
          if (changedFields.length > 0 && broadcastToDetail && broadcastFields && row.id != null) {
            const broadcastList = broadcastFields.value || [];
            const needBroadcast = changedFields.some(f => broadcastList.includes(f));
            if (needBroadcast) {
              broadcastToDetail(row.id, row, changedFields);
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
          // 收集实际变化的字段
          const changedFields: string[] = [];
          for (const [field, value] of Object.entries(fillData)) {
            if (row[field] !== value) {
              const oldValue = row[field];
              row[field] = value;
              markFieldChange(row, field, oldValue, value, 'user');
              changedFields.push(field);
            }
          }
          // 获取当前 tab 的计算规则
          const calcRules = detailCalcRulesByTab?.value?.[tabKey] || [];
          const needCalc = changedFields.length > 0 && shouldTriggerCalc(changedFields, calcRules);
          // 检查是否需要触发聚合（广播到主表）
          const aggRules = compiledAggRules?.value || [];
          const needAgg = changedFields.length > 0 && shouldTriggerAgg(changedFields, aggRules);
          
          const splitDetailApi = detailGridApisByTab?.value?.[tabKey];
          if (splitDetailApi) {
            const node = splitDetailApi.getRowNode?.(String(rowId));
            if (node && needCalc) {
              runDetailCalc(node, splitDetailApi, row, masterId, tabKey, masterRowKey);
            }
            splitDetailApi.refreshCells?.({ force: true });
          } else {
            const secondLevelInfo = masterGridApi.value?.getDetailGridInfo(`detail_${masterRowKey}`);
            if (secondLevelInfo?.api) {
              secondLevelInfo.api.forEachDetailGridInfo((detailInfo: any) => {
                if (detailInfo.id?.includes(tabKey)) {
                  detailInfo.api.forEachNode((node: any) => {
                    if (node.data?.id === rowId && needCalc) {
                      runDetailCalc(node, detailInfo.api, row, masterId, tabKey, masterRowKey);
                    }
                  });
                  detailInfo.api.refreshCells({ force: true });
                }
              });
            }
          }
          // 触发了从表计算或聚合规则时，重新计算聚合
          if (needCalc || needAgg) {
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
