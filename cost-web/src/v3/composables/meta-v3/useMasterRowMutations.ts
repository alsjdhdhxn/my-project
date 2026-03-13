import type { Ref, ShallowRef } from 'vue';
import type { GridApi } from 'ag-grid-community';
import { buildCopyExcludedFields, clearCopiedIdentityFields } from '@/v3/composables/meta-v3/copy-row-fields';
import { type RowData, ensureRowKey, generateTempId, initRowData } from '@/v3/logic/calc-engine';

export function useMasterRowMutations(params: {
  masterGridApi: ShallowRef<GridApi | null>;
  masterPkColumn: Ref<string>;
  detailCache: Map<string, Record<string, RowData[]>>;
  detailFkColumnByTab: Ref<Record<string, string>>;
  detailPkColumnByTab: Ref<Record<string, string>>;
  loadDetailData: (masterId: number, masterRowKey?: string) => Promise<void>;
  resolveCurrentMasterRow: (row: RowData) => RowData;
  isPersistedRow: (row: RowData | null | undefined) => boolean;
}) {
  const {
    masterGridApi,
    masterPkColumn,
    detailCache,
    detailFkColumnByTab,
    detailPkColumnByTab,
    loadDetailData,
    resolveCurrentMasterRow,
    isPersistedRow
  } = params;

  function focusInsertedMasterRow(insertIndex: number, rowKey: string) {
    const api = masterGridApi.value;
    setTimeout(() => {
      api?.ensureIndexVisible(insertIndex, 'middle');
      const newNode = api?.getRowNode(String(rowKey));
      if (newNode) {
        newNode.setSelected(true, true);
      }
    }, 100);
  }

  function addMasterRow() {
    const api = masterGridApi.value;
    const newRow = initRowData({ id: generateTempId() }, true);
    ensureRowKey(newRow);

    const selectedNodes = api?.getSelectedNodes() || [];
    const insertIndex =
      selectedNodes.length > 0 && selectedNodes[0].rowIndex != null ? selectedNodes[0].rowIndex + 1 : 0;

    if (api) {
      api.applyServerSideTransaction({
        route: [],
        add: [newRow],
        addIndex: insertIndex
      });
    }

    focusInsertedMasterRow(insertIndex, String(newRow._rowKey));

    return newRow;
  }

  function deleteMasterRow(row: RowData) {
    if (!row) return;
    const api = masterGridApi.value;
    const currentRow = resolveCurrentMasterRow(row);

    if (!isPersistedRow(currentRow)) {
      if (api) {
        api.applyServerSideTransaction({
          route: [],
          remove: [currentRow]
        });
      }
    } else {
      currentRow._isDeleted = true;
      const node = api?.getRowNode(String(ensureRowKey(currentRow)));
      if (node) api?.refreshCells({ rowNodes: [node] });
    }
  }

  async function copyMasterRow(sourceRow: RowData) {
    if (!sourceRow) return;
    const api = masterGridApi.value;
    const sourceMasterId = sourceRow.id;
    ensureRowKey(sourceRow);
    const sourceRowKey = sourceRow._rowKey as string;
    const newMasterId = generateTempId();
    const newRow = initRowData({ id: newMasterId }, true);
    const masterCopyExcludedFields = buildCopyExcludedFields(masterPkColumn.value);
    ensureRowKey(newRow);

    for (const [key, value] of Object.entries(sourceRow)) {
      if (!key.startsWith('_') && !masterCopyExcludedFields.has(key)) newRow[key] = value;
    }
    clearCopiedIdentityFields(newRow, masterPkColumn.value);

    const sourceNode = api?.getRowNode(String(sourceRowKey));
    const insertIndex = sourceNode?.rowIndex != null ? sourceNode.rowIndex + 1 : 0;

    if (api) {
      api.applyServerSideTransaction({
        route: [],
        add: [newRow],
        addIndex: insertIndex
      });
    }

    if (sourceMasterId != null && sourceRowKey) {
      let sourceCached = detailCache.get(sourceRowKey);
      if (!sourceCached) {
        await loadDetailData(sourceMasterId, sourceRowKey);
        sourceCached = detailCache.get(sourceRowKey);
      }

      if (sourceCached) {
        const newCached: Record<string, RowData[]> = {};
        for (const [tabKey, rows] of Object.entries(sourceCached)) {
          const fkColumn = detailFkColumnByTab.value[tabKey] || 'masterId';
          const detailPkColumn = detailPkColumnByTab.value[tabKey];
          const detailCopyExcludedFields = buildCopyExcludedFields(detailPkColumn, fkColumn);
          newCached[tabKey] = rows
            .filter(r => !r._isDeleted)
            .map(r => {
              const newDetailRow = initRowData({ id: generateTempId(), [fkColumn]: newMasterId }, true);
              for (const [key, value] of Object.entries(r)) {
                if (!key.startsWith('_') && !detailCopyExcludedFields.has(key)) newDetailRow[key] = value;
              }
              clearCopiedIdentityFields(newDetailRow, detailPkColumn);
              return newDetailRow;
            });
        }
        detailCache.set(newRow._rowKey as string, newCached);
      }
    }

    focusInsertedMasterRow(insertIndex, String(newRow._rowKey));

    return newRow;
  }

  return {
    addMasterRow,
    deleteMasterRow,
    copyMasterRow
  };
}
