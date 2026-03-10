import { shallowRef } from 'vue';
import type { ColDef } from 'ag-grid-community';
import { fetchPageComponents } from '@/service/api';
import {
  type LookupRule,
  extractLookupRules,
  filterColumnsByVariant,
  loadTableMeta
} from '@/composables/useMetaColumns';
import type {
  ContextMenuRule,
  GridOptionsRule,
  PageComponentWithRules,
  PageRule,
  RelationRule,
  SplitLayoutConfig,
  ToolbarRule
} from '@/v3/composables/meta-v3/types';
import {
  type NestedConfig,
  type ParsedPageConfig,
  type ValidationRule,
  compileAggRules,
  compileCalcRules,
  parsePageComponents,
  parseValidationRules
} from '@/v3/logic/calc-engine';
import {
  applyCellStyleRules,
  attachGroupCellRenderer,
  collectPageRules,
  getComponentRules,
  groupRulesByComponent,
  parseAggregateRuleConfig,
  parseCalcRuleConfig,
  parseCellEditableRule,
  parseContextMenuRule,
  parseGridOptionsRule,
  parseGridStyleRule,
  parseLookupRuleConfig,
  parseRelationRule,
  parseRoleBindingRule,
  parseRowEditableRule,
  parseSummaryConfigRule,
  parseToolbarRule,
  parseValidationRuleConfig
} from '@/v3/composables/meta-v3/usePageRules';
import {
  type ResolvedGridOptions,
  applyGroupByColumns,
  mergeGridOptions,
  normalizeGridOptions
} from '@/v3/composables/meta-v3/grid-options';
import { DIRTY_CELL_CLASS_RULES, mergeCellClassRules } from '@/v3/composables/meta-v3/cell-style';

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

function hasComponentType(components: PageComponentWithRules[], type: string): boolean {
  const visit = (items: PageComponentWithRules[]): boolean => {
    for (const item of items) {
      if (item.componentType === type) return true;
      if (Array.isArray(item.children) && visit(item.children)) return true;
    }
    return false;
  };
  return visit(components || []);
}

