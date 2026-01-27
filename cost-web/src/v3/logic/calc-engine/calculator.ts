/**
 * 纯函数计算引擎
 * 无 Vue/AG Grid 依赖，可独立测试
 */
import { compile, type EvalFunction } from 'mathjs';

// ==================== 类型定义 ====================

/** 单个公式定义 */
export interface FormulaDefinition {
  expression: string;
  triggerFields: string[];
}

/** 行级计算规则 */
export interface CalcRule {
  field: string;
  expression: string;
  triggerFields: string[];
  condition?: string; // JS 语法条件，如 "useFlag !== '包材'"
  order?: number;
  // 多公式支持
  formulaField?: string; // 指定用哪个字段的值来选公式
  formulas?: Record<string, FormulaDefinition>; // 公式映射表
}

/** 聚合规则 */
export interface AggRule {
  sourceField?: string;
  targetField: string;
  algorithm?: 'SUM' | 'AVG' | 'COUNT' | 'MAX' | 'MIN';
  filter?: string; // JS 语法，如 "useFlag === '原料'"
  expression?: string; // 表达式计算，如 "totalYl + totalFl"
}

/** 聚合配置（包含规则和后处理） */
export interface AggConfig {
  rules: AggRule[];
  postProcess?: string; // 后处理表达式，如 "if (totalYl > 0) { totalYl /= 1.13; ... }"
}

/** 编译后的计算规则 */
interface CompiledCalcRule extends CalcRule {
  compiled?: EvalFunction; // 单公式时使用
  compiledFormulas?: Record<string, EvalFunction>; // 多公式时使用
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

