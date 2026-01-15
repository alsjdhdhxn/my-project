import { shallowRef } from 'vue';
import type { ColDef } from 'ag-grid-community';
import { fetchPageComponents } from '@/service/api';
import { loadTableMeta, extractCalcRules, extractLookupRules, filterColumnsByVariant, type LookupRule } from '@/composables/useMetaColumns';
import type { PageComponentWithRules, RelationRule, PageRule, GridOptionsRule, SplitLayoutConfig } from '@/composables/meta-v2/types';
import {
  parsePageComponents,
  compileCalcRules,
  compileAggRules,
  parseValidationRules,
  type ParsedPageConfig,
  type NestedConfig,
  type ValidationRule
} from '@/logic/calc-engine';
import {
  collectPageRules,
  groupRulesByComponent,
  getComponentRules,
  parseValidationRuleConfig,
  parseLookupRuleConfig,
  parseCalcRuleConfig,
  parseAggregateRuleConfig,
  parseBroadcastRuleConfig,
  parseSummaryConfigRule,
  parseRoleBindingRule,
  parseRelationRule,
  parseGridOptionsRule,
  attachGroupCellRenderer
} from '@/composables/meta-v2/usePageRules';
import {
  normalizeGridOptions,
  mergeGridOptions,
  applyGroupByColumns,
  type ResolvedGridOptions
} from '@/composables/meta-v2/grid-options';
import { DIRTY_CELL_CLASS_RULES, mergeCellClassRules } from '@/composables/meta-v2/cell-style';

function buildComponentTree(components: PageComponentWithRules[]): PageComponentWithRules[] {
  const hasChildren = components.some(component => Array.isArray(component.children) && component.children.length > 0);
  if (hasChildren) return components;

  const map = new Map<string, PageComponentWithRules>();
  for (const component of components) {
    map.set(component.componentKey, { ...component, children: [] });
  }

  const roots: PageComponentWithRules[] = [];
  for (const component of map.values()) {
    if (component.parentKey && map.has(component.parentKey)) {
      map.get(component.parentKey)!.children!.push(component);
    } else {
      roots.push(component);
    }
  }

  for (const component of map.values()) {
    if (component.children) {
      component.children.sort((a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0));
    }
  }
  roots.sort((a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0));

  return roots;
}

function normalizeRole(role?: string): string | null {
  if (!role) return null;
  const normalized = role.trim().toUpperCase();
  return normalized.length > 0 ? normalized : null;
}

function collectComponentKeysByType(components: PageComponentWithRules[], type: string): string[] {
  const keys: string[] = [];
  const visit = (component: PageComponentWithRules) => {
    if (component.componentType === type) keys.push(component.componentKey);
    if (Array.isArray(component.children)) {
      component.children.forEach(visit);
    }
  };
  components.forEach(visit);
  return keys;
}

function resolveLayoutKeys(
  components: PageComponentWithRules[],
  rulesByComponent: Map<string, PageRule[]>
): { masterGridKey?: string; detailTabsKey?: string; detailType?: string; splitConfig?: SplitLayoutConfig } {
  let relation: RelationRule | null = null;
  const roleMap = new Map<string, string>();

  const visit = (component: PageComponentWithRules) => {
    const rules = rulesByComponent.get(component.componentKey) || [];
    const roleRule = parseRoleBindingRule(component.componentKey, rules);
    const normalizedRole = normalizeRole(roleRule?.role);
    if (normalizedRole) roleMap.set(component.componentKey, normalizedRole);

    const relationRule = parseRelationRule(component.componentKey, rules);
    if (relationRule) relation = { ...(relation || {}), ...relationRule };

    if (Array.isArray(component.children)) {
      component.children.forEach(visit);
    }
  };
  components.forEach(visit);

  let masterGridKey = relation?.masterKey;
  let detailTabsKey = relation?.detailKey;

  if (!masterGridKey) {
    for (const [key, role] of roleMap.entries()) {
      if (role === 'MASTER_GRID' || role === 'MASTER') {
        masterGridKey = key;
        break;
      }
    }
  }

  if (!detailTabsKey) {
    for (const [key, role] of roleMap.entries()) {
      if (role === 'DETAIL_TABS' || role === 'DETAIL') {
        detailTabsKey = key;
        break;
      }
    }
  }

  if (!masterGridKey) {
    const gridKeys = collectComponentKeysByType(components, 'GRID');
    if (gridKeys.length === 1) masterGridKey = gridKeys[0];
  }

  if (!detailTabsKey) {
    const tabsKeys = collectComponentKeysByType(components, 'TABS');
    if (tabsKeys.length === 1) detailTabsKey = tabsKeys[0];
  }

  return {
    masterGridKey,
    detailTabsKey,
    detailType: relation?.detailType,
    splitConfig: relation?.splitConfig
  };
}

