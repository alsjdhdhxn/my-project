import { ref, type Ref } from 'vue';
import type { ColDef, GridReadyEvent, CellValueChangedEvent } from 'ag-grid-community';
import { useGridContextMenu } from '@/composables/meta-v2/useGridContextMenu';
import {
  buildGridRuntimeOptions,
  autoSizeColumnsOnReady,
  type ResolvedGridOptions
} from '@/composables/meta-v2/grid-options';
import { DIRTY_CELL_CLASS_RULES, isFlagTrue } from '@/composables/meta-v2/cell-style';

type RuntimeApi = {
  masterGridApi?: Ref<any>;
  masterGridKey?: Ref<string | null> | string | null;
  broadcastFields?: Ref<string[]>;
  addMasterRow?: () => void;
  deleteMasterRow?: (row: any) => void;
  copyMasterRow?: (row: any) => void;
  addDetailRow?: (masterId: number, tabKey: string) => void;
  deleteDetailRow?: (masterId: number, tabKey: string, row: any) => void;
  copyDetailRow?: (masterId: number, tabKey: string, row: any) => void;
  save?: () => void;
  saveGridConfig?: (gridKey: string, api: any, columnApi: any) => void;
  applyGridConfig?: (gridKey: string, api: any, columnApi: any) => void;
  markFieldChange?: (row: any, field: string, oldValue: any, newValue: any, type: 'user' | 'calc') => void;
  runMasterCalc?: (node: any, row: any) => void;
  broadcastToDetail?: (masterId: number, row: any) => Promise<void> | void;
  onMasterCellClicked?: (event: any) => void;
};

export function useMasterGridBindings(params: {
  runtime: RuntimeApi;
  isUserEditing?: Ref<boolean>;
  metaRowClassGetter?: (params: any) => string | undefined;
  gridOptions?: ResolvedGridOptions | null;
  columnDefs?: Ref<ColDef[]>;
  onSelectionChanged?: (rows: any[]) => void;
  gridKey?: string | null;
}) {
  const { runtime } = params;
  const isUserEditing = params.isUserEditing ?? ref(false);
  const metaRowClassGetter = params.metaRowClassGetter;
  const gridOptions = params.gridOptions || null;

  const cellClassRules = DIRTY_CELL_CLASS_RULES;

  const defaultColDef: ColDef = {
    sortable: true,
    filter: true,
    resizable: true,
    editable: true,
    wrapText: true,
    autoHeight: true,
    cellClassRules
  };

  const autoSizeStrategy = undefined;
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
    const classes: string[] = [];
    if (isFlagTrue(params.data?._isDeleted)) classes.push('row-deleted');
    if (isFlagTrue(params.data?._isNew)) classes.push('row-new');
    const metaClass = metaRowClassGetter?.(params);
    if (metaClass) classes.push(metaClass);
    return classes.length > 0 ? classes.join(' ') : undefined;
  }

  const resolveGridKey = (key?: string | null) => key && key.trim().length > 0 ? key : 'masterGrid';
  const runtimeMasterKey = (runtime as any).masterGridKey?.value ?? (runtime as any).masterGridKey;
  const masterGridKey = resolveGridKey(params.gridKey ?? runtimeMasterKey);

  const { getMasterContextMenuItems } = useGridContextMenu({
    addMasterRow: runtime.addMasterRow || (() => {}),
    deleteMasterRow: runtime.deleteMasterRow || (() => {}),
    copyMasterRow: runtime.copyMasterRow || (() => {}),
    addDetailRow: runtime.addDetailRow || (() => {}),
    deleteDetailRow: runtime.deleteDetailRow || (() => {}),
    copyDetailRow: runtime.copyDetailRow || (() => {}),
    save: runtime.save || (() => {}),
    saveGridConfig: (runtime as any).saveGridConfig,
    masterGridKey
  });

  function onGridReady(params: GridReadyEvent) {
    if (runtime.masterGridApi) runtime.masterGridApi.value = params.api;
    const currentDefs = (params.api.getColumnDefs?.() as ColDef[] | undefined)
      ?? params.columnApi?.getAllGridColumns?.().map(col => col.getColDef())
      ?? [];
    const hasExplicitWidth = currentDefs.some(def => typeof def.width === 'number' && def.width > 0);
    if (gridOptions?.autoSizeColumns) {
      autoSizeColumnsOnReady(params.api, currentDefs, gridOptions);
    } else if (!hasExplicitWidth) {
      params.api.sizeColumnsToFit();
    }
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

  function onSelectionChanged() {
    const rows = runtime.masterGridApi?.value?.getSelectedRows?.() || [];
    params.onSelectionChanged?.(rows);
  }

  return {
    isUserEditing,
    cellClassRules,
    defaultColDef,
    gridOptions: buildGridRuntimeOptions(gridOptions),
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
    onCellClicked,
    onSelectionChanged
  };
}
