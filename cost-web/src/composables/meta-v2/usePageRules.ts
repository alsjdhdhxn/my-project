import type { ColDef } from 'ag-grid-community';
import type { AggRule, CalcRule, ValidationRule, NestedConfig } from '@/logic/calc-engine';
import type { LookupRule } from '@/composables/useMetaColumns';
import { registerRuleParser } from '@/composables/meta-v2/registry';
import type {
  PageRule,
  PageComponentWithRules,
  ColumnOverrideRule,
  GridOptionsRule,
  LookupRuleConfig,
  RoleBindingRule,
  RelationRule
} from '@/composables/meta-v2/types';

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

export function parseRuleArray<T>(rule: PageRule | undefined, label: string): T[] {
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

export function parseRuleObject<T>(rule: PageRule | undefined, label: string): T | null {
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

export function parseLookupRuleConfig(componentKey: string, rules: PageRule[]): LookupRule[] {
  const rule = getRuleByType(rules, 'LOOKUP');
  const items = parseRuleArray<LookupRuleConfig>(rule, `${componentKey}.LOOKUP`);
  return items
    .filter(item => Boolean(item.field || item.fieldName))
    .map(item => ({
      fieldName: item.field ?? item.fieldName ?? '',
      lookupCode: item.lookupCode,
      mapping: item.mapping
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

registerRuleParser('COLUMN_OVERRIDE', ({ componentKey, rules }) => parseColumnOverrideConfig(componentKey, rules));
registerRuleParser('VALIDATION', ({ componentKey, rules }) => parseValidationRuleConfig(componentKey, rules));
registerRuleParser('LOOKUP', ({ componentKey, rules }) => parseLookupRuleConfig(componentKey, rules));
registerRuleParser('CALC', ({ componentKey, rules }) => parseCalcRuleConfig(componentKey, rules));
registerRuleParser('AGGREGATE', ({ componentKey, rules }) => parseAggregateRuleConfig(componentKey, rules));
registerRuleParser('BROADCAST', ({ componentKey, rules }) => parseBroadcastRuleConfig(componentKey, rules));
registerRuleParser('SUMMARY_CONFIG', ({ componentKey, rules }) => parseSummaryConfigRule(componentKey, rules));
registerRuleParser('NESTED_CONFIG', ({ componentKey, rules }) => parseSummaryConfigRule(componentKey, rules));
registerRuleParser('ROLE_BINDING', ({ componentKey, rules }) => parseRoleBindingRule(componentKey, rules));
registerRuleParser('RELATION', ({ componentKey, rules }) => parseRelationRule(componentKey, rules));
registerRuleParser('GRID_OPTIONS', ({ componentKey, rules }) => parseGridOptionsRule(componentKey, rules));
registerRuleParser('GRID_FEATURES', ({ componentKey, rules }) => parseGridOptionsRule(componentKey, rules));
