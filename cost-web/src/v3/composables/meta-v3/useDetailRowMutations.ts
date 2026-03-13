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

  function addDetailRow(masterId: number, tabKey: string, masterRowKey?: string) {
    const resolvedRowKey = masterRowKey ?? resolveMasterRowKey(masterId);
    if (!resolvedRowKey) return null;
    const cached = detailCache.get(resolvedRowKey);
    if (!cached || !cached[tabKey]) return null;
    const fkColumn = detailFkColumnByTab.value[tabKey] || 'masterId';
    const newRow = initRowData({ id: generateTempId(), [fkColumn]: masterId }, true);
    cached[tabKey].push(newRow);
    setDetailRows(resolvedRowKey, tabKey, cached[tabKey]);
    return newRow;
  }

  function deleteDetailRow(masterId: number, tabKey: string, row: RowData, masterRowKey?: string) {
    if (!row) return false;
    const resolvedRowKey = masterRowKey ?? resolveMasterRowKey(masterId);
    if (!resolvedRowKey) return false;
    const cached = detailCache.get(resolvedRowKey);
    if (!cached || !cached[tabKey]) return false;
    const currentRow = resolveCurrentDetailRow(cached[tabKey], row);

    if (!isPersistedRow(currentRow)) {
      const idx = cached[tabKey].findIndex(r => r === currentRow || r._rowKey === currentRow._rowKey || r.id === currentRow.id);
      if (idx >= 0) cached[tabKey].splice(idx, 1);
      setDetailRows(resolvedRowKey, tabKey, cached[tabKey]);
    } else {
      currentRow._isDeleted = true;
      refreshDetailCells(resolvedRowKey, tabKey);
    }

    return true;
  }

  function copyDetailRow(masterId: number, tabKey: string, sourceRow: RowData, masterRowKey?: string) {
    if (!sourceRow) return null;
    const resolvedRowKey = masterRowKey ?? resolveMasterRowKey(masterId);
    if (!resolvedRowKey) return null;
    const cached = detailCache.get(resolvedRowKey);
    if (!cached || !cached[tabKey]) return null;
    const fkColumn = detailFkColumnByTab.value[tabKey] || 'masterId';
    const detailPkColumn = detailPkColumnByTab.value[tabKey];
    const detailCopyExcludedFields = buildCopyExcludedFields(detailPkColumn, fkColumn);
    const newRow = initRowData({ id: generateTempId(), [fkColumn]: masterId }, true);

    copyRowFields(sourceRow, newRow, detailCopyExcludedFields);
    clearCopiedIdentityFields(newRow, detailPkColumn);

    cached[tabKey].push(newRow);
    setDetailRows(resolvedRowKey, tabKey, cached[tabKey]);
    return newRow;
  }

  return {
    addDetailRow,
    deleteDetailRow,
    copyDetailRow
  };
}
