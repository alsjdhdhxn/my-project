import { ref, type Ref } from 'vue';
import type { ColDef, GridReadyEvent, CellValueChangedEvent } from 'ag-grid-community';
import { useGridContextMenu } from '@/composables/meta-v2/useGridContextMenu';

type RuntimeApi = {
  masterGridApi?: Ref<any>;
  broadcastFields?: Ref<string[]>;
  addMasterRow?: () => void;
  deleteMasterRow?: (row: any) => void;
  copyMasterRow?: (row: any) => void;
  addDetailRow?: (masterId: number, tabKey: string) => void;
  deleteDetailRow?: (masterId: number, tabKey: string, row: any) => void;
  copyDetailRow?: (masterId: number, tabKey: string, row: any) => void;
  save?: () => void;
  markFieldChange?: (row: any, field: string, oldValue: any, newValue: any, type: 'user' | 'calc') => void;
  runMasterCalc?: (node: any, row: any) => void;
  broadcastToDetail?: (masterId: number, row: any) => Promise<void> | void;
  onMasterCellClicked?: (event: any) => void;
};

export function useMasterGridBindings(params: { runtime: RuntimeApi; isUserEditing?: Ref<boolean> }) {
  const { runtime } = params;
  const isUserEditing = params.isUserEditing ?? ref(false);

  const cellClassRules = {
    'cell-user-changed': (params: any) => {
      const row = params.data;
      const field = params.colDef?.field;
      return row?._dirtyFields?.[field]?.type === 'user';
    },
    'cell-calc-changed': (params: any) => {
      const row = params.data;
      const field = params.colDef?.field;
      return row?._dirtyFields?.[field]?.type === 'calc';
    },
    'cell-new': (params: any) => params.data?._isNew === true,
    'cell-deleted': (params: any) => params.data?._isDeleted === true
  };

  const defaultColDef: ColDef = {
    sortable: true,
    filter: true,
    resizable: true,
    editable: true,
    wrapText: true,
    autoHeight: true,
    cellClassRules
  };

  const autoSizeStrategy = { type: 'fitCellContents' as const };
  const rowSelection = {
    mode: 'singleRow' as const,
    enableClickSelection: true,
    hideDisabledCheckboxes: true,
    checkboxes: false
  };
  const rowHeight = 28;
  const headerHeight = 28;

  const getRowId = (params: any) => String(params.data?.id);
  function getRowClass(params: any): string | undefined {
    if (params.data?._isDeleted) return 'row-deleted';
    if (params.data?._isNew) return 'row-new';
    return undefined;
  }

  const { getMasterContextMenuItems } = useGridContextMenu({
    addMasterRow: runtime.addMasterRow || (() => {}),
    deleteMasterRow: runtime.deleteMasterRow || (() => {}),
    copyMasterRow: runtime.copyMasterRow || (() => {}),
    addDetailRow: runtime.addDetailRow || (() => {}),
    deleteDetailRow: runtime.deleteDetailRow || (() => {}),
    copyDetailRow: runtime.copyDetailRow || (() => {}),
    save: runtime.save || (() => {})
  });

  function onGridReady(params: GridReadyEvent) {
    if (runtime.masterGridApi) runtime.masterGridApi.value = params.api;
    params.api.sizeColumnsToFit();
  }

  function onCellEditingStarted() {
    isUserEditing.value = true;
  }

  function onCellEditingStopped() {
    isUserEditing.value = false;
  }

  async function onCellValueChanged(event: CellValueChangedEvent) {
    const field = event.colDef?.field;
    const row = event.data;
    const masterId = row?.id;
    if (!field || masterId == null) return;

    const changeType = isUserEditing.value ? 'user' : 'calc';
    runtime.markFieldChange?.(row, field, event.oldValue, event.newValue, changeType);
    runtime.masterGridApi?.value?.refreshCells({ rowNodes: [event.node], columns: [field], force: true });

    if (isUserEditing.value) {
      runtime.runMasterCalc?.(event.node, row);
      const broadcastList = runtime.broadcastFields?.value || [];
      if (broadcastList.includes(field)) {
        await runtime.broadcastToDetail?.(masterId, row);
      }
    }
  }

  function onCellClicked(event: any) {
    runtime.onMasterCellClicked?.(event);
  }

  return {
    isUserEditing,
    cellClassRules,
    defaultColDef,
    autoSizeStrategy,
    rowSelection,
    rowHeight,
    headerHeight,
    getRowId,
    getRowClass,
    getContextMenuItems: getMasterContextMenuItems,
    onGridReady,
    onCellEditingStarted,
    onCellEditingStopped,
    onCellValueChanged,
    onCellClicked
  };
}
