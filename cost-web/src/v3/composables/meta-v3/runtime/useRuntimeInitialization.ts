import type { Ref } from 'vue';
import { useRuntimeBootstrap } from './useRuntimeBootstrap';
import { useRuntimeComponentState } from './useRuntimeComponentState';
import { useRuntimeExtensions } from './useRuntimeExtensions';
import type { MetaError, RuntimeFeatures, RuntimeLogger, RuntimeStage } from './types';

type RuntimeInitializationOptions = {
  pageCode: string;
  logger: RuntimeLogger;
  meta: {
    pageComponents: Ref<any[]>;
    masterGridKey: Ref<string | null>;
    masterColumnDefs: Ref<any[]>;
    masterGridOptions?: Ref<any>;
    masterRowClassGetter?: Ref<any>;
    masterContextMenu?: Ref<any>;
    masterRowEditableRules?: Ref<any[]>;
    masterSumFields?: Ref<string[]>;
  };
  runtimeStatus: Ref<'loading' | 'ready' | 'error'>;
  runtimeError: Ref<MetaError | null>;
  isReady: Ref<boolean>;
  componentStateByKey: Ref<Record<string, any>>;
  componentErrors: Ref<Record<string, any>>;
  resolvedFeatures: Ref<Required<RuntimeFeatures>>;
  notifyError: (message: string) => void;
  getRuntime: () => any;
  reportComponentError: (componentKey: string, stage: RuntimeStage, message: string, raw?: unknown) => void;
  refreshAutoFeatures: () => void;
  makeError: (params: {
    pageCode: string;
    stage: RuntimeStage;
    message: string;
    componentKey?: string;
    code?: string;
    raw?: unknown;
  }) => MetaError;
  loadComponentsRaw: () => Promise<boolean>;
  parseConfigRaw: () => boolean;
  loadMetaRaw: () => Promise<boolean>;
  compileRulesRaw: () => boolean;
};

export function useRuntimeInitialization(options: RuntimeInitializationOptions) {
  const {
    pageCode,
    logger,
    meta,
    runtimeStatus,
    runtimeError,
    isReady,
    componentStateByKey,
    componentErrors,
    resolvedFeatures,
    notifyError,
    getRuntime,
    reportComponentError,
    refreshAutoFeatures,
    makeError,
    loadComponentsRaw,
    parseConfigRaw,
    loadMetaRaw,
    compileRulesRaw
  } = options;

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
    getRuntime
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

  return {
    buildStates,
    applyExtensions,
    init,
    loadComponents,
    parseConfig,
    loadMeta,
    compileRules
  };
}
