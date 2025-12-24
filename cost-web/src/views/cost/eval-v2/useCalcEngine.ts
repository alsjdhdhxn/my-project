/**
 * 评估单计算引擎（多 Tab 版）
 * 支持不同从表有独立的计算规则
 */
import { compile, type EvalFunction } from 'mathjs';
import type { useDataStore, TabKey } from './useDataStore';

interface CalcRule {
  field: string;
  expression: string;
  compiled: EvalFunction;
  dependencies: {
    master: string[];
    detail: string[];
  };
  order: number;
}

interface AggRule {
  targetField: string;
  sourceField: string;
  sourceTab: TabKey;
  algorithm: 'SUM' | 'AVG' | 'COUNT' | 'MAX' | 'MIN';
}

// 原料/辅料计算规则（共用）
const MATERIAL_RULES: Omit<CalcRule, 'compiled'>[] = [
  {
    field: 'batchQty',
    expression: 'master.apexPl * perHl / 100 / master.yield * 100',
    dependencies: { master: ['apexPl', 'yield'], detail: ['perHl'] },
    order: 1
  },
  {
    field: 'costBatch',
    expression: 'batchQty * price',
    dependencies: { master: [], detail: ['batchQty', 'price'] },
    order: 2
  }
];

// 包材计算规则（独立）
// packQty = 批量(万片) * 1000，即每万片需要1000个包装单位
// packCost = packQty * price
const PACKAGE_RULES: Omit<CalcRule, 'compiled'>[] = [
  {
    field: 'packQty',
    expression: 'master.apexPl * 1000',
    dependencies: { master: ['apexPl'], detail: [] },
    order: 1
  },
  {
    field: 'packCost',
    expression: 'packQty * price',
    dependencies: { master: [], detail: ['packQty', 'price'] },
    order: 2
  }
];

// 聚合规则
const AGG_RULES: AggRule[] = [
  { targetField: 'totalYl', sourceField: 'costBatch', sourceTab: 'material', algorithm: 'SUM' },
  { targetField: 'totalFl', sourceField: 'costBatch', sourceTab: 'auxiliary', algorithm: 'SUM' },
  { targetField: 'totalPack', sourceField: 'packCost', sourceTab: 'package', algorithm: 'SUM' }
];

// 预编译规则
function compileRules(rules: Omit<CalcRule, 'compiled'>[]): CalcRule[] {
  return rules.map(rule => ({
    ...rule,
    compiled: compile(rule.expression)
  })).sort((a, b) => a.order - b.order);
}

export function useCalcEngine(store: ReturnType<typeof useDataStore>) {
  // 按 Tab 类型编译规则
  const rulesByTab: Record<TabKey, CalcRule[]> = {
    material: compileRules(MATERIAL_RULES),
    auxiliary: compileRules(MATERIAL_RULES),  // 辅料用同样的规则
    package: compileRules(PACKAGE_RULES)
  };

  /**
   * 主表字段变化 → 批量计算所有从表
   */
  function onMasterChange(field: string) {
    // 遍历所有 Tab
    (['material', 'auxiliary', 'package'] as TabKey[]).forEach(tabKey => {
      const rules = rulesByTab[tabKey];
      const affected = getAffectedRules(rules, 'master', field);
      
      if (affected.length > 0) {
        store.details.value[tabKey].forEach(row => {
          affected.forEach(rule => {
            const scope = { master: store.master.value, ...row };
            try {
              const result = rule.compiled.evaluate(scope);
              (row as any)[rule.field] = round2(result);
              store.markDetailChange(tabKey, row.id!, rule.field, 'cascade');
            } catch (e) {
              console.warn('[CalcEngine] 计算错误:', tabKey, rule.field, e);
            }
          });
        });
      }
    });

    // 聚合
    runAggregates();
  }

  /**
   * 从表字段变化 → 只计算当前行
   */
  function onDetailChange(tabKey: TabKey, rowId: number, field: string) {
    const row = store.details.value[tabKey].find(r => r.id === rowId);
    if (!row) return;

    const rules = rulesByTab[tabKey];
    const affected = getAffectedRules(rules, 'detail', field);

    if (affected.length > 0) {
      affected.forEach(rule => {
        const scope = { master: store.master.value, ...row };
        try {
          const result = rule.compiled.evaluate(scope);
          (row as any)[rule.field] = round2(result);
          store.markDetailChange(tabKey, rowId, rule.field, 'cascade');
        } catch (e) {
          console.warn('[CalcEngine] 计算错误:', tabKey, rule.field, e);
        }
      });
    }

    // 聚合
    runAggregates();
  }

  /**
   * 获取受影响的规则（BFS 处理级联）
   */
  function getAffectedRules(rules: CalcRule[], source: 'master' | 'detail', field: string): CalcRule[] {
    const affected = new Set<string>();
    const queue = [field];
    let currentSource = source;

    while (queue.length > 0) {
      const current = queue.shift()!;
      rules.forEach(rule => {
        const deps = currentSource === 'master' ? rule.dependencies.master : rule.dependencies.detail;
        if (deps.includes(current) && !affected.has(rule.field)) {
          affected.add(rule.field);
          queue.push(rule.field);
        }
      });
      currentSource = 'detail';
    }

    return rules.filter(r => affected.has(r.field));
  }

  /**
   * 执行聚合计算
   */
  function runAggregates() {
    AGG_RULES.forEach(rule => {
      const rows = store.details.value[rule.sourceTab];
      let result = 0;

      switch (rule.algorithm) {
        case 'SUM':
          result = rows.reduce((sum, r) => sum + (Number((r as any)[rule.sourceField]) || 0), 0);
          break;
        case 'AVG':
          result = rows.length > 0
            ? rows.reduce((sum, r) => sum + (Number((r as any)[rule.sourceField]) || 0), 0) / rows.length
            : 0;
          break;
        case 'COUNT':
          result = rows.length;
          break;
        case 'MAX':
          result = rows.length > 0 ? Math.max(...rows.map(r => Number((r as any)[rule.sourceField]) || 0)) : 0;
          break;
        case 'MIN':
          result = rows.length > 0 ? Math.min(...rows.map(r => Number((r as any)[rule.sourceField]) || 0)) : 0;
          break;
      }

      store.updateMasterField(rule.targetField as any, round2(result));
      store.markMasterChange(rule.targetField, 'cascade');
    });

    // 计算总成本
    const totalCost = store.master.value.totalYl + store.master.value.totalFl + store.master.value.totalPack;
    store.updateMasterField('totalCost', round2(totalCost));
    store.markMasterChange('totalCost', 'cascade');
  }

  /**
   * 初始化计算
   */
  function initCalc() {
    (['material', 'auxiliary', 'package'] as TabKey[]).forEach(tabKey => {
      const rules = rulesByTab[tabKey];
      store.details.value[tabKey].forEach(row => {
        rules.forEach(rule => {
          const scope = { master: store.master.value, ...row };
          try {
            const result = rule.compiled.evaluate(scope);
            (row as any)[rule.field] = round2(result);
          } catch (e) {
            console.warn('[CalcEngine] 初始化计算错误:', tabKey, rule.field, e);
          }
        });
      });
    });

    runAggregates();
  }

  function round2(v: number): number {
    if (isNaN(v) || !isFinite(v)) return 0;
    return Math.round(v * 100) / 100;
  }

  return {
    onMasterChange,
    onDetailChange,
    initCalc
  };
}
