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
    editable: col.editable,
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

  return colDef;
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

  return {
    metadata: data,
    columns: metaToColDefs(data.columns),
    calcRules: extractCalcRules(data.columns),
    defaultValues: extractDefaultValues(data.columns)
  };
}
