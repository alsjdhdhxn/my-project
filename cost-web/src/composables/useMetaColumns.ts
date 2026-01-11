/**
 * 元数据列定义转换
 * 将后端元数据转换为 AG Grid ColDef
 */
import type { ColDef } from 'ag-grid-community';
import { fetchTableMetadata, fetchTableMetadataWithPermission } from '@/service/api';
import type { CalcRule } from '@/logic/calc-engine';

type ColumnMetadata = Api.Metadata.ColumnMetadata;

/** 样式规则 */
export interface StyleRule {
  condition: StyleCondition;
  cellStyle?: Record<string, string>;  // 单元格样式（文字变色等）
  rowStyle?: Record<string, string>;   // 行样式（底色等）
  style?: Record<string, string>;      // 兼容旧格式（等同于 cellStyle）
}

/** 样式条件 */
export interface StyleCondition {
  type: 'contains' | 'startsWith' | 'endsWith' | 'equals' | 'compare';
  pattern?: string;
  compareValue?: any;
  operator?: '>' | '>=' | '<' | '<=' | '==' | '!=';
}

/** 行样式规则（用于 getRowClass） */
export interface RowStyleRule {
  fieldName: string;
  condition: StyleCondition;
  rowStyle: Record<string, string>;
  className: string;
}

/**
 * 元数据转 AG Grid 列定义
 */
export function metaToColDef(col: ColumnMetadata): ColDef {
  const colDef: ColDef = {
    field: col.fieldName,
    headerName: col.headerText,
    editable: Boolean(col.editable),
    sortable: true,
    resizable: true
  };

  // 宽度：只有明确设置了宽度才使用，否则让 flex 生效
  if (col.width && col.width > 0) {
    colDef.width = col.width;
  }

  // 数据类型处理
  switch (col.dataType) {
    case 'number':
      colDef.type = 'numericColumn';
      colDef.valueParser = (params) => {
        const val = Number(params.newValue);
        return isNaN(val) ? 0 : val;
      };
      break;
    case 'date':
      colDef.valueFormatter = (params) => {
        if (!params.value) return '';
        const date = new Date(params.value);
        return isNaN(date.getTime()) ? params.value : date.toLocaleDateString('zh-CN');
      };
      break;
    case 'datetime':
      colDef.valueFormatter = (params) => {
        if (!params.value) return '';
        const date = new Date(params.value);
        return isNaN(date.getTime()) ? params.value : date.toLocaleString('zh-CN');
      };
      break;
  }

  // 样式规则 - 使用 cellClassRules 实现动态样式
  if (col.rulesConfig) {
    try {
      const config = JSON.parse(col.rulesConfig);
      
      // 0. 自定义排序
      if (config.comparator) {
        colDef.comparator = getComparator(config.comparator);
      }
      
      // 1. 样式规则
      if (config.style && Array.isArray(config.style)) {
        const cellClassRules: Record<string, (params: any) => boolean> = {};
        
        config.style.forEach((rule: StyleRule, index: number) => {
          const className = `meta-cell-${col.fieldName}-${index}`;
          const condition = rule.condition;
          
          // 为每个规则创建判断函数
          cellClassRules[className] = (params: any) => {
            const value = params.value;
            if (value == null) return false;
            return matchStyleRule(value, condition);
          };
        });
        
        colDef.cellClassRules = cellClassRules;
        
        // 存储样式规则用于 CSS 注入
        colDef.context = {
          styleRules: config.style,
          fieldName: col.fieldName
        };
      }
      
      // 2. 对比值渲染
      if (config.compare?.enabled) {
        const format = config.compare.format || 'value'; // value/percent/both
        colDef.cellRenderer = (params: any) => {
          return renderCompareValue(params, col.fieldName, format);
        };
      }
    } catch (e) {
      console.warn(`[useMetaColumns] 解析 rulesConfig 失败: ${col.fieldName}`, e);
    }
  }

  return colDef;
}

/**
 * 获取自定义排序函数
 */
