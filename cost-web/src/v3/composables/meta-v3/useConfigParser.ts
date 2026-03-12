import type { GridOptionsRule, PageComponentWithRules, PageRule, SplitLayoutConfig } from '@/v3/composables/meta-v3/types';
import { collectComponentKeysByType } from '@/v3/composables/meta-v3/useComponentLoader';
import { type ResolvedGridOptions, mergeGridOptions, normalizeGridOptions } from '@/v3/composables/meta-v3/grid-options';
import { getComponentRules, parseGridOptionsRule, parseSummaryConfigRule } from '@/v3/composables/meta-v3/usePageRules';
import { type NestedConfig, type ParsedPageConfig, parsePageComponents } from '@/v3/logic/calc-engine';

type ParseMetaConfigParams = {
  components: PageComponentWithRules[];
  rulesByComponent: Map<string, PageRule[]>;
  masterGridKey?: string;
  detailTabsKey?: string;
  layoutDetailType?: string | null;
  layoutSplitConfig?: SplitLayoutConfig | null;
  uniqueKeys: (keys: Array<string | undefined | null>) => string[];
  collectRulesByKeys: (rulesByComponent: Map<string, PageRule[]>, keys: string[]) => PageRule[];
};

type ParseMetaConfigResult = {
  pageConfig: ParsedPageConfig;
  broadcastFields: string[];
  masterGridOptions: ResolvedGridOptions | null;
  detailGridOptionsByTab: Record<string, ResolvedGridOptions>;
  detailLayoutMode: 'nested' | 'split';
  detailSplitConfig: SplitLayoutConfig | null;
};

function mergeNestedConfig(base: NestedConfig | undefined, override: NestedConfig): NestedConfig {
  const merged: NestedConfig = { ...(base || {}) };
  const hasOwn = (key: keyof NestedConfig) => Object.hasOwn(override, key);

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
    cellSelection: enterprise.cellSelection,
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

export function parseMetaConfig(params: ParseMetaConfigParams): ParseMetaConfigResult | null {
  const resolvedMasterGridKey = params.masterGridKey ?? undefined;
  const resolvedDetailTabsKey = params.detailTabsKey ?? undefined;

  const pageConfig = parsePageComponents(params.components, {
    masterGridKey: resolvedMasterGridKey,
    detailTabsKey: resolvedDetailTabsKey
  });
  if (!pageConfig) {
    return null;
  }

  const masterRuleKeysForGlobal = params.uniqueKeys([resolvedMasterGridKey, 'master', 'masterGrid']);
  const masterRulesForGlobal = params.collectRulesByKeys(params.rulesByComponent, masterRuleKeysForGlobal);
  const masterRuleLabelForGlobal = resolvedMasterGridKey || 'master';
  const summaryOverride = parseSummaryConfigRule(masterRuleLabelForGlobal, masterRulesForGlobal);
  if (summaryOverride !== null) {
    pageConfig.nestedConfig = mergeNestedConfig(pageConfig.nestedConfig, summaryOverride);
  }

  const detailGridKeys = collectComponentKeysByType(params.components, 'DETAIL_GRID');
  const detailTabsRuleLabel = resolvedDetailTabsKey || 'detailTabs';
  let detailTabsRules: PageRule[] = [];

  if (resolvedDetailTabsKey) {
    detailTabsRules = getComponentRules(params.rulesByComponent, [resolvedDetailTabsKey]);
  } else if (detailGridKeys.length > 0) {
    detailTabsRules = getComponentRules(params.rulesByComponent, ['detailTabs']);
  }

  const enterpriseOptions = normalizeGridOptions(enterpriseToGridOptions(pageConfig.enterpriseConfig));
  const masterRuleKeys = params.uniqueKeys([resolvedMasterGridKey, 'master', 'masterGrid']);
  const masterRules = params.collectRulesByKeys(params.rulesByComponent, masterRuleKeys);
  const masterRuleLabel = resolvedMasterGridKey || 'master';
  const masterGridRuleOptions = normalizeGridOptions(parseGridOptionsRule(masterRuleLabel, masterRules));
  const masterGridOptions = mergeGridOptions(enterpriseOptions, masterGridRuleOptions);

  if (masterGridOptions.rowModelType && masterGridOptions.rowModelType !== 'serverSide') {
    console.warn(`[V3] 主表 rowModelType 配置为 "${masterGridOptions.rowModelType}"，已强制覆盖为 "serverSide"`);
  }
  masterGridOptions.rowModelType = 'serverSide';
  if (!masterGridOptions.cacheBlockSize) {
    masterGridOptions.cacheBlockSize = 100;
  }

  const detailBaseRuleOptions = normalizeGridOptions(parseGridOptionsRule(detailTabsRuleLabel, detailTabsRules));
  const detailBaseOptions = mergeGridOptions(inheritDetailGridOptions(masterGridOptions), detailBaseRuleOptions);
  const detailGridOptionsByTab: Record<string, ResolvedGridOptions> = {};

  for (const tab of pageConfig.tabs || []) {
    const tabRules = getComponentRules(params.rulesByComponent, [tab.key]);
    const tabGridRuleOptions = normalizeGridOptions(parseGridOptionsRule(tab.key, tabRules));
    const mergedTabOptions = mergeGridOptions(detailBaseOptions, tabGridRuleOptions);

    if (mergedTabOptions.rowModelType && mergedTabOptions.rowModelType !== 'clientSide') {
      console.warn(`[V3] 明细表 ${tab.key} rowModelType 配置为 "${mergedTabOptions.rowModelType}"，已强制覆盖为 "clientSide"`);
    }
    delete mergedTabOptions.rowModelType;
    detailGridOptionsByTab[tab.key] = mergedTabOptions;
  }

  return {
    pageConfig,
    broadcastFields: [],
    masterGridOptions,
    detailGridOptionsByTab,
    detailLayoutMode: params.layoutDetailType?.toLowerCase() === 'split' ? 'split' : 'nested',
    detailSplitConfig: params.layoutSplitConfig || null
  };
}