  const compiled = rules.map((rule, idx) => {
    const result: CompiledCalcRule = {
      ...rule,
      order: rule.order ?? idx
    };

    // 多公式模式
    if (rule.formulaField && rule.formulas) {
      result.compiledFormulas = {};
      for (const [key, formula] of Object.entries(rule.formulas)) {
        try {
          result.compiledFormulas[key] = compile(formula.expression);
        } catch (e) {
          console.warn(`[Calculator] 编译公式失败: ${rule.field}.${key}`, e);
        }
      }
    } 
    // 单公式模式
    else if (rule.expression) {
      try {
        result.compiled = compile(rule.expression);
      } catch (e) {
        console.warn(`[Calculator] 编译公式失败: ${rule.field}`, e);
      }
    }

    return result;
  });

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
 * @param precision Optional display precision; null keeps raw values
 * @returns 计算后的字段值 Map
 */
export function calcRowFields(
  row: Record<string, any>,
  context: Record<string, any>,
  rules: CompiledCalcRule[],
  precision: number | null = null
): Record<string, number> {
  const results: Record<string, number> = {};
  
  // 构建 scope，确保数值字段有默认值（避免 null/undefined 导致 NaN）
  const scope: Record<string, any> = {};
  for (const [key, value] of Object.entries({ ...context, ...row })) {
    // 数值类型字段：null/undefined 转为 0
    scope[key] = value ?? 0;
  }

  // 从规则中提取所有依赖字段，确保都有默认值
  for (const rule of rules) {
    // 单公式模式的 triggerFields
    for (const field of rule.triggerFields || []) {
      if (!(field in scope)) {
        scope[field] = 0;
      }
    }
    // 多公式模式的各公式 triggerFields
    if (rule.formulas) {
      for (const formula of Object.values(rule.formulas)) {
        for (const field of formula.triggerFields || []) {
          if (!(field in scope)) {
            scope[field] = 0;
          }
        }
      }
    }
  }

  for (const rule of rules) {
    // 检查条件
    if (!evalCondition(rule.condition, row)) {
      continue;
    }

    try {
      let value: number;

      // 多公式模式：根据 formulaField 的值选择公式
      if (rule.formulaField && rule.compiledFormulas) {
        const formulaKey = String(row[rule.formulaField] ?? '');
        const compiledFormula = rule.compiledFormulas[formulaKey];
        
        if (compiledFormula) {
          value = compiledFormula.evaluate(scope);
        } else {
          // 没有匹配的公式，保持原值不变（不加入 results）
          if (row[rule.field] != null) {
            scope[rule.field] = row[rule.field];
          }
          continue;
        }
      }
      // 单公式模式
      else if (rule.compiled) {
        value = rule.compiled.evaluate(scope);
      } else {
        continue;
      }

      const raw = normalizeNumber(Number(value));
      const output = applyPrecision(raw, precision);
      results[rule.field] = output;
      // 更新 scope，支持级联计算
      scope[rule.field] = raw;
    } catch (e) {
      console.warn('[Calculator] 计算错误:', rule.field, e);
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
      let isDep = false;

      if (isBroadcast) {
        // 广播字段：检查表达式中是否包含该字段
        if (rule.expression && rule.expression.includes(current)) {
          isDep = true;
        }
        // 多公式模式：检查所有公式的表达式
        if (rule.formulas) {
          for (const formula of Object.values(rule.formulas)) {
            if (formula.expression.includes(current)) {
              isDep = true;
              break;
            }
          }
        }
      } else {
        // 普通字段：检查 triggerFields
        if (rule.triggerFields.includes(current)) {
          isDep = true;
        }
        // 多公式模式：检查所有公式的 triggerFields
        if (rule.formulas) {
          for (const formula of Object.values(rule.formulas)) {
            if (formula.triggerFields.includes(current)) {
              isDep = true;
              break;
            }
          }
        }
        // 检查 formulaField 本身是否变化
        if (rule.formulaField === current) {
          isDep = true;
        }
      }

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
 * @param precision Optional display precision; null keeps raw values
 * @param postProcess 后处理表达式
 * @returns 聚合结果 Map
 */
export function calcAggregates(
  rows: Record<string, any>[],
  rules: CompiledAggRule[],
  currentMaster: Record<string, any> = {},
  precision: number | null = null,
  postProcess?: string
): Record<string, number> {
  const results: Record<string, number> = {};

  // 第一轮：执行 SUM/AVG/COUNT 等聚合
  for (const rule of rules) {
    if (rule.algorithm && rule.sourceField) {
      const filteredRows = rule.filter ? filterRows(rows, rule.filter) : rows;
      const value = aggregate(filteredRows, rule.sourceField, rule.algorithm);
      results[rule.targetField] = normalizeNumber(value);
    }
  }

  // 第二轮：执行表达式计算（依赖第一轮结果）
  for (const rule of rules) {
    if (rule.compiledExpr && !rule.algorithm) {
      const context = { ...currentMaster, ...results };
      try {
        const value = rule.compiledExpr.evaluate(context);
        results[rule.targetField] = normalizeNumber(Number(value) || 0);
      } catch (e) {
        console.warn('[Calculator] 聚合表达式计算失败:', rule.expression, e);
        results[rule.targetField] = 0;
      }
    }
  }

  // 第三轮：执行后处理（可修正聚合结果）
  if (postProcess) {
    try {
      // 构建后处理函数，传入所有聚合结果作为可修改变量
      const fields = Object.keys(results);
      const fn = new Function(...fields, `
        ${postProcess}
        return { ${fields.join(', ')} };
      `);
      const processed = fn(...Object.values(results));
      // 更新结果并四舍五入
      for (const field of fields) {
        if (typeof processed[field] === 'number') {
          results[field] = normalizeNumber(processed[field]);
        }
      }
    } catch (e) {
      console.warn('[Calculator] 后处理执行失败:', postProcess, e);
    }
  }

  return applyPrecisionMap(results, precision);
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

function normalizeNumber(value: number): number {
  if (Number.isNaN(value) || !Number.isFinite(value)) return 0;
  return value;
}

function applyPrecision(value: number, precision: number | null): number {
  if (precision == null) return value;
  return round(value, precision);
}

function applyPrecisionMap(
  results: Record<string, number>,
  precision: number | null
): Record<string, number> {
  if (precision == null) return results;
  const output: Record<string, number> = {};
  for (const [field, value] of Object.entries(results)) {
    output[field] = applyPrecision(value, precision);
  }
  return output;
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