function getComparator(comparatorName: string) {
  const comparators: Record<string, (valueA: any, valueB: any) => number> = {
    // 自定义分类排序：原料 → 辅料 → 印字包材 → 非印字包材
    customCategorySort: (valueA: any, valueB: any) => {
      const order: Record<string, number> = {
        '原料': 1,
        '辅料': 2,
        '印字包材': 3,
        '非印字包材': 4
      };
      
      const orderA = order[valueA] || 999;
      const orderB = order[valueB] || 999;
      
      return orderA - orderB;
    }
  };
  
  return comparators[comparatorName] || undefined;
}

/**
 * 匹配样式规则
 */
export function matchStyleRule(value: any, condition: StyleCondition): boolean {
  if (!condition) return false;

  const { type, pattern, operator, compareValue } = condition;

  switch (type) {
    case 'contains':
      return String(value).includes(pattern || '');
    case 'startsWith':
      return String(value).startsWith(pattern || '');
    case 'endsWith':
      return String(value).endsWith(pattern || '');
    case 'equals':
      return value === compareValue;
    case 'compare':
      switch (operator) {
        case '>': return Number(value) > Number(compareValue);
        case '>=': return Number(value) >= Number(compareValue);
        case '<': return Number(value) < Number(compareValue);
        case '<=': return Number(value) <= Number(compareValue);
        case '==': return value == compareValue;
        case '!=': return value != compareValue;
        default: return false;
      }
    default:
      return false;
  }
}

/**
 * 渲染对比值（带箭头和颜色）
 * @param params AG Grid cellRenderer 参数
 * @param fieldName 字段名
 * @param format 格式：value=数值差, percent=百分比, both=两者
 */
function renderCompareValue(params: any, fieldName: string, format: string): string {
  const value = params.value;
  const data = params.data;
  
  if (value == null) return '';
  
  const diff = data?.[`${fieldName}Diff`];
  const diffPercent = data?.[`${fieldName}DiffPercent`];
  
  // 没有历史数据，直接显示当前值
  if (diff == null && diffPercent == null) {
    return String(value);
  }
  
  // 构建差值显示
  let diffHtml = '';
  if (diff != null && diff !== 0) {
    const isUp = diff > 0;
    const arrow = isUp ? '↑' : '↓';
    const color = isUp ? '#43a047' : '#e53935'; // 成本：涨绿跌红（涨是坏事）
    
    let diffText = '';
    if (format === 'value' || format === 'both') {
      diffText = Math.abs(diff).toFixed(2);
    }
    if ((format === 'percent' || format === 'both') && diffPercent != null) {
      const percentText = Math.abs(diffPercent).toFixed(1) + '%';
      diffText = format === 'both' ? `${diffText} (${percentText})` : percentText;
    }
    
    diffHtml = `<span style="color:${color};font-size:11px;margin-left:4px">${arrow}${diffText}</span>`;
  }
  
  return `<span>${value}</span>${diffHtml}`;
}

/**
 * 从列元数据提取行样式规则
 */
export function extractRowStyleRules(columns: ColumnMetadata[]): RowStyleRule[] {
  const rules: RowStyleRule[] = [];
  
  columns.forEach(col => {
    if (!col.rulesConfig) return;
    
    try {
      const config = JSON.parse(col.rulesConfig);
      if (!config.style || !Array.isArray(config.style)) return;
      
      config.style.forEach((rule: StyleRule, index: number) => {
        // 只提取有 rowStyle 的规则
        if (rule.rowStyle && Object.keys(rule.rowStyle).length > 0) {
          rules.push({
            fieldName: col.fieldName,
            condition: rule.condition,
            rowStyle: rule.rowStyle,
            className: `meta-row-${col.fieldName}-${index}`
          });
        }
      });
    } catch (e) {
      // 忽略解析错误
    }
  });
  
  return rules;
}

/**
 * 创建行样式类函数（用于 AG Grid getRowClass）
 * 返回 CSS 类名，配合注入的样式规则实现整行变色
 */
