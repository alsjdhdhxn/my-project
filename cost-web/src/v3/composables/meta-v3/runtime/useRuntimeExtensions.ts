import type { Ref } from 'vue';
import { useMasterGridBindings } from '@/v3/composables/meta-v3/useMasterGridBindings';
import { resolveFormRenderer } from '@/v3/composables/meta-v3/form-renderer-registry';
import { findFirstGridKey, flattenComponents } from './helpers';
import type {
  ComponentState,
  FormState,
  GridState,
  RuntimeFeatures,
  RuntimeLogger
} from './types';

type RuntimeExtensionsMeta = {
  pageComponents: Ref<any[]>;
  masterGridKey: Ref<string | null>;
  masterColumnDefs: Ref<any[]>;
  masterGridOptions?: Ref<any>;
  masterRowClassGetter?: Ref<any>;
  masterContextMenu?: Ref<any>;
  masterRowEditableRules?: Ref<any[]>;
  masterSumFields?: Ref<string[]>;
};

type RuntimeExtensionsOptions = {
  logger: RuntimeLogger;
  meta: RuntimeExtensionsMeta;
  componentStateByKey: Ref<Record<string, ComponentState>>;
  resolvedFeatures: Ref<Required<RuntimeFeatures>>;
  notifyError: (message: string) => void;
  getRuntime: () => any;
};

function parseFormComponentConfig(component: any) {
  try {
    return component.componentConfig ? JSON.parse(component.componentConfig) : {};
  } catch (error) {
    console.warn('[MetaV3] form config parse failed', error);
    return {};
  }
}

export function useRuntimeExtensions(options: RuntimeExtensionsOptions) {
  const { logger, meta, componentStateByKey, resolvedFeatures, notifyError, getRuntime } = options;

  function applyExtensions() {
    logger.log('applyExtensions', 'start');
    const components = meta.pageComponents.value || [];
    const flatComponents = flattenComponents(components);
    const masterKey = meta.masterGridKey.value || findFirstGridKey(components);
    const gridState = masterKey ? (componentStateByKey.value[masterKey] as GridState | undefined) : undefined;

    const masterGridOptions = meta.masterGridOptions?.value;
    const dataSource = getRuntime()?.createServerSideDataSource?.({
      pageSize: masterGridOptions?.cacheBlockSize || 100
    });

    if (masterKey && gridState) {
      const bindings = useMasterGridBindings({
        runtime: getRuntime(),
        metaRowClassGetter: meta.masterRowClassGetter?.value,
        gridOptions: masterGridOptions,
        columnDefs: meta.masterColumnDefs,
        gridKey: masterKey,
        contextMenuConfig: meta.masterContextMenu?.value,
        rowEditableRules: meta.masterRowEditableRules?.value,
        dataSource,
        sumFields: meta.masterSumFields?.value,
        notifyError
      });

      gridState.defaultColDef = bindings.defaultColDef;
      gridState.rowSelection = bindings.rowSelection;
      gridState.autoSizeStrategy = bindings.autoSizeStrategy;
      gridState.getRowId = bindings.getRowId;
      gridState.getRowClass = bindings.getRowClass;
      gridState.getRowStyle = bindings.getRowStyle;
      gridState.getContextMenuItems = resolvedFeatures.value.contextMenu ? bindings.getContextMenuItems : undefined;
      gridState.gridOptions = bindings.gridOptions;
      gridState.dataSource = dataSource;
      gridState.rowHeight = bindings.rowHeight;
      gridState.headerHeight = bindings.headerHeight;
      gridState.onGridReady = bindings.onGridReady;
      gridState.onCellEditingStarted = bindings.onCellEditingStarted;
      gridState.onCellEditingStopped = bindings.onCellEditingStopped;
      gridState.onCellValueChanged = bindings.onCellValueChanged;
      gridState.onCellClicked = bindings.onCellClicked;
      gridState.onFilterChanged = bindings.onFilterChanged;
    }

    for (const component of flatComponents) {
      if (component.componentType !== 'FORM') continue;
      const state = componentStateByKey.value[component.componentKey] as FormState | undefined;
      if (!state) continue;
      const config = parseFormComponentConfig(component) as {
        rendererKey?: string;
        variantKey?: string;
        placeholder?: string;
      };
      const rendererKey = config.rendererKey || config.variantKey;
      if (rendererKey) {
        state.renderer = resolveFormRenderer(rendererKey) || state.renderer;
      }
      if (config.placeholder) state.placeholder = config.placeholder;
    }
  }

  return {
    applyExtensions
  };
}
