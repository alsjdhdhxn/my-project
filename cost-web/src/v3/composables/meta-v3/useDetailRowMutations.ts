import type { Ref } from 'vue';
import { type RowData, generateTempId, initRowData } from '@/v3/logic/calc-engine';
import { buildCopyExcludedFields, clearCopiedIdentityFields, copyRowFields } from '@/v3/composables/meta-v3/copy-row-fields';
import { isPersistedRow } from '@/v3/composables/meta-v3/row-persistence';

export function useDetailRowMutations(params: {
  detailCache: Map<string, Record<string, RowData[]>>;
  detailFkColumnByTab: Ref<Record<string, string>>;
  detailPkColumnByTab: Ref<Record<string, string>>;
  resolveMasterRowKey: (masterId: number) => string | null;
  resolveCurrentDetailRow: (rows: RowData[], row: RowData) => RowData;
  setDetailRows: (masterRowKey: string, tabKey: string, rows: RowData[]) => void;
  refreshDetailCells: (masterRowKey: string, tabKey: string) => void;
}) {
  const {
    detailCache,
    detailFkColumnByTab,
    detailPkColumnByTab,
    resolveMasterRowKey,
    resolveCurrentDetailRow,
    setDetailRows,
    refreshDetailCells
  } = params;

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
      const idx = detailRows.rows.findIndex(r => r === currentRow || r._rowKey === currentRow._rowKey || r.id === currentRow.id);
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
    const detailCopyExcludedFields = buildCopyExcludedFields(detailPkColumn, fkColumn);
    const newRow = initRowData({ id: generateTempId(), [fkColumn]: masterId }, true);

    copyRowFields(sourceRow, newRow, detailCopyExcludedFields);
    clearCopiedIdentityFields(newRow, detailPkColumn);

    appendDetailRow(detailRows, tabKey, newRow);
    return newRow;
  }

  return {
    addDetailRow,
    deleteDetailRow,
    copyDetailRow
  };
}
