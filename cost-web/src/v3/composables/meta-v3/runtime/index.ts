import { ref, shallowRef } from 'vue';
import type { GridApi } from 'ag-grid-community';
import { useMetaConfig } from '@/v3/composables/meta-v3/useMetaConfig';
import { useMasterDetailData } from '@/v3/composables/meta-v3/useMasterDetailData';
import { useCalcBroadcast } from '@/v3/composables/meta-v3/useCalcBroadcast';
import { useAdvancedSearch } from '@/v3/composables/meta-v3/useAdvancedSearch';
import { useSave } from '@/v3/composables/meta-v3/useSave';
import { useUserGridConfig } from '@/v3/composables/meta-v3/useUserGridConfig';
import { useCustomExport } from '@/v3/composables/meta-v3/useCustomExport';
import { createRuntimeLogger } from './logger';
import { useRuntimeBootstrap } from './useRuntimeBootstrap';
import { useRuntimeComponentState } from './useRuntimeComponentState';
import { useRuntimeExtensions } from './useRuntimeExtensions';
import { useRuntimeLookup } from './useRuntimeLookup';
import { useRuntimeMetadataReload } from './useRuntimeMetadataReload';
import { useRuntimeActions } from './useRuntimeActions';
import { useRuntimeState } from './useRuntimeState';
import type { MetaError, RuntimeFeatures, RuntimeStage } from './types';

type NotifyFn = (message: string) => void;

export type BaseRuntimeOptions = {
  pageCode: string;
  notifyInfo: NotifyFn;
  notifyError: NotifyFn;
  notifySuccess: NotifyFn;
};

const DEFAULT_FEATURES: Required<RuntimeFeatures> = {
  detailTabs: true,
  broadcast: true,
  aggregates: true,
  lookup: true,
  export: true,
  contextMenu: true
};

function resolveFeatures(features?: RuntimeFeatures): Required<RuntimeFeatures> {
  return { ...DEFAULT_FEATURES, ...(features || {}) };
}

function makeError(params: {
  pageCode: string;
  stage: RuntimeStage;
  message: string;
  componentKey?: string;
  code?: string;
  raw?: unknown;
}): MetaError {
  return {
    code: params.code || 'META_RUNTIME_ERROR',
    message: params.message,
    stage: params.stage,
    pageCode: params.pageCode,
    componentKey: params.componentKey,
    raw: params.raw
  };
}

