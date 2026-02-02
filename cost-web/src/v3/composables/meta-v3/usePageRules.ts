import type { ColDef } from 'ag-grid-community';
import type { AggRule, CalcRule, ValidationRule, NestedConfig } from '@/v3/logic/calc-engine';
import type { LookupRule } from '@/composables/useMetaColumns';
import type {
  PageRule,
  PageComponentWithRules,
  ColumnOverrideRule,
  GridOptionsRule,
  LookupRuleConfig,
  RoleBindingRule,
  RelationRule,
  ButtonRule,
  ButtonItemRule,
  ContextMenuRule,
  RowEditableRule,
  RowClassRule,
  ToolbarRule,
  CellEditableRule,
  CellEditableCondition
} from '@/v3/composables/meta-v3/types';

export function collectPageRules(components: PageComponentWithRules[]): PageRule[] {
  const rules: PageRule[] = [];
  const visit = (component: PageComponentWithRules) => {
    if (Array.isArray(component.rules)) {
      for (const rule of component.rules) {
        const componentKey = rule.componentKey || component.componentKey;
        rules.push({ ...rule, componentKey });
      }
    }
    if (Array.isArray(component.children)) {
      component.children.forEach(visit);
    }
  };
  components.forEach(visit);
  return rules;
}

export function groupRulesByComponent(rules: PageRule[]): Map<string, PageRule[]> {
  const map = new Map<string, PageRule[]>();
  for (const rule of rules) {
    if (!rule.componentKey) continue;
    const list = map.get(rule.componentKey) || [];
    list.push(rule);
    map.set(rule.componentKey, list);
  }
  for (const list of map.values()) {
    list.sort((a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0));
  }
  return map;
}

export function getComponentRules(
  rulesByComponent: Map<string, PageRule[]>,
  componentKeys: string[]
): PageRule[] {
  for (const key of componentKeys) {
    const rules = rulesByComponent.get(key);
    if (rules && rules.length > 0) return rules;
  }
  return [];
}

function getRuleByType(rules: PageRule[], ruleType: string): PageRule | undefined {
  return rules.find(rule => rule.ruleType === ruleType);
}

function parseRuleArray<T>(rule: PageRule | undefined, label: string): T[] {
  if (!rule?.rules) return [];
  try {
    const raw = typeof rule.rules === 'string' ? JSON.parse(rule.rules) : rule.rules;
    if (!Array.isArray(raw)) {
      console.warn(`[PageRule] ${label} is not an array`);
      return [];
    }
    return raw as T[];
  } catch (error) {
    console.warn(`[PageRule] Failed to parse ${label}`, error);
    return [];
  }
}

function parseRuleObject<T>(rule: PageRule | undefined, label: string): T | null {
  if (!rule?.rules) return null;
  try {
    const raw = typeof rule.rules === 'string' ? JSON.parse(rule.rules) : rule.rules;
    if (!raw || Array.isArray(raw) || typeof raw !== 'object') {
      console.warn(`[PageRule] ${label} is not an object`);
      return null;
    }
    return raw as T;
  } catch (error) {
    console.warn(`[PageRule] Failed to parse ${label}`, error);
    return null;
  }
}

function normalizeStringList(raw: unknown): string[] | null {
  if (!Array.isArray(raw)) return null;
  return raw.filter(item => typeof item === 'string') as string[];
}

export function parseValidationRuleConfig(componentKey: string, rules: PageRule[]): ValidationRule[] {
  const rule = getRuleByType(rules, 'VALIDATION');
  const items = parseRuleArray<Record<string, any>>(rule, `${componentKey}.VALIDATION`);
  return items
    .map(item => ({
      field: item.field ?? item.fieldName,
      required: item.required,
      notZero: item.notZero,
      min: item.min,
      max: item.max,
      pattern: item.pattern,
      message: item.message
    }))
    .filter(item => Boolean(item.field));
}

