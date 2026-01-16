import { computed, ref, shallowRef, watch } from 'vue';
import type { GridApi } from 'ag-grid-community';
import { useMetaConfig } from '@/composables/meta-v2/useMetaConfig';
import { useMasterDetailData } from '@/composables/meta-v2/useMasterDetailData';
import { useCalcBroadcast } from '@/composables/meta-v2/useCalcBroadcast';
import { useLookupDialog } from '@/composables/meta-v2/useLookupDialog';
import { useSave } from '@/composables/meta-v2/useSave';
import { useUserGridConfig } from '@/composables/meta-v2/useUserGridConfig';
import { useExportExcel } from '@/composables/meta-v2/useExportExcel';
import { useMasterGridBindings } from '@/composables/meta-v2/useMasterGridBindings';
import { useAuthStore } from '@/store/modules/auth';
import { createRuntimeLogger } from './logger';
import type { ComponentState, GridState, MetaError, RuntimeFeatures, RuntimeStage } from './types';

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

function findFirstGridKey(components: any[]): string | null {
  const visit = (items: any[]): string | null => {
    for (const item of items) {
      if (item.componentType === 'GRID') return item.componentKey;
      if (Array.isArray(item.children)) {
        const found = visit(item.children);
        if (found) return found;
      }
    }
    return null;
  };
  return visit(components || []);
}

