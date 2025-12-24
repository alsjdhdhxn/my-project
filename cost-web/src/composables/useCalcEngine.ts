/**
 * 通用计算引擎
 * 支持行级计算、聚合计算、级联依赖
 */
import { compile, type EvalFunction } from 'mathjs';
import type { GridStore, RowData } from './useGridStore';

/** 行级计算规则 */
export interface CalcRule {
  /** 目标字段 */
  field: string;
  /** 计算表达式（mathjs语法） */
  expression: string;
  /** 依赖字段 */
  dependencies: string[];
  /** 执行顺序 */
  order?: number;
}

/** 聚合规则 */
export interface AggRule {
  /** 目标字段 */
  targetField: string;
  /** 源字段 */
  sourceField: string;
  /** 聚合算法 */
  algorithm: 'SUM' | 'AVG' | 'COUNT' | 'MAX' | 'MIN';
  /** 过滤条件（可选） */
  filter?: (row: RowData) => boolean;
}

interface CompiledRule extends CalcRule {
  compiled: EvalFunction;
}

export interface CalcEngineOptions {
  /** 上下文数据（如主表数据） */
  context?: Record<string, any>;
  /** 小数位数，默认2 */
  precision?: number;
  /** 聚合结果回调 */
  onAggregateChange?: (results: Record<string, number>) => void;
}

export function useCalcEngine(store: GridStore, options: CalcEngineOptions = {}) {
  const { precision = 2, onAggregateChange } = options;
  
  const calcRules: CompiledRule[] = [];
  const aggRules: AggRule[] = [];
  let contextRef: Record<string, any> = options.context || {};

  /**
   * 设置上下文（如主表数据）
   */
  function setContext(ctx: Record<string, any>) {
    contextRef = ctx;
  }

  /**
   * 注册行级计算规则
   */
  function registerCalcRule(rule: CalcRule) {
    const compiled = compile(rule.expression);
    calcRules.push({
      ...rule,
      order: rule.order ?? calcRules.length,
      compiled
    });
    // 按 order 排序
    calcRules.sort((a, b) => (a.order ?? 0) - (b.order ?? 0));
  }

  /**
   * 批量注册计算规则
   */
  function registerCalcRules(rules: CalcRule[]) {
    rules.forEach(registerCalcRule);
  }

  /**
   * 注册聚合规则
   */
  function registerAggRule(rule: AggRule) {
    aggRules.push(rule);
  }

  /**
   * 批量注册聚合规则
   */
  function registerAggRules(rules: AggRule[]) {
    rules.forEach(registerAggRule);
  }

  /**
   * 字段变化时触发计算
   */
  function onFieldChange(rowId: number | string, field: string) {
    const row = store.getRow(rowId);
    if (!row) return;

    // 找出受影响的规则（BFS处理级联）
    const affected = getAffectedRules(field);
    
    // 执行计算
    affected.forEach(rule => {
      const scope = { ...contextRef, ...row };
      try {
        const result = rule.compiled.evaluate(scope);
        const rounded = round(result);
        store.updateField(rowId, rule.field, rounded);
        store.markChange(rowId, rule.field, 'cascade');
      } catch (e) {
        console.warn('[CalcEngine] 计算错误:', rule.field, e);
      }
    });

    // 执行聚合
    runAggregates();
  }

  /**
   * 上下文变化时批量计算所有行
   */
  function onContextChange(field: string) {
    const affected = getAffectedRules(field, true);
    console.log('[CalcEngine] onContextChange:', field, 'affected rules:', affected.map(r => r.field));
    
    if (affected.length > 0) {
      store.rows.value.forEach(row => {
        if (row._isDeleted) return;
        
        affected.forEach(rule => {
          const scope = { ...contextRef, ...row };
          try {
            const result = rule.compiled.evaluate(scope);
            const rounded = round(result);
            console.log('[CalcEngine] calc:', rule.field, '=', rounded, 'scope:', scope);
            store.updateField(row.id, rule.field, rounded);
            store.markChange(row.id, rule.field, 'cascade');
          } catch (e) {
            console.warn('[CalcEngine] 计算错误:', rule.field, e);
          }
        });
      });
    }

    runAggregates();
  }

  /**
   * 初始化计算（加载数据后调用）
   */
  function initCalc() {
    store.rows.value.forEach(row => {
      if (row._isDeleted) return;
      
      calcRules.forEach(rule => {
        const scope = { ...contextRef, ...row };
        try {
          const result = rule.compiled.evaluate(scope);
          store.updateField(row.id, rule.field, round(result));
        } catch (e) {
          console.warn('[CalcEngine] 初始化计算错误:', rule.field, e);
        }
      });
    });

    runAggregates();
  }

  /**
   * 获取受影响的规则（BFS处理级联）
   */
  function getAffectedRules(field: string, isContext = false): CompiledRule[] {
    const affected = new Set<string>();
    const queue = [field];

    while (queue.length > 0) {
      const current = queue.shift()!;
      calcRules.forEach(rule => {
        // 检查依赖：如果是上下文字段，检查表达式中是否包含该字段
        const isDep = isContext 
          ? rule.expression.includes(current)
          : rule.dependencies.includes(current);
        
        if (isDep && !affected.has(rule.field)) {
          affected.add(rule.field);
          queue.push(rule.field);
        }
      });
    }

    return calcRules.filter(r => affected.has(r.field));
  }

  /**
   * 执行聚合计算
   */
  function runAggregates(): Record<string, number> {
    const results: Record<string, number> = {};

    aggRules.forEach(rule => {
      const rows = store.visibleRows.value.filter(r => 
        !rule.filter || rule.filter(r)
      );

      let result = 0;
      const values = rows.map(r => Number(r[rule.sourceField]) || 0);

      switch (rule.algorithm) {
        case 'SUM':
          result = values.reduce((sum, v) => sum + v, 0);
          break;
        case 'AVG':
          result = values.length > 0 ? values.reduce((sum, v) => sum + v, 0) / values.length : 0;
          break;
        case 'COUNT':
          result = rows.length;
          break;
        case 'MAX':
          result = values.length > 0 ? Math.max(...values) : 0;
          break;
        case 'MIN':
          result = values.length > 0 ? Math.min(...values) : 0;
          break;
      }

      results[rule.targetField] = round(result);
    });

    // 触发回调
    if (onAggregateChange && Object.keys(results).length > 0) {
      onAggregateChange(results);
    }

    return results;
  }

  /**
   * 四舍五入
   */
  function round(v: number): number {
    if (isNaN(v) || !isFinite(v)) return 0;
    const factor = Math.pow(10, precision);
    return Math.round(v * factor) / factor;
  }

  /**
   * 清除规则
   */
  function clearRules() {
    calcRules.length = 0;
    aggRules.length = 0;
  }

  return {
    setContext,
    registerCalcRule,
    registerCalcRules,
    registerAggRule,
    registerAggRules,
    onFieldChange,
    onContextChange,
    initCalc,
    runAggregates,
    clearRules
  };
}

export type CalcEngine = ReturnType<typeof useCalcEngine>;
