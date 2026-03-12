import { shallowRef } from 'vue';
import type { ColDef } from 'ag-grid-community';
import { fetchPageComponents } from '@/service/api';
import { type LookupRule, loadTableMeta } from '@/v3/composables/meta-v3/useMetaColumns';
import { parseMetaConfig } from '@/v3/composables/meta-v3/useConfigParser';
import type {
  ContextMenuRule,
  PageComponentWithRules,
  PageRule,
  RelationRule,
  SplitLayoutConfig,
  ToolbarRule
} from '@/v3/composables/meta-v3/types';
import { type ParsedPageConfig, type ValidationRule, compileAggRules, compileCalcRules } from '@/v3/logic/calc-engine';
import { attachGroupCellRenderer, collectPageRules, groupRulesByComponent, parseRelationRule, parseRoleBindingRule } from '@/v3/composables/meta-v3/usePageRules';
import { type ResolvedGridOptions, applyGroupByColumns } from '@/v3/composables/meta-v3/grid-options';
import { DIRTY_CELL_CLASS_RULES, mergeCellClassRules } from '@/v3/composables/meta-v3/cell-style';
import {
  buildComponentTree,
  collectComponentKeysByType,
  getComponentConfig,
  getDetailGridComponentConfig,
  injectMasterDetailRoot
} from '@/v3/composables/meta-v3/useComponentLoader';
import { compileMetaRules } from '@/v3/composables/meta-v3/useRuleCompiler';