/**
 * 解析 Lookup 弹窗规则配置
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
export function parseLookupRuleConfig(componentKey: string, rules: PageRule[]): LookupRule[] {
  const rule = getRuleByType(rules, 'LOOKUP');
  const items = parseRuleArray<LookupRuleConfig>(rule, `${componentKey}.LOOKUP`);
  return items
    .filter(item => Boolean(item.field || item.fieldName))
    .map(item => ({
      fieldName: item.field ?? item.fieldName ?? '',
      lookupCode: item.lookupCode,
      mapping: item.mapping,
      noFillback: item.noFillback,
      filterField: item.filterField,
      filterColumn: item.filterColumn,
      filterValueFrom: item.filterValueFrom
    }));
}

export function parseCalcRuleConfig(componentKey: string, rules: PageRule[]): CalcRule[] {
  const rule = getRuleByType(rules, 'CALC');
  return parseRuleArray<CalcRule>(rule, `${componentKey}.CALC`);
}

export function parseAggregateRuleConfig(componentKey: string, rules: PageRule[]): AggRule[] {
  const rule = getRuleByType(rules, 'AGGREGATE');
  return parseRuleArray<AggRule>(rule, `${componentKey}.AGGREGATE`);
}

export function parseColumnOverrideConfig(componentKey: string, rules: PageRule[]): ColumnOverrideRule[] {
  const rule = getRuleByType(rules, 'COLUMN_OVERRIDE');
  return parseRuleArray<ColumnOverrideRule>(rule, `${componentKey}.COLUMN_OVERRIDE`);
}

export function parseBroadcastRuleConfig(componentKey: string, rules: PageRule[]): string[] | null {
  const rule = getRuleByType(rules, 'BROADCAST');
  if (!rule?.rules) return null;
  try {
    const raw = typeof rule.rules === 'string' ? JSON.parse(rule.rules) : rule.rules;
    const directList = normalizeStringList(raw);
    if (directList) return directList;
    if (raw && typeof raw === 'object') {
      const obj = raw as { fields?: unknown; broadcast?: unknown; broadcastFields?: unknown };
      const list = normalizeStringList(obj.fields)
        || normalizeStringList(obj.broadcast)
        || normalizeStringList(obj.broadcastFields);
      if (list) return list;
    }
    console.warn(`[PageRule] ${componentKey}.BROADCAST is not a string array`);
    return null;
  } catch (error) {
    console.warn(`[PageRule] Failed to parse ${componentKey}.BROADCAST`, error);
    return null;
  }
}

export function parseSummaryConfigRule(componentKey: string, rules: PageRule[]): NestedConfig | null {
  const rule = getRuleByType(rules, 'SUMMARY_CONFIG') || getRuleByType(rules, 'NESTED_CONFIG');
  if (!rule) return null;
  return parseRuleObject<NestedConfig>(rule, `${componentKey}.${rule.ruleType || 'SUMMARY_CONFIG'}`);
}

export function parseRoleBindingRule(componentKey: string, rules: PageRule[]): RoleBindingRule | null {
  const rule = getRuleByType(rules, 'ROLE_BINDING');
  if (!rule) return null;
  return parseRuleObject<RoleBindingRule>(rule, `${componentKey}.ROLE_BINDING`);
}

export function parseRelationRule(componentKey: string, rules: PageRule[]): RelationRule | null {
  const rule = getRuleByType(rules, 'RELATION');
  if (!rule) return null;
  return parseRuleObject<RelationRule>(rule, `${componentKey}.RELATION`);
}

export function parseGridOptionsRule(componentKey: string, rules: PageRule[]): GridOptionsRule | null {
  const rule = getRuleByType(rules, 'GRID_OPTIONS') || getRuleByType(rules, 'GRID_FEATURES');
  if (!rule) return null;
  return parseRuleObject<GridOptionsRule>(rule, `${componentKey}.${rule.ruleType || 'GRID_OPTIONS'}`);
}

/**
 * 组件配置类型（包含按钮）
 */
