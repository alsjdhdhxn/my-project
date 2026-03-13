import { ref, type Ref, type ShallowRef } from 'vue';
import type { GridApi } from 'ag-grid-community';
import type { DynamicQueryCondition } from '@/service/api';
import { fetchDynamicDataById } from '@/service/api';
import { applyCopiedRowFields } from '@/v3/composables/meta-v3/copy-row-fields';
import { createMasterServerSideDataSource } from '@/v3/composables/meta-v3/master-server-side-data-source';
import { applyRowPatch, type RowFieldChange } from '@/v3/composables/meta-v3/row-patch';
import { isPersistedRow } from '@/v3/composables/meta-v3/row-persistence';
import { type ParsedPageConfig, type RowData, ensureRowKey, generateTempId, initRowData } from '@/v3/logic/calc-engine';

type QueryCondition = DynamicQueryCondition;

export function useMasterStore(params: {
  pageCode: string;
  pageConfig: Ref<ParsedPageConfig | null>;
  detailFkColumnByTab: Ref<Record<string, string>>;
  masterPkColumn: Ref<string>;
  detailPkColumnByTab: Ref<Record<string, string>>;
  masterGridApi: ShallowRef<GridApi | null>;
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
    detailCache,
    loadDetailData,
    notifyError
  } = params;

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
    return found;
  }

  function resolveMasterRowKey(masterId: number): string | null {
    const row = getMasterRowById(masterId);
    if (!row) return null;
    ensureRowKey(row);
    return row._rowKey || null;
  }

  function applyMasterPatch(
    rowId: number | null,
    rowKey: string | null,
    patch: Record<string, any>,
    fallbackChanges?: RowFieldChange[]
  ) {
    const row = (rowKey ? getMasterRowByRowKey(rowKey) : null) ?? (rowId != null ? getMasterRowById(rowId) : null);
    if (!row) return null;

    const resolvedRowKey = String(ensureRowKey(row));
    const node = masterGridApi.value?.getRowNode?.(resolvedRowKey) ?? null;
    const appliedChanges = applyRowPatch(row, patch);
    const changes =
      appliedChanges.length > 0
        ? appliedChanges
        : (fallbackChanges || []).filter(change => !Object.is(change.oldValue, change.newValue));

    return {
      row,
      rowKey: resolvedRowKey,
      node,
      changes
    };
  }

  const advancedConditions = ref<QueryCondition[]>([]);

  function setAdvancedConditions(conditions: QueryCondition[]) {
    advancedConditions.value = Array.isArray(conditions)
      ? conditions.filter(condition => Boolean(condition?.field) && Boolean(condition?.operator))
      : [];
  }

  function clearAdvancedConditions() {
    advancedConditions.value = [];
  }

  const createServerSideDataSource = createMasterServerSideDataSource({
    pageCode,
    getTableCode: () => pageConfig.value?.masterTableCode,
    getMasterPkColumn: () => masterPkColumn.value,
    getAdvancedConditions: () => advancedConditions.value,
    notifyError
  });

  async function reloadMasterRow(masterId: number, masterRowKey?: string) {
    const tableCode = pageConfig.value?.masterTableCode;
    const resolvedRowKey = masterRowKey ?? resolveMasterRowKey(masterId);
    if (!tableCode || !resolvedRowKey) return null;

    const api = masterGridApi.value as any;
    const currentNode = api?.getRowNode?.(String(resolvedRowKey));
    const currentRow = currentNode?.data as RowData | undefined;
    const hasLocalChanges = Boolean(currentRow?._isNew || currentRow?._isDeleted || currentRow?._dirtyFields);

    if (hasLocalChanges) {
      return currentRow ?? null;
    }

    const { data, error } = await fetchDynamicDataById(tableCode, masterId);
    if (error || !data) {
      notifyError('加载主表数据失败');
      return currentRow ?? null;
    }

    const refreshedRow = initRowData(data, false, masterPkColumn.value);
    refreshedRow._rowKey = resolvedRowKey;

    if (currentNode?.setData) {
      currentNode.setData(refreshedRow);
    } else {
      api?.applyServerSideTransaction?.({
        route: [],
        update: [refreshedRow]
      });
    }

    return refreshedRow;
  }

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

  function insertMasterRow(row: RowData, insertIndex: number) {
    const api = masterGridApi.value;
    if (!api) return;
    api.applyServerSideTransaction({
      route: [],
      add: [row],
      addIndex: insertIndex
    });
    focusInsertedMasterRow(insertIndex, String(row._rowKey));
  }

  function addMasterRow() {
    const api = masterGridApi.value;
    const newRow = initRowData({ id: generateTempId() }, true);
    ensureRowKey(newRow);

    const selectedNodes = api?.getSelectedNodes() || [];
    const insertIndex =
      selectedNodes.length > 0 && selectedNodes[0].rowIndex != null ? selectedNodes[0].rowIndex + 1 : 0;

    insertMasterRow(newRow, insertIndex);

    return newRow;
  }

  function deleteMasterRow(row: RowData) {
    if (!row) return;
    const api = masterGridApi.value;
    const rowKey = row._rowKey ? String(row._rowKey) : null;
    const currentRow =
      (rowKey ? getMasterRowByRowKey(rowKey) : null) ??
      (isPersistedRow(row) ? getMasterRowById(Number(row.id)) : null) ??
      row;

    if (!isPersistedRow(currentRow)) {
      if (api) {
        api.applyServerSideTransaction({
          route: [],
          remove: [currentRow]
        });
      }
      return;
    }

    currentRow._isDeleted = true;
    const node = api?.getRowNode(String(ensureRowKey(currentRow)));
    if (node) api?.refreshCells({ rowNodes: [node] });
  }

  async function copyMasterRow(sourceRow: RowData) {
    if (!sourceRow) return;
    const api = masterGridApi.value;
    const sourceMasterId = sourceRow.id;
    ensureRowKey(sourceRow);
    const sourceRowKey = sourceRow._rowKey as string;
    const newMasterId = generateTempId();
    const newRow = initRowData({ id: newMasterId }, true);
    ensureRowKey(newRow);

    applyCopiedRowFields({
      sourceRow,
      targetRow: newRow,
      excludeFields: [masterPkColumn.value],
      clearFields: [masterPkColumn.value]
    });

    const sourceNode = api?.getRowNode(String(sourceRowKey));
    const insertIndex = sourceNode?.rowIndex != null ? sourceNode.rowIndex + 1 : 0;

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
          newCached[tabKey] = rows
            .filter(r => !r._isDeleted)
            .map(r => {
              const newDetailRow = initRowData({ id: generateTempId(), [fkColumn]: newMasterId }, true);
              applyCopiedRowFields({
                sourceRow: r,
                targetRow: newDetailRow,
                excludeFields: [detailPkColumn, fkColumn],
                clearFields: [detailPkColumn]
              });
              return newDetailRow;
            });
        }
        detailCache.set(newRow._rowKey as string, newCached);
      }
    }

    insertMasterRow(newRow, insertIndex);

    return newRow;
  }

  return {
    advancedConditions,
    setAdvancedConditions,
    clearAdvancedConditions,
    createServerSideDataSource,
    getMasterRowByRowKey,
    getMasterRowById,
    resolveMasterRowKey,
    applyMasterPatch,
    reloadMasterRow,
    addMasterRow,
    deleteMasterRow,
    copyMasterRow
  };
}
