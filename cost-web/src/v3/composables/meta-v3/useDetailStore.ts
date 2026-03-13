import type { Ref, ShallowRef } from 'vue';
import type { GridApi } from 'ag-grid-community';
import { searchDynamicData } from '@/service/api';
import { debugLog } from '@/v3/composables/meta-v3/debug';
import { forEachDetailGridApi } from '@/v3/composables/meta-v3/detail-grid-apis';
import { applyCopiedRowFields } from '@/v3/composables/meta-v3/copy-row-fields';
import { isPersistedRow } from '@/v3/composables/meta-v3/row-persistence';
import { findRowByIdentity, isSameRowIdentity } from '@/v3/composables/meta-v3/row-identity';
import { type ParsedPageConfig, type RowData, generateTempId, initRowData } from '@/v3/logic/calc-engine';

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

  function forEachDetailGrid(masterRowKey: string, tabKey: string, callback: (api: any) => void) {
    forEachDetailGridApi({ masterGridApi, detailGridApisByTab, masterRowKey, tabKey, callback });
  }

  function setDetailRows(masterRowKey: string, tabKey: string, rows: RowData[]) {
    forEachDetailGrid(masterRowKey, tabKey, api => {
      api?.setGridOption?.('rowData', rows);
    });
  }

  function refreshDetailCells(masterRowKey: string, tabKey: string) {
    forEachDetailGrid(masterRowKey, tabKey, api => {
      api?.refreshCells?.({ force: true });
    });
  }

  function replaceDetailRows(masterRowKey: string, groupedRows: Record<string, RowData[]>) {
    for (const [tabKey, rows] of Object.entries(groupedRows)) {
      setDetailRows(masterRowKey, tabKey, rows);
    }
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

  function resolveDetailRows(masterId: number, tabKey: string, masterRowKey?: string) {
    const resolvedRowKey = masterRowKey ?? resolveMasterRowKey(masterId);
    if (!resolvedRowKey) return null;
    const cached = detailCache.get(resolvedRowKey);
    const rows = cached?.[tabKey];
    if (!rows) return null;
    return {
      masterRowKey: resolvedRowKey,
      rows
    };
  }

  function resolveCurrentDetailRow(rows: RowData[], row: RowData) {
    return findRowByIdentity(rows, row);
  }

  function appendDetailRow(detailRows: { masterRowKey: string; rows: RowData[] }, tabKey: string, row: RowData) {
    detailRows.rows.push(row);
    setDetailRows(detailRows.masterRowKey, tabKey, detailRows.rows);
  }

  function addDetailRow(masterId: number, tabKey: string, masterRowKey?: string) {
    const detailRows = resolveDetailRows(masterId, tabKey, masterRowKey);
    if (!detailRows) return null;
    const fkColumn = detailFkColumnByTab.value[tabKey] || 'masterId';
    const newRow = initRowData({ id: generateTempId(), [fkColumn]: masterId }, true);
    appendDetailRow(detailRows, tabKey, newRow);
    return newRow;
  }

  function deleteDetailRow(masterId: number, tabKey: string, row: RowData, masterRowKey?: string) {
    if (!row) return false;
    const detailRows = resolveDetailRows(masterId, tabKey, masterRowKey);
    if (!detailRows) return false;
    const currentRow = resolveCurrentDetailRow(detailRows.rows, row);

    if (!isPersistedRow(currentRow)) {
      const idx = detailRows.rows.findIndex(r => isSameRowIdentity(r, currentRow));
      if (idx >= 0) detailRows.rows.splice(idx, 1);
      setDetailRows(detailRows.masterRowKey, tabKey, detailRows.rows);
    } else {
      currentRow._isDeleted = true;
      refreshDetailCells(detailRows.masterRowKey, tabKey);
    }

    return true;
  }

  function copyDetailRow(masterId: number, tabKey: string, sourceRow: RowData, masterRowKey?: string) {
    if (!sourceRow) return null;
    const detailRows = resolveDetailRows(masterId, tabKey, masterRowKey);
    if (!detailRows) return null;
    const fkColumn = detailFkColumnByTab.value[tabKey] || 'masterId';
    const detailPkColumn = detailPkColumnByTab.value[tabKey];
    const newRow = initRowData({ id: generateTempId(), [fkColumn]: masterId }, true);

    applyCopiedRowFields({
      sourceRow,
      targetRow: newRow,
      excludeFields: [detailPkColumn, fkColumn],
      clearFields: [detailPkColumn]
    });

    appendDetailRow(detailRows, tabKey, newRow);
    return newRow;
  }

  function clearAllCache() {
    detailCache.clear();
  }

  return {
    detailCache,
    clearAllCache,
    loadDetailData,
    addDetailRow,
    deleteDetailRow,
    copyDetailRow
  };
}
