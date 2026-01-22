import type { Ref, ShallowRef } from 'vue';
import type { GridApi } from 'ag-grid-community';
import {
  calcRowFields,
  calcAggregates,
  compileCalcRules,
  compileAggRules,
  type ParsedPageConfig,
  type RowData
} from '@/v3/logic/calc-engine';
import {
  applySummaryRowValues,
  buildSummaryRows,
  getSummaryRowId,
  resolveSummaryConfig
} from '@/v3/composables/meta-v3/summary-config';
import { debugLog, isDebugEnabled } from '@/v3/composables/meta-v3/debug';

type CompiledCalcRules = ReturnType<typeof compileCalcRules>;

type CompiledAggRules = ReturnType<typeof compileAggRules>;

export function useCalcBroadcast(params: {
  masterGridApi: ShallowRef<GridApi | null>;
  masterRows: Ref<RowData[]>;
  detailCache: Map<number, Record<string, RowData[]>>;
  broadcastFields: Ref<string[]>;
  detailCalcRulesByTab: Ref<Record<string, CompiledCalcRules>>;
  compiledAggRules: Ref<CompiledAggRules>;
  compiledMasterCalcRules: Ref<CompiledCalcRules>;
  pageConfig: Ref<ParsedPageConfig | null>;
  loadDetailData?: (masterId: number) => Promise<void>;
  detailGridApisByTab?: Ref<Record<string, any>>;
}) {
  const {
    masterGridApi,
    masterRows,
    detailCache,
    broadcastFields,
    detailCalcRulesByTab,
    compiledAggRules,
    compiledMasterCalcRules,
    pageConfig,
    loadDetailData,
    detailGridApisByTab
  } = params;

  function markFieldChange(row: RowData, field: string, oldValue: any, newValue: any, type: 'user' | 'calc') {
    if (!row._dirtyFields) row._dirtyFields = {};
    if (!row._dirtyFields[field]) {
      row._dirtyFields[field] = { originalValue: oldValue, type };
    } else {
      if (newValue === row._dirtyFields[field].originalValue) {
        delete row._dirtyFields[field];
        if (Object.keys(row._dirtyFields).length === 0) delete row._dirtyFields;
        return;
      }
      if (type === 'user') row._dirtyFields[field].type = 'user';
    }
    console.log('[markFieldChange]', field, type, row._dirtyFields);
  }

  function runDetailCalc(node: any, api: any, row: RowData, masterId: number, tabKey: string) {
    const masterRow = masterRows.value.find(r => r.id === masterId);
    if (!masterRow) return;
    const calcRules = detailCalcRulesByTab.value[tabKey] || [];
    if (calcRules.length === 0) return;

    const context: Record<string, any> = {};
    for (const field of broadcastFields.value) context[field] = masterRow[field];

    const results = calcRowFields(row, context, calcRules);
    const changedFields: string[] = [];
    for (const [field, value] of Object.entries(results)) {
      if (row[field] !== value) {
        const oldValue = row[field];
        row[field] = value;
        markFieldChange(row, field, oldValue, value, 'calc');
        changedFields.push(field);
      }
    }
    if (changedFields.length > 0) {
      if (node) {
        api?.refreshCells({ rowNodes: [node], columns: changedFields, force: true });
      } else {
        api?.refreshCells({ force: true });
      }
      if (isDebugEnabled()) {
        debugLog('detail-calc', {
          masterId,
          tabKey,
          rowId: row?.id,
          changedFields,
          context
        });
      }
    }
  }

  function runMasterCalc(node: any, row: RowData) {
    if (compiledMasterCalcRules.value.length === 0) return;
    const results = calcRowFields(row, {}, compiledMasterCalcRules.value);
    const changedFields: string[] = [];
    for (const [field, value] of Object.entries(results)) {
      if (row[field] !== value) {
        const oldValue = row[field];
        row[field] = value;
        markFieldChange(row, field, oldValue, value, 'calc');
        changedFields.push(field);
      }
    }
    if (changedFields.length > 0) {
      if (node) {
        masterGridApi.value?.refreshCells({ rowNodes: [node], columns: changedFields, force: true });
      } else {
        masterGridApi.value?.refreshCells({ force: true });
      }
      if (isDebugEnabled()) {
        debugLog('master-calc', {
          masterId: row?.id,
          changedFields
        });
      }
    }
  }

  async function broadcastToDetail(masterId: number, masterRow: RowData) {
    let cached = detailCache.get(masterId);
    if (!cached && loadDetailData) {
      await loadDetailData(masterId);
      cached = detailCache.get(masterId);
    }
    if (!cached) return;

    const context: Record<string, any> = {};
    for (const field of broadcastFields.value) context[field] = masterRow[field];

    for (const [tabKey, rows] of Object.entries(cached)) {
      const calcRules = detailCalcRulesByTab.value[tabKey] || [];
      if (calcRules.length === 0) continue;
      let changedCount = 0;
      for (const row of rows) {
        if (row._isDeleted) continue;
        const results = calcRowFields(row, context, calcRules);
        for (const [field, value] of Object.entries(results)) {
          if (row[field] !== value) {
            const oldValue = row[field];
            row[field] = value;
            markFieldChange(row, field, oldValue, value, 'calc');
            changedCount += 1;
          }
        }
      }
      if (isDebugEnabled() && changedCount > 0) {
        debugLog('broadcast-detail', {
          masterId,
          tabKey,
          changedCount
        });
      }
    }

    refreshAllDetailGrids(masterId);
    recalcAggregates(masterId);
    console.log('[broadcast done]', masterId);
  }

  function refreshAllDetailGrids(masterId: number) {
    const detailApis = detailGridApisByTab?.value;
    if (detailApis && Object.keys(detailApis).length > 0) {
      Object.values(detailApis).forEach(api => api?.refreshCells?.({ force: true }));
      return;
    }
    const api = masterGridApi.value;
    if (!api) return;
    const secondLevelInfo = api.getDetailGridInfo(`detail_${masterId}`);
    if (!secondLevelInfo?.api) {
      console.log('[refresh third level] second level not expanded');
      return;
    }
    const cached = detailCache.get(masterId);
    if (!cached) return;
    const tabs = pageConfig.value?.tabs || [];

    secondLevelInfo.api.forEachDetailGridInfo((detailInfo: any) => {
      if (!detailInfo?.api) return;
      let tabKey: string | undefined;
      for (const tab of tabs) {
        if (detailInfo.id?.includes(tab.key)) {
          tabKey = tab.key;
          break;
        }
      }
      if (!tabKey || !cached[tabKey]) return;
      console.log('[refresh third level]', tabKey, cached[tabKey].length, 'rows');
      detailInfo.api.refreshCells({ force: true });
    });
  }

  function recalcAggregates(masterId: number) {
    const cached = detailCache.get(masterId);
    if (!cached) return;
    const masterNode = masterGridApi.value?.getRowNode(String(masterId));
    if (!masterNode) return;
    const masterRow = masterNode.data;

    const allRows: RowData[] = [];
    for (const rows of Object.values(cached)) {
      allRows.push(...rows.filter(r => !r._isDeleted));
    }

    const results = calcAggregates(
      allRows,
      compiledAggRules.value,
      masterRow as Record<string, any>,
      2,
      pageConfig.value?.postProcess
    );

    const changedFields: string[] = [];
    for (const [field, value] of Object.entries(results)) {
      if (masterRow[field] !== value) {
        const oldValue = masterRow[field];
        masterRow[field] = value;
        markFieldChange(masterRow, field, oldValue, value, 'calc');
        changedFields.push(field);
      }
    }

    if (compiledMasterCalcRules.value.length > 0) {
      const calcResults = calcRowFields(masterRow, {}, compiledMasterCalcRules.value);
      for (const [field, value] of Object.entries(calcResults)) {
        if (masterRow[field] !== value) {
          const oldValue = masterRow[field];
          masterRow[field] = value;
          markFieldChange(masterRow, field, oldValue, value, 'calc');
          changedFields.push(field);
        }
      }
    }

    if (changedFields.length > 0) {
      masterGridApi.value?.refreshCells({ rowNodes: [masterNode], columns: changedFields, force: true });
    }

    refreshSummaryRow(masterId);
    if (isDebugEnabled()) {
      debugLog('aggregate', { masterId, results });
    }
    console.log('[aggregate calc]', results);
  }

  function refreshSummaryRow(masterId: number) {
    const api = masterGridApi.value;
    if (!api) return;
    const secondLevelInfo = api.getDetailGridInfo(`detail_${masterId}`);
    if (!secondLevelInfo?.api) return;
    const cached = detailCache.get(masterId);
    if (!cached || !pageConfig.value) return;

    const summaryConfig = resolveSummaryConfig(pageConfig.value);
    const summaryRows = buildSummaryRows({
      masterId,
      pageConfig: pageConfig.value,
      detailCache,
      summaryConfig
    });

    for (const summaryRow of summaryRows) {
      const tabKey = summaryRow._tabKey;
      if (!tabKey) continue;
      const summaryNode = secondLevelInfo.api.getRowNode(getSummaryRowId(masterId, String(tabKey)));
      if (summaryNode) {
        applySummaryRowValues(summaryNode, summaryRow, summaryConfig);
      }
    }
  }

  return {
    markFieldChange,
    runDetailCalc,
    runMasterCalc,
    broadcastToDetail,
    refreshAllDetailGrids,
    recalcAggregates,
    refreshSummaryRow
  };
}

