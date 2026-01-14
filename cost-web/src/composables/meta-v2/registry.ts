import type { ParsedPageConfig, RowData, ValidationRule } from '@/logic/calc-engine';
import type { PageComponentWithRules, PageRule } from '@/composables/meta-v2/types';

export type RuleParserContext = {
  componentKey: string;
  rules: PageRule[];
};

export type RuleParser<T = unknown> = (context: RuleParserContext) => T;

const ruleParsers = new Map<string, RuleParser<any>>();

export function registerRuleParser<T>(
  ruleType: string,
  parser: RuleParser<T>,
  options?: { override?: boolean }
): boolean {
  if (!options?.override && ruleParsers.has(ruleType)) return false;
  ruleParsers.set(ruleType, parser);
  return true;
}

export function getRuleParser<T>(ruleType: string): RuleParser<T> | undefined {
  return ruleParsers.get(ruleType) as RuleParser<T> | undefined;
}

export function parseRuleByType<T>(
  ruleType: string,
  componentKey: string,
  rules: PageRule[],
  fallback: () => T
): T {
  const parser = getRuleParser<T>(ruleType);
  return parser ? parser({ componentKey, rules }) : fallback();
}

export type ComponentExtensionContext = {
  pageCode: string;
  pageConfig: ParsedPageConfig;
  pageComponents: PageComponentWithRules[];
  component: PageComponentWithRules;
  componentRules: PageRule[];
  rulesByComponent: Map<string, PageRule[]>;
  state: Record<string, any>;
  runtime?: any;
};

export type ComponentExtension = {
  key: string;
  order?: number;
  match?: (component: PageComponentWithRules) => boolean;
  apply: (context: ComponentExtensionContext) => void;
};

const componentExtensions: ComponentExtension[] = [];

export function registerComponentExtension(extension: ComponentExtension): void {
  componentExtensions.push(extension);
}

function getSortedComponentExtensions(): ComponentExtension[] {
  return [...componentExtensions].sort((a, b) => {
    const orderDiff = (a.order ?? 0) - (b.order ?? 0);
    if (orderDiff !== 0) return orderDiff;
    return a.key.localeCompare(b.key);
  });
}

function getComponentState(componentStateByKey: Record<string, any>, componentKey: string): Record<string, any> {
  if (!componentStateByKey[componentKey]) componentStateByKey[componentKey] = {};
  return componentStateByKey[componentKey];
}

export function applyComponentExtensions(params: {
  pageCode: string;
  pageConfig: ParsedPageConfig;
  pageComponents: PageComponentWithRules[];
  rulesByComponent: Map<string, PageRule[]>;
  componentStateByKey: Record<string, any>;
  runtime?: any;
}): void {
  const extensions = getSortedComponentExtensions();
  if (extensions.length === 0) return;

  const visit = (component: PageComponentWithRules) => {
    const componentRules = params.rulesByComponent.get(component.componentKey) || [];
    const state = getComponentState(params.componentStateByKey, component.componentKey);
    for (const extension of extensions) {
      if (extension.match && !extension.match(component)) continue;
      try {
        extension.apply({
          pageCode: params.pageCode,
          pageConfig: params.pageConfig,
          pageComponents: params.pageComponents,
          component,
          componentRules,
          rulesByComponent: params.rulesByComponent,
          state,
          runtime: params.runtime
        });
      } catch (error) {
        console.warn(`[MetaV2] component extension failed: ${extension.key}`, error);
      }
    }
    if (Array.isArray(component.children)) {
      component.children.forEach(visit);
    }
  };

  params.pageComponents.forEach(visit);
}

export type SaveHookContext = {
  pageCode: string;
  pageConfig: ParsedPageConfig | null;
  masterRows: RowData[];
  detailCache: Map<number, Record<string, RowData[]>>;
  dirtyMaster: RowData[];
  dirtyDetailByTab: Record<string, RowData[]>;
  masterValidationRules: ValidationRule[];
  detailValidationRulesByTab: Record<string, ValidationRule[]>;
  masterColumnMeta: any[];
  detailColumnMetaByTab: Record<string, any[]>;
  saveStats: { successCount: number; errors: string[] };
  addError: (message: string) => void;
};

export type SaveHook = {
  key: string;
  order?: number;
  beforeValidate?: (context: SaveHookContext) => boolean | void;
  afterValidate?: (context: SaveHookContext) => boolean | void;
  beforeSave?: (context: SaveHookContext) => boolean | void;
  afterSave?: (context: SaveHookContext) => boolean | void;
};

export type SaveHookStage = 'beforeValidate' | 'afterValidate' | 'beforeSave' | 'afterSave';

const saveHooks: SaveHook[] = [];

export function registerSaveHook(hook: SaveHook): void {
  saveHooks.push(hook);
}

function getSortedSaveHooks(): SaveHook[] {
  return [...saveHooks].sort((a, b) => {
    const orderDiff = (a.order ?? 0) - (b.order ?? 0);
    if (orderDiff !== 0) return orderDiff;
    return a.key.localeCompare(b.key);
  });
}

export function runSaveHooks(stage: SaveHookStage, context: SaveHookContext): boolean {
  const hooks = getSortedSaveHooks();
  for (const hook of hooks) {
    const handler = hook[stage];
    if (!handler) continue;
    try {
      const result = handler(context);
      if (result === false) return false;
    } catch (error) {
      console.warn(`[MetaV2] save hook failed: ${hook.key}.${stage}`, error);
      return false;
    }
  }
  return true;
}
