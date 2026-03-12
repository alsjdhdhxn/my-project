import { watch, type Ref } from 'vue';
import { findFirstGridKey, flattenComponents } from './helpers';
import type { ComponentState, GridState, RuntimeLogger } from './types';

type RuntimeComponentMeta = {
  pageComponents: Ref<any[]>;
  masterGridKey: Ref<string | null>;
  masterColumnDefs: Ref<any[]>;
};

type RuntimeComponentStateOptions = {
  logger: RuntimeLogger;
  meta: RuntimeComponentMeta;
  componentStateByKey: Ref<Record<string, ComponentState>>;
  componentErrors: Ref<Record<string, any>>;
};

export function useRuntimeComponentState(options: RuntimeComponentStateOptions) {
  const { logger, meta, componentStateByKey, componentErrors } = options;

  let watchersAttached = false;

  function buildStates() {
    logger.log('buildStates', 'start');
    const components = meta.pageComponents.value || [];
    const flatComponents = flattenComponents(components);
    const nextStates: Record<string, ComponentState> = {};

    for (const component of flatComponents) {
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
        rowData: [],
        columnDefs: meta.masterColumnDefs.value || []
      };
      nextStates[masterKey] = gridState;
    }

    componentStateByKey.value = nextStates;

    if (!watchersAttached && masterKey) {
      watchersAttached = true;
      watch(
        meta.masterColumnDefs,
        defs => {
          const state = componentStateByKey.value[masterKey] as GridState | undefined;
          if (state) state.columnDefs = defs || [];
        },
        { deep: false }
      );
    }
  }

  return {
    buildStates
  };
}