type ComponentConfigWithButtons = {
  buttons?: ButtonItemRule[];
  tabs?: Array<{ key: string; buttons?: ButtonItemRule[] }>;
};

/**
 * 解析组件配置中的按钮
 */
function parseComponentConfigButtons(componentConfig?: string): ButtonItemRule[] | null {
  if (!componentConfig) return null;
  try {
    const config = JSON.parse(componentConfig) as ComponentConfigWithButtons;
    if (Array.isArray(config.buttons)) {
      return config.buttons;
    }
    return null;
  } catch {
    return null;
  }
}

/**
 * 解析 TABS 组件中某个 tab 的按钮
 */
function parseTabButtons(componentConfig?: string, tabKey?: string): ButtonItemRule[] | null {
  if (!componentConfig || !tabKey) return null;
  try {
    const config = JSON.parse(componentConfig) as ComponentConfigWithButtons;
    const tab = config.tabs?.find(t => t.key === tabKey);
    if (tab && Array.isArray(tab.buttons)) {
      return tab.buttons;
    }
    return null;
  } catch {
    return null;
  }
}

/**
 * 解析按钮规则
 * 优先从 componentConfig.buttons 读取，如果没有则从 rules 中读取（兼容旧数据）
 */
export function parseButtonRule(componentKey: string, rules: PageRule[], componentConfig?: string, tabKey?: string): ButtonRule | null {
  // 优先从 componentConfig 读取
  let buttons: ButtonItemRule[] | null = null;
  
  if (tabKey) {
    // 如果是 tab，从 tabs[].buttons 读取
    buttons = parseTabButtons(componentConfig, tabKey);
  } else {
    // 否则从 componentConfig.buttons 读取
    buttons = parseComponentConfigButtons(componentConfig);
  }
  
  if (buttons && buttons.length > 0) {
    return { items: buttons };
  }
  
  // 兼容：从 rules 中读取 BUTTON 类型
  const rule = getRuleByType(rules, 'BUTTON');
  if (!rule?.rules) return null;
  try {
    const raw = typeof rule.rules === 'string' ? JSON.parse(rule.rules) : rule.rules;
    if (Array.isArray(raw)) {
      return { items: raw };
    }
    if (raw && typeof raw === 'object') {
      const obj = raw as { items?: unknown };
      if (Array.isArray(obj.items)) {
        return { items: obj.items };
      }
    }
    console.warn(`[PageRule] ${componentKey}.BUTTON is not a valid object`);
    return null;
  } catch (error) {
    console.warn(`[PageRule] Failed to parse ${componentKey}.BUTTON`, error);
    return null;
  }
}

/**
 * 从按钮项中过滤出指定位置的按钮
 */
function filterButtonsByPosition(items: ButtonItemRule[], position: 'context' | 'toolbar'): ButtonItemRule[] {
  const result: ButtonItemRule[] = [];
  
  for (const item of items) {
    // separator 只在右键菜单中保留，工具栏不需要
    if (item.type === 'separator') {
      if (position === 'context') {
        result.push(item);
      }
      continue;
    }
    
    // 检查 position
    const pos = item.position || 'context'; // 默认是 context
    if (pos !== position && pos !== 'both') continue;
    
    // 递归处理子菜单
    if (item.items && item.items.length > 0) {
      const subItems = filterButtonsByPosition(item.items, position);
      if (subItems.length > 0) {
        result.push({ ...item, items: subItems });
      }
    } else {
      result.push(item);
    }
  }
  
  return result;
}

/**
 * 解析右键菜单规则（从按钮配置中提取 position='context' 的按钮）
 */
export function parseContextMenuRule(componentKey: string, rules: PageRule[], componentConfig?: string, tabKey?: string): ContextMenuRule | null {
  const buttonRule = parseButtonRule(componentKey, rules, componentConfig, tabKey);
  if (!buttonRule) return null;
  const contextItems = filterButtonsByPosition(buttonRule.items, 'context');
  return contextItems.length > 0 ? { items: contextItems } : null;
}

