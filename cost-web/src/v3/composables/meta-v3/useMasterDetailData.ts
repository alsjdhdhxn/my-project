import type { Ref, ShallowRef } from 'vue';
import type { GridApi, IServerSideGetRowsParams } from 'ag-grid-community';
import { searchDynamicData } from '@/service/api';
import { debugLog } from '@/v3/composables/meta-v3/debug';
import { ensureRowKey, generateTempId, initRowData, type ParsedPageConfig, type RowData } from '@/v3/logic/calc-engine';

type RecalcAggregates = (masterId: number, masterRowKey?: string) => void;
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

  const detailCache = new Map<string, Record<string, RowData[]>>();


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

  function resolveMasterRowKey(masterId: number): string | null {
    const row = getMasterRowById(masterId);
    if (!row) return null;
    ensureRowKey(row);
    return row._rowKey || null;
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
      grouped[tab.key] = (data?.list || []).map((row: any) => initRowData(row));
      debugLog('detail response', { tabKey: tab.key, count: grouped[tab.key].length });
    }

    detailCache.set(resolvedRowKey, grouped);
    if (detailGridApisByTab?.value) {
      for (const [tabKey, rows] of Object.entries(grouped)) {
        detailGridApisByTab.value[tabKey]?.setGridOption?.('rowData', rows);
      }
    }
    debugLog(
      'detail loaded',
      {
        masterId,
        rowKey: resolvedRowKey,
        tabs: Object.keys(grouped)
          .map(k => `${k}: ${grouped[k].length} rows`)
          .join(', ')
      }
    );
  }

  function addMasterRow() {
    const api = masterGridApi.value;
    const newRow = initRowData({ id: generateTempId() }, true);
    ensureRowKey(newRow);

    // 获取当前选中行的索引，用于在其下方插入
    const selectedNodes = api?.getSelectedNodes() || [];
    const insertIndex = selectedNodes.length > 0 && selectedNodes[0].rowIndex != null
      ? selectedNodes[0].rowIndex + 1
      : 0;

    // 更新本地缓存（仅客户端模式）

    // V3 强制使用 SSRM：使用事务 API 插入行到 Grid
    if (api) {
      api.applyServerSideTransaction({
        route: [],
        add: [newRow],
        addIndex: insertIndex
      });
    }

    afterAddMasterRow?.(newRow);

    // 滚动到新行位置
    setTimeout(() => {
      api?.ensureIndexVisible(insertIndex, 'middle');
      // 选中新行
      const newNode = api?.getRowNode(String(newRow._rowKey));
      if (newNode) {
        newNode.setSelected(true, true);
      }
    }, 100);
  }

  function deleteMasterRow(row: RowData) {
    if (!row) return;
    const api = masterGridApi.value;

    if (row._isNew) {
      // 新增行直接删除

      // V3 强制使用 SSRM：使用事务 API 删除行
      if (api) {
        api.applyServerSideTransaction({
          route: [],
          remove: [row]
        });
      }
    } else {
      // 已有行标记删除
      row._isDeleted = true;
      const node = api?.getRowNode(String(row._rowKey));
      if (node) api?.refreshCells({ rowNodes: [node] });
    }
  }

  function addDetailRow(masterId: number, tabKey: string, masterRowKey?: string) {
    const resolvedRowKey = masterRowKey ?? resolveMasterRowKey(masterId);
    if (!resolvedRowKey) return;
    const cached = detailCache.get(resolvedRowKey);
    if (!cached || !cached[tabKey]) return;
    const fkColumn = detailFkColumnByTab.value[tabKey] || 'masterId';
    const newRow = initRowData({ id: generateTempId(), [fkColumn]: masterId }, true);
    cached[tabKey].push(newRow);
    afterAddDetailRow?.(masterId, tabKey, newRow);

    const secondLevelInfo = masterGridApi.value?.getDetailGridInfo(`detail_${resolvedRowKey}`);
    if (secondLevelInfo?.api) {
      secondLevelInfo.api.forEachDetailGridInfo((detailInfo: any) => {
        if (detailInfo.id?.includes(tabKey)) detailInfo.api.setGridOption('rowData', cached[tabKey]);
      });
    }
    detailGridApisByTab?.value?.[tabKey]?.setGridOption?.('rowData', cached[tabKey]);

    recalcAggregates(masterId, resolvedRowKey);
  }

  function deleteDetailRow(masterId: number, tabKey: string, row: RowData, masterRowKey?: string) {
    if (!row) return;
    const resolvedRowKey = masterRowKey ?? resolveMasterRowKey(masterId);
    if (!resolvedRowKey) return;
    const cached = detailCache.get(resolvedRowKey);
    if (!cached || !cached[tabKey]) return;

    if (row._isNew) {
      // 新增行直接从数组中移除
      const idx = cached[tabKey].findIndex(r => r.id === row.id);
      if (idx >= 0) cached[tabKey].splice(idx, 1);

      // 刷新 Grid 的 rowData，让行从视觉上消失
      const secondLevelInfo = masterGridApi.value?.getDetailGridInfo(`detail_${resolvedRowKey}`);
      if (secondLevelInfo?.api) {
        secondLevelInfo.api.forEachDetailGridInfo((detailInfo: any) => {
          if (detailInfo.id?.includes(tabKey)) {
            detailInfo.api.setGridOption('rowData', cached[tabKey]);
          }
        });
      }
      detailGridApisByTab?.value?.[tabKey]?.setGridOption?.('rowData', cached[tabKey]);
    } else {
      // 已有行标记删除，刷新样式
      row._isDeleted = true;
      const secondLevelInfo = masterGridApi.value?.getDetailGridInfo(`detail_${resolvedRowKey}`);
      if (secondLevelInfo?.api) {
        secondLevelInfo.api.forEachDetailGridInfo((detailInfo: any) => {
          if (detailInfo.id?.includes(tabKey)) detailInfo.api.refreshCells();
        });
      }
      detailGridApisByTab?.value?.[tabKey]?.refreshCells?.({ force: true });
    }

    recalcAggregates(masterId, resolvedRowKey);
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

    for (const [key, value] of Object.entries(sourceRow)) {
      if (!key.startsWith('_') && key !== 'id') newRow[key] = value;
    }

    // 获取源行的索引，在其下方插入
    const sourceNode = api?.getRowNode(String(sourceRowKey));
    const insertIndex = sourceNode?.rowIndex != null
      ? sourceNode.rowIndex + 1
      : 0;

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
          newCached[tabKey] = rows.filter(r => !r._isDeleted).map(r => {
            const newDetailRow = initRowData({ id: generateTempId(), [fkColumn]: newMasterId }, true);
            for (const [key, value] of Object.entries(r)) {
              if (!key.startsWith('_') && key !== 'id' && key !== fkColumn) newDetailRow[key] = value;
            }
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
  }

  function copyDetailRow(masterId: number, tabKey: string, sourceRow: RowData, masterRowKey?: string) {
    if (!sourceRow) return;
    const resolvedRowKey = masterRowKey ?? resolveMasterRowKey(masterId);
    if (!resolvedRowKey) return;
    const cached = detailCache.get(resolvedRowKey);
    if (!cached || !cached[tabKey]) return;
    const fkColumn = detailFkColumnByTab.value[tabKey] || 'masterId';
    const newRow = initRowData({ id: generateTempId(), [fkColumn]: masterId }, true);

    for (const [key, value] of Object.entries(sourceRow)) {
      if (!key.startsWith('_') && key !== 'id' && key !== fkColumn) newRow[key] = value;
    }

    cached[tabKey].push(newRow);
    const secondLevelInfo = masterGridApi.value?.getDetailGridInfo(`detail_${resolvedRowKey}`);
    if (secondLevelInfo?.api) {
      secondLevelInfo.api.forEachDetailGridInfo((detailInfo: any) => {
        if (detailInfo.id?.includes(tabKey)) detailInfo.api.setGridOption('rowData', cached[tabKey]);
      });
    }
    detailGridApisByTab?.value?.[tabKey]?.setGridOption?.('rowData', cached[tabKey]);

    recalcAggregates(masterId, resolvedRowKey);
  }

  return {
    detailCache,
    getMasterRowByRowKey,
    getMasterRowById,
    resolveMasterRowKey,
    loadDetailData,
    addMasterRow,
    deleteMasterRow,
    addDetailRow,
    deleteDetailRow,
    copyMasterRow,
    copyDetailRow,
    /** Server-Side Row Model 数据源（V3 强制使用 SSRM） */
    createServerSideDataSource: (options?: { tableCode?: string; pageSize?: number }) => {
      const tableCode = options?.tableCode || pageConfig.value?.masterTableCode;
      const pageSizeFallback = options?.pageSize || 100;
      if (!tableCode) return null;
      let lastQueryKey = '';
      // 防抖：避免短时间内重复请求
      let pendingRequest: Promise<void> | null = null;
      let lastRequestTime = 0;
      const REQUEST_DEBOUNCE_MS = 50;
      // 缓存总行数，避免每次都传导致 Grid 重置
      let cachedRowCount: number | undefined = undefined;
      let lastSortFilterKey = '';

      return {
        getRows: async (params: IServerSideGetRowsParams) => {
          const now = Date.now();
          // 如果距离上次请求时间太短，跳过（AG Grid 内部可能触发多次）
          if (now - lastRequestTime < REQUEST_DEBOUNCE_MS && pendingRequest) {
            debugLog('ssrm debounce skip', { timeSinceLastRequest: now - lastRequestTime });
            return;
          }
          lastRequestTime = now;
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

          // 检查排序/过滤是否变化，如果变化则清除缓存的 rowCount
          const sortFilterKey = JSON.stringify({ filterModel, sortModel });
          if (sortFilterKey !== lastSortFilterKey) {
            lastSortFilterKey = sortFilterKey;
            cachedRowCount = undefined; // 排序/过滤变化时重置
          }

          // 查询键变化时更新标记
          const queryKey = JSON.stringify({ filterModel, sortModel });
          if (startRow === 0 && queryKey !== lastQueryKey) {
            lastQueryKey = queryKey;
          }

          debugLog('ssrm request', { page, pageSize, sortField, sortOrder, conditions });

          try {
            const requestPromise = searchDynamicData(tableCode, {
              pageCode,
              page,
              pageSize,
              sortField,
              sortOrder,
              conditions: conditions.length > 0 ? conditions : undefined
            });
            pendingRequest = requestPromise.then(() => { pendingRequest = null; });

            const { data, error } = await requestPromise;

            if (error) {
              params.fail();
              notifyError('加载主表数据失败');
              return;
            }

            const rows = (data?.list || []).map((row: any) => initRowData(row));
            const total = data?.total;

            // 缓存 rowCount，只在第一次请求或排序/过滤变化时更新
            if (total != null && cachedRowCount === undefined) {
              cachedRowCount = total;
            }

            debugLog('ssrm response', { rowCount: rows.length, total });

            // SSRM 成功回调
            // 只在第一次请求时传 rowCount，后续请求不传（避免 Grid 重置）
            const successParams: any = { rowData: rows };
            if (startRow === 0 && cachedRowCount != null) {
              successParams.rowCount = cachedRowCount;
            }

            params.success(successParams);
          } catch (e) {
            params.fail();
            notifyError('加载主表数据失败');
          }
        }
      };
    }
  };
}