export function useBaseRuntime(options: BaseRuntimeOptions, features?: RuntimeFeatures) {
  const { pageCode, notifyInfo, notifyError, notifySuccess } = options;
  const resolvedFeatures = resolveFeatures(features);
  const logger = createRuntimeLogger(pageCode, notifyError);

  const isReady = ref(false);
  const componentStateByKey = ref<Record<string, ComponentState>>({});
  const componentErrors = ref<Record<string, MetaError>>({});

  const masterGridApi = shallowRef<GridApi | null>(null);
  const detailGridApisByTab = ref<Record<string, any>>({});

  const authStore = useAuthStore();
  const isAdmin = computed(() => authStore.userInfo.roles?.includes('ADMIN'));

  const meta = useMetaConfig(pageCode, notifyError);
  const {
    loadComponents: loadComponentsRaw,
    parseConfig: parseConfigRaw,
    loadMeta: loadMetaRaw,
    compileRules: compileRulesRaw,
    ...metaApi
  } = meta;
  const gridConfig = useUserGridConfig({ pageCode, notifyError, notifySuccess });

  const recalcAggregatesRef = { current: (_masterId: number) => {} };
  const recalcAggregatesProxy = (masterId: number) => {
    if (!resolvedFeatures.aggregates) return;
    recalcAggregatesRef.current(masterId);
  };

  const addRowHooks = {
    onMasterRowAdded: (_row: any) => {},
    onDetailRowAdded: (_masterId: number, _tabKey: string, _row: any) => {}
  };

  const data = useMasterDetailData({
    pageCode,
    pageConfig: meta.pageConfig,
    detailFkColumnByTab: meta.detailFkColumnByTab,
    masterGridApi,
    detailGridApisByTab,
    notifyError,
    recalcAggregates: recalcAggregatesProxy,
    afterAddMasterRow: row => addRowHooks.onMasterRowAdded(row),
    afterAddDetailRow: (masterId, tabKey, row) => addRowHooks.onDetailRowAdded(masterId, tabKey, row)
  });

  const calc = useCalcBroadcast({
    masterGridApi,
    masterRows: data.masterRows,
    detailCache: data.detailCache,
    broadcastFields: meta.broadcastFields,
    detailCalcRulesByTab: meta.detailCalcRulesByTab,
    compiledAggRules: meta.compiledAggRules,
    compiledMasterCalcRules: meta.compiledMasterCalcRules,
    pageConfig: meta.pageConfig,
    loadDetailData: data.loadDetailData,
    detailGridApisByTab
  });

  addRowHooks.onMasterRowAdded = (row) => {
    calc.runMasterCalc(null, row);
  };
  addRowHooks.onDetailRowAdded = (masterId, tabKey, row) => {
    if (!resolvedFeatures.detailTabs) return;
    const api = detailGridApisByTab.value?.[tabKey];
    calc.runDetailCalc(null, api, row, masterId, tabKey);
  };

  recalcAggregatesRef.current = calc.recalcAggregates;

  const lookup = resolvedFeatures.lookup ? useLookupDialog({
    masterRows: data.masterRows,
    detailCache: data.detailCache,
    masterGridApi,
    masterLookupRules: meta.masterLookupRules,
    detailLookupRulesByTab: meta.detailLookupRulesByTab,
    markFieldChange: calc.markFieldChange,
    runMasterCalc: calc.runMasterCalc,
    runDetailCalc: calc.runDetailCalc,
    recalcAggregates: recalcAggregatesProxy,
    detailGridApisByTab
  }) : {
    currentLookupRule: ref(null),
    lookupDialogRef: ref(null),
    onDetailCellClicked: () => {},
    onLookupSelect: () => {},
    onLookupCancel: () => {}
  };

  const { save } = useSave({
    pageCode,
    pageConfig: meta.pageConfig,
    masterRows: data.masterRows,
    detailCache: data.detailCache,
    masterValidationRules: meta.masterValidationRules,
    detailValidationRulesByTab: meta.detailValidationRulesByTab,
    masterColumnMeta: meta.masterColumnMeta,
    detailColumnMetaByTab: meta.detailColumnMetaByTab,
    detailFkColumnByTab: meta.detailFkColumnByTab,
    masterGridApi,
    notifyInfo,
    notifyError,
    notifySuccess
  });

  const exportExcel = resolvedFeatures.export ? useExportExcel({
    pageCode,
    masterGridApi,
    masterGridKey: meta.masterGridKey,
    pageConfig: meta.pageConfig,
    isAdmin,
    notifyInfo,
    notifyError,
    notifySuccess
  }) : {};

  const runtimeApi = {
    pageCode,
    masterGridApi,
    detailGridApisByTab,
    ...metaApi,
    componentStateByKey,
    ...data,
    markFieldChange: calc.markFieldChange,
    runMasterCalc: calc.runMasterCalc,
    runDetailCalc: resolvedFeatures.detailTabs ? calc.runDetailCalc : () => {},
    recalcAggregates: resolvedFeatures.aggregates ? calc.recalcAggregates : () => {},
    broadcastToDetail: resolvedFeatures.broadcast ? calc.broadcastToDetail : async () => {},
    ...lookup,
    ...exportExcel,
    save,
    applyGridConfig: gridConfig.applyGridConfig,
    saveGridConfig: gridConfig.saveGridConfig
  };

  const runtimeStatus = ref<'loading' | 'ready' | 'error'>('loading');
  const runtimeError = ref<MetaError | null>(null);

  function setComponentError(componentKey: string, stage: RuntimeStage, message: string, raw?: unknown) {
    const error = makeError({ pageCode, stage, message, componentKey, raw });
    componentErrors.value[componentKey] = error;
    logger.error(error);
  }

  async function loadComponents() {
    logger.log('loadComponents', 'start');
    const ok = await loadComponentsRaw();
    if (!ok) {
      const error = makeError({ pageCode, stage: 'loadComponents', message: 'Failed to load components' });
      runtimeError.value = error;
      runtimeStatus.value = 'error';
      logger.error(error);
      return false;
    }
    return true;
  }

  function parseConfig() {
    logger.log('parseConfig', 'start');
    const ok = parseConfigRaw();
    if (!ok) {
      const error = makeError({ pageCode, stage: 'parseConfig', message: 'Failed to parse page config' });
      runtimeError.value = error;
      runtimeStatus.value = 'error';
      logger.error(error);
      return false;
    }
    return true;
  }

  async function loadMeta() {
    logger.log('loadMeta', 'start');
    const ok = await loadMetaRaw();
    if (!ok) {
      const key = meta.masterGridKey.value || findFirstGridKey(meta.pageComponents.value) || 'masterGrid';
      setComponentError(key, 'loadMeta', 'Failed to load table metadata');
    }
    return ok;
  }

  function compileRules() {
    logger.log('compileRules', 'start');
    const ok = compileRulesRaw();
    if (!ok) {
      const key = meta.masterGridKey.value || findFirstGridKey(meta.pageComponents.value) || 'masterGrid';
      setComponentError(key, 'compileRules', 'Failed to compile rules');
    }
    return ok;
  }

  let watchersAttached = false;

  function buildStates() {
    logger.log('buildStates', 'start');
    const components = meta.pageComponents.value || [];
    const nextStates: Record<string, ComponentState> = {};

    for (const component of components) {
      nextStates[component.componentKey] = {
        componentKey: component.componentKey,
        componentType: component.componentType,
        status: 'ready',
        error: componentErrors.value[component.componentKey]
      };
      if (componentErrors.value[component.componentKey]) {
        nextStates[component.componentKey].status = 'error';
      }
    }

    const masterKey = meta.masterGridKey.value || findFirstGridKey(components);
    if (masterKey) {
      const gridError = componentErrors.value[masterKey];
      const gridState: GridState = {
        componentKey: masterKey,
        componentType: 'GRID',
        status: gridError ? 'error' : 'ready',
        error: gridError,
        rowData: data.masterRows.value || [],
        columnDefs: meta.masterColumnDefs.value || []
      };
      nextStates[masterKey] = gridState;
    }

    componentStateByKey.value = nextStates;

    if (!watchersAttached && masterKey) {
      watchersAttached = true;
      watch(data.masterRows, (rows) => {
        const state = componentStateByKey.value[masterKey] as GridState | undefined;
        if (state) state.rowData = rows || [];
      }, { deep: false });
      watch(meta.masterColumnDefs, (defs) => {
        const state = componentStateByKey.value[masterKey] as GridState | undefined;
        if (state) state.columnDefs = defs || [];
      }, { deep: false });
    }
  }

  function applyExtensions() {
    logger.log('applyExtensions', 'start');
    const components = meta.pageComponents.value || [];
    const masterKey = meta.masterGridKey.value || findFirstGridKey(components);
    if (!masterKey) return;
    const gridState = componentStateByKey.value[masterKey] as GridState | undefined;
    if (!gridState) return;

    const bindings = useMasterGridBindings({
      runtime: runtimeApi,
      metaRowClassGetter: meta.masterRowClassGetter?.value,
      gridOptions: meta.masterGridOptions?.value,
      columnDefs: meta.masterColumnDefs,
      gridKey: masterKey
    });

    gridState.defaultColDef = bindings.defaultColDef;
    gridState.rowSelection = bindings.rowSelection;
    gridState.autoSizeStrategy = bindings.autoSizeStrategy;
    gridState.getRowId = bindings.getRowId;
    gridState.getRowClass = bindings.getRowClass;
    gridState.getContextMenuItems = resolvedFeatures.contextMenu ? bindings.getContextMenuItems : undefined;
    gridState.gridOptions = bindings.gridOptions;
    gridState.rowHeight = bindings.rowHeight;
    gridState.headerHeight = bindings.headerHeight;
    gridState.onGridReady = bindings.onGridReady;
    gridState.onCellEditingStarted = bindings.onCellEditingStarted;
    gridState.onCellEditingStopped = bindings.onCellEditingStopped;
    gridState.onCellValueChanged = bindings.onCellValueChanged;
    gridState.onCellClicked = bindings.onCellClicked;
  }

  async function init() {
    const componentsOk = await loadComponents();
    if (!componentsOk) {
      isReady.value = true;
      return;
    }

    const configOk = parseConfig();
    if (!configOk) {
      isReady.value = true;
      return;
    }

    await loadMeta();
    compileRules();
    buildStates();
    applyExtensions();
    runtimeStatus.value = runtimeError.value ? 'error' : 'ready';
    isReady.value = true;
    await data.loadMasterData();
  }

  return {
    isReady,
    status: runtimeStatus,
    pageError: runtimeError,
    features: resolvedFeatures,
    init,
    loadComponents,
    parseConfig,
    loadMeta,
    compileRules,
    buildStates,
    applyExtensions,
    ...runtimeApi
  };
}

/** 单表页面 Runtime（禁用主从相关功能） */
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

/** 主从页面 Runtime（启用全部功能） */
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
