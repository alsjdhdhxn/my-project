/**
 * 纯函数计算引擎
 * 无 Vue/AG Grid 依赖，可独立测试
 */
import { compile, type EvalFunction } from 'mathjs';

// ==================== 类型定义 ====================

/** 行级计算规则 */
export interface CalcRule {
  field: string;
  expression: string;
  triggerFields: string[];
  condition?: string; // JS 语法条件，如 "useFlag !== '包材'"
  order?: number;
}

/** 聚合规则 */
export interface AggRule {
  sourceField?: string;
  targetField: string;
  algorithm?: 'SUM' | 'AVG' | 'COUNT' | 'MAX' | 'MIN';
  filter?: string; // JS 语法，如 "useFlag === '原料'"
  expression?: string; // 表达式计算，如 "totalYl + totalFl"
}

/** 编译后的计算规则 */
interface CompiledCalcRule extends CalcRule {
  compiled: EvalFunction;
}

/** 编译后的聚合规则 */
interface CompiledAggRule extends AggRule {
  compiledExpr?: EvalFunction;
}

// ==================== 编译缓存 ====================

const calcRuleCache = new Map<string, CompiledCalcRule[]>();
const aggRuleCache = new Map<string, CompiledAggRule[]>();

// ==================== 核心函数 ====================

/**
 * 编译计算规则（带缓存）
 */
export function compileCalcRules(rules: CalcRule[], cacheKey?: string): CompiledCalcRule[] {
  if (cacheKey && calcRuleCache.has(cacheKey)) {
    return calcRuleCache.get(cacheKey)!;
  }

  const compiled = rules.map((rule, idx) => ({
    ...rule,
    order: rule.order ?? idx,
    compiled: compile(rule.expression)
  }));

  // 按 order 排序
  compiled.sort((a, b) => (a.order ?? 0) - (b.order ?? 0));

  if (cacheKey) {
    calcRuleCache.set(cacheKey, compiled);
  }

  return compiled;
}

/**
 * 编译聚合规则（带缓存）
 */
export function compileAggRules(rules: AggRule[], cacheKey?: string): CompiledAggRule[] {
  if (cacheKey && aggRuleCache.has(cacheKey)) {
    return aggRuleCache.get(cacheKey)!;
  }

  const compiled = rules.map(rule => ({
    ...rule,
    compiledExpr: rule.expression ? compile(rule.expression) : undefined
  }));

  if (cacheKey) {
    aggRuleCache.set(cacheKey, compiled);
  }

  return compiled;
}

/**
 * 评估条件表达式（JS 语法）
 */
export function evalCondition(condition: string | undefined, row: Record<string, any>): boolean {
  if (!condition) return true;

  try {
    // 构建安全的条件评估函数
    const fn = new Function(...Object.keys(row), `return ${condition}`);
    return fn(...Object.values(row));
  } catch (e) {
    console.warn('[Calculator] 条件评估失败:', condition, e);
    return true; // 条件失败时默认执行
  }
}

/**
 * 行级计算 - 纯函数
 * @param row 行数据
 * @param context 上下文（主表广播字段）
 * @param rules 编译后的计算规则
 * @param precision 小数精度，默认 2
 * @returns 计算后的字段值 Map
 */
export function calcRowFields(
  row: Record<string, any>,
  context: Record<string, any>,
  rules: CompiledCalcRule[],
  precision = 2
): Record<string, number> {
  const results: Record<string, number> = {};
  const scope = { ...context, ...row };

  for (const rule of rules) {
    // 检查条件
    if (!evalCondition(rule.condition, row)) {
      continue;
    }

    try {
      const value = rule.compiled.evaluate(scope);
      const rounded = round(value, precision);
      results[rule.field] = rounded;
      // 更新 scope，支持级联计算
      scope[rule.field] = rounded;
    } catch (e) {
      console.warn('[Calculator] 计算错误:', rule.field, rule.expression, e);
      results[rule.field] = 0;
    }
  }

  return results;
}

/**
 * 获取受影响的计算规则
 * @param field 变化的字段
 * @param rules 所有规则
 * @param isBroadcast 是否是广播字段（从 expression 中查找）
 */
export function getAffectedRules(
  field: string,
  rules: CompiledCalcRule[],
  isBroadcast = false
): CompiledCalcRule[] {
  const affected = new Set<string>();
  const queue = [field];

  while (queue.length > 0) {
    const current = queue.shift()!;

    for (const rule of rules) {
      const isDep = isBroadcast
        ? rule.expression.includes(current)
        : rule.triggerFields.includes(current);

      if (isDep && !affected.has(rule.field)) {
        affected.add(rule.field);
        queue.push(rule.field);
      }
    }
  }

  return rules.filter(r => affected.has(r.field));
}

/**
 * 聚合计算 - 纯函数
 * @param rows 从表行数组
 * @param rules 编译后的聚合规则
 * @param currentMaster 当前主表行（用于表达式计算）
 * @param precision 小数精度
 * @returns 聚合结果 Map
 */
export function calcAggregates(
  rows: Record<string, any>[],
  rules: CompiledAggRule[],
  currentMaster: Record<string, any> = {},
  precision = 2
): Record<string, number> {
  const results: Record<string, number> = {};

  // 第一轮：执行 SUM/AVG/COUNT 等聚合
  for (const rule of rules) {
    if (rule.algorithm && rule.sourceField) {
      const filteredRows = rule.filter ? filterRows(rows, rule.filter) : rows;
      const value = aggregate(filteredRows, rule.sourceField, rule.algorithm);
      results[rule.targetField] = round(value, precision);
    }
  }

  // 第二轮：执行表达式计算（依赖第一轮结果）
  for (const rule of rules) {
    if (rule.compiledExpr && !rule.algorithm) {
      const context = { ...currentMaster, ...results };
      try {
        const value = rule.compiledExpr.evaluate(context);
        results[rule.targetField] = round(Number(value) || 0, precision);
      } catch (e) {
        console.warn('[Calculator] 聚合表达式计算失败:', rule.expression, e);
        results[rule.targetField] = 0;
      }
    }
  }

  return results;
}

/**
 * 过滤行数据（JS 语法）
 */
function filterRows(rows: Record<string, any>[], filterExpr: string): Record<string, any>[] {
  return rows.filter(row => {
    try {
      const fn = new Function(...Object.keys(row), `return ${filterExpr}`);
      return fn(...Object.values(row));
    } catch {
      return true;
    }
  });
}

/**
 * 执行聚合计算
 */
function aggregate(rows: Record<string, any>[], field: string, algorithm: string): number {
  if (rows.length === 0) return 0;

  const values = rows.map(r => Number(r[field]) || 0);

  switch (algorithm) {
    case 'SUM':
      return values.reduce((a, b) => a + b, 0);
    case 'AVG':
      return values.reduce((a, b) => a + b, 0) / values.length;
    case 'COUNT':
      return rows.length;
    case 'MAX':
      return Math.max(...values);
    case 'MIN':
      return Math.min(...values);
    default:
      return 0;
  }
}

/**
 * 四舍五入
 */
function round(value: number, precision: number): number {
  if (Number.isNaN(value) || !Number.isFinite(value)) return 0;
  const factor = 10 ** precision;
  return Math.round(value * factor) / factor;
}

/**
 * 清除编译缓存
 */
export function clearCalcCache(cacheKey?: string) {
  if (cacheKey) {
    calcRuleCache.delete(cacheKey);
    aggRuleCache.delete(cacheKey);
  } else {
    calcRuleCache.clear();
    aggRuleCache.clear();
  }
}
