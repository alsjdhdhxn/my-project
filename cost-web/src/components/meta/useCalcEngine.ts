/**
 * 计算引擎 - 跨表广播 + 聚合
 *
 * 职责：
 * 1. 广播：主表参数变更时，更新从表所有行的 _ctx
 * 2. 聚合：从表数据变更后，汇总到主表
 *
 * 行内计算交给 AG Grid valueGetter
 */
import { reactive } from 'vue';

// ============ 类型定义 ============

/** 广播配置：主表 → 从表 */
export interface BroadcastConfig {
  source: string;       // 源组件 key（主表）
  target: string;       // 目标组件 key（从表）
  fields: string[];     // 要广播的字段
}

/** 聚合配置：从表 → 主表 */
export interface AggConfig {
  source: string;       // 源组件 key（从表）
  target: string;       // 目标组件 key（主表）
  sourceField: string;  // 源字段
  targetField: string;  // 目标字段
  algorithm: 'SUM' | 'AVG' | 'COUNT' | 'MAX' | 'MIN';
  filter?: string;      // 过滤条件，如 "useFlag=='原料'"
  postProcess?: string; // 后处理表达式，如 "result/1.13"
}

/** 引擎配置 */
export interface CalcEngineConfig {
  broadcasts: BroadcastConfig[];
  aggregates: AggConfig[];
}

/** Grid 注册信息 */
interface GridInfo {
  key: string;
  api: any;             // AG Grid API
  getData: () => any[]; // 获取当前数据
  setData: (data: any[]) => void;
}

// ============ 计算引擎 ============

export function useCalcEngine(config: CalcEngineConfig) {
  // 注册的 Grid
  const grids = reactive<Record<string, GridInfo>>({});
  
  // 主表数据（响应式引用）
  let masterData: Record<string, any> = {};

  /** 注册 Grid */
  function registerGrid(info: GridInfo) {
    grids[info.key] = info;
    console.log('[CalcEngine] 注册 Grid:', info.key);
  }

  /** 注销 Grid */
  function unregisterGrid(key: string) {
    delete grids[key];
  }

  /** 设置主表数据引用 */
  function setMasterData(data: Record<string, any>) {
    masterData = data;
  }

  /** 广播：主表字段变更，更新从表 _ctx */
  function broadcast(changedField: string) {
    config.broadcasts.forEach(bc => {
      if (!bc.fields.includes(changedField)) return;

      const targetGrid = grids[bc.target];
      if (!targetGrid) return;

      const rows = targetGrid.getData();
      if (!rows?.length) return;

      // 构建 _ctx 对象
      const ctx: Record<string, any> = {};
      bc.fields.forEach(f => {
        ctx[f] = masterData[f];
      });

      // 更新所有行的 _ctx
      rows.forEach(row => {
        row._ctx = { ...ctx };
      });

      // 刷新 Grid 显示
      targetGrid.api?.refreshCells();
      
      console.log('[CalcEngine] 广播完成:', changedField, '→', bc.target, ctx);
    });

    // 广播后执行聚合
    runAggregates();
  }

  /** 执行所有聚合计算 */
  function runAggregates() {
    const results: Record<string, number> = {};

    config.aggregates.forEach(agg => {
      const sourceGrid = grids[agg.source];
      if (!sourceGrid) return;

      const rows = sourceGrid.getData() || [];
      
      // 过滤
      const filtered = agg.filter 
        ? rows.filter(row => matchFilter(row, agg.filter!))
        : rows;

      // 聚合
      let result = 0;
      switch (agg.algorithm) {
        case 'SUM':
          result = filtered.reduce((sum, r) => sum + (Number(r[agg.sourceField]) || 0), 0);
          break;
        case 'AVG':
          result = filtered.length > 0
            ? filtered.reduce((sum, r) => sum + (Number(r[agg.sourceField]) || 0), 0) / filtered.length
            : 0;
          break;
        case 'COUNT':
          result = filtered.length;
          break;
        case 'MAX':
          result = filtered.length > 0 
            ? Math.max(...filtered.map(r => Number(r[agg.sourceField]) || 0))
            : 0;
          break;
        case 'MIN':
          result = filtered.length > 0
            ? Math.min(...filtered.map(r => Number(r[agg.sourceField]) || 0))
            : 0;
          break;
      }

      // 后处理
      if (agg.postProcess) {
        result = evalPostProcess(agg.postProcess, result, results);
      }

      results[agg.targetField] = round2(result);
    });

    // 一次性更新主表
    Object.entries(results).forEach(([field, value]) => {
      masterData[field] = value;
    });

    // 刷新主表显示
    const masterGridKey = config.broadcasts[0]?.source;
    if (masterGridKey && grids[masterGridKey]) {
      grids[masterGridKey].api?.refreshCells();
    }

    console.log('[CalcEngine] 聚合完成:', results);
  }

  /** 从表数据变更时调用 */
  function onDetailChange() {
    runAggregates();
  }

  /** 初始化从表 _ctx */
  function initDetailCtx(gridKey: string) {
    const bc = config.broadcasts.find(b => b.target === gridKey);
    if (!bc) return;

    const targetGrid = grids[gridKey];
    if (!targetGrid) return;

    const rows = targetGrid.getData();
    if (!rows?.length) return;

    // 构建 _ctx
    const ctx: Record<string, any> = {};
    bc.fields.forEach(f => {
      ctx[f] = masterData[f];
    });

    rows.forEach(row => {
      row._ctx = { ...ctx };
    });

    console.log('[CalcEngine] 初始化 _ctx:', gridKey, ctx);
  }

  // ============ 工具函数 ============

  function matchFilter(row: Record<string, any>, filter: string): boolean {
    try {
      const expr = filter
        .replace(/(\w+)==['"]([^'"]+)['"]/g, "row['$1']==='$2'")
        .replace(/(\w+)!=(['"][^'"]+['"])/g, "row['$1']!==$2")
        .replace(/\|\|/g, '||');
      return new Function('row', `return ${expr};`)(row);
    } catch {
      return true;
    }
  }

  function evalPostProcess(expr: string, result: number, allResults: Record<string, number>): number {
    try {
      // 替换 IF 函数
      let processed = expr.replace(
        /IF\s*\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\s*\)/gi,
        '(($1) ? ($2) : ($3))'
      );
      
      const scope = { result, ...allResults, ...masterData };
      return new Function(...Object.keys(scope), `return ${processed};`)(...Object.values(scope));
    } catch {
      return result;
    }
  }

  function round2(value: number): number {
    return Math.round(value * 100) / 100;
  }

  return {
    registerGrid,
    unregisterGrid,
    setMasterData,
    broadcast,
    onDetailChange,
    initDetailCtx,
    runAggregates
  };
}
