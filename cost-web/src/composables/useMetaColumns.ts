/**
 * 元数据列定义转换
 * 将后端元数据转换为 AG Grid ColDef
 */
import type { ColDef } from 'ag-grid-community';
import { fetchTableMetadata, fetchTableMetadataWithPermission } from '@/service/api';
import type { CalcRule } from '@/logic/calc-engine';

type ColumnMetadata = Api.Metadata.ColumnMetadata;

interface NumberFormatConfig {
  precision: number;
  trimZeros?: boolean;
  roundMode?: 'round' | 'ceil' | 'floor';
}

const _DEFAULT_NUMBER_PRECISION = 2; // 已废弃，精度由 COLUMN_OVERRIDE 配置控制

/** 样式规则 */
export interface StyleRule {
  condition: StyleCondition;
  cellStyle?: Record<string, string>; // 单元格样式（文字变色等）
  rowStyle?: Record<string, string>; // 行样式（底色等）
  style?: Record<string, string>; // 兼容旧格式（等同于 cellStyle）
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
  columnName: string;
  condition: StyleCondition;
  rowStyle: Record<string, string>;
  className: string;
}

/**
 * 元数据转 AG Grid 列定义
 */
export function metaToColDef(col: ColumnMetadata): ColDef {
  const colDef: ColDef = {
    field: col.columnName,
    headerName: col.headerText,
    editable: Boolean(col.editable),
    sortable: true,
    resizable: true,
    context: {
      metaColumnId: col.id,
      columnName: col.columnName
    }
  };

  // 宽度：只有明确设置了宽度才使用，否则让 flex 生效
  if (col.width && col.width > 0) {
    colDef.width = col.width;
  }
  if (col.visible === false) {
    colDef.hide = true;
  }
  if (col.pinned) {
    colDef.pinned = col.pinned;
  }

  // 数据类型处理
  switch (col.dataType) {
    case 'number':
      colDef.type = 'numericColumn';
      colDef.valueParser = params => {
        // 允许置空
        if (params.newValue === '' || params.newValue === null || params.newValue === undefined) {
          return null;
        }
        const val = Number(params.newValue);
        return isNaN(val) ? null : val;
      };
      colDef.valueFormatter = params => formatNumberValue(params.value);
      break;
    case 'date':
      colDef.valueFormatter = params => {
        if (!params.value) return '';
        const date = new Date(params.value);
        return isNaN(date.getTime()) ? params.value : date.toLocaleDateString('zh-CN');
      };
      break;
    case 'datetime':
      colDef.valueFormatter = params => {
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
      const numberFormat = resolveNumberFormat(config);
      if (col.dataType === 'number' && numberFormat) {
        colDef.valueFormatter = params => formatNumberValue(params.value, numberFormat);
      }
      if (config.columnControl?.lockVisible === true || config.lockVisible === true) {
        colDef.lockVisible = true;
        // Hide locked columns from Columns Tool Panel so users cannot toggle them.
        colDef.suppressColumnsToolPanel = true;
      }
      applyEditorConfig(colDef, config);
      if (typeof config.aggFunc === 'string' && config.aggFunc.length > 0) {
        colDef.aggFunc = config.aggFunc;
      }

      // 0. 自定义排序
      if (config.comparator) {
        colDef.comparator = getComparator(config.comparator);
      }

      // 1. 样式规则
      if (config.style && Array.isArray(config.style)) {
        const cellClassRules: Record<string, (params: any) => boolean> = {};

        config.style.forEach((rule: StyleRule, index: number) => {
          const className = `meta-cell-${col.columnName}-${index}`;
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
          ...(colDef.context || {}),
          styleRules: config.style,
          columnName: col.columnName
        };
      }

      // 2. 对比值渲染
      if (config.compare?.enabled) {
        const compareConfig = {
          format: config.compare.format || 'value', // value/percent/both
          upColor: config.compare.upColor || '#e53935', // 上涨颜色（默认红色）
          downColor: config.compare.downColor || '#43a047' // 下跌颜色（默认绿色）
        };
        colDef.cellRenderer = (params: any) => {
          return renderCompareValue(params, col.columnName, compareConfig);
        };
      }
    } catch (e) {
      console.warn(`[useMetaColumns] 解析 rulesConfig 失败: ${col.columnName}`, e);
    }
  }

  return colDef;
}

function resolveNumberFormat(config: any): NumberFormatConfig | null {
  if (!config || typeof config !== 'object') return null;
  const format = config.format ?? null;
  const precisionRaw = format?.precision ?? config.precision;
  if (precisionRaw == null) return null;
  const precision = Number(precisionRaw);
  if (!Number.isFinite(precision) || precision < 0) return null;
  const trimZeros = Boolean(format?.trimZeros ?? config.trimZeros);
  const roundModeRaw = format?.roundMode ?? config.roundMode;
  const roundMode = roundModeRaw === 'ceil' || roundModeRaw === 'floor' ? roundModeRaw : 'round';
  return { precision: Math.floor(precision), trimZeros, roundMode };
}

function formatNumberValue(value: any, format?: NumberFormatConfig): string {
  if (value === null || value === undefined || value === '') return '';
  const num = Number(value);
  if (!Number.isFinite(num)) return String(value);
  if (!format) {
    return String(num);
  }
  const factor = 10 ** format.precision;
  let rounded = num;
  switch (format.roundMode) {
    case 'ceil':
      rounded = Math.ceil(num * factor) / factor;
      break;
    case 'floor':
      rounded = Math.floor(num * factor) / factor;
      break;
    default:
      rounded = Math.round(num * factor) / factor;
      break;
  }
  let text = rounded.toFixed(format.precision);
  if (format.trimZeros) {
    text = trimTrailingZeros(text);
  }
  return text;
}

function applyEditorConfig(colDef: ColDef, config: any) {
  if (!config || typeof config !== 'object') return;
  const editorType = config.editor?.type || config.cellEditor;
  const editorParams = config.editor?.params || config.cellEditorParams;
  if (typeof editorType !== 'string' || editorType.length === 0 || editorType === 'lookup') {
    return;
  }
  colDef.cellEditor = editorType;
  if (editorParams && typeof editorParams === 'object') {
    colDef.cellEditorParams = editorParams;
  }
}

function trimTrailingZeros(value: string): string {
  return value.replace(/(?:\.0+|(\.\d+?)0+)$/, '$1');
}

/**
 * 获取自定义排序函数
 */
function getComparator(comparatorName: string) {
  const comparators: Record<string, (valueA: any, valueB: any) => number> = {
    // 自定义分类排序：原料 → 辅料 → 印字包材 → 非印字包材
    customCategorySort: (valueA: any, valueB: any) => {
      const order: Record<string, number> = {
        原料: 1,
        辅料: 2,
        印字包材: 3,
        非印字包材: 4
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
        case '>':
          return Number(value) > Number(compareValue);
        case '>=':
          return Number(value) >= Number(compareValue);
        case '<':
          return Number(value) < Number(compareValue);
        case '<=':
          return Number(value) <= Number(compareValue);
        case '==':
          return value == compareValue;
        case '!=':
          return value != compareValue;
        default:
          return false;
      }
    default:
      return false;
  }
}

/** 对比值渲染配置 */
interface CompareRenderConfig {
  format: string;
  upColor: string;
  downColor: string;
}

/**
 * 渲染对比值（带箭头和颜色）
 * @param params AG Grid cellRenderer 参数
 * @param columnName 字段名
 * @param config 对比配置
 */
function renderCompareValue(params: any, columnName: string, config: CompareRenderConfig): string {
  const value = params.value;
  const data = params.data;

  if (value == null) return '';

  const diff = data?.[`${columnName}Diff`];
  const diffPercent = data?.[`${columnName}DiffPercent`];

  // 没有对比数据，直接显示当前值
  if (diff == null && diffPercent == null) {
    return String(value);
  }

  // 构建差值显示
  let diffHtml = '';
  if (diff != null && diff !== 0) {
    const isUp = diff > 0;
    const arrow = isUp ? '↑' : '↓';
    const color = isUp ? config.upColor : config.downColor;

    let diffText = '';
    if (config.format === 'value' || config.format === 'both') {
      diffText = Math.abs(diff).toFixed(2);
    }
    if ((config.format === 'percent' || config.format === 'both') && diffPercent != null) {
      const percentText = `${Math.abs(diffPercent).toFixed(1)}%`;
      diffText = config.format === 'both' ? `${diffText} (${percentText})` : percentText;
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
            columnName: col.columnName,
            condition: rule.condition,
            rowStyle: rule.rowStyle,
            className: `meta-row-${col.columnName}-${index}`
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
      const value = data[rule.columnName];
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
  return columns.sort((a, b) => a.displayOrder - b.displayOrder).map(metaToColDef);
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
              field: col.columnName,
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
              field: col.columnName,
              expression: calc.expression,
              triggerFields: calc.triggerFields || [],
              order: index
            });
          }
        }
      } catch (e) {
        console.warn(`[useMetaColumns] 解析 rulesConfig 失败: ${col.columnName}`, e);
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
      defaults[col.columnName] = 0;
    } else {
      defaults[col.columnName] = '';
    }
  });

  return defaults;
}

