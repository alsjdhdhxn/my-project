import type { Ref, ShallowRef } from 'vue';
import type { GridApi } from 'ag-grid-community';
import type { RowData } from '@/v3/logic/calc-engine';

export function useDetailGridSync(params: {
  masterGridApi: ShallowRef<GridApi | null>;
  detailGridApisByTab?: Ref<Record<string, any>>;
}) {
  const { masterGridApi, detailGridApisByTab } = params;

  function forEachDetailGrid(masterRowKey: string, tabKey: string, callback: (api: any) => void) {
    const secondLevelInfo = masterGridApi.value?.getDetailGridInfo(`detail_${masterRowKey}`);
    if (secondLevelInfo?.api) {
      secondLevelInfo.api.forEachDetailGridInfo((detailInfo: any) => {
        if (detailInfo.id?.includes(tabKey)) {
          callback(detailInfo.api);
        }
      });
    }

    const tabApi = detailGridApisByTab?.value?.[tabKey];
    if (tabApi) {
      callback(tabApi);
    }
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

  return {
    setDetailRows,
    refreshDetailCells,
    replaceDetailRows
  };
}
