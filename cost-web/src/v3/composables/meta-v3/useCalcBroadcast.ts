import type { Ref, ShallowRef } from 'vue';
import type { GridApi } from 'ag-grid-community';
import {
  calcRowFields,
  calcAggregates,
  compileCalcRules,
  compileAggRules,
  getAffectedRules,
  ensureRowKey,
  type ParsedPageConfig,
  type RowData
} from '@/v3/logic/calc-engine';
import {
  applySummaryRowValues,
  buildSummaryRows,
  getSummaryRowId,
  resolveSummaryConfig
} from '@/v3/composables/meta-v3/summary-config';

type CompiledCalcRules = ReturnType<typeof compileCalcRules>;

type CompiledAggRules = ReturnType<typeof compileAggRules>;

type CalcChange = {
  rowId?: string | number;
  field: string;
  oldValue: any;
  newValue: any;
  reason?: string;
};

type DetailLogGroup = {
  tabKey: string;
  rules: any[];
  ruleIndexMap: Map<string, { index: number; type: string }>;
  changes: CalcChange[];
};

type AggregateLog = {
  masterId: number;
  rowCount: number;
  aggregateRules: any[];
  masterCalcRules: any[];
  changes: CalcChange[];
};

const CALC_LOG_FLAG = '__META_V3_CALC_LOG__';

