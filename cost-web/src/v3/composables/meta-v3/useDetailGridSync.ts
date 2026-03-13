import type { Ref, ShallowRef } from 'vue';
import type { GridApi } from 'ag-grid-community';
import type { RowData } from '@/v3/logic/calc-engine';
import { forEachDetailGridApi } from '@/v3/composables/meta-v3/detail-grid-apis';

export function useDetailGridSync(params: {
  masterGridApi: ShallowRef<GridApi | null>;
  detailGridApisByTab?: Ref<Record<string, any>>;
}) {
  const { masterGridApi, detailGridApisByTab } = params;

  function forEachDetailGrid(masterRowKey: string, tabKey: string, callback: (api: any) => void) {
    forEachDetailGridApi({ masterGridApi, detailGridApisByTab, masterRowKey, tabKey, callback });
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