export function useBaseRuntime(options: BaseRuntimeOptions, features?: RuntimeFeatures) {
  const { pageCode, notifyInfo, notifyError, notifySuccess } = options;
  const autoFeatureEnabled = !features;
  const resolvedFeatures = ref<Required<RuntimeFeatures>>(resolveFeatures(features));
  const logger = createRuntimeLogger(pageCode, notifyError);

  const masterGridApi = shallowRef<GridApi | null>(null);
  const detailGridApisByTab = ref<Record<string, any>>({});
  const activeMasterRowKey = ref<string | null>(null);

  const meta = useMetaConfig(pageCode, notifyError);
  const {
    loadComponents: loadComponentsRaw,
    parseConfig: parseConfigRaw,
    loadMeta: loadMetaRaw,
    compileRules: compileRulesRaw,
    ...metaApi
  } = meta;
  const gridConfig = useUserGridConfig({ pageCode, notifyError, notifySuccess });
  const isReady = ref(false);
  const {
    runtimeStatus,
    runtimeError,
    componentStateByKey,
    componentErrors,
    reportComponentError,
    refreshAutoFeatures
  } = useRuntimeState({
    pageCode,
    logger,
    autoFeatureEnabled,
    resolvedFeatures,
    meta: {
      pageConfig: meta.pageConfig,
      detailCalcRulesByTab: meta.detailCalcRulesByTab,
      compiledAggRules: meta.compiledAggRules,
      compiledMasterCalcRules: meta.compiledMasterCalcRules,
      masterLookupRules: meta.masterLookupRules,
      detailLookupRulesByTab: meta.detailLookupRulesByTab,
      masterGridKey: meta.masterGridKey,
      pageComponents: meta.pageComponents
    },
    makeError
  });

  const recalcAggregatesRef = { current: (_masterId: number, _masterRowKey?: string) => {} };
  const recalcAggregatesProxy = (masterId: number, masterRowKey?: string) => {
    if (!resolvedFeatures.value.aggregates) return;
    recalcAggregatesRef.current(masterId, masterRowKey);
  };

  const data = useMasterDetailData({
    pageCode,
    pageConfig: meta.pageConfig,
    detailFkColumnByTab: meta.detailFkColumnByTab,
    masterPkColumn: meta.masterPkColumn,
    detailPkColumnByTab: meta.detailPkColumnByTab,
    masterGridApi,
    detailGridApisByTab,
    notifyError,
    recalcAggregates: recalcAggregatesProxy
  });

  const calc = useCalcBroadcast({
    masterGridApi,
    getMasterRowById: data.getMasterRowById,
    getMasterRowByRowKey: data.getMasterRowByRowKey,
    resolveMasterRowKey: data.resolveMasterRowKey,
    detailCache: data.detailCache,
    detailCalcRulesByTab: meta.detailCalcRulesByTab,
    compiledAggRules: meta.compiledAggRules,
    compiledMasterCalcRules: meta.compiledMasterCalcRules,
    pageConfig: meta.pageConfig,
    loadDetailData: data.loadDetailData,
    detailGridApisByTab
  });

  recalcAggregatesRef.current = calc.recalcAggregates;

  function addMasterRow() {
    const newRow = data.addMasterRow();
    if (newRow) {
      calc.runMasterCalc(null, newRow);
    }
    return newRow;
  }

  function addDetailRow(masterId: number, tabKey: string, masterRowKey?: string) {
    const newRow = data.addDetailRow(masterId, tabKey, masterRowKey);
    if (!newRow || !resolvedFeatures.value.detailTabs) return newRow;
    const api = detailGridApisByTab.value?.[tabKey];
    calc.runDetailCalc(null, api, newRow, masterId, tabKey, masterRowKey);
    return newRow;
  }

  const runtimeLookup = useRuntimeLookup({
    resolvedFeatures,
    meta: {
      masterCellEditableRules: meta.masterCellEditableRules,
      masterRowEditableRules: meta.masterRowEditableRules,
      masterLookupRules: meta.masterLookupRules,
      detailLookupRulesByTab: meta.detailLookupRulesByTab
    },
    getMasterRowById: data.getMasterRowById,
    getMasterRowByRowKey: data.getMasterRowByRowKey,
    detailCache: data.detailCache,
    masterGridApi,
    markFieldChange: calc.markFieldChange,
    runMasterCalc: calc.runMasterCalc,
    runDetailCalc: calc.runDetailCalc,
    recalcAggregates: recalcAggregatesProxy,
    broadcastToDetail: calc.broadcastToDetail,
    detailGridApisByTab
  });

  const advancedSearch = useAdvancedSearch({
    pageCode,
    pageConfig: meta.pageConfig,
    masterGridKey: meta.masterGridKey,
    masterColumnMeta: meta.masterColumnMeta,
    detailColumnMetaByTab: meta.detailColumnMetaByTab,
    masterColumnDefs: meta.masterColumnDefs,
    detailColumnDefsByTab: meta.detailColumnsByTab,
    masterLookupRules: meta.masterLookupRules,
    detailLookupRulesByTab: meta.detailLookupRulesByTab,
    masterGridApi,
    setAdvancedConditions: data.setAdvancedConditions,
    clearAdvancedConditions: data.clearAdvancedConditions,
    clearAllCache: data.clearAllCache,
    notifyInfo
  });

  const { save, isSaving } = useSave({
    pageCode,
    pageConfig: meta.pageConfig,
    detailCache: data.detailCache,
    getMasterRowById: data.getMasterRowById,
    getMasterRowByRowKey: data.getMasterRowByRowKey,
    resolveMasterRowKey: data.resolveMasterRowKey,
    masterValidationRules: meta.masterValidationRules,
    detailValidationRulesByTab: meta.detailValidationRulesByTab,
    masterColumnMeta: meta.masterColumnMeta,
    detailColumnMetaByTab: meta.detailColumnMetaByTab,
    masterPkColumn: meta.masterPkColumn,
    detailPkColumnByTab: meta.detailPkColumnByTab,
    detailFkColumnByTab: meta.detailFkColumnByTab,
    loadDetailData: data.loadDetailData,
    masterGridApi,
    detailGridApisByTab,
    activeMasterRowKey,
    notifyInfo,
    notifyError,
    notifySuccess
  });

  const customExport = useCustomExport({
    pageCode,
    masterGridApi,
    notifyInfo,
    notifyError,
    notifySuccess
  });

  let runtimeApi: any;
  const { executeAction, registerActionHandler, resolveActionHandler } = useRuntimeActions({
    pageCode,
    notifyError,
    notifySuccess,
    getRuntime: () => runtimeApi,
    masterGridApi,
    activeMasterRowKey,
    pageConfig: meta.pageConfig,
    data
  });

  runtimeApi = {
    pageCode,
    masterGridApi,
    detailGridApisByTab,
    activeMasterRowKey,
    ...metaApi,
    componentStateByKey,
    ...data,
    addMasterRow,
    addDetailRow,
    markFieldChange: calc.markFieldChange,
    runMasterCalc: calc.runMasterCalc,
    runDetailCalc: (
      node: any,
      api: any,
      row: any,
      masterId: number,
      tabKey: string,
      masterRowKey?: string,
      changedFields?: string | string[],
      valueOverrides?: Record<string, any>
    ) => {
      if (!resolvedFeatures.value.detailTabs) return;
      return calc.runDetailCalc(node, api, row, masterId, tabKey, masterRowKey, changedFields, valueOverrides);
    },
    recalcAggregates: (masterId: number) => {
      if (!resolvedFeatures.value.aggregates) return;
      return calc.recalcAggregates(masterId);
    },
    broadcastToDetail: async (masterId: number, row: any, changedFields?: string | string[]) => {
      if (!resolvedFeatures.value.broadcast) return;
      return calc.broadcastToDetail(masterId, row, changedFields);
    },
    ...runtimeLookup,
    customExportConfigs: customExport.customExportConfigs,
    executeCustomExport: customExport.executeCustomExport,
    advancedSearch,
    executeAction,
    registerActionHandler,
    resolveActionHandler,
    save,
    isSaving,
    applyGridConfig: gridConfig.applyGridConfig,
    saveGridConfig: gridConfig.saveGridConfig
  };

  registerActionHandler('advancedSearch', () => advancedSearch.open());

  const { buildStates } = useRuntimeComponentState({
    logger,
    meta: {
      pageComponents: meta.pageComponents,
      masterGridKey: meta.masterGridKey,
      masterColumnDefs: meta.masterColumnDefs
    },
    componentStateByKey,
    componentErrors
  });
  const { applyExtensions } = useRuntimeExtensions({
    logger,
    meta: {
      pageComponents: meta.pageComponents,
      masterGridKey: meta.masterGridKey,
      masterColumnDefs: meta.masterColumnDefs,
      masterGridOptions: meta.masterGridOptions,
      masterRowClassGetter: meta.masterRowClassGetter,
      masterContextMenu: meta.masterContextMenu,
      masterRowEditableRules: meta.masterRowEditableRules,
      masterSumFields: meta.masterSumFields
    },
    componentStateByKey,
    resolvedFeatures,
    notifyError,
    getRuntime: () => runtimeApi
  });
  const { init, loadComponents, parseConfig, loadMeta, compileRules } = useRuntimeBootstrap({
    pageCode,
    logger,
    meta: {
      pageComponents: meta.pageComponents,
      masterGridKey: meta.masterGridKey
    },
    runtimeStatus,
    runtimeError,
    isReady,
    reportComponentError,
    refreshAutoFeatures,
    makeError,
    loadComponentsRaw,
    parseConfigRaw,
    loadMetaRaw,
    compileRulesRaw,
    buildStates,
    applyExtensions
  });

  const { reloadMetadata } = useRuntimeMetadataReload({
    pageCode,
    resolvedFeatures,
    meta: {
      pageComponents: meta.pageComponents,
      masterGridKey: meta.masterGridKey,
      masterColumnDefs: meta.masterColumnDefs,
      detailColumnsByTab: meta.detailColumnsByTab
    },
    componentStateByKey,
    masterGridApi,
    detailGridApisByTab,
    detailCache: data.detailCache,
    resolveMasterRowKey: data.resolveMasterRowKey,
    applyGridConfig: gridConfig.applyGridConfig,
    loadComponents: loadComponentsRaw,
    parseConfig: parseConfigRaw,
    loadMeta: loadMetaRaw,
    compileRules: compileRulesRaw,
    refreshAutoFeatures,
    runMasterCalc: calc.runMasterCalc,
    broadcastToDetail: calc.broadcastToDetail
  });

  return {
    isReady,
    status: runtimeStatus,
    pageError: runtimeError,
    features: resolvedFeatures,
    reportComponentError,
    init,
    reloadMetadata,
    loadComponents,
    parseConfig,
    loadMeta,
    compileRules,
    buildStates,
    applyExtensions,
    ...runtimeApi
  };
}

/** Single-grid runtime (master-detail features disabled) */
export function useSingleGridRuntime(options: BaseRuntimeOptions) {
  return {
    ...useBaseRuntime(options, {
      detailTabs: false,
      broadcast: false,
      aggregates: false,
      lookup: true,
      export: true,
      contextMenu: true
    }),
    mode: 'single' as const
  };
}

/** Master-detail runtime (all features enabled) */
export function useMasterDetailRuntime(options: BaseRuntimeOptions) {
  return {
    ...useBaseRuntime(options, {
      detailTabs: true,
      broadcast: true,
      aggregates: true,
      lookup: true,
      export: true,
      contextMenu: true
    }),
    mode: 'masterDetail' as const
  };
}