function uniqueKeys(keys: Array<string | undefined | null>): string[] {
  const result: string[] = [];
  const seen = new Set<string>();
  for (const key of keys) {
    if (!key || seen.has(key)) continue;
    seen.add(key);
    result.push(key);
  }
  return result;
}

function collectRulesByKeys(
  rulesByComponent: Map<string, PageRule[]>,
  keys: string[]
): PageRule[] {
  const result: PageRule[] = [];
  for (const key of keys) {
    const rules = rulesByComponent.get(key);
    if (rules && rules.length > 0) result.push(...rules);
  }
  return result;
}

function mergeNestedConfig(base: NestedConfig | undefined, override: NestedConfig): NestedConfig {
  const merged: NestedConfig = { ...(base || {}) };
  const hasOwn = (key: keyof NestedConfig) => Object.prototype.hasOwnProperty.call(override, key);
  if (hasOwn('enabled')) merged.enabled = override.enabled;
  if (hasOwn('summaryColumns')) merged.summaryColumns = override.summaryColumns;
  if (hasOwn('summaryAggregates')) merged.summaryAggregates = override.summaryAggregates;
  if (hasOwn('groupLabelField')) merged.groupLabelField = override.groupLabelField;
  if (hasOwn('groupLabelHeader')) merged.groupLabelHeader = override.groupLabelHeader;

  if (merged.enabled == null && (hasOwn('summaryColumns') || hasOwn('summaryAggregates'))) {
    merged.enabled = true;
  }

  return merged;
}

function enterpriseToGridOptions(enterprise?: ParsedPageConfig['enterpriseConfig']): GridOptionsRule | null {
  if (!enterprise) return null;
  return {
    enableSidebar: enterprise.enableSidebar,
    enableRangeSelection: enterprise.enableRangeSelection,
    groupBy: enterprise.groupBy,
    groupColumnName: enterprise.groupColumnName
  };
}

function inheritDetailGridOptions(master?: ResolvedGridOptions | null): ResolvedGridOptions {
  if (!master) return {};
  return {
    sideBar: master.sideBar,
    cellSelection: master.cellSelection,
    autoSizeColumns: master.autoSizeColumns,
    autoSizeMode: master.autoSizeMode
  };
}