function normalizeRole(role?: string): string | null {
  if (!role) return null;
  const normalized = role.trim().toUpperCase();
  return normalized.length > 0 ? normalized : null;
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
    if (normalizedRole) {
      roleMap.set(component.componentKey, normalizedRole);
    }

    const relationRule = parseRelationRule(component.componentKey, rules);
    if (relationRule) {
      relation = { ...(relation || {}), ...relationRule };
    }

    if (Array.isArray(component.children)) {
      component.children.forEach(visit);
    }
  };

  components.forEach(visit);

  const relationValue = relation as RelationRule | null;
  let masterGridKey = relationValue?.masterKey;
  let detailTabsKey = relationValue?.detailKey;

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
    if (gridKeys.length === 1) {
      masterGridKey = gridKeys[0];
    }
  }

  if (!detailTabsKey) {
    const detailGridKeys = collectComponentKeysByType(components, 'DETAIL_GRID');
    if (detailGridKeys.length > 0) {
      detailTabsKey = 'detailTabs';
    }
  }

  return {
    masterGridKey,
    detailTabsKey,
    detailType: relationValue?.detailType,
    splitConfig: relationValue?.splitConfig
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

function collectRulesByKeys(rulesByComponent: Map<string, PageRule[]>, keys: string[]): PageRule[] {
  const result: PageRule[] = [];

  for (const key of keys) {
    const rules = rulesByComponent.get(key);
    if (rules && rules.length > 0) {
      result.push(...rules);
    }
  }

  return result;
}

function extractSumFieldsFromMetadata(columns: Array<{ columnName?: string; rulesConfig?: string }>): string[] {
  const result: string[] = [];
  const seen = new Set<string>();

  for (const col of columns || []) {
    if (!col.columnName || seen.has(col.columnName) || !col.rulesConfig) continue;

    try {
      const config = JSON.parse(col.rulesConfig);
      if (config?.aggFunc === 'sum') {
        result.push(col.columnName);
        seen.add(col.columnName);
      }
    } catch {
      // Ignore invalid rulesConfig.
    }
  }

  return result;
}

function mergeLookupRules(metadataRules: LookupRule[], pageRules: LookupRule[]): LookupRule[] {
  const map = new Map<string, LookupRule>();

  for (const rule of metadataRules || []) {
    if (rule?.columnName) {
      map.set(rule.columnName, rule);
    }
  }

  for (const rule of pageRules || []) {
    if (rule?.columnName) {
      map.set(rule.columnName, rule);
    }
  }

  return Array.from(map.values());
}

export function useMetaConfig(pageCode: string, notifyError: (message: string) => void) {
  const pageConfig = shallowRef<ParsedPageConfig | null>(null);
  const pageComponents = shallowRef<PageComponentWithRules[]>([]);
  const rulesByComponent = shallowRef<Map<string, PageRule[]>>(new Map());
  const broadcastFields = shallowRef<string[]>([]);
  const masterColumnDefs = shallowRef<ColDef[]>([]);
  const detailColumnsByTab = shallowRef<Record<string, ColDef[]>>({});
  const detailCalcRulesByTab = shallowRef<Record<string, ReturnType<typeof compileCalcRules>>>({});
  const detailFkColumnByTab = shallowRef<Record<string, string>>({});
  const masterPkColumn = shallowRef<string>('ID');
  const detailPkColumnByTab = shallowRef<Record<string, string>>({});
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
  const masterContextMenu = shallowRef<ContextMenuRule | null>(null);
  const detailContextMenuByTab = shallowRef<Record<string, ContextMenuRule | null>>({});
  const detailContextMenuDefault = shallowRef<ContextMenuRule | null>(null);

  const masterLookupRules = shallowRef<LookupRule[]>([]);
  const detailLookupRulesByTab = shallowRef<Record<string, LookupRule[]>>({});
  const layoutDetailTypeRef = shallowRef<string | null>(null);
  const layoutSplitConfigRef = shallowRef<SplitLayoutConfig | null>(null);
  const masterRowEditableRules = shallowRef<import('@/v3/composables/meta-v3/types').RowEditableRule[]>([]);
  const masterCellEditableRules = shallowRef<import('@/v3/composables/meta-v3/types').CellEditableRule[]>([]);
  const masterRowClassRules = shallowRef<import('@/v3/composables/meta-v3/types').GridStyleRule[]>([]);
  const detailRowClassRulesByTab = shallowRef<Record<string, import('@/v3/composables/meta-v3/types').GridStyleRule[]>>(
    {}
  );
  const detailRowEditableRulesByTab = shallowRef<
    Record<string, import('@/v3/composables/meta-v3/types').RowEditableRule[]>
  >({});
  const detailCellEditableRulesByTab = shallowRef<
    Record<string, import('@/v3/composables/meta-v3/types').CellEditableRule[]>
  >({});
  const masterToolbar = shallowRef<ToolbarRule | null>(null);
  const detailToolbarByTab = shallowRef<Record<string, ToolbarRule | null>>({});
  const masterSumFields = shallowRef<string[]>([]);
  const detailSumFieldsByTab = shallowRef<Record<string, string[]>>({});

  function resolveRuntimeColumnName(rawColumns: any[], targetColumn?: string | null, fallback = 'ID') {
    const normalizedTarget = String(targetColumn || '').trim().toUpperCase();
    if (normalizedTarget) {
      const byTarget = rawColumns.find(
        col => String(col?.targetColumn || '').trim().toUpperCase() === normalizedTarget
      );
      if (byTarget?.columnName) return String(byTarget.columnName);

      const byColumn = rawColumns.find(
        col => String(col?.columnName || '').trim().toUpperCase() === normalizedTarget
      );
      if (byColumn?.columnName) return String(byColumn.columnName);

      const byQuery = rawColumns.find(
        col => String(col?.queryColumn || '').trim().toUpperCase() === normalizedTarget
      );
      if (byQuery?.columnName) return String(byQuery.columnName);
    }

    return fallback;
  }

  async function loadComponents() {
    const pageRes = await fetchPageComponents(pageCode);
    if (pageRes.error || !pageRes.data) {
      notifyError('加载页面组件失败');
      return false;
    }

    const pageComponentsData = pageRes.data as PageComponentWithRules[];
    const pageComponentTree = buildComponentTree(pageComponentsData);
    pageComponents.value = injectMasterDetailRoot(pageComponentTree);

    const rulesMap = groupRulesByComponent(collectPageRules(pageComponentTree));
    rulesByComponent.value = rulesMap;

    const {
      masterGridKey: resolvedMasterGridKey,
      detailTabsKey: resolvedDetailTabsKey,
      detailType,
      splitConfig
    } = resolveLayoutKeys(pageComponentTree, rulesMap);

    masterGridKey.value = resolvedMasterGridKey ?? null;
    detailTabsKey.value = resolvedDetailTabsKey ?? null;
    layoutDetailTypeRef.value = detailType ?? null;
    layoutSplitConfigRef.value = splitConfig || null;
    return true;
  }

  function parseConfig() {
    const components = pageComponents.value || [];
    if (components.length === 0) {
      notifyError('页面组件为空');
      return false;
    }

    const parsedConfig = parseMetaConfig({
      components,
      rulesByComponent: rulesByComponent.value,
      masterGridKey: masterGridKey.value ?? undefined,
      detailTabsKey: detailTabsKey.value ?? undefined,
      layoutDetailType: layoutDetailTypeRef.value,
      layoutSplitConfig: layoutSplitConfigRef.value,
      uniqueKeys,
      collectRulesByKeys
    });

    if (!parsedConfig) {
      notifyError('页面配置解析失败');
      return false;
    }

    pageConfig.value = parsedConfig.pageConfig;
    broadcastFields.value = parsedConfig.broadcastFields;
    masterGridOptions.value = parsedConfig.masterGridOptions;
    detailGridOptionsByTab.value = parsedConfig.detailGridOptionsByTab;
    detailLayoutMode.value = parsedConfig.detailLayoutMode;
    detailSplitConfig.value = parsedConfig.detailSplitConfig;
    return true;
  }

  async function loadMeta() {
    if (!pageConfig.value) return false;

    const config = pageConfig.value;
    const resolvedMasterGridKey = masterGridKey.value ?? undefined;

    const masterMeta = await loadTableMeta(config.masterTableCode, pageCode, resolvedMasterGridKey ?? 'masterGrid');
    if (!masterMeta) {
      notifyError('加载主表元数据失败');
      return false;
    }

    const masterColumns = mergeCellClassRules(
      attachGroupCellRenderer(applyGroupByColumns(masterMeta.columns, masterGridOptions.value?.groupBy)),
      DIRTY_CELL_CLASS_RULES
    );
    masterColumnDefs.value = masterColumns;
    masterRowClassGetter.value = masterMeta.getRowClass;
    masterColumnMeta.value = masterMeta.rawColumns || [];
    masterPkColumn.value = resolveRuntimeColumnName(masterMeta.rawColumns || [], masterMeta.metadata.pkColumn, 'ID');
    masterSumFields.value = extractSumFieldsFromMetadata(masterMeta.rawColumns || []);

    detailColumnsByTab.value = {};
    detailRowClassGetterByTab.value = {};
    detailColumnMetaByTab.value = {};
    detailFkColumnByTab.value = {};
    detailPkColumnByTab.value = {};
    detailSumFieldsByTab.value = {};

    for (const tab of config.tabs || []) {
      const tableCode = tab.tableCode || config.detailTableCode;
      if (!tableCode) continue;

      const detailMeta = await loadTableMeta(tableCode, pageCode, tab.key);
      if (!detailMeta) {
        console.warn(`[load detail meta failed] ${tableCode}`);
        continue;
      }

      const tabGridOptions = detailGridOptionsByTab.value[tab.key];
      detailColumnsByTab.value[tab.key] = mergeCellClassRules(
        applyGroupByColumns(detailMeta.columns, tabGridOptions?.groupBy),
        DIRTY_CELL_CLASS_RULES
      );
      detailRowClassGetterByTab.value[tab.key] = detailMeta.getRowClass;
      detailSumFieldsByTab.value[tab.key] = extractSumFieldsFromMetadata(detailMeta.rawColumns || []);

      const fkColumnName = detailMeta.metadata.parentFkColumn;
      detailFkColumnByTab.value[tab.key] = fkColumnName
        ? detailMeta.rawColumns.find(col => col.columnName.toUpperCase() === fkColumnName.toUpperCase())?.columnName ||
          fkColumnName
        : masterPkColumn.value;

      detailPkColumnByTab.value[tab.key] = resolveRuntimeColumnName(
        detailMeta.rawColumns || [],
        detailMeta.metadata.pkColumn,
        'ID'
      );
      detailColumnMetaByTab.value[tab.key] = detailMeta.rawColumns || [];
    }

    return true;
  }

  function compileRules() {
    return compileMetaRules({
      pageCode,
      pageConfig: pageConfig.value,
      pageComponents: pageComponents.value || [],
      rulesByComponent: rulesByComponent.value,
      masterGridKey: masterGridKey.value ?? undefined,
      detailTabsKey: detailTabsKey.value ?? undefined,
      masterColumnDefs,
      detailColumnsByTab,
      masterColumnMeta,
      detailColumnMetaByTab,
      masterValidationRules,
      detailValidationRulesByTab,
      masterLookupRules,
      detailLookupRulesByTab,
      compiledMasterCalcRules,
      compiledAggRules,
      detailCalcRulesByTab,
      masterContextMenu,
      detailContextMenuDefault,
      detailContextMenuByTab,
      masterRowEditableRules,
      masterCellEditableRules,
      masterRowClassRules,
      detailRowClassRulesByTab,
      detailRowEditableRulesByTab,
      detailCellEditableRulesByTab,
      masterToolbar,
      detailToolbarByTab,
      uniqueKeys,
      collectRulesByKeys,
      mergeLookupRules,
      getComponentConfig,
      getDetailGridComponentConfig
    });
  }

  async function loadMetadata() {
    const ok = await loadComponents();
    if (!ok) return false;
    if (!parseConfig()) return false;
    if (!(await loadMeta())) return false;
    return compileRules();
  }

  return {
    pageConfig,
    pageComponents,
    rulesByComponent,
    broadcastFields,
    masterColumnDefs,
    detailColumnsByTab,
    detailCalcRulesByTab,
    detailFkColumnByTab,
    masterPkColumn,
    detailPkColumnByTab,
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
    masterContextMenu,
    detailContextMenuByTab,
    masterLookupRules,
    detailLookupRulesByTab,
    masterRowEditableRules,
    masterCellEditableRules,
    masterRowClassRules,
    detailRowClassRulesByTab,
    detailRowEditableRulesByTab,
    detailCellEditableRulesByTab,
    masterToolbar,
    detailToolbarByTab,
    masterSumFields,
    detailSumFieldsByTab,
    loadComponents,
    parseConfig,
    loadMeta,
    compileRules,
    loadMetadata
  };
}
