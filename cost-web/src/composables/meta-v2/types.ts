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

export type RelationRule = {
  masterKey?: string;
  detailKey?: string;
  detailType?: string;
};
