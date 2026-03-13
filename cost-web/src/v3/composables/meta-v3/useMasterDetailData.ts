import type { Ref, ShallowRef } from 'vue';
import type { GridApi } from 'ag-grid-community';
import { useDetailGridSync } from '@/v3/composables/meta-v3/useDetailGridSync';
import { useDetailDataLoader } from '@/v3/composables/meta-v3/useDetailDataLoader';
import { useDetailRowMutations } from '@/v3/composables/meta-v3/useDetailRowMutations';
import { useMasterRowMutations } from '@/v3/composables/meta-v3/useMasterRowMutations';
import { useMasterQueryState } from '@/v3/composables/meta-v3/useMasterQueryState';
import { useMasterRowReload } from '@/v3/composables/meta-v3/useMasterRowReload';
import { useMasterRowAccess } from '@/v3/composables/meta-v3/useMasterRowAccess';
import { isPersistedRow } from '@/v3/composables/meta-v3/row-persistence';
import { resolveCurrentDetailRow, resolveCurrentMasterRow } from '@/v3/composables/meta-v3/row-resolution';
import { type ParsedPageConfig, type RowData } from '@/v3/logic/calc-engine';

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

  const detailCache = new Map<string, Record<string, RowData[]>>();
  const { setDetailRows, refreshDetailCells, replaceDetailRows } = useDetailGridSync({
    masterGridApi,
    detailGridApisByTab
  });
  const { getMasterRowByRowKey, getMasterRowById, resolveMasterRowKey } = useMasterRowAccess({
    masterGridApi
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

  /** 清空所有业务数据缓存 */
  function clearAllCache() {
    detailCache.clear();
  }

  const { addMasterRow, deleteMasterRow, copyMasterRow } = useMasterRowMutations({
    masterGridApi,
    masterPkColumn,
    detailCache,
    detailFkColumnByTab,
    detailPkColumnByTab,
    loadDetailData,
    resolveCurrentMasterRow: row => resolveCurrentMasterRow(row, { getMasterRowByRowKey, getMasterRowById }),
    isPersistedRow
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
    detailCache,
    clearAllCache,
    advancedConditions,
    setAdvancedConditions,
    clearAdvancedConditions,
    getMasterRowByRowKey,
    getMasterRowById,
    resolveMasterRowKey,
    loadDetailData,
    reloadMasterRow,
    addMasterRow,
    deleteMasterRow,
    addDetailRow,
    deleteDetailRow,
    copyMasterRow,
    copyDetailRow,
    createServerSideDataSource
  };
}
