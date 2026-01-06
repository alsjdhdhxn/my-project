/**
 * 计算引擎模块导出
 */

// 计算器
export {
  type CalcRule,
  type AggRule,
  type FormulaDefinition,
  compileCalcRules,
  compileAggRules,
  calcRowFields,
  calcAggregates,
  getAffectedRules,
  evalCondition,
  clearCalcCache
} from './calculator';

// 解析器
export {
  type TabConfig,
  type TabsComponentConfig,
  type PageComponent,
  type ParsedPageConfig,
  type EnterpriseConfig,
  parsePageComponents,
  parseTabConfig,
  parseCalcRules,
  parseAggRules,
  extractDefaultValues,
  filterColumns
} from './parser';

// 构建器
export {
  type RowData,
  type MasterRowData,
  type ChangeRecord,
  type RecordItem,
  type SaveParams,
  buildSaveParams,
  buildRecordItem,
  isRowChanged,
  generateTempId,
  initRowData,
  clearRowChanges
} from './builder';

// 验证器
export {
  type ValidationRule,
  type ValidationError,
  type ValidationResult,
  type ColumnMetadata,
  parseValidationRules,
  validateRow,
  validateRows,
  formatValidationErrors,
  getErrorFields
} from './validator';
