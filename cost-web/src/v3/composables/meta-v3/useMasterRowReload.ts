import type { Ref, ShallowRef } from 'vue';
import type { GridApi } from 'ag-grid-community';
import { fetchDynamicDataById } from '@/service/api';
import { type ParsedPageConfig, type RowData, initRowData } from '@/v3/logic/calc-engine';

export function useMasterRowReload(params: {
  pageConfig: Ref<ParsedPageConfig | null>;
  masterPkColumn: Ref<string>;
  masterGridApi: ShallowRef<GridApi | null>;
  notifyError: (message: string) => void;
  resolveMasterRowKey: (masterId: number) => string | null;
}) {
  const { pageConfig, masterPkColumn, masterGridApi, notifyError, resolveMasterRowKey } = params;

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

  return {
    reloadMasterRow
  };
}
