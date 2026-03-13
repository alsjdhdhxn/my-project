import type { Ref, ShallowRef } from 'vue';
import type { GridApi } from 'ag-grid-community';
import { useDetailGridSync } from '@/v3/composables/meta-v3/useDetailGridSync';
import { useDetailDataLoader } from '@/v3/composables/meta-v3/useDetailDataLoader';
import { useDetailRowMutations } from '@/v3/composables/meta-v3/useDetailRowMutations';
import { resolveCurrentDetailRow } from '@/v3/composables/meta-v3/row-resolution';
import { type ParsedPageConfig, type RowData } from '@/v3/logic/calc-engine';

export function useDetailStore(params: {
  pageCode: string;
  pageConfig: Ref<ParsedPageConfig | null>;
  detailFkColumnByTab: Ref<Record<string, string>>;
  detailPkColumnByTab: Ref<Record<string, string>>;
  masterGridApi: ShallowRef<GridApi | null>;
  detailGridApisByTab?: Ref<Record<string, any>>;
  resolveMasterRowKey: (masterId: number) => string | null;
  notifyError: (message: string) => void;
}) {
  const {
    pageCode,
    pageConfig,
    detailFkColumnByTab,
    detailPkColumnByTab,
    masterGridApi,
    detailGridApisByTab,
    resolveMasterRowKey,
    notifyError
  } = params;

  const detailCache = new Map<string, Record<string, RowData[]>>();
  const { setDetailRows, refreshDetailCells, replaceDetailRows } = useDetailGridSync({
    masterGridApi,
    detailGridApisByTab
  });

  const { loadDetailData } = useDetailDataLoader({
    pageCode,
    pageConfig,
    detailFkColumnByTab,
    detailPkColumnByTab,
    detailCache,
    replaceDetailRows,
    resolveMasterRowKey,
    notifyError
  });

  const { addDetailRow, deleteDetailRow, copyDetailRow } = useDetailRowMutations({
    detailCache,
    detailFkColumnByTab,
    detailPkColumnByTab,
    resolveMasterRowKey,
    resolveCurrentDetailRow,
    setDetailRows,
    refreshDetailCells
  });

  function clearAllCache() {
    detailCache.clear();
  }

  return {
    cache: {
      detailCache,
      clearAllCache
    },
    loader: {
      loadDetailData
    },
    detail: {
      addDetailRow,
      deleteDetailRow,
      copyDetailRow
    }
  };
}
