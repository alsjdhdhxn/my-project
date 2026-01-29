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

export type LookupRuleConfig = {
  field?: string;
  fieldName?: string;
  lookupCode: string;
  mapping: Record<string, string>;
  /** 是否禁止回填（仅查看模式） */
  noFillback?: boolean;
  /** 用于筛选的字段名（当前行的字段） */
  filterField?: string;
  /** 用于筛选的列名（弹窗数据源的列） */
  filterColumn?: string;
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
