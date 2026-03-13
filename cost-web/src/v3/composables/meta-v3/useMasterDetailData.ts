import type { Ref, ShallowRef } from 'vue';
import type { GridApi } from 'ag-grid-community';
import { useDetailStore } from '@/v3/composables/meta-v3/useDetailStore';
import { useMasterRowMutations } from '@/v3/composables/meta-v3/useMasterRowMutations';
import { useMasterQueryState } from '@/v3/composables/meta-v3/useMasterQueryState';
import { useMasterRowReload } from '@/v3/composables/meta-v3/useMasterRowReload';
import { useMasterRowAccess } from '@/v3/composables/meta-v3/useMasterRowAccess';
import { isPersistedRow } from '@/v3/composables/meta-v3/row-persistence';
import { resolveCurrentMasterRow } from '@/v3/composables/meta-v3/row-resolution';
import { type ParsedPageConfig } from '@/v3/logic/calc-engine';

export function useMasterDetailData(params: {
  pageCode: string;
  pageConfig: Ref<ParsedPageConfig | null>;
  detailFkColumnByTab: Ref<Record<string, string>>;
  masterPkColumn: Ref<string>;
  detailPkColumnByTab: Ref<Record<string, string>>;
  masterGridApi: ShallowRef<GridApi | null>;
  detailGridApisByTab?: Ref<Record<string, any>>;
  notifyError: (message: string) => void;
}) {
  const {
    pageCode,
    pageConfig,
    detailFkColumnByTab,
    masterPkColumn,
    detailPkColumnByTab,
    masterGridApi,
    detailGridApisByTab,
    notifyError
  } = params;

  const { getMasterRowByRowKey, getMasterRowById, resolveMasterRowKey } = useMasterRowAccess({
    masterGridApi
  });
  const detailStore = useDetailStore({
    pageCode,
    pageConfig,
    detailFkColumnByTab,
    detailPkColumnByTab,
    masterGridApi,
    detailGridApisByTab,
    resolveMasterRowKey,
    notifyError
  });
  const { cache: cacheApi, loader: detailLoaderApi, detail: detailApi } = detailStore;

  const { addMasterRow, deleteMasterRow, copyMasterRow } = useMasterRowMutations({
    masterGridApi,
    masterPkColumn,
    detailCache: cacheApi.detailCache,
    detailFkColumnByTab,
    detailPkColumnByTab,
    loadDetailData: detailLoaderApi.loadDetailData,
    resolveCurrentMasterRow: row => resolveCurrentMasterRow(row, { getMasterRowByRowKey, getMasterRowById }),
    isPersistedRow
  });

  const { advancedConditions, setAdvancedConditions, clearAdvancedConditions, createServerSideDataSource } =
    useMasterQueryState({
      pageCode,
      getTableCode: () => pageConfig.value?.masterTableCode,
      getMasterPkColumn: () => masterPkColumn.value,
      notifyError
    });

  const { reloadMasterRow } = useMasterRowReload({
    pageConfig,
    masterPkColumn,
    masterGridApi,
    notifyError,
    resolveMasterRowKey
  });

  return {
    cache: {
      ...cacheApi
    },
    query: {
      advancedConditions,
      setAdvancedConditions,
      clearAdvancedConditions,
      createServerSideDataSource
    },
    access: {
      getMasterRowByRowKey,
      getMasterRowById,
      resolveMasterRowKey
    },
    loader: {
      ...detailLoaderApi,
      reloadMasterRow
    },
    master: {
      addMasterRow,
      deleteMasterRow,
      copyMasterRow
    },
    detail: {
      ...detailApi
    }
  };
}
