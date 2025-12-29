/**
 * 聚合引擎
 * 从 PAGE_COMPONENT 的 LOGIC_AGG 配置读取聚合规则，执行跨组件聚合计算
 */
import { compile } from 'mathjs';
import type { GridStore } from './useGridStore';

/** 聚合规则配置（从 COMPONENT_CONFIG 解析） */
export interface AggRule {
  /** 源组件（从表） */
  source?: string;
  /** 目标组件（主表） */
  target: string;
  /** 源字段 */
  sourceField?: string;
  /** 目标字段 */
  targetField: string;
  /** 聚合算法：SUM, AVG, COUNT, MAX, MIN */
  algorithm?: 'SUM' | 'AVG' | 'COUNT' | 'MAX' | 'MIN';
  /** 过滤条件（如 useFlag=='原料'） */
  filter?: string;
  /** 表达式（用于计算字段，如 totalYl + totalFl） */
  expression?: string;
}

/** 组件数据源映射 */
export interface DataSourceMap {
  [componentKey: string]: GridStore;
}

/**
 * 创建聚合引擎
 */
export function useAggEngine() {
  const rules: AggRule[] = [];
  let dataSources: DataSourceMap = {};
  let targetStore: GridStore | null = null;
  let targetRowId: any = null;

  /**
   * 注册聚合规则
   */
  function registerAggRules(aggRules: AggRule[]) {
    rules.length = 0;
    rules.push(...aggRules);
  }

  /**
   * 设置数据源映射
   */
  function setDataSources(sources: DataSourceMap) {
    dataSources = sources;
  }

  /**
   * 设置目标 Store 和当前行 ID
   */
  function setTarget(store: GridStore, rowId: any) {
    targetStore = store;
    targetRowId = rowId;
  }

  /**
   * 执行所有聚合计算
   */
  function calculate() {
    if (!targetStore || targetRowId == null) return;

    const results: Record<string, number> = {};

    // 第一轮：执行 SUM/AVG/COUNT 等聚合
    rules.forEach(rule => {
      if (rule.algorithm && rule.source && rule.sourceField) {
        const sourceStore = dataSources[rule.source];
        if (!sourceStore) return;

        const rows = sourceStore.visibleRows.value;
        const filteredRows = rule.filter ? filterRows(rows, rule.filter) : rows;
        const value = aggregate(filteredRows, rule.sourceField, rule.algorithm);
        
        results[rule.targetField] = round2(value);
      }
    });

    // 第二轮：执行表达式计算（依赖第一轮结果）
    rules.forEach(rule => {
      if (rule.expression && !rule.algorithm) {
        // 获取当前主表行数据
        const currentRow = targetStore!.getRow(targetRowId);
        if (!currentRow) return;

        // 合并已计算的结果和当前行数据
        const context = { ...currentRow, ...results };
        
        try {
          const expr = compile(rule.expression);
          const value = expr.evaluate(context);
          results[rule.targetField] = round2(Number(value) || 0);
        } catch (e) {
          console.warn(`[AggEngine] 表达式计算失败: ${rule.expression}`, e);
          results[rule.targetField] = 0;
        }
      }
    });

    // 更新目标 Store
    targetStore.updateFields(targetRowId, results);
    
    // 标记为级联计算
    Object.keys(results).forEach(field => {
      targetStore!.markChange(targetRowId, field, 'cascade');
    });

    return results;
  }

  /**
   * 过滤行数据
   */
  function filterRows(rows: any[], filterExpr: string): any[] {
    // 简单解析 field=='value' 格式
    const match = filterExpr.match(/(\w+)==['"](.*)['"]/);
    if (!match) return rows;

    const [, field, value] = match;
    return rows.filter(row => row[field] === value);
  }

  /**
   * 执行聚合计算
   */
  function aggregate(rows: any[], field: string, algorithm: string): number {
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
   * 四舍五入到2位小数
   */
  function round2(value: number): number {
    return Math.round(value * 100) / 100;
  }

  return {
    registerAggRules,
    setDataSources,
    setTarget,
    calculate,
    rules
  };
}

export type AggEngine = ReturnType<typeof useAggEngine>;

/**
 * 从 PAGE_COMPONENT 提取聚合规则
 */
export function extractAggRules(components: Api.Metadata.PageComponent[]): AggRule[] {
  const rules: AggRule[] = [];

  function traverse(comps: Api.Metadata.PageComponent[]) {
    comps.forEach(comp => {
      if (comp.componentType === 'LOGIC_AGG' && comp.componentConfig) {
        try {
          const config = JSON.parse(comp.componentConfig) as AggRule;
          rules.push(config);
        } catch (e) {
          console.warn(`[extractAggRules] 解析配置失败: ${comp.componentKey}`, e);
        }
      }
      if (comp.children) {
        traverse(comp.children);
      }
    });
  }

  traverse(components);
  return rules;
}
