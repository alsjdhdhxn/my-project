import { ref, type Ref, type ShallowRef } from 'vue';
import type { GridApi } from 'ag-grid-community';
import { searchDynamicData } from '@/service/api';
import { generateTempId, initRowData, type ParsedPageConfig, type RowData } from '@/logic/calc-engine';

type RecalcAggregates = (masterId: number) => void;

export function useMasterDetailData(params: {
  pageCode: string;
  pageConfig: Ref<ParsedPageConfig | null>;
  detailFkColumnByTab: Ref<Record<string, string>>;
  masterGridApi: ShallowRef<GridApi | null>;
  notifyError: (message: string) => void;
  recalcAggregates: RecalcAggregates;
}) {
  const { pageCode, pageConfig, detailFkColumnByTab, masterGridApi, notifyError, recalcAggregates } = params;

  const masterRows = ref<RowData[]>([]);
  const detailCache = new Map<number, Record<string, RowData[]>>();

  async function loadMasterData() {
    const tableCode = pageConfig.value?.masterTableCode;
    if (!tableCode) return;
    const { data, error } = await searchDynamicData(tableCode, { pageCode });
    if (error) {
      notifyError('加载主表数据失败');
      return;
    }
    masterRows.value = (data?.list || []).map((row: any) => initRowData(row));
  }

  async function loadDetailData(masterId: number) {
    const tabs = pageConfig.value?.tabs || [];
    const grouped: Record<string, RowData[]> = {};

    for (const tab of tabs) {
      const tableCode = tab.tableCode || pageConfig.value?.detailTableCode;
      const fkColumn = detailFkColumnByTab.value[tab.key] || 'masterId';
      if (!tableCode) continue;

      const { data, error } = await searchDynamicData(tableCode, {
        pageCode,
        conditions: [{ field: fkColumn, operator: 'eq', value: masterId }]
      });
      if (error) {
        console.error(`[load detail failed] ${tab.key}`, error);
        grouped[tab.key] = [];
        continue;
      }
      grouped[tab.key] = (data?.list || []).map((row: any) => initRowData(row));
    }

    detailCache.set(masterId, grouped);
    console.log('[detail loaded]', masterId, Object.keys(grouped).map(k => `${k}: ${grouped[k].length} rows`).join(', '));
  }

  function addMasterRow() {
    const newRow = initRowData({ id: generateTempId() }, true);
    masterRows.value.push(newRow);
    setTimeout(() => masterGridApi.value?.ensureIndexVisible(masterRows.value.length - 1), 100);
  }

  function deleteMasterRow(row: RowData) {
    if (!row) return;
    if (row._isNew) {
      const idx = masterRows.value.findIndex(r => r.id === row.id);
      if (idx >= 0) masterRows.value.splice(idx, 1);
    } else {
      row._isDeleted = true;
      const node = masterGridApi.value?.getRowNode(String(row.id));
      if (node) masterGridApi.value?.refreshCells({ rowNodes: [node] });
    }
  }

  function addDetailRow(masterId: number, tabKey: string) {
    const cached = detailCache.get(masterId);
    if (!cached || !cached[tabKey]) return;
    const fkColumn = detailFkColumnByTab.value[tabKey] || 'masterId';
    const newRow = initRowData({ id: generateTempId(), [fkColumn]: masterId }, true);
    cached[tabKey].push(newRow);

    const secondLevelInfo = masterGridApi.value?.getDetailGridInfo(`detail_${masterId}`);
    if (secondLevelInfo?.api) {
      secondLevelInfo.api.forEachDetailGridInfo((detailInfo: any) => {
        if (detailInfo.id?.includes(tabKey)) detailInfo.api.setGridOption('rowData', cached[tabKey]);
      });
    }

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

    recalcAggregates(masterId);
  }

  async function copyMasterRow(sourceRow: RowData) {
    if (!sourceRow) return;
    const sourceMasterId = sourceRow.id;
    const newMasterId = generateTempId();
    const newRow = initRowData({ id: newMasterId }, true);

    for (const [key, value] of Object.entries(sourceRow)) {
      if (!key.startsWith('_') && key !== 'id') newRow[key] = value;
    }
    masterRows.value.push(newRow);

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

    setTimeout(() => masterGridApi.value?.ensureIndexVisible(masterRows.value.length - 1), 100);
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
    copyDetailRow
  };
}