export function applyColumnOverrides(columns: ColDef[], overrides: ColumnOverrideRule[]): ColDef[] {
  if (!overrides || overrides.length === 0) return columns;
  const overrideMap = new Map<string, ColumnOverrideRule>();
  for (const override of overrides) {
    const key = override.field || override.fieldName;
    if (!key) continue;
    overrideMap.set(key, override);
  }
  return columns.map(col => {
    const field = col.field as string | undefined;
    if (!field) return col;
    const override = overrideMap.get(field);
    if (!override) return col;
    const updated: ColDef = { ...col };
    if (override.width != null) updated.width = override.width;
    if (override.visible != null) updated.hide = override.visible === false;
    if (override.editable != null) updated.editable = override.editable;
    if (override.searchable === false) updated.filter = false;
    if (override.searchable === true && updated.filter === false) updated.filter = true;
    // 支持下拉框编辑器
    if (override.cellEditor) updated.cellEditor = override.cellEditor;
    if (override.cellEditorParams) updated.cellEditorParams = override.cellEditorParams;
    return updated;
  });
}

export function attachGroupCellRenderer(columns: ColDef[]): ColDef[] {
  const index = columns.findIndex(col => !col.hide);
  if (index < 0) return columns;
  return columns.map((col, idx) => {
    if (idx !== index) return col;
    return { ...col, cellRenderer: 'agGroupCellRenderer' };
  });
}

/** 解析 ROW_EDITABLE 规则 */
export function parseRowEditableRule(componentKey: string, rules: PageRule[]): RowEditableRule[] {
  const rule = rules.find(r => r.ruleType === 'ROW_EDITABLE');
  if (!rule?.rules) return [];
  try {
    const raw = typeof rule.rules === 'string' ? JSON.parse(rule.rules) : rule.rules;
    if (Array.isArray(raw)) return raw as RowEditableRule[];
    if (raw && typeof raw === 'object') return [raw as RowEditableRule];
    return [];
  } catch (error) {
    console.warn(`[PageRule] Failed to parse ${componentKey}.ROW_EDITABLE`, error);
    return [];
  }
}

/** 根据 ROW_EDITABLE 规则生成 editable 回调 */
export function buildRowEditableCallback(rules: RowEditableRule[]): ((params: any) => boolean) | undefined {
  if (!rules || rules.length === 0) return undefined;
  return (params: any) => {
    const data = params.data;
    if (!data) return true;
    for (const rule of rules) {
      const fieldValue = data[rule.field];
      let passed = true;
      switch (rule.operator) {
        case 'notNull':
          passed = fieldValue != null;
          break;
        case 'eq':
          passed = fieldValue === rule.value;
          break;
        case 'ne':
          passed = fieldValue !== rule.value;
          break;
        case 'in':
          passed = Array.isArray(rule.value) && rule.value.includes(fieldValue);
          break;
        case 'notIn':
          passed = !Array.isArray(rule.value) || !rule.value.includes(fieldValue);
          break;
      }
      if (!passed) return false;
    }
    return true;
  };
}

/** 解析 CELL_EDITABLE 规则 */
export function parseCellEditableRule(componentKey: string, rules: PageRule[]): CellEditableRule[] {
  const rule = rules.find(r => r.ruleType === 'CELL_EDITABLE');
  if (!rule?.rules) return [];
  try {
    const raw = typeof rule.rules === 'string' ? JSON.parse(rule.rules) : rule.rules;
    if (Array.isArray(raw)) return raw as CellEditableRule[];
    if (raw && typeof raw === 'object') return [raw as CellEditableRule];
    return [];
  } catch (error) {
    console.warn(`[PageRule] Failed to parse ${componentKey}.CELL_EDITABLE`, error);
    return [];
  }
}