export function useMetaConfig(pageCode: string, notifyError: (message: string) => void) {
  const pageConfig = shallowRef<ParsedPageConfig | null>(null);
  const pageComponents = shallowRef<PageComponentWithRules[]>([]);
  const broadcastFields = shallowRef<string[]>([]);
  const masterColumnDefs = shallowRef<ColDef[]>([]);
  const detailColumnsByTab = shallowRef<Record<string, ColDef[]>>({});
  const detailCalcRulesByTab = shallowRef<Record<string, ReturnType<typeof compileCalcRules>>>({});
  const detailFkColumnByTab = shallowRef<Record<string, string>>({});
  const compiledAggRules = shallowRef<ReturnType<typeof compileAggRules>>([]);
  const compiledMasterCalcRules = shallowRef<ReturnType<typeof compileCalcRules>>([]);
  const masterRowClassGetter = shallowRef<((params: any) => string | undefined) | undefined>(undefined);
  const detailRowClassGetterByTab = shallowRef<Record<string, ((params: any) => string | undefined) | undefined>>({});
  const masterGridOptions = shallowRef<ResolvedGridOptions | null>(null);
  const detailGridOptionsByTab = shallowRef<Record<string, ResolvedGridOptions>>({});
  const detailLayoutMode = shallowRef<'nested' | 'split'>('nested');
  const detailSplitConfig = shallowRef<SplitLayoutConfig | null>(null);
  const masterGridKey = shallowRef<string | null>(null);
  const detailTabsKey = shallowRef<string | null>(null);

  const masterValidationRules = shallowRef<ValidationRule[]>([]);
  const detailValidationRulesByTab = shallowRef<Record<string, ValidationRule[]>>({});
  const masterColumnMeta = shallowRef<any[]>([]);
  const detailColumnMetaByTab = shallowRef<Record<string, any[]>>({});

  const masterLookupRules = shallowRef<LookupRule[]>([]);
  const detailLookupRulesByTab = shallowRef<Record<string, LookupRule[]>>({});
  const componentStateByKey = shallowRef<Record<string, any>>({});

  async function loadMetadata() {
    const pageRes = await fetchPageComponents(pageCode);
    if (pageRes.error || !pageRes.data) {
      notifyError('加载页面配置失败');
      return false;
    }

    const pageComponentsData = pageRes.data as PageComponentWithRules[];
    const pageComponentTree = buildComponentTree(pageComponentsData);
    pageComponents.value = pageComponentTree;
    const rulesByComponent = groupRulesByComponent(collectPageRules(pageComponentTree));
    const {
      masterGridKey: resolvedMasterGridKey,
      detailTabsKey: resolvedDetailTabsKey,
      detailType,
      splitConfig
    } = resolveLayoutKeys(pageComponentTree, rulesByComponent);
    masterGridKey.value = resolvedMasterGridKey ?? null;
    detailTabsKey.value = resolvedDetailTabsKey ?? null;
    const config = parsePageComponents(pageComponentTree, {
      masterGridKey: resolvedMasterGridKey,
      detailTabsKey: resolvedDetailTabsKey
    });
    if (!config) {
      notifyError('解析页面配置失败');
      return false;
    }

    const tabsComponentKeys = collectComponentKeysByType(pageComponentTree, 'TABS');
    const ruleKeys = resolvedDetailTabsKey ? [resolvedDetailTabsKey] : tabsComponentKeys;
    let detailTabsRules: PageRule[] = [];
    let detailTabsRuleLabel = resolvedDetailTabsKey || ruleKeys[0] || 'tabs';

    if (ruleKeys.length > 0) {
      detailTabsRules = getComponentRules(rulesByComponent, ruleKeys);
      detailTabsRuleLabel = resolvedDetailTabsKey || ruleKeys[0] || 'tabs';
      const broadcastOverride = parseBroadcastRuleConfig(detailTabsRuleLabel, detailTabsRules);
      if (broadcastOverride !== null) {
        config.broadcast = broadcastOverride;
        config.broadcastFields = broadcastOverride;
      }

      const summaryOverride = parseSummaryConfigRule(detailTabsRuleLabel, detailTabsRules);
      if (summaryOverride !== null) {
        config.nestedConfig = mergeNestedConfig(config.nestedConfig, summaryOverride);
      }
    }

    const resolvedDetailType = detailType?.toLowerCase();
    detailLayoutMode.value = resolvedDetailType === 'split' ? 'split' : 'nested';
    detailSplitConfig.value = splitConfig || null;

    pageConfig.value = config;
    componentStateByKey.value = {};
    broadcastFields.value = config.broadcast || [];

    const enterpriseOptions = normalizeGridOptions(enterpriseToGridOptions(config.enterpriseConfig));

    const masterRuleKeys = uniqueKeys([resolvedMasterGridKey, 'master', 'masterGrid']);
    const masterRules = collectRulesByKeys(rulesByComponent, masterRuleKeys);
    const masterRuleLabel = resolvedMasterGridKey || 'master';
    const masterGridRuleOptions = normalizeGridOptions(parseGridOptionsRule(masterRuleLabel, masterRules));
    masterGridOptions.value = mergeGridOptions(enterpriseOptions, masterGridRuleOptions);

    const masterMeta = await loadTableMeta(config.masterTableCode, pageCode, resolvedMasterGridKey ?? 'masterGrid');
    if (!masterMeta) {
      notifyError('加载主表元数据失败');
      return false;
    }

    const masterColumns = mergeCellClassRules(
      attachGroupCellRenderer(
        applyGroupByColumns(
          masterMeta.columns,
          masterGridOptions.value?.groupBy
        )
      ),
      DIRTY_CELL_CLASS_RULES
    );
    masterColumnDefs.value = masterColumns;
    masterRowClassGetter.value = masterMeta.getRowClass;

    masterColumnMeta.value = masterMeta.rawColumns || [];
    const masterValidation = parseValidationRuleConfig(masterRuleLabel, masterRules);
    masterValidationRules.value = masterValidation.length > 0 ? masterValidation : parseValidationRules(masterColumnMeta.value);

    const masterLookup = parseLookupRuleConfig(masterRuleLabel, masterRules);
    masterLookupRules.value = masterLookup.length > 0 ? masterLookup : extractLookupRules(masterColumnMeta.value);

    const masterCalcRules = parseCalcRuleConfig(masterRuleLabel, masterRules);
    if (masterCalcRules.length > 0) {
      compiledMasterCalcRules.value = compileCalcRules(masterCalcRules, `${pageCode}_master`);
    } else if (config.masterCalcRules?.length) {
      compiledMasterCalcRules.value = compileCalcRules(config.masterCalcRules, `${pageCode}_master`);
    } else {
      compiledMasterCalcRules.value = [];
    }

    const masterAggRules = parseAggregateRuleConfig(masterRuleLabel, masterRules);
    if (masterAggRules.length > 0) {
      compiledAggRules.value = compileAggRules(masterAggRules, `${pageCode}_agg`);
    } else if (config.aggregates?.length) {
      compiledAggRules.value = compileAggRules(config.aggregates, `${pageCode}_agg`);
    } else {
      compiledAggRules.value = [];
    }

    const detailBaseRuleOptions = normalizeGridOptions(parseGridOptionsRule(detailTabsRuleLabel, detailTabsRules));
    const detailBaseOptions = mergeGridOptions(
      inheritDetailGridOptions(masterGridOptions.value),
      detailBaseRuleOptions
    );
    detailRowClassGetterByTab.value = {};
    detailGridOptionsByTab.value = {};

    for (const tab of config.tabs || []) {
      const tableCode = tab.tableCode || config.detailTableCode;
      if (!tableCode) continue;

      const detailMeta = await loadTableMeta(tableCode, pageCode, tab.key);
      if (!detailMeta) {
        console.warn(`[load detail meta failed] ${tableCode}`);
        continue;
      }

      const tabRules = getComponentRules(rulesByComponent, [tab.key]);
      const tabGridRuleOptions = normalizeGridOptions(parseGridOptionsRule(tab.key, tabRules));
      const tabGridOptions = mergeGridOptions(detailBaseOptions, tabGridRuleOptions);
      detailGridOptionsByTab.value[tab.key] = tabGridOptions;
      detailColumnsByTab.value[tab.key] = mergeCellClassRules(
        applyGroupByColumns(
          filterColumnsByVariant(
            detailMeta.columns,
            tab.variantKey,
            detailMeta.rawColumns || []
          ),
          tabGridOptions.groupBy
        ),
        DIRTY_CELL_CLASS_RULES
      );
      detailRowClassGetterByTab.value[tab.key] = detailMeta.getRowClass;

      const fkColumnName = detailMeta.metadata.parentFkColumn;
      detailFkColumnByTab.value[tab.key] = fkColumnName
        ? (detailMeta.rawColumns.find(col => col.columnName.toUpperCase() === fkColumnName.toUpperCase())?.fieldName || 'masterId')
        : 'masterId';

      detailColumnMetaByTab.value[tab.key] = detailMeta.rawColumns || [];
      const detailValidation = parseValidationRuleConfig(tab.key, tabRules);
      detailValidationRulesByTab.value[tab.key] = detailValidation.length > 0
        ? detailValidation
        : parseValidationRules(detailMeta.rawColumns || []);

      const detailLookup = parseLookupRuleConfig(tab.key, tabRules);
      detailLookupRulesByTab.value[tab.key] = detailLookup.length > 0
        ? detailLookup
        : extractLookupRules(detailMeta.rawColumns || []);

      const detailCalcRules = parseCalcRuleConfig(tab.key, tabRules);
      const calcRules = detailCalcRules.length > 0 ? detailCalcRules : extractCalcRules(detailMeta.rawColumns);
      if (calcRules.length > 0) {
        detailCalcRulesByTab.value[tab.key] = compileCalcRules(calcRules, `${pageCode}_${tab.key}`);
        console.log(`[detail calc rules] ${tab.key}:`, calcRules.length, 'rules');
      }
    }

    return true;
  }

    return {
      pageConfig,
      pageComponents,
      broadcastFields,
      masterColumnDefs,
      detailColumnsByTab,
      detailCalcRulesByTab,
      detailFkColumnByTab,
      compiledAggRules,
      compiledMasterCalcRules,
      masterRowClassGetter,
      detailRowClassGetterByTab,
      masterGridOptions,
      detailGridOptionsByTab,
      detailLayoutMode,
      detailSplitConfig,
      masterGridKey,
      detailTabsKey,
      masterValidationRules,
      detailValidationRulesByTab,
      masterColumnMeta,
      detailColumnMetaByTab,
      masterLookupRules,
    detailLookupRulesByTab,
    componentStateByKey,
    loadMetadata
  };
}