export function createRowClassGetter(rules: RowStyleRule[]) {
  if (rules.length === 0) return undefined;
  
  return (params: any): string | undefined => {
    const data = params.data;
    if (!data) return undefined;
    
    for (const rule of rules) {
      const value = data[rule.fieldName];
      if (value != null && matchStyleRule(value, rule.condition)) {
        return rule.className;
      }
    }
    
    return undefined;
  };
}

/**
 * 批量转换列定义
 */
export function metaToColDefs(columns: ColumnMetadata[]): ColDef[] {
  return columns
    .filter(col => col.fieldName !== 'id') // 排除 id 列
    .sort((a, b) => a.displayOrder - b.displayOrder)
    .map(metaToColDef);
}

/**
 * 从元数据提取计算规则
 */
export function extractCalcRules(columns: ColumnMetadata[]): CalcRule[] {
  const rules: CalcRule[] = [];
  
  columns.forEach((col, index) => {
    if (col.rulesConfig) {
      try {
        const config = JSON.parse(col.rulesConfig);
        if (config.calculate) {
          const calc = config.calculate;
          
          // 多公式模式
          if (calc.formulaField && calc.formulas) {
            rules.push({
              field: col.fieldName,
              expression: '', // 多公式模式不使用单一表达式
              triggerFields: [], // 触发字段在各公式中定义
              formulaField: calc.formulaField,
              formulas: calc.formulas,
              order: index
            });
          }
          // 单公式模式
          else if (calc.expression) {
            rules.push({
              field: col.fieldName,
              expression: calc.expression,
              triggerFields: calc.triggerFields || [],
              order: index
            });
          }
        }
      } catch (e) {
        console.warn(`[useMetaColumns] 解析 rulesConfig 失败: ${col.fieldName}`, e);
      }
    }
  });

  return rules;
}

/**
 * 从元数据提取默认值
 */
export function extractDefaultValues(columns: ColumnMetadata[]): Record<string, any> {
  const defaults: Record<string, any> = {};
  
  columns.forEach(col => {
    if (col.dataType === 'number') {
      defaults[col.fieldName] = 0;
    } else {
      defaults[col.fieldName] = '';
    }
  });

  return defaults;
}

/** Lookup 配置 */
export interface LookupRule {
  fieldName: string;
  lookupCode: string;
  mapping: Record<string, string>;
}

/**
 * 从元数据提取 lookup 配置
 */
export function extractLookupRules(columns: ColumnMetadata[]): LookupRule[] {
  const rules: LookupRule[] = [];
  
  columns.forEach(col => {
    if (!col.rulesConfig) return;
    
    try {
      const config = JSON.parse(col.rulesConfig);
      if (config.lookup?.code && config.lookup?.mapping) {
        rules.push({
          fieldName: col.fieldName,
          lookupCode: config.lookup.code,
          mapping: config.lookup.mapping
        });
      }
    } catch (e) {
      // 忽略解析错误
    }
  });
  
  return rules;
}

/**
 * 根据变体键过滤列定义
 * @param columns 所有列定义
 * @param variantKey 变体键（如 '原辅料'、'包材'）
 * @param rawColumns 原始列元数据（包含 variantKey 配置）
 */
export function filterColumnsByVariant(
  columns: ColDef[],
  variantKey: string | undefined,
  rawColumns: ColumnMetadata[]
): ColDef[] {
  if (!variantKey) return columns;
  
  // 构建字段 → variantKey 映射
  const variantMap = new Map<string, string | undefined>();
  rawColumns.forEach(col => {
    if (col.rulesConfig) {
      try {
        const config = JSON.parse(col.rulesConfig);
        if (config.variantKey) {
          variantMap.set(col.fieldName, config.variantKey);
        }
      } catch (e) {
        // 忽略解析错误
      }
    }
  });
  
  // 过滤：只保留没有 variantKey 或 variantKey 匹配的列
  return columns.filter(col => {
    const field = col.field as string;
    const colVariantKey = variantMap.get(field);
    return !colVariantKey || colVariantKey === variantKey;
  });
}