/** 检查条件是否匹配 */
function checkCondition(data: any, condition: CellEditableCondition): boolean {
  const fieldValue = data[condition.field];
  switch (condition.operator) {
    case 'notNull':
      return fieldValue != null;
    case 'eq':
      return fieldValue === condition.value;
    case 'ne':
      return fieldValue !== condition.value;
    case 'in':
      return Array.isArray(condition.value) && condition.value.includes(fieldValue);
    case 'notIn':
      return !Array.isArray(condition.value) || !condition.value.includes(fieldValue);
    default:
      return false;
  }
}

/** 根据 CELL_EDITABLE 规则生成单元格级 editable 回调 */
export function buildCellEditableCallback(
  cellRules: CellEditableRule[],
  rowRules?: RowEditableRule[]
): ((params: any) => boolean) | undefined {
  if ((!cellRules || cellRules.length === 0) && (!rowRules || rowRules.length === 0)) {
    return undefined;
  }
  
  const rowCallback = buildRowEditableCallback(rowRules || []);
  
  return (params: any) => {
    const data = params.data;
    const field = params.colDef?.field;
    
    if (!data) return true;
    
    // 新增行始终可编辑
    if (data._isNew) return true;
    
    // 检查 CELL_EDITABLE 规则
    if (cellRules && cellRules.length > 0) {
      for (const rule of cellRules) {
        if (checkCondition(data, rule.condition)) {
          // 条件匹配，只有 editableFields 中的字段可编辑
          return rule.editableFields.includes(field);
        }
      }
    }
    
    // 没有匹配的 CELL_EDITABLE 规则，使用 ROW_EDITABLE 规则
    if (rowCallback) {
      return rowCallback(params);
    }
    
    return true;
  };
}

/** 解析 ROW_CLASS 规则 */
export function parseRowClassRule(componentKey: string, rules: PageRule[]): RowClassRule[] {
  const rule = rules.find(r => r.ruleType === 'ROW_CLASS');
  if (!rule?.rules) return [];
  try {
    const raw = typeof rule.rules === 'string' ? JSON.parse(rule.rules) : rule.rules;
    if (Array.isArray(raw)) return raw as RowClassRule[];
    if (raw && typeof raw === 'object') return [raw as RowClassRule];
    return [];
  } catch (error) {
    console.warn(`[PageRule] Failed to parse ${componentKey}.ROW_CLASS`, error);
    return [];
  }
}

/** 根据 ROW_CLASS 规则生成 getRowClass 回调 */
export function buildRowClassCallback(rules: RowClassRule[]): ((params: any) => string | undefined) | undefined {
  if (!rules || rules.length === 0) return undefined;
  return (params: any) => {
    const data = params.data;
    if (!data) return undefined;
    const classes: string[] = [];
    for (const rule of rules) {
      const fieldValue = data[rule.field];
      let matched = false;
      switch (rule.operator) {
        case 'notNull':
          matched = fieldValue != null;
          break;
        case 'eq':
          matched = fieldValue === rule.value;
          break;
        case 'ne':
          matched = fieldValue !== rule.value;
          break;
        case 'in':
          matched = Array.isArray(rule.value) && rule.value.includes(fieldValue);
          break;
        case 'notIn':
          matched = !Array.isArray(rule.value) || !rule.value.includes(fieldValue);
          break;
      }
      if (matched && rule.className) {
        classes.push(rule.className);
      }
    }
    return classes.length > 0 ? classes.join(' ') : undefined;
  };
}

/**
 * 解析工具栏规则（从按钮配置中提取 position='toolbar' 的按钮）
 */
export function parseToolbarRule(componentKey: string, rules: PageRule[], componentConfig?: string, tabKey?: string): ToolbarRule | null {
  const buttonRule = parseButtonRule(componentKey, rules, componentConfig, tabKey);
  if (!buttonRule) return null;
  const toolbarItems = filterButtonsByPosition(buttonRule.items, 'toolbar');
  return toolbarItems.length > 0 ? { items: toolbarItems } : null;
}