export function useCalcBroadcast(params: {
  masterGridApi: ShallowRef<GridApi | null>;
  getMasterRowById: (masterId: number) => RowData | null;
  getMasterRowByRowKey: (rowKey: string) => RowData | null;
  resolveMasterRowKey: (masterId: number) => string | null;
  detailCache: Map<string, Record<string, RowData[]>>;
  broadcastFields: Ref<string[]>;
  detailCalcRulesByTab: Ref<Record<string, CompiledCalcRules>>;
  compiledAggRules: Ref<CompiledAggRules>;
  compiledMasterCalcRules: Ref<CompiledCalcRules>;
  pageConfig: Ref<ParsedPageConfig | null>;
  loadDetailData?: (masterId: number, masterRowKey?: string) => Promise<void>;
  detailGridApisByTab?: Ref<Record<string, any>>;
}) {
  const {
    masterGridApi,
    getMasterRowById,
    getMasterRowByRowKey,
    resolveMasterRowKey,
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
  }

  function formatValue(value: any) {
    if (typeof value === 'string') return `"${value}"`;
    if (value == null) return String(value);
    return String(value);
  }

  function formatCalcRule(rule: any) {
    const base = rule.expression
      ? `${rule.field} = ${rule.expression}`
      : rule.formulaField
        ? `${rule.field} = [formula by ${rule.formulaField}]`
        : `${rule.field} = [rule]`;
    return rule.condition ? `${base} | condition: ${rule.condition}` : base;
  }

  function formatAggRule(rule: any) {
    if (rule.algorithm && rule.sourceField) {
      const base = `${rule.targetField} = ${rule.algorithm}(${rule.sourceField})`;
      return rule.filter ? `${base} | filter: ${rule.filter}` : base;
    }
    if (rule.expression) return `${rule.targetField} = ${rule.expression}`;
    return `${rule.targetField} = [rule]`;
  }

  function buildRuleIndexMap(rules: any[]) {
    const map = new Map<string, { index: number; type: string }>();
    rules.forEach((rule, idx) => {
      const reasonType = rule.expression ? 'expression' : rule.formulaField ? 'formula' : 'rule';
      if (rule.field) {
        map.set(rule.field, { index: idx + 1, type: reasonType });
      } else if (rule.targetField) {
        map.set(rule.targetField, { index: idx + 1, type: rule.expression ? 'expression' : 'aggregate' });
      }
    });
    return map;
  }

  function isCalcLogEnabled(): boolean {
    try {
      const g = globalThis as any;
      if (g && Object.prototype.hasOwnProperty.call(g, CALC_LOG_FLAG)) {
        return Boolean(g[CALC_LOG_FLAG]);
      }
    } catch {
      // ignore
    }
    return true;
  }

  function logCalcBroadcast(params: {
    masterId: number;
    triggerFields: string[];
    detailLogs: DetailLogGroup[];
    aggregateLog?: AggregateLog | null;
  }) {
    if (!isCalcLogEnabled()) return;
    const { masterId, triggerFields, detailLogs, aggregateLog } = params;
    const hasDetail = detailLogs.some(group => group.changes.length > 0);
    const hasMaster = aggregateLog?.changes?.length;
    if (!hasDetail && !hasMaster) return;

    const header = `[MetaV3][CALC] masterId=${masterId}`;
    console.groupCollapsed(header);
    console.log('trigger:');
    console.log(`  - broadcastFields: [${triggerFields.map(f => `"${f}"`).join(', ')}]`);

    for (const group of detailLogs) {
      if (group.changes.length === 0) continue;
      console.log(`detail rules (${group.tabKey}):`);
      for (const rule of group.rules) {
        const ruleMeta = group.ruleIndexMap.get(rule.field);
        const prefix = ruleMeta ? `(#${ruleMeta.index}) ` : '';
        console.log(`  - ${prefix}${formatCalcRule(rule)}`);
      }
      console.log('detail changes:');
      console.table(group.changes.map(change => ({
        rowId: change.rowId ?? '-',
        field: change.field,
        from: formatValue(change.oldValue),
        to: formatValue(change.newValue),
        reason: change.reason ?? ''
      })));
    }

    if (aggregateLog && aggregateLog.changes.length > 0) {
      const aggIndexMap = buildRuleIndexMap(aggregateLog.aggregateRules);
      const calcIndexMap = buildRuleIndexMap(aggregateLog.masterCalcRules);

      console.log('master rules (aggregate):');
      for (const rule of aggregateLog.aggregateRules) {
        const ruleMeta = aggIndexMap.get(rule.targetField);
        const prefix = ruleMeta ? `(#${ruleMeta.index}) ` : '';
        console.log(`  - ${prefix}${formatAggRule(rule)}`);
      }
      if (aggregateLog.masterCalcRules.length > 0) {
        console.log('master rules (calc):');
        for (const rule of aggregateLog.masterCalcRules) {
          const ruleMeta = calcIndexMap.get(rule.field);
          const prefix = ruleMeta ? `(#${ruleMeta.index}) ` : '';
          console.log(`  - ${prefix}${formatCalcRule(rule)}`);
        }
      }

      console.log('master changes:');
      console.table(aggregateLog.changes.map(change => ({
        field: change.field,
        from: formatValue(change.oldValue),
        to: formatValue(change.newValue),
        reason: change.reason ?? ''
      })));
    }

    console.groupEnd();
  }

  function runDetailCalc(node: any, api: any, row: RowData, masterId: number, tabKey: string, masterRowKey?: string) {
    const masterRow = getMasterRowById(masterId) || (masterRowKey ? getMasterRowByRowKey(masterRowKey) : null);
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
    }
  }

  function resolveAffectedRules(calcRules: CompiledCalcRules, changedFields: string[]) {
    if (changedFields.length === 0) return calcRules;
    const affectedFields = new Set<string>();
    for (const field of changedFields) {
      for (const rule of getAffectedRules(field, calcRules, true)) {
        affectedFields.add(rule.field);
      }
    }
    if (affectedFields.size === 0) return [];
    return calcRules.filter(rule => affectedFields.has(rule.field));
  }

  async function broadcastToDetail(masterId: number, masterRow: RowData, changedFields?: string | string[]) {
    const masterRowKey = ensureRowKey(masterRow);
    let cached = detailCache.get(masterRowKey);
    if (!cached && loadDetailData) {
      await loadDetailData(masterId, masterRowKey);
      cached = detailCache.get(masterRowKey);
    }
    if (!cached) return;

    const context: Record<string, any> = {};
    for (const field of broadcastFields.value) context[field] = masterRow[field];
    const changedList = Array.isArray(changedFields)
      ? changedFields.filter(Boolean)
      : changedFields
        ? [changedFields]
        : [];

    const detailLogs: DetailLogGroup[] = [];
    for (const [tabKey, rows] of Object.entries(cached)) {
      const calcRules = detailCalcRulesByTab.value[tabKey] || [];
      if (calcRules.length === 0) continue;
      const effectiveRules = resolveAffectedRules(calcRules, changedList);
      if (effectiveRules.length === 0) continue;
      const ruleIndexMap = buildRuleIndexMap(calcRules);
      const changes: CalcChange[] = [];
      for (const row of rows) {
        if (row._isDeleted) continue;
        const results = calcRowFields(row, context, effectiveRules);
        for (const [field, value] of Object.entries(results)) {
          if (row[field] !== value) {
            const oldValue = row[field];
            row[field] = value;
            markFieldChange(row, field, oldValue, value, 'calc');
            const reasonMeta = ruleIndexMap.get(field);
            const reason = reasonMeta ? `rule#${reasonMeta.index} / ${reasonMeta.type}` : undefined;
            changes.push({ rowId: row?.id ?? row?._rowKey, field, oldValue, newValue: value, reason });
          }
        }
      }
      if (changes.length > 0) {
        detailLogs.push({
          tabKey,
          rules: effectiveRules,
          ruleIndexMap,
          changes
        });
      }
    }

    refreshAllDetailGrids(masterRowKey);
    const aggregateLog = recalcAggregates(masterId, masterRowKey);
    logCalcBroadcast({
      masterId,
      triggerFields: changedList,
      detailLogs,
      aggregateLog
    });
  }

  function refreshAllDetailGrids(masterRowKey: string) {
    const detailApis = detailGridApisByTab?.value;
    if (detailApis && Object.keys(detailApis).length > 0) {
      Object.values(detailApis).forEach(api => api?.refreshCells?.({ force: true }));
      return;
    }
    const api = masterGridApi.value;
    if (!api) return;
    const secondLevelInfo = api.getDetailGridInfo(`detail_${masterRowKey}`);
    if (!secondLevelInfo?.api) {
      return;
    }
    const cached = detailCache.get(masterRowKey);
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
      detailInfo.api.refreshCells({ force: true });
    });
  }

  function recalcAggregates(masterId: number, masterRowKey?: string): AggregateLog | null {
    const resolvedRowKey = masterRowKey ?? resolveMasterRowKey(masterId);
    if (!resolvedRowKey) return null;
    const cached = detailCache.get(resolvedRowKey);
    if (!cached) return null;
    const masterNode = masterGridApi.value?.getRowNode(String(resolvedRowKey));
    if (!masterNode) return null;
    const masterRow = masterNode.data;
    const effectiveMasterId = masterRow?.id ?? masterId;

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
    const changes: CalcChange[] = [];
    const aggReasonMap = buildRuleIndexMap(compiledAggRules.value);
    for (const [field, value] of Object.entries(results)) {
      if (masterRow[field] !== value) {
        const oldValue = masterRow[field];
        masterRow[field] = value;
        markFieldChange(masterRow, field, oldValue, value, 'calc');
        changedFields.push(field);
        const reasonMeta = aggReasonMap.get(field);
        const reason = reasonMeta ? `rule#${reasonMeta.index} / aggregate` : undefined;
        changes.push({ field, oldValue, newValue: value, reason });
      }
    }

    if (compiledMasterCalcRules.value.length > 0) {
      const calcReasonMap = buildRuleIndexMap(compiledMasterCalcRules.value);
      const calcResults = calcRowFields(masterRow, {}, compiledMasterCalcRules.value);
      for (const [field, value] of Object.entries(calcResults)) {
        if (masterRow[field] !== value) {
          const oldValue = masterRow[field];
          masterRow[field] = value;
          markFieldChange(masterRow, field, oldValue, value, 'calc');
          changedFields.push(field);
          const reasonMeta = calcReasonMap.get(field);
          const reason = reasonMeta ? `rule#${reasonMeta.index} / calc` : undefined;
          changes.push({ field, oldValue, newValue: value, reason });
        }
      }
    }

    if (changedFields.length > 0) {
      masterGridApi.value?.refreshCells({ rowNodes: [masterNode], columns: changedFields, force: true });
    }

    refreshSummaryRow(effectiveMasterId, resolvedRowKey);
    return {
      masterId: effectiveMasterId,
      rowCount: allRows.length,
      aggregateRules: compiledAggRules.value,
      masterCalcRules: compiledMasterCalcRules.value,
      changes
    };
  }

  function refreshSummaryRow(masterId: number, masterRowKey?: string) {
    const api = masterGridApi.value;
    if (!api) return;
    const resolvedRowKey = masterRowKey ?? resolveMasterRowKey(masterId);
    if (!resolvedRowKey) return;
    const secondLevelInfo = api.getDetailGridInfo(`detail_${resolvedRowKey}`);
    if (!secondLevelInfo?.api) return;
    const cached = detailCache.get(resolvedRowKey);
    if (!cached || !pageConfig.value) return;

    const summaryConfig = resolveSummaryConfig(pageConfig.value);
    const summaryRows = buildSummaryRows({
      masterId,
      masterRowKey: resolvedRowKey,
      pageConfig: pageConfig.value,
      detailCache,
      summaryConfig
    });

    for (const summaryRow of summaryRows) {
      const tabKey = summaryRow._tabKey;
      if (!tabKey) continue;
      const summaryNode = secondLevelInfo.api.getRowNode(getSummaryRowId(resolvedRowKey, String(tabKey)));
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