/**
 * Lookup 弹窗规则
 *
 * 筛选相关字段说明：
 * - filterField: 从"当前行数据"取哪个字段的值作为筛选值
 *   生效场景：filterValueFrom 没写或为 'row'
 *   例：filterField: "id" → 用当前行的 rowData.id 作为筛选值
 *
 * - filterColumn: 弹窗数据源里要过滤的列名（SQL 中的列名）
 *   例：filterColumn: "GOODSID" → 最终会拼成 AND GOODSID = <filterValue>
 *
 * - filterValueFrom: 筛选值来源
 *   'row': 用 rowData[filterField]
 *   'cell': 用你点击的单元格的值（不需要 filterField）
 */
export interface LookupRule {
  columnName: string;
  lookupCode: string;
  mapping: Record<string, string>;
  /** 是否禁止回填（仅查看模式） */
  noFillback?: boolean;
  /** 从当前行取哪个字段的值作为筛选值，生效于 filterValueFrom='row' 或未配置时 */
  filterField?: string;
  /** 弹窗数据源的筛选列名（SQL列名），如 "GOODSID" */
  filterColumn?: string;
  /** 筛选值来源：'row' 用行数据字段，'cell' 用点击单元格的值 */
  filterValueFrom?: 'row' | 'cell';
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
          columnName: col.columnName,
          lookupCode: config.lookup.code,
          mapping: config.lookup.mapping,
          noFillback: config.lookup.noFillback,
          filterField: config.lookup.filterField,
          filterColumn: config.lookup.filterColumn,
          filterValueFrom: config.lookup.filterValueFrom
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
          variantMap.set(col.columnName, config.variantKey);
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
export async function loadTableMeta(tableCode: string, pageCode?: string, gridKey?: string) {
  // 根据是否传入 pageCode 决定调用哪个接口
  const { data, error } = pageCode
    ? await fetchTableMetadataWithPermission(tableCode, pageCode, gridKey)
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
    const columnName = col.context?.columnName;

    if (styleRules && columnName) {
      styleRules.forEach((rule: StyleRule, index: number) => {
        const className = `meta-cell-${columnName}-${index}`;

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
