import type { Ref, ShallowRef } from 'vue';
import type { GridApi } from 'ag-grid-community';
import { searchDynamicData } from '@/service/api';
import { debugLog } from '@/v3/composables/meta-v3/debug';
import { useDetailGridSync } from '@/v3/composables/meta-v3/useDetailGridSync';
import { useDetailRowMutations } from '@/v3/composables/meta-v3/useDetailRowMutations';
import { useMasterRowMutations } from '@/v3/composables/meta-v3/useMasterRowMutations';
import { useMasterQueryState } from '@/v3/composables/meta-v3/useMasterQueryState';
import { useMasterRowReload } from '@/v3/composables/meta-v3/useMasterRowReload';
import { isPersistedRow } from '@/v3/composables/meta-v3/row-persistence';
import { type ParsedPageConfig, type RowData, ensureRowKey, initRowData } from '@/v3/logic/calc-engine';

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

  function getMasterRowByRowKey(rowKey: string): RowData | null {
    if (!rowKey) return null;
    const api = masterGridApi.value as any;
    const node = api?.getRowNode?.(String(rowKey));
    if (node?.data) return node.data as RowData;
    return null;
  }

  function getMasterRowById(id: number): RowData | null {
    if (id == null) return null;
    const api = masterGridApi.value as any;
    let found: RowData | null = null;
    api?.forEachNode?.((node: any) => {
      if (node?.data?.id === id) {
        found = node.data;
      }
    });
    if (found) return found;
    return null;
  }

  function resolveCurrentMasterRow(row: RowData) {
    const rowKey = row?._rowKey ? String(row._rowKey) : null;
    if (rowKey) {
      const currentRow = getMasterRowByRowKey(rowKey);
      if (currentRow) return currentRow;
    }
    if (isPersistedRow(row)) {
      const currentRow = getMasterRowById(Number(row.id));
      if (currentRow) return currentRow;
    }
    return row;
  }

  function resolveCurrentDetailRow(rows: RowData[], row: RowData) {
    const rowKey = row?._rowKey ? String(row._rowKey) : null;
    if (rowKey) {
      const currentRow = rows.find(r => r._rowKey === rowKey);
      if (currentRow) return currentRow;
    }
    if (row.id != null) {
      const currentRow = rows.find(r => r.id === row.id);
      if (currentRow) return currentRow;
    }
    return row;
  }

  function resolveMasterRowKey(masterId: number): string | null {
    const row = getMasterRowById(masterId);
    if (!row) return null;
    ensureRowKey(row);
    return row._rowKey || null;
  }

  async function loadDetailData(masterId: number, masterRowKey?: string) {
    const resolvedRowKey = masterRowKey ?? resolveMasterRowKey(masterId);
    if (!resolvedRowKey) {
      notifyError('无法定位主表行，明细加载失败');
      return;
    }
    const tabs = pageConfig.value?.tabs || [];
    const grouped: Record<string, RowData[]> = {};

    for (const tab of tabs) {
      const tableCode = tab.tableCode || pageConfig.value?.detailTableCode;
      const fkColumn = detailFkColumnByTab.value[tab.key] || 'masterId';
      if (!tableCode) continue;

      debugLog('detail request', {
        pageCode,
        masterId,
        tabKey: tab.key,
        tableCode,
        fkColumn
      });
      const { data, error } = await searchDynamicData(tableCode, {
        pageCode,
        conditions: [{ field: fkColumn, operator: 'eq', value: masterId }]
      });
      if (error) {
        console.error(`[load detail failed] ${tab.key}`, error);
        debugLog('detail error', { tabKey: tab.key, tableCode });
        grouped[tab.key] = [];
        continue;
      }
      grouped[tab.key] = (data?.list || []).map((row: any) =>
        initRowData(row, false, detailPkColumnByTab.value[tab.key])
      );
      debugLog('detail response', { tabKey: tab.key, count: grouped[tab.key].length });
    }

    detailCache.set(resolvedRowKey, grouped);
    replaceDetailRows(resolvedRowKey, grouped);
    debugLog('detail loaded', {
      masterId,
      rowKey: resolvedRowKey,
      tabs: Object.keys(grouped)
        .map(k => `${k}: ${grouped[k].length} rows`)
        .join(', ')
    });
  }

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
    resolveCurrentMasterRow,
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
