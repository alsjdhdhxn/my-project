import type { Ref, ShallowRef } from 'vue';
import type { GridApi } from 'ag-grid-community';
import { fetchDynamicDataById, searchDynamicData } from '@/service/api';
import { buildCopyExcludedFields, clearCopiedIdentityFields } from '@/v3/composables/meta-v3/copy-row-fields';
import { debugLog } from '@/v3/composables/meta-v3/debug';
import { useDetailGridSync } from '@/v3/composables/meta-v3/useDetailGridSync';
import { useDetailRowMutations } from '@/v3/composables/meta-v3/useDetailRowMutations';
import { useMasterQueryState } from '@/v3/composables/meta-v3/useMasterQueryState';
import { type ParsedPageConfig, type RowData, ensureRowKey, generateTempId, initRowData } from '@/v3/logic/calc-engine';

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

  function isPersistedRow(row: RowData | null | undefined) {
    const numericId = typeof row?.id === 'number' ? row.id : Number(row?.id);
    return Number.isFinite(numericId) && numericId > 0;
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

  function addMasterRow() {
    const api = masterGridApi.value;
    const newRow = initRowData({ id: generateTempId() }, true);
    ensureRowKey(newRow);

    // 获取当前选中行的索引，用于在其下方插入
    const selectedNodes = api?.getSelectedNodes() || [];
    const insertIndex =
      selectedNodes.length > 0 && selectedNodes[0].rowIndex != null ? selectedNodes[0].rowIndex + 1 : 0;

    // 更新本地缓存（仅客户端模式）

    // V3 强制使用 SSRM：使用事务 API 插入行到 Grid
    if (api) {
      api.applyServerSideTransaction({
        route: [],
        add: [newRow],
        addIndex: insertIndex
      });
    }

    // 滚动到新行位置
    setTimeout(() => {
      api?.ensureIndexVisible(insertIndex, 'middle');
      // 选中新行
      const newNode = api?.getRowNode(String(newRow._rowKey));
      if (newNode) {
        newNode.setSelected(true, true);
      }
    }, 100);

    return newRow;
  }

  function deleteMasterRow(row: RowData) {
    if (!row) return;
    const api = masterGridApi.value;
    const currentRow = resolveCurrentMasterRow(row);

    if (!isPersistedRow(currentRow)) {
      // 新增行直接删除

      // V3 强制使用 SSRM：使用事务 API 删除行
      if (api) {
        api.applyServerSideTransaction({
          route: [],
          remove: [currentRow]
        });
      }
    } else {
      // 已有行标记删除
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

    // 获取源行的索引，在其下方插入
    const sourceNode = api?.getRowNode(String(sourceRowKey));
    const insertIndex = sourceNode?.rowIndex != null ? sourceNode.rowIndex + 1 : 0;

    // V3 强制使用 SSRM：使用事务 API 插入行到 Grid
    if (api) {
      api.applyServerSideTransaction({
        route: [],
        add: [newRow],
        addIndex: insertIndex
      });
    }

    // 复制子表数据
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

    // 滚动到新行位置并选中
    setTimeout(() => {
      api?.ensureIndexVisible(insertIndex, 'middle');
      const newNode = api?.getRowNode(String(newRow._rowKey));
      if (newNode) {
        newNode.setSelected(true, true);
      }
    }, 100);

    return newRow;
  }

  /** 清空所有业务数据缓存 */
  function clearAllCache() {
    detailCache.clear();
  }

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
