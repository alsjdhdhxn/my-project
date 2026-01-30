export type RawRules = string | unknown;

export type PageRule = {
  id?: number;
  pageCode?: string;
  componentKey?: string;
  ruleType?: string;
  rules?: RawRules;
  sortOrder?: number;
};

export type PageComponentWithRules = Api.Metadata.PageComponent & {
  rules?: PageRule[];
  children?: PageComponentWithRules[];
};

export type ColumnOverrideRule = {
  field?: string;
  fieldName?: string;
  width?: number;
  visible?: boolean;
  editable?: boolean;
  searchable?: boolean;
  required?: boolean;
  cellEditor?: string;
  cellEditorParams?: Record<string, any>;
};

/**
 * Lookup 弹窗规则配置
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
export type LookupRuleConfig = {
  field?: string;
  fieldName?: string;
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
};

export type RoleBindingRule = {
  role: string;
  masterKey?: string;
  detailKey?: string;
};

export type SplitLayoutConfig = {
  defaultSize?: number;
  min?: number;
  max?: number;
};

export type GridOptionsRule = {
  sideBar?: boolean | Record<string, any>;
  enableSidebar?: boolean;
  cellSelection?: boolean | Record<string, any>;
  rowModelType?: 'clientSide' | 'serverSide';
  cacheBlockSize?: number;
  maxBlocksInCache?: number;
  /** SSRM: 最大并发请求数 */
  maxConcurrentDatasourceRequests?: number;
  /** SSRM: 请求防抖毫秒数 */
  blockLoadDebounceMillis?: number;
  groupBy?: string[];
  groupColumnName?: string;
  groupDefaultExpanded?: number;
  autoSizeColumns?: boolean;
  autoSizeMode?: 'fitCellContents' | 'fitGridWidth';
};

export type RelationRule = {
  masterKey?: string;
  detailKey?: string;
  detailType?: string;
  splitConfig?: SplitLayoutConfig;
};

export type ContextMenuItemRule = {
  type?: 'action' | 'separator' | 'group';
  action?: string;
  label?: string;
  items?: ContextMenuItemRule[];
  visible?: boolean;
  disabled?: boolean;
  requiresRow?: boolean;
  requiresSelection?: boolean;
  permission?: string;
};

export type ContextMenuRule = {
  items: ContextMenuItemRule[];
};

/** 行级可编辑规则 */
export type RowEditableRule = {
  field: string;
  operator: 'notNull' | 'eq' | 'ne' | 'in' | 'notIn';
  value?: any;
};

/** 单元格级可编辑规则 - 条件匹配时只允许编辑指定字段 */
export type CellEditableCondition = {
  field: string;
  operator: 'notNull' | 'eq' | 'ne' | 'in' | 'notIn';
  value?: any;
};

export type CellEditableRule = {
  condition: CellEditableCondition;
  editableFields: string[];
};

/** 行级样式规则 */
export type RowClassRule = {
  field: string;
  operator: 'notNull' | 'eq' | 'ne' | 'in' | 'notIn';
  value?: any;
  className: string;
};

/** 工具栏按钮规则 */
export type ToolbarItemRule = {
  action: string;
  label: string;
  type?: 'default' | 'primary' | 'info' | 'success' | 'warning' | 'error';
  sql?: string;
  script?: string;
  disabled?: boolean;
  visible?: boolean;
  requiresRow?: boolean;
  confirm?: string;
};

export type ToolbarRule = {
  items: ToolbarItemRule[];
};
