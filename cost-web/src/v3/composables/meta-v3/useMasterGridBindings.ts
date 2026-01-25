import { ref, type Ref, watch } from 'vue';
import type { ColDef, GridReadyEvent, CellValueChangedEvent } from 'ag-grid-community';
import { useGridContextMenu } from '@/v3/composables/meta-v3/useGridContextMenu';
import type { ContextMenuRule, RowEditableRule, RowClassRule } from '@/v3/composables/meta-v3/types';
import { buildRowEditableCallback, buildRowClassCallback } from '@/v3/composables/meta-v3/usePageRules';
import {
  buildGridRuntimeOptions,
  autoSizeColumnsOnReady,
  type ResolvedGridOptions
} from '@/v3/composables/meta-v3/grid-options';
import { DIRTY_CELL_CLASS_RULES, isFlagTrue } from '@/v3/composables/meta-v3/cell-style';
import type { CustomExportConfig } from '@/service/api/export-config';

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
  customExportConfigs?: Ref<CustomExportConfig[]> | CustomExportConfig[];
  executeCustomExport?: (exportCode: string, mode: 'all' | 'current') => void;
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
  contextMenuConfig?: ContextMenuRule | null;
  rowEditableRules?: RowEditableRule[];
  rowClassRules?: RowClassRule[];
  dataSource?: any;
}) {
  const { runtime } = params;
  const isUserEditing = params.isUserEditing ?? ref(false);
  const metaRowClassGetter = params.metaRowClassGetter;
  const gridOptions = params.gridOptions || null;

  const cellClassRules = DIRTY_CELL_CLASS_RULES;
  const rowEditableRules = params.rowEditableRules
    ?? (runtime as any).masterRowEditableRules?.value
    ?? [];
  const rowEditableCallback = buildRowEditableCallback(rowEditableRules);

  const defaultColDef: ColDef = {
    sortable: true,
    filter: 'agTextColumnFilter',
    resizable: true,
    editable: rowEditableCallback ?? true,
    wrapHeaderText: true,
    autoHeaderHeight: true,
    cellClassRules,
    suppressHeaderMenuButton: true
  };

  function wrapColumnEditable(def: ColDef, callback: (params: any) => boolean) {
    if (!def || (def as any).__rowEditableWrapped) return;
    const existing = def.editable;
    def.editable = (params: any) => {
      const base = typeof existing === 'function' ? existing(params) : existing === false ? false : true;
      return base && callback(params);
    };
    (def as any).__rowEditableWrapped = true;
  }

  if (rowEditableCallback && params.columnDefs) {
    watch(
      params.columnDefs,
      (defs) => {
        if (!Array.isArray(defs)) return;
        defs.forEach(def => wrapColumnEditable(def, rowEditableCallback));
      },
      { immediate: true }
    );
  }

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

  // Row class rules (from ROW_CLASS config).
  const rowClassRules = params.rowClassRules ?? (runtime as any).masterRowClassRules?.value ?? [];
  const rowClassCallback = buildRowClassCallback(rowClassRules);
  const dataSource = params.dataSource;

  function getRowClass(params: any): string | undefined {
    const classes: string[] = [];
    if (isFlagTrue(params.data?._isDeleted)) classes.push('row-deleted');
    if (isFlagTrue(params.data?._isNew)) classes.push('row-new');
    // 应用 ROW_CLASS 规则
    const ruleClass = rowClassCallback?.(params);
    if (ruleClass) classes.push(ruleClass);
    // 应用元数据样式
    const metaClass = metaRowClassGetter?.(params);
    if (metaClass) classes.push(metaClass);
    return classes.length > 0 ? classes.join(' ') : undefined;
  }

  const resolveGridKey = (key?: string | null) => key && key.trim().length > 0 ? key : 'masterGrid';
  const runtimeMasterKey = (runtime as any).masterGridKey?.value ?? (runtime as any).masterGridKey;
  const masterGridKey = resolveGridKey(params.gridKey ?? runtimeMasterKey);

  const { getMasterContextMenuItems } = useGridContextMenu({
    addMasterRow: runtime.addMasterRow || (() => { }),
    deleteMasterRow: runtime.deleteMasterRow || (() => { }),
    copyMasterRow: runtime.copyMasterRow || (() => { }),
    addDetailRow: runtime.addDetailRow || (() => { }),
    deleteDetailRow: runtime.deleteDetailRow || (() => { }),
    copyDetailRow: runtime.copyDetailRow || (() => { }),
    save: runtime.save || (() => { }),
    saveGridConfig: (runtime as any).saveGridConfig,
    customExportConfigs: runtime.customExportConfigs,
    executeCustomExport: runtime.executeCustomExport,
    masterGridKey,
    masterMenuConfig: params.contextMenuConfig
  });

  function onGridReady(params: GridReadyEvent) {
    if (runtime.masterGridApi) runtime.masterGridApi.value = params.api;
    // V3 强制使用 SSRM
    if (dataSource) {
      params.api.setGridOption('serverSideDatasource', dataSource);
    }
    const currentDefs = (params.api.getColumnDefs?.() as ColDef[] | undefined) ?? [];
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

  function onFilterChanged() {
    const api = runtime.masterGridApi?.value;
    if (!api) return;
    // V3 强制使用 SSRM: 清除缓存并重新请求
    api.refreshServerSide?.({ purge: true });
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
    onSelectionChanged,
    onFilterChanged
  };
}
