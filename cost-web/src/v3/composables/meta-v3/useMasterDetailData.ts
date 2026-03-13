import type { Ref, ShallowRef } from 'vue';
import type { GridApi } from 'ag-grid-community';
import { useDetailStore } from '@/v3/composables/meta-v3/useDetailStore';
import { useMasterStore } from '@/v3/composables/meta-v3/useMasterStore';
import { useMasterRowAccess } from '@/v3/composables/meta-v3/useMasterRowAccess';
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

  const access = useMasterRowAccess({
    masterGridApi
  });

  const detailStore = useDetailStore({
    pageCode,
    pageConfig,
    detailFkColumnByTab,
    detailPkColumnByTab,
    masterGridApi,
    detailGridApisByTab,
    resolveMasterRowKey: access.resolveMasterRowKey,
    notifyError
  });
  const { cache: cacheApi, loader: detailLoaderApi, detail: detailApi } = detailStore;

  const masterStore = useMasterStore({
    pageCode,
    pageConfig,
    detailFkColumnByTab,
    masterPkColumn,
    detailPkColumnByTab,
    masterGridApi,
    access,
    detailCache: cacheApi.detailCache,
    loadDetailData: detailLoaderApi.loadDetailData,
    notifyError
  });

  return {
    cache: cacheApi,
    query: masterStore.query,
    access: masterStore.access,
    loader: {
      ...detailLoaderApi,
      ...masterStore.loader
    },
    master: masterStore.master,
    detail: detailApi
  };
}