/**
 * 加载表元数据并转换
 * @param tableCode 表编码
 * @param pageCode 页面编码（可选，传入则合并权限）
 */
export async function loadTableMeta(tableCode: string, pageCode?: string) {
  // 根据是否传入 pageCode 决定调用哪个接口
  const { data, error } = pageCode
    ? await fetchTableMetadataWithPermission(tableCode, pageCode)
    : await fetchTableMetadata(tableCode);
  
  if (error || !data) {
    console.error(`[useMetaColumns] 加载元数据失败: ${tableCode}`, error);
    return null;
  }

  const columns = metaToColDefs(data.columns);
  const rowStyleRules = extractRowStyleRules(data.columns);
  
  // 生成动态样式（单元格 + 行）
  injectDynamicStyles(columns, rowStyleRules);

  return {
    metadata: data,
    columns,
    rawColumns: data.columns, // 原始列元数据，用于提取验证规则
    calcRules: extractCalcRules(data.columns),
    defaultValues: extractDefaultValues(data.columns),
    lookupRules: extractLookupRules(data.columns),
    rowStyleRules,
    getRowClass: createRowClassGetter(rowStyleRules)
  };
}

/**
 * 注入动态样式到页面
 */
function injectDynamicStyles(columns: ColDef[], rowStyleRules: RowStyleRule[] = []) {
  // 使用唯一的 style 元素
  const styleId = 'meta-dynamic-styles';
  let styleEl = document.getElementById(styleId) as HTMLStyleElement;
  
  if (!styleEl) {
    styleEl = document.createElement('style');
    styleEl.id = styleId;
    document.head.appendChild(styleEl);
  }

  // 收集所有已有的 CSS 规则（避免重复）
  const existingRules = new Set<string>();
  const existingContent = styleEl.textContent || '';
  existingContent.split('\n').forEach(line => {
    const match = line.match(/^\.(meta-(?:cell|row)-[^\s{]+)/);
    if (match) existingRules.add(match[1]);
  });

  // 生成新的 CSS 规则
  const newRules: string[] = [];
  
  // 1. 单元格样式
  columns.forEach(col => {
    const styleRules = col.context?.styleRules as StyleRule[] | undefined;
    const fieldName = col.context?.fieldName;
    
    if (styleRules && fieldName) {
      styleRules.forEach((rule: StyleRule, index: number) => {
        const className = `meta-cell-${fieldName}-${index}`;
        
        // 跳过已存在的规则
        if (existingRules.has(className)) return;
        
        // 优先使用 cellStyle，兼容旧的 style
        const styles = rule.cellStyle || rule.style || {};
        
        // 将样式对象转换为 CSS 字符串
        const styleStr = Object.entries(styles)
          .map(([key, value]) => {
            // 将 camelCase 转换为 kebab-case
            const cssKey = key.replace(/([A-Z])/g, '-$1').toLowerCase();
            return `${cssKey}: ${value}`;
          })
          .join('; ');
        
        if (styleStr) {
          newRules.push(`.${className} { ${styleStr} !important; }`);
        }
      });
    }
  });
  
  // 2. 行样式 - 需要更具体的选择器覆盖 AG Grid 默认样式
  rowStyleRules.forEach(rule => {
    if (existingRules.has(rule.className)) return;
    
    const styleStr = Object.entries(rule.rowStyle)
      .map(([key, value]) => {
        const cssKey = key.replace(/([A-Z])/g, '-$1').toLowerCase();
        return `${cssKey}: ${value}`;
      })
      .join('; ');
    
    if (styleStr) {
      // 使用更具体的选择器确保覆盖 AG Grid 默认样式
      newRules.push(`.ag-row.${rule.className} { ${styleStr} !important; }`);
      // 同时覆盖单元格背景
      newRules.push(`.ag-row.${rule.className} .ag-cell { ${styleStr} !important; }`);
    }
  });

  // 追加新规则
  if (newRules.length > 0) {
    styleEl.textContent = existingContent + (existingContent ? '\n' : '') + newRules.join('\n');
  }
}