function injectMasterDetailRoot(components: PageComponentWithRules[]): PageComponentWithRules[] {
  if (hasComponentType(components, 'MASTER_DETAIL')) return components;
  const hasGrid = hasComponentType(components, 'GRID');
  const hasDetailGrid = hasComponentType(components, 'DETAIL_GRID');
  if (!hasGrid || !hasDetailGrid) return components;
  const pageCode = components[0]?.pageCode || '';
  return [
    {
      id: -1,
      pageCode,
      componentKey: '__v3_master_detail__',
      componentType: 'MASTER_DETAIL',
      sortOrder: -1,
      children: components
    } as PageComponentWithRules
  ];
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

/**
 * 根据 componentKey 查找组件
 */
function findComponentByKey(components: PageComponentWithRules[], key: string): PageComponentWithRules | null {
  for (const component of components) {
    if (component.componentKey === key) return component;
    if (Array.isArray(component.children)) {
      const found = findComponentByKey(component.children, key);
      if (found) return found;
    }
  }
  return null;
}

/**
 * 获取组件的 componentConfig
 */
function getComponentConfig(components: PageComponentWithRules[], key: string): string | undefined {
  const component = findComponentByKey(components, key);
  return component?.componentConfig;
}

/**
 * 获取 DETAIL_GRID 组件的 componentConfig（按 componentKey 查找） */
function getDetailGridComponentConfig(components: PageComponentWithRules[], key: string): string | undefined {
  return getComponentConfig(components, key);
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
    if (gridKeys.length === 1) masterGridKey = gridKeys[0];
  }

  if (!detailTabsKey) {
    const detailGridKeys = collectComponentKeysByType(components, 'DETAIL_GRID');
    // 占位 key，实际 tab key 会在 DETAIL_GRID 解析后确定
    if (detailGridKeys.length > 0) detailTabsKey = 'detailTabs';
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
    if (rules && rules.length > 0) result.push(...rules);
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
      // ignore invalid rulesConfig
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
    const normalizedTarget = String(targetColumn || '')
      .trim()
      .toUpperCase();
    if (normalizedTarget) {
      const byTarget = rawColumns.find(
        col =>
          String(col?.targetColumn || '')
            .trim()
            .toUpperCase() === normalizedTarget
      );
      if (byTarget?.columnName) return String(byTarget.columnName);
      const byColumn = rawColumns.find(
        col =>
          String(col?.columnName || '')
            .trim()
            .toUpperCase() === normalizedTarget
      );
      if (byColumn?.columnName) return String(byColumn.columnName);
      const byQuery = rawColumns.find(
        col =>
          String(col?.queryColumn || '')
            .trim()
            .toUpperCase() === normalizedTarget
      );
      if (byQuery?.columnName) return String(byQuery.columnName);
    }
    return fallback;
  }

  async function loadComponents() {
    const pageRes = await fetchPageComponents(pageCode);
    if (pageRes.error || !pageRes.data) {
      notifyError('????????');
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
      notifyError('????????');
      return false;
    }

    const resolvedMasterGridKey = masterGridKey.value ?? undefined;
    const resolvedDetailTabsKey = detailTabsKey.value ?? undefined;
    const config = parsePageComponents(components, {
      masterGridKey: resolvedMasterGridKey,
      detailTabsKey: resolvedDetailTabsKey
    });
    if (!config) {
      notifyError('????????');
      return false;
    }

    const rulesMap = rulesByComponent.value;

    // 从主表规则中读取 broadcast/summary 等全局配置覆盖
    const masterRuleKeysForGlobal = uniqueKeys([resolvedMasterGridKey, 'master', 'masterGrid']);
    const masterRulesForGlobal = collectRulesByKeys(rulesMap, masterRuleKeysForGlobal);
    const masterRuleLabelForGlobal = resolvedMasterGridKey || 'master';

    const summaryOverride = parseSummaryConfigRule(masterRuleLabelForGlobal, masterRulesForGlobal);
    if (summaryOverride !== null) {
      config.nestedConfig = mergeNestedConfig(config.nestedConfig, summaryOverride);
    }

    // 从表级别的全局规则仍然支持通过 detailTabs 统一下发
    const detailGridKeys = collectComponentKeysByType(components, 'DETAIL_GRID');
    let detailTabsRules: PageRule[] = [];
    const detailTabsRuleLabel = resolvedDetailTabsKey || 'detailTabs';

    if (resolvedDetailTabsKey) {
      detailTabsRules = getComponentRules(rulesMap, [resolvedDetailTabsKey]);
    } else if (detailGridKeys.length > 0) {
      // 尝试使用 detailTabs key 读取全局从表规则
      detailTabsRules = getComponentRules(rulesMap, ['detailTabs']);
    }

    const resolvedDetailType = layoutDetailTypeRef.value?.toLowerCase();
    detailLayoutMode.value = resolvedDetailType === 'split' ? 'split' : 'nested';
    detailSplitConfig.value = layoutSplitConfigRef.value || null;

    pageConfig.value = config;
    broadcastFields.value = [];

    const enterpriseOptions = normalizeGridOptions(enterpriseToGridOptions(config.enterpriseConfig));
    const masterRuleKeys = uniqueKeys([resolvedMasterGridKey, 'master', 'masterGrid']);
    const masterRules = collectRulesByKeys(rulesMap, masterRuleKeys);
    const masterRuleLabel = resolvedMasterGridKey || 'master';
    const masterGridRuleOptions = normalizeGridOptions(parseGridOptionsRule(masterRuleLabel, masterRules));
    const mergedMasterOptions = mergeGridOptions(enterpriseOptions, masterGridRuleOptions);
    // V3 强制主表使用 SSRM，不接受元数据中的其他 rowModelType
    if (mergedMasterOptions.rowModelType && mergedMasterOptions.rowModelType !== 'serverSide') {
      console.warn(`[V3] 主表 rowModelType 配置为 "${mergedMasterOptions.rowModelType}"，已强制覆盖为 "serverSide"`);
    }
    mergedMasterOptions.rowModelType = 'serverSide';
    // SSRM 默认分页块大小
    if (!mergedMasterOptions.cacheBlockSize) {
      mergedMasterOptions.cacheBlockSize = 100;
    }
    masterGridOptions.value = mergedMasterOptions;

    const detailBaseRuleOptions = normalizeGridOptions(parseGridOptionsRule(detailTabsRuleLabel, detailTabsRules));
    const detailBaseOptions = mergeGridOptions(
      inheritDetailGridOptions(masterGridOptions.value),
      detailBaseRuleOptions
    );

    detailGridOptionsByTab.value = {};
    for (const tab of config.tabs || []) {
      const tabRules = getComponentRules(rulesMap, [tab.key]);
      const tabGridRuleOptions = normalizeGridOptions(parseGridOptionsRule(tab.key, tabRules));
      const mergedTabOptions = mergeGridOptions(detailBaseOptions, tabGridRuleOptions);
      // V3 强制明细表使用 Client-Side，不接受元数据中的其他 rowModelType
      if (mergedTabOptions.rowModelType && mergedTabOptions.rowModelType !== 'clientSide') {
        console.warn(
          `[V3] 明细表 ${tab.key} rowModelType 配置为 "${mergedTabOptions.rowModelType}"，已强制覆盖为 "clientSide"`
        );
      }
      // 删除 rowModelType，保留 ag-grid 默认的 clientSide 模式
      delete mergedTabOptions.rowModelType;
      detailGridOptionsByTab.value[tab.key] = mergedTabOptions;
    }

    return true;
  }

  async function loadMeta() {
    if (!pageConfig.value) return false;

    const config = pageConfig.value;
    const resolvedMasterGridKey = masterGridKey.value ?? undefined;

    const masterMeta = await loadTableMeta(config.masterTableCode, pageCode, resolvedMasterGridKey ?? 'masterGrid');
    if (!masterMeta) {
      notifyError('?????????');
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
        applyGroupByColumns(
          filterColumnsByVariant(detailMeta.columns, tab.variantKey, detailMeta.rawColumns || []),
          tabGridOptions?.groupBy
        ),
        DIRTY_CELL_CLASS_RULES
      );
      detailRowClassGetterByTab.value[tab.key] = detailMeta.getRowClass;
      detailSumFieldsByTab.value[tab.key] = extractSumFieldsFromMetadata(detailMeta.rawColumns || []);

      const fkColumnName = detailMeta.metadata.parentFkColumn;
      detailFkColumnByTab.value[tab.key] = fkColumnName
        ? detailMeta.rawColumns.find(col => col.columnName.toUpperCase() === fkColumnName.toUpperCase())?.columnName ||
          fkColumnName
        : 'MASTER_ID';

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
    const config = pageConfig.value;
    if (!config) return false;

    const resolvedMasterGridKey = masterGridKey.value ?? undefined;
    const resolvedDetailTabsKey = detailTabsKey.value ?? undefined;
    const rulesMap = rulesByComponent.value;
    const masterRuleKeys = uniqueKeys([resolvedMasterGridKey, 'master', 'masterGrid']);
    const masterRules = collectRulesByKeys(rulesMap, masterRuleKeys);
    const masterRuleLabel = resolvedMasterGridKey || 'master';

    const masterValidation = parseValidationRuleConfig(masterRuleLabel, masterRules);
    masterValidationRules.value =
      masterValidation.length > 0 ? masterValidation : parseValidationRules(masterColumnMeta.value);

    const masterLookup = parseLookupRuleConfig(masterRuleLabel, masterRules);
    masterLookupRules.value = mergeLookupRules(extractLookupRules(masterColumnMeta.value), masterLookup);

    // 给有 lookup 的列添加高亮样式
    const lookupFields = new Set(masterLookupRules.value.map(r => r.columnName));
    if (lookupFields.size > 0) {
      masterColumnDefs.value = masterColumnDefs.value.map(col => {
        if (col.field && lookupFields.has(col.field)) {
          return { ...col, cellClass: 'lookup-field' };
        }
        return col;
      });
    }

    const masterCalcRules = parseCalcRuleConfig(masterRuleLabel, masterRules);
    if (masterCalcRules.length > 0) {
      compiledMasterCalcRules.value = compileCalcRules(masterCalcRules, `${pageCode}_master`);
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

    detailValidationRulesByTab.value = {};
    detailLookupRulesByTab.value = {};
    detailCalcRulesByTab.value = {};
    detailContextMenuByTab.value = {};

    // 获取主表组件配置，用于读取工具栏、右键菜单等规则
    const masterComponentConfig = getComponentConfig(pageComponents.value || [], resolvedMasterGridKey || 'masterGrid');
    masterContextMenu.value = parseContextMenuRule(masterRuleLabel, masterRules, masterComponentConfig);
    masterRowEditableRules.value = parseRowEditableRule(masterRuleLabel, masterRules);
    masterCellEditableRules.value = parseCellEditableRule(masterRuleLabel, masterRules);
    masterRowClassRules.value = parseGridStyleRule(masterRuleLabel, masterRules);
    // 应用主表单元格级样式规则
    masterColumnDefs.value = applyCellStyleRules(masterColumnDefs.value, masterRowClassRules.value);
    masterToolbar.value = parseToolbarRule(masterRuleLabel, masterRules, masterComponentConfig);
    detailContextMenuDefault.value = null;
    const detailGlobalRules = getComponentRules(rulesMap, ['detailTabs']);
    detailContextMenuDefault.value = parseContextMenuRule('detailTabs', detailGlobalRules);

    for (const tab of config.tabs || []) {
      const tabRules = getComponentRules(rulesMap, [tab.key]);
      const rawColumns = detailColumnMetaByTab.value[tab.key] || [];
      const detailValidation = parseValidationRuleConfig(tab.key, tabRules);
      detailValidationRulesByTab.value[tab.key] =
        detailValidation.length > 0 ? detailValidation : parseValidationRules(rawColumns);

      const detailLookup = parseLookupRuleConfig(tab.key, tabRules);
      detailLookupRulesByTab.value[tab.key] = mergeLookupRules(extractLookupRules(rawColumns), detailLookup);

      // 给有 lookup 的列添加高亮样式
      const detailLookupFields = new Set(detailLookupRulesByTab.value[tab.key].map(r => r.columnName));
      if (detailLookupFields.size > 0 && detailColumnsByTab.value[tab.key]) {
        detailColumnsByTab.value[tab.key] = detailColumnsByTab.value[tab.key].map(col => {
          if (col.field && detailLookupFields.has(col.field)) {
            return { ...col, cellClass: 'lookup-field' };
          }
          return col;
        });
      }

      const detailCalcRules = parseCalcRuleConfig(tab.key, tabRules);
      if (detailCalcRules.length > 0) {
        detailCalcRulesByTab.value[tab.key] = compileCalcRules(detailCalcRules, `${pageCode}_${tab.key}`);
      } else {
        detailCalcRulesByTab.value[tab.key] = [];
      }
      const detailGridConfig = getDetailGridComponentConfig(pageComponents.value || [], tab.key);
      detailContextMenuByTab.value[tab.key] =
        parseContextMenuRule(tab.key, tabRules, detailGridConfig) || detailContextMenuDefault.value;
      detailToolbarByTab.value[tab.key] = parseToolbarRule(tab.key, tabRules, detailGridConfig);
      detailRowClassRulesByTab.value[tab.key] = parseGridStyleRule(tab.key, tabRules);
      if (detailColumnsByTab.value[tab.key]) {
        detailColumnsByTab.value[tab.key] = applyCellStyleRules(
          detailColumnsByTab.value[tab.key],
          detailRowClassRulesByTab.value[tab.key] || []
        );
      }
      detailRowEditableRulesByTab.value[tab.key] = parseRowEditableRule(tab.key, tabRules);
      detailCellEditableRulesByTab.value[tab.key] = parseCellEditableRule(tab.key, tabRules);
    }
    return true;
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
