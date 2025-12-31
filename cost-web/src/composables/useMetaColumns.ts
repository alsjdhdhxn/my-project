/**
 * 元数据列定义转换
 * 将后端元数据转换为 AG Grid ColDef
 */
import type { ColDef } from 'ag-grid-community';
import { fetchTableMetadata } from '@/service/api';
import type { CalcRule } from './useCalcEngine';

type ColumnMetadata = Api.Metadata.ColumnMetadata;

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

  // 宽度
  if (col.width) {
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
      colDef.type = 'dateColumn';
      break;
    case 'datetime':
      colDef.type = 'dateColumn';
      break;
  }

  // 样式规则 - 使用 cellClassRules 实现动态样式
  if (col.rulesConfig) {
    try {
      const config = JSON.parse(col.rulesConfig);
      if (config.style && Array.isArray(config.style)) {
        const cellClassRules: Record<string, (params: any) => boolean> = {};
        
        config.style.forEach((rule: any, index: number) => {
          const className = `meta-style-${col.fieldName}-${index}`;
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
    } catch (e) {
      console.warn(`[useMetaColumns] 解析 rulesConfig 失败: ${col.fieldName}`, e);
    }
  }

  return colDef;
}

/**
 * 匹配样式规则
 */
function matchStyleRule(value: any, condition: any): boolean {
  if (!condition) return false;

  const { type, pattern, operator, compareValue } = condition;

  switch (type) {
    case 'contains':
      return String(value).includes(pattern);
    case 'startsWith':
      return String(value).startsWith(pattern);
    case 'endsWith':
      return String(value).endsWith(pattern);
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
          rules.push({
            field: col.fieldName,
            expression: config.calculate.expression,
            dependencies: config.calculate.triggerFields || [],
            order: index
          });
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

/**
 * 加载表元数据并转换
 */
export async function loadTableMeta(tableCode: string) {
  const { data, error } = await fetchTableMetadata(tableCode);
  
  if (error || !data) {
    console.error(`[useMetaColumns] 加载元数据失败: ${tableCode}`, error);
    return null;
  }

  const columns = metaToColDefs(data.columns);
  
  // 生成动态样式
  injectDynamicStyles(columns);

  return {
    metadata: data,
    columns,
    rawColumns: data.columns, // 原始列元数据，用于提取验证规则
    calcRules: extractCalcRules(data.columns),
    defaultValues: extractDefaultValues(data.columns)
  };
}

/**
 * 注入动态样式到页面
 */
function injectDynamicStyles(columns: ColDef[]) {
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
    const match = line.match(/^\.(meta-style-[^\s{]+)/);
    if (match) existingRules.add(match[1]);
  });

  // 生成新的 CSS 规则
  const newRules: string[] = [];
  
  columns.forEach(col => {
    const styleRules = col.context?.styleRules;
    const fieldName = col.context?.fieldName;
    
    if (styleRules && fieldName) {
      styleRules.forEach((rule: any, index: number) => {
        const className = `meta-style-${fieldName}-${index}`;
        
        // 跳过已存在的规则
        if (existingRules.has(className)) return;
        
        const styles = rule.style || {};
        
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

  // 追加新规则
  if (newRules.length > 0) {
    styleEl.textContent = existingContent + (existingContent ? '\n' : '') + newRules.join('\n');
  }
}
