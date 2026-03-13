import type { Ref, ShallowRef } from 'vue';
import type { GridApi } from 'ag-grid-community';
import { useMasterRowMutations } from '@/v3/composables/meta-v3/useMasterRowMutations';
import { useMasterQueryState } from '@/v3/composables/meta-v3/useMasterQueryState';
import { useMasterRowReload } from '@/v3/composables/meta-v3/useMasterRowReload';
import { isPersistedRow } from '@/v3/composables/meta-v3/row-persistence';
import { resolveCurrentMasterRow } from '@/v3/composables/meta-v3/row-resolution';
import { type ParsedPageConfig, type RowData } from '@/v3/logic/calc-engine';

export function useMasterStore(params: {
  pageCode: string;
  pageConfig: Ref<ParsedPageConfig | null>;
  detailFkColumnByTab: Ref<Record<string, string>>;
  masterPkColumn: Ref<string>;
  detailPkColumnByTab: Ref<Record<string, string>>;
  masterGridApi: ShallowRef<GridApi | null>;
  access: {
    getMasterRowByRowKey: (rowKey: string) => RowData | null;
    getMasterRowById: (id: number) => RowData | null;
    resolveMasterRowKey: (masterId: number) => string | null;
  };
  detailCache: Map<string, Record<string, RowData[]>>;
  loadDetailData: (masterId: number, masterRowKey?: string) => Promise<void>;
  notifyError: (message: string) => void;
}) {
  const {
    pageCode,
    pageConfig,
    detailFkColumnByTab,
    masterPkColumn,
    detailPkColumnByTab,
    masterGridApi,
    access,
    detailCache,
    loadDetailData,
    notifyError
  } = params;

  const master = useMasterRowMutations({
    masterGridApi,
    masterPkColumn,
    detailCache,
    detailFkColumnByTab,
    detailPkColumnByTab,
    loadDetailData,
    resolveCurrentMasterRow: row =>
      resolveCurrentMasterRow(row, {
        getMasterRowByRowKey: access.getMasterRowByRowKey,
        getMasterRowById: access.getMasterRowById
      }),
    isPersistedRow
  });

  const query = useMasterQueryState({
    pageCode,
    getTableCode: () => pageConfig.value?.masterTableCode,
    getMasterPkColumn: () => masterPkColumn.value,
    notifyError
  });

  const reload = useMasterRowReload({
    pageConfig,
    masterPkColumn,
    masterGridApi,
    notifyError,
    resolveMasterRowKey: access.resolveMasterRowKey
  });

  return {
    query,
    access,
    loader: {
      reloadMasterRow: reload.reloadMasterRow
    },
    master
  };
}
