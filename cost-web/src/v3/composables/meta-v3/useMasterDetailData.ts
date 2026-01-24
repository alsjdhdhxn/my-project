import { ref, type Ref, type ShallowRef } from 'vue';
import type { GridApi, IServerSideGetRowsParams } from 'ag-grid-community';
import { searchDynamicData } from '@/service/api';
import { debugLog } from '@/v3/composables/meta-v3/debug';
import { generateTempId, initRowData, type ParsedPageConfig, type RowData } from '@/v3/logic/calc-engine';

type RecalcAggregates = (masterId: number) => void;
type QueryCondition = { field: string; operator: string; value: any; value2?: any };

export function useMasterDetailData(params: {
  pageCode: string;
  pageConfig: Ref<ParsedPageConfig | null>;
  detailFkColumnByTab: Ref<Record<string, string>>;
  masterGridApi: ShallowRef<GridApi | null>;
  detailGridApisByTab?: Ref<Record<string, any>>;
  notifyError: (message: string) => void;
  recalcAggregates: RecalcAggregates;
  afterAddMasterRow?: (row: RowData) => void;
  afterAddDetailRow?: (masterId: number, tabKey: string, row: RowData) => void;
}) {
  const {
    pageCode,
    pageConfig,
    detailFkColumnByTab,
    masterGridApi,
    detailGridApisByTab,
    notifyError,
    recalcAggregates,
    afterAddMasterRow,
    afterAddDetailRow
  } = params;

  const masterRows = ref<RowData[]>([]);
  const detailCache = new Map<number, Record<string, RowData[]>>();
  const masterRowMap = new Map<number, RowData>();

  function resetMasterCache(rows: RowData[]) {
    masterRowMap.clear();
    masterRows.value = rows;
    for (const row of rows) {
      const id = row?.id;
      if (typeof id === 'number') {
        masterRowMap.set(id, row);
      }
    }
  }

  function mergeMasterCache(rows: RowData[]) {
    const merged: RowData[] = [];
    for (const row of rows) {
      const id = row?.id;
      if (typeof id === 'number') {
        const existing = masterRowMap.get(id);
        if (existing) {
          merged.push(existing);
          continue;
        }
        masterRowMap.set(id, row);
      }
      masterRows.value.push(row);
      merged.push(row);
    }
    return merged;
  }

  function toTextCondition(field: string, type: string, value: any): QueryCondition | null {
    if (value == null || value === '') return null;
    switch (type) {
      case 'contains':
      case 'startsWith':
      case 'endsWith':
        return { field, operator: 'like', value };
      case 'equals':
        return { field, operator: 'eq', value };
      case 'notEqual':
        return { field, operator: 'ne', value };
      default:
        return null;
    }
  }

  function toNumberCondition(field: string, type: string, value: any, value2?: any): QueryCondition | null {
    if (value == null || value === '') return null;
    switch (type) {
      case 'equals':
        return { field, operator: 'eq', value };
      case 'notEqual':
        return { field, operator: 'ne', value };
      case 'lessThan':
        return { field, operator: 'lt', value };
      case 'lessThanOrEqual':
        return { field, operator: 'le', value };
      case 'greaterThan':
        return { field, operator: 'gt', value };
      case 'greaterThanOrEqual':
        return { field, operator: 'ge', value };
      case 'inRange':
        if (value2 == null || value2 === '') return null;
        return { field, operator: 'between', value, value2 };
      default:
        return null;
    }
  }

  function toDateCondition(field: string, type: string, value: any, value2?: any): QueryCondition | null {
    if (value == null || value === '') return null;
    switch (type) {
      case 'equals':
        return { field, operator: 'eq', value };
      case 'notEqual':
        return { field, operator: 'ne', value };
      case 'lessThan':
        return { field, operator: 'lt', value };
      case 'greaterThan':
        return { field, operator: 'gt', value };
      case 'inRange':
        if (value2 == null || value2 === '') return null;
        return { field, operator: 'between', value, value2 };
      default:
        return null;
    }
  }

  function buildConditionsFromFilterModel(filterModel: Record<string, any> | null | undefined): QueryCondition[] {
    if (!filterModel) return [];
    const conditions: QueryCondition[] = [];
    for (const [field, filter] of Object.entries(filterModel)) {
      if (!filter) continue;
      if (filter.operator && filter.condition1) {
        const first = buildConditionsFromFilterModel({ [field]: filter.condition1 });
        const second = buildConditionsFromFilterModel({ [field]: filter.condition2 });
        conditions.push(...first);
        if (filter.operator === 'AND') {
          conditions.push(...second);
        }
        continue;
      }
      if (filter.filterType === 'set' && Array.isArray(filter.values)) {
        if (filter.values.length > 0) {
          conditions.push({ field, operator: 'in', value: filter.values });
        }
        continue;
      }
      const type = filter.type;
      if (filter.filterType === 'text') {
        const cond = toTextCondition(field, type, filter.filter);
        if (cond) conditions.push(cond);
        continue;
      }
      if (filter.filterType === 'number') {
        const cond = toNumberCondition(field, type, filter.filter, filter.filterTo);
        if (cond) conditions.push(cond);
        continue;
      }
      if (filter.filterType === 'date') {
        const cond = toDateCondition(field, type, filter.dateFrom, filter.dateTo);
        if (cond) conditions.push(cond);
      }
    }
    return conditions;
  }

  async function loadMasterData() {
    const tableCode = pageConfig.value?.masterTableCode;
    if (!tableCode) return;
    const { data, error } = await searchDynamicData(tableCode, { pageCode });
    if (error) {
      notifyError('加载主表数据失败');
      return;
    }
    const rows = (data?.list || []).map((row: any) => initRowData(row));
    resetMasterCache(rows);
  }

  async function loadDetailData(masterId: number) {
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
      grouped[tab.key] = (data?.list || []).map((row: any) => initRowData(row));
      debugLog('detail response', { tabKey: tab.key, count: grouped[tab.key].length });
    }

    detailCache.set(masterId, grouped);
    if (detailGridApisByTab?.value) {
      for (const [tabKey, rows] of Object.entries(grouped)) {
        detailGridApisByTab.value[tabKey]?.setGridOption?.('rowData', rows);
      }
    }
    debugLog(
      'detail loaded',
      masterId,
      Object.keys(grouped)
        .map(k => `${k}: ${grouped[k].length} rows`)
        .join(', ')
    );
  }

  function addMasterRow() {
    const api = masterGridApi.value;
    const newRow = initRowData({ id: generateTempId() }, true);

    // 获取当前选中行的索引，用于在其下方插入
    const selectedNodes = api?.getSelectedNodes() || [];
    const insertIndex = selectedNodes.length > 0 && selectedNodes[0].rowIndex != null
      ? selectedNodes[0].rowIndex + 1
      : 0;

    // 判断是否为 SSRM/Infinite 模式
    const rowModelType = (api as any)?.getGridOption?.('rowModelType');
    const isServerSide = rowModelType === 'serverSide' || rowModelType === 'infinite';

    if (isServerSide && api) {
      // SSRM 模式：使用事务 API 插入行
      if (rowModelType === 'serverSide') {
        api.applyServerSideTransaction({
          route: [],
          add: [newRow],
          addIndex: insertIndex
        });
      } else {
        // Infinite 模式不支持事务，刷新数据源
        // 先将新行加入缓存，然后刷新
        masterRows.value.splice(insertIndex, 0, newRow);
        if (typeof newRow.id === 'number') {
          masterRowMap.set(newRow.id, newRow);
        }
        api.refreshInfiniteCache();
      }
    } else {
      // Client-Side 模式：直接操作数组
      masterRows.value.splice(insertIndex, 0, newRow);
      if (typeof newRow.id === 'number') {
        masterRowMap.set(newRow.id, newRow);
      }
    }

    afterAddMasterRow?.(newRow);

    // 滚动到新行位置
    setTimeout(() => {
      api?.ensureIndexVisible(insertIndex, 'middle');
      // 选中新行
      const newNode = api?.getRowNode(String(newRow.id));
      if (newNode) {
        newNode.setSelected(true, true);
      }
    }, 100);
  }

  function deleteMasterRow(row: RowData) {
    if (!row) return;
    const api = masterGridApi.value;
    const rowModelType = (api as any)?.getGridOption?.('rowModelType');
    const isServerSide = rowModelType === 'serverSide' || rowModelType === 'infinite';

    if (row._isNew) {
      // 新增行直接删除
      const idx = masterRows.value.findIndex(r => r.id === row.id);
      if (idx >= 0) masterRows.value.splice(idx, 1);
      if (typeof row.id === 'number') {
        masterRowMap.delete(row.id);
      }

      if (isServerSide && api) {
        if (rowModelType === 'serverSide') {
          api.applyServerSideTransaction({
            route: [],
            remove: [row]
          });
        } else {
          api.refreshInfiniteCache();
        }
      }
    } else {
      // 已有行标记删除
      row._isDeleted = true;
      const node = api?.getRowNode(String(row.id));
      if (node) api?.refreshCells({ rowNodes: [node] });
    }
  }

  function addDetailRow(masterId: number, tabKey: string) {
    const cached = detailCache.get(masterId);
    if (!cached || !cached[tabKey]) return;
    const fkColumn = detailFkColumnByTab.value[tabKey] || 'masterId';
    const newRow = initRowData({ id: generateTempId(), [fkColumn]: masterId }, true);
    cached[tabKey].push(newRow);
    afterAddDetailRow?.(masterId, tabKey, newRow);

    const secondLevelInfo = masterGridApi.value?.getDetailGridInfo(`detail_${masterId}`);
    if (secondLevelInfo?.api) {
      secondLevelInfo.api.forEachDetailGridInfo((detailInfo: any) => {
        if (detailInfo.id?.includes(tabKey)) detailInfo.api.setGridOption('rowData', cached[tabKey]);
      });
    }
    detailGridApisByTab?.value?.[tabKey]?.setGridOption?.('rowData', cached[tabKey]);

    recalcAggregates(masterId);
  }

  function deleteDetailRow(masterId: number, tabKey: string, row: RowData) {
    if (!row) return;
    const cached = detailCache.get(masterId);
    if (!cached || !cached[tabKey]) return;

    if (row._isNew) {
      const idx = cached[tabKey].findIndex(r => r.id === row.id);
      if (idx >= 0) cached[tabKey].splice(idx, 1);
    } else {
      row._isDeleted = true;
    }

    const secondLevelInfo = masterGridApi.value?.getDetailGridInfo(`detail_${masterId}`);
    if (secondLevelInfo?.api) {
      secondLevelInfo.api.forEachDetailGridInfo((detailInfo: any) => {
        if (detailInfo.id?.includes(tabKey)) detailInfo.api.refreshCells();
      });
    }
    detailGridApisByTab?.value?.[tabKey]?.refreshCells?.({ force: true });

    recalcAggregates(masterId);
  }

  async function copyMasterRow(sourceRow: RowData) {
    if (!sourceRow) return;
    const api = masterGridApi.value;
    const sourceMasterId = sourceRow.id;
    const newMasterId = generateTempId();
    const newRow = initRowData({ id: newMasterId }, true);

    for (const [key, value] of Object.entries(sourceRow)) {
      if (!key.startsWith('_') && key !== 'id') newRow[key] = value;
    }

    // 获取源行的索引，在其下方插入
    const sourceNode = api?.getRowNode(String(sourceMasterId));
    const insertIndex = sourceNode?.rowIndex != null ? sourceNode.rowIndex + 1 : masterRows.value.length;

    // 判断是否为 SSRM/Infinite 模式
    const rowModelType = (api as any)?.getGridOption?.('rowModelType');
    const isServerSide = rowModelType === 'serverSide' || rowModelType === 'infinite';

    if (isServerSide && api) {
      if (rowModelType === 'serverSide') {
        api.applyServerSideTransaction({
          route: [],
          add: [newRow],
          addIndex: insertIndex
        });
      } else {
        masterRows.value.splice(insertIndex, 0, newRow);
        if (typeof newRow.id === 'number') {
          masterRowMap.set(newRow.id, newRow);
        }
        api.refreshInfiniteCache();
      }
    } else {
      masterRows.value.splice(insertIndex, 0, newRow);
      if (typeof newRow.id === 'number') {
        masterRowMap.set(newRow.id, newRow);
      }
    }

    // 复制子表数据
    if (sourceMasterId != null) {
      let sourceCached = detailCache.get(sourceMasterId);
      if (!sourceCached) {
        await loadDetailData(sourceMasterId);
        sourceCached = detailCache.get(sourceMasterId);
      }

      if (sourceCached) {
        const newCached: Record<string, RowData[]> = {};
        for (const [tabKey, rows] of Object.entries(sourceCached)) {
          const fkColumn = detailFkColumnByTab.value[tabKey] || 'masterId';
          newCached[tabKey] = rows.filter(r => !r._isDeleted).map(r => {
            const newDetailRow = initRowData({ id: generateTempId(), [fkColumn]: newMasterId }, true);
            for (const [key, value] of Object.entries(r)) {
              if (!key.startsWith('_') && key !== 'id' && key !== fkColumn) newDetailRow[key] = value;
            }
            return newDetailRow;
          });
        }
        detailCache.set(newMasterId, newCached);
      }
    }

    // 滚动到新行位置并选中
    setTimeout(() => {
      api?.ensureIndexVisible(insertIndex, 'middle');
      const newNode = api?.getRowNode(String(newRow.id));
      if (newNode) {
        newNode.setSelected(true, true);
      }
    }, 100);
  }

  function copyDetailRow(masterId: number, tabKey: string, sourceRow: RowData) {
    if (!sourceRow) return;
    const cached = detailCache.get(masterId);
    if (!cached || !cached[tabKey]) return;
    const fkColumn = detailFkColumnByTab.value[tabKey] || 'masterId';
    const newRow = initRowData({ id: generateTempId(), [fkColumn]: masterId }, true);

    for (const [key, value] of Object.entries(sourceRow)) {
      if (!key.startsWith('_') && key !== 'id' && key !== fkColumn) newRow[key] = value;
    }

    cached[tabKey].push(newRow);
    const secondLevelInfo = masterGridApi.value?.getDetailGridInfo(`detail_${masterId}`);
    if (secondLevelInfo?.api) {
      secondLevelInfo.api.forEachDetailGridInfo((detailInfo: any) => {
        if (detailInfo.id?.includes(tabKey)) detailInfo.api.setGridOption('rowData', cached[tabKey]);
      });
    }
    detailGridApisByTab?.value?.[tabKey]?.setGridOption?.('rowData', cached[tabKey]);

    recalcAggregates(masterId);
  }

  return {
    masterRows,
    detailCache,
    loadMasterData,
    loadDetailData,
    addMasterRow,
    deleteMasterRow,
    addDetailRow,
    deleteDetailRow,
    copyMasterRow,
    copyDetailRow,
    /** Infinite Row Model 数据源（兼容旧版） */
    createMasterDataSource: (options?: { tableCode?: string; pageSize?: number }) => {
      const tableCode = options?.tableCode || pageConfig.value?.masterTableCode;
      const pageSizeFallback = options?.pageSize || 200;
      if (!tableCode) return null;
      let lastQueryKey = '';
      return {
        getRows: async (params: any) => {
          const startRow = params.request?.startRow ?? params.startRow ?? 0;
          const endRow = params.request?.endRow ?? params.endRow ?? startRow + pageSizeFallback;
          const pageSize = Math.max(endRow - startRow, 1);
          const page = Math.floor(startRow / pageSize) + 1;

          const sortModel = params.request?.sortModel ?? params.sortModel ?? [];
          const sortField = sortModel[0]?.colId;
          const sortOrder = sortModel[0]?.sort;

          const filterModel = params.request?.filterModel ?? params.filterModel;
          const conditions = buildConditionsFromFilterModel(filterModel);
          const queryKey = JSON.stringify({ filterModel, sortModel });
          if (startRow === 0 && queryKey !== lastQueryKey) {
            resetMasterCache([]);
            lastQueryKey = queryKey;
          }

          const { data, error } = await searchDynamicData(tableCode, {
            pageCode,
            page,
            pageSize,
            sortField,
            sortOrder,
            conditions: conditions.length > 0 ? conditions : undefined
          });

          if (error) {
            params.failCallback?.();
            notifyError('加载主表数据失败');
            return;
          }

          const rows = (data?.list || []).map((row: any) => initRowData(row));
          const synced = mergeMasterCache(rows);
          const total = data?.total ?? synced.length;
          params.successCallback?.(synced, total);
        }
      };
    },
    /** Server-Side Row Model 数据源（AG Grid v35 SSRM） */
    createServerSideDataSource: (options?: { tableCode?: string; pageSize?: number }) => {
      const tableCode = options?.tableCode || pageConfig.value?.masterTableCode;
      const pageSizeFallback = options?.pageSize || 100;
      if (!tableCode) return null;
      let lastQueryKey = '';

      return {
        getRows: async (params: IServerSideGetRowsParams) => {
          const request = params.request;
          const startRow = request.startRow ?? 0;
          const endRow = request.endRow ?? startRow + pageSizeFallback;
          const pageSize = Math.max(endRow - startRow, 1);
          const page = Math.floor(startRow / pageSize) + 1;

          // 排序
          const sortModel = request.sortModel ?? [];
          const sortField = sortModel[0]?.colId;
          const sortOrder = sortModel[0]?.sort;

          // 过滤
          const filterModel = request.filterModel;
          const conditions = buildConditionsFromFilterModel(filterModel);

          // 查询键变化时重置缓存
          const queryKey = JSON.stringify({ filterModel, sortModel });
          if (startRow === 0 && queryKey !== lastQueryKey) {
            resetMasterCache([]);
            lastQueryKey = queryKey;
          }

          debugLog('ssrm request', { page, pageSize, sortField, sortOrder, conditions });

          try {
            const { data, error } = await searchDynamicData(tableCode, {
              pageCode,
              page,
              pageSize,
              sortField,
              sortOrder,
              conditions: conditions.length > 0 ? conditions : undefined
            });

            if (error) {
              params.fail();
              notifyError('加载主表数据失败');
              return;
            }

            const rows = (data?.list || []).map((row: any) => initRowData(row));
            const synced = mergeMasterCache(rows);
            const total = data?.total ?? synced.length;

            debugLog('ssrm response', { rowCount: synced.length, total });

            // SSRM 成功回调
            params.success({
              rowData: synced,
              rowCount: total
            });
          } catch (e) {
            params.fail();
            notifyError('加载主表数据失败');
          }
        }
      };
    }
  };
}


