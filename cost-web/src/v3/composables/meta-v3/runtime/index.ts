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
import { useRuntimeLookup } from './useRuntimeLookup';
import { useRuntimeMetadataReload } from './useRuntimeMetadataReload';
import { useRuntimeActions } from './useRuntimeActions';
import { useRuntimeState } from './useRuntimeState';
import { useRuntimeMutations } from './useRuntimeMutations';
import { useRuntimeInitialization } from './useRuntimeInitialization';
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

  const dataApi = useMasterDetailData({
    pageCode,
    pageConfig: meta.pageConfig,
    detailFkColumnByTab: meta.detailFkColumnByTab,
    masterPkColumn: meta.masterPkColumn,
    detailPkColumnByTab: meta.detailPkColumnByTab,
    masterGridApi,
    detailGridApisByTab,
    notifyError
  });
  const { cache: cacheApi, query: queryApi, access: accessApi, loader: loaderApi, master: masterApi, detail: detailApi } = dataApi;

  const calc = useCalcBroadcast({
    masterGridApi,
    getMasterRowById: accessApi.getMasterRowById,
    getMasterRowByRowKey: accessApi.getMasterRowByRowKey,
    resolveMasterRowKey: accessApi.resolveMasterRowKey,
    detailCache: cacheApi.detailCache,
    detailCalcRulesByTab: meta.detailCalcRulesByTab,
    compiledAggRules: meta.compiledAggRules,
    compiledMasterCalcRules: meta.compiledMasterCalcRules,
    pageConfig: meta.pageConfig,
    loadDetailData: loaderApi.loadDetailData,
    detailGridApisByTab
  });

  const calcApi = {
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
    recalcAggregates: (masterId: number, masterRowKey?: string) => {
      if (!resolvedFeatures.value.aggregates) return;
      return calc.recalcAggregates(masterId, masterRowKey);
    },
    broadcastToDetail: async (masterId: number, row: any, changedFields?: string | string[]) => {
      if (!resolvedFeatures.value.broadcast) return;
      return calc.broadcastToDetail(masterId, row, changedFields);
    }
  };

  const { addMasterRow, addDetailRow, deleteDetailRow, copyDetailRow } = useRuntimeMutations({
    resolvedFeatures,
    detailGridApisByTab,
    addMasterRowRaw: masterApi.addMasterRow,
    addDetailRowRaw: detailApi.addDetailRow,
    deleteDetailRowRaw: detailApi.deleteDetailRow,
    copyDetailRowRaw: detailApi.copyDetailRow,
    runMasterCalc: calcApi.runMasterCalc,
    runDetailCalc: calcApi.runDetailCalc,
    recalcAggregates: calcApi.recalcAggregates
  });

  const runtimeLookup = useRuntimeLookup({
    resolvedFeatures,
    meta: {
      masterCellEditableRules: meta.masterCellEditableRules,
      masterRowEditableRules: meta.masterRowEditableRules,
      masterLookupRules: meta.masterLookupRules,
      detailLookupRulesByTab: meta.detailLookupRulesByTab
    },
    getMasterRowById: accessApi.getMasterRowById,
    getMasterRowByRowKey: accessApi.getMasterRowByRowKey,
    detailCache: cacheApi.detailCache,
    masterGridApi,
    markFieldChange: calcApi.markFieldChange,
    runMasterCalc: calcApi.runMasterCalc,
    runDetailCalc: calcApi.runDetailCalc,
    recalcAggregates: calcApi.recalcAggregates,
    broadcastToDetail: calcApi.broadcastToDetail,
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
    setAdvancedConditions: queryApi.setAdvancedConditions,
    clearAdvancedConditions: queryApi.clearAdvancedConditions,
    clearAllCache: cacheApi.clearAllCache,
    notifyInfo
  });

  const { save, isSaving } = useSave({
    pageCode,
    pageConfig: meta.pageConfig,
    detailCache: cacheApi.detailCache,
    getMasterRowById: accessApi.getMasterRowById,
    getMasterRowByRowKey: accessApi.getMasterRowByRowKey,
    resolveMasterRowKey: accessApi.resolveMasterRowKey,
    masterValidationRules: meta.masterValidationRules,
    detailValidationRulesByTab: meta.detailValidationRulesByTab,
    masterColumnMeta: meta.masterColumnMeta,
    detailColumnMetaByTab: meta.detailColumnMetaByTab,
    masterPkColumn: meta.masterPkColumn,
    detailPkColumnByTab: meta.detailPkColumnByTab,
    detailFkColumnByTab: meta.detailFkColumnByTab,
    loadDetailData: loaderApi.loadDetailData,
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
  const { executeAction, registerActionHandler } = useRuntimeActions({
    pageCode,
    notifyError,
    notifySuccess,
    getRuntime: () => runtimeApi,
    masterGridApi,
    activeMasterRowKey,
    pageConfig: meta.pageConfig,
    data: {
      detailCache: cacheApi.detailCache,
      getMasterRowByRowKey: accessApi.getMasterRowByRowKey,
      reloadMasterRow: loaderApi.reloadMasterRow,
      loadDetailData: loaderApi.loadDetailData,
      clearAllCache: cacheApi.clearAllCache
    }
  });

  runtimeApi = {
    masterGridApi,
    detailGridApisByTab,
    activeMasterRowKey,
    ...metaApi,
    componentStateByKey,
    detailCache: cacheApi.detailCache,
    createServerSideDataSource: queryApi.createServerSideDataSource,
    getMasterRowById: accessApi.getMasterRowById,
    loadDetailData: loaderApi.loadDetailData,
    addMasterRow,
    deleteMasterRow: masterApi.deleteMasterRow,
    addDetailRow,
    deleteDetailRow,
    copyMasterRow: masterApi.copyMasterRow,
    copyDetailRow,
    ...calcApi,
    ...runtimeLookup,
    customExportConfigs: customExport.customExportConfigs,
    executeCustomExport: customExport.executeCustomExport,
    advancedSearch,
    executeAction,
    save,
    isSaving,
    applyGridConfig: gridConfig.applyGridConfig,
    saveGridConfig: gridConfig.saveGridConfig
  };

  registerActionHandler('advancedSearch', () => advancedSearch.open());

  const { init, loadComponents, parseConfig, loadMeta, compileRules } = useRuntimeInitialization({
    pageCode,
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
    runtimeStatus,
    runtimeError,
    isReady,
    componentStateByKey,
    componentErrors,
    resolvedFeatures,
    notifyError,
    getRuntime: () => runtimeApi,
    reportComponentError,
    refreshAutoFeatures,
    makeError,
    loadComponentsRaw,
    parseConfigRaw,
    loadMetaRaw,
    compileRulesRaw
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
    detailCache: cacheApi.detailCache,
    resolveMasterRowKey: accessApi.resolveMasterRowKey,
    applyGridConfig: gridConfig.applyGridConfig,
    loadComponents: loadComponentsRaw,
    parseConfig: parseConfigRaw,
    loadMeta: loadMetaRaw,
    compileRules: compileRulesRaw,
    refreshAutoFeatures,
    runMasterCalc: calcApi.runMasterCalc,
    broadcastToDetail: calcApi.broadcastToDetail
  });

  return {
    isReady,
    pageError: runtimeError,
    features: resolvedFeatures,
    reportComponentError,
    init,
    reloadMetadata,
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
