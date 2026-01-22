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
};

export type LookupRuleConfig = {
  field?: string;
  fieldName?: string;
  lookupCode: string;
  mapping: Record<string, string>;
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
  rowModelType?: 'clientSide' | 'infinite';
  cacheBlockSize?: number;
  maxBlocksInCache?: number;
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

/** 行级可编辑规�?*/
export type RowEditableRule = {
  field: string;
  operator: 'notNull' | 'eq' | 'ne' | 'in' | 'notIn';
  value?: any;
};

/** 行级样式规则 */
export type RowClassRule = {
  field: string;
  operator: 'notNull' | 'eq' | 'ne' | 'in' | 'notIn';
  value?: any;
  className: string;
};

