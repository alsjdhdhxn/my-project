import { type Ref, ref, watch } from 'vue';
import type { CellValueChangedEvent, ColDef, GridReadyEvent } from 'ag-grid-community';
import type { CustomExportConfig } from '@/service/api/export-config';
import { useGridContextMenu } from '@/v3/composables/meta-v3/useGridContextMenu';
import type { CellEditableRule, ContextMenuRule, RowClassRule, RowEditableRule } from '@/v3/composables/meta-v3/types';
import {
  buildCellEditableCallback,
  buildRowClassCallback,
  buildRowEditableCallback,
  buildRowStyleCallback,
  computeSumRow
} from '@/v3/composables/meta-v3/usePageRules';
import {
  type ResolvedGridOptions,
  autoSizeColumnsOnReady,
  buildGridRuntimeOptions
} from '@/v3/composables/meta-v3/grid-options';
import { DIRTY_CELL_CLASS_RULES, isFlagTrue } from '@/v3/composables/meta-v3/cell-style';
import { ensureRowKey } from '@/v3/logic/calc-engine';

// 用于追踪已包装 editable 的列定义
const wrappedEditableColumns = new WeakSet<ColDef>();

type RuntimeApi = {
  masterGridApi?: Ref<any>;
  masterGridKey?: Ref<string | null> | string | null;
  broadcastFields?: Ref<string[]>;
  addMasterRow?: () => void;
  deleteMasterRow?: (row: any) => void;
  copyMasterRow?: (row: any) => void;
  addDetailRow?: (masterId: number, tabKey: string, masterRowKey?: string) => void;
  deleteDetailRow?: (masterId: number, tabKey: string, row: any, masterRowKey?: string) => void;
  copyDetailRow?: (masterId: number, tabKey: string, row: any, masterRowKey?: string) => void;
  save?: () => void;
  saveGridConfig?: (gridKey: string, api: any, columnApi: any) => void;
  applyGridConfig?: (gridKey: string, api: any, columnApi: any) => void;
  customExportConfigs?: Ref<CustomExportConfig[]> | CustomExportConfig[];
  executeCustomExport?: (exportCode: string, mode: 'all' | 'current') => void;
  executeAction?: (
    actionCode: string,
    options?: { data?: Record<string, any>; selectedRow?: Record<string, any> | null }
  ) => Promise<void>;
  markFieldChange?: (row: any, field: string, oldValue: any, newValue: any, type: 'user' | 'calc') => void;
  runMasterCalc?: (node: any, row: any, valueOverrides?: Record<string, any>) => string[] | void;
  broadcastToDetail?: (masterId: number, row: any, changedFields?: string | string[]) => Promise<void> | void;
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
  cellEditableRules?: CellEditableRule[];
  rowClassRules?: RowClassRule[];
  dataSource?: any;
  sumFields?: string[];
  notifyError?: (message: string) => void;
}) {
  const { runtime } = params;
  const isUserEditing = params.isUserEditing ?? ref(false);
  const metaRowClassGetter = params.metaRowClassGetter;
  const gridOptions = params.gridOptions || null;

  const cellClassRules = DIRTY_CELL_CLASS_RULES;

  // 缓存 editable 回调，规则变化时自动重建
  let _cachedCellRules: any = null;
  let _cachedRowRules: any = null;
  let _cachedEditableCallback: ((params: any) => boolean) | undefined;

  function getEditableCallback(): ((params: any) => boolean) | undefined {
    const cellRules = (runtime as any).masterCellEditableRules?.value ?? params.cellEditableRules ?? [];
    const rowRules = (runtime as any).masterRowEditableRules?.value ?? params.rowEditableRules ?? [];
    // 规则引用没变就复用缓存
    if (cellRules === _cachedCellRules && rowRules === _cachedRowRules) {
      return _cachedEditableCallback;
    }
    _cachedCellRules = cellRules;
    _cachedRowRules = rowRules;
    if (cellRules.length > 0) {
      _cachedEditableCallback = buildCellEditableCallback(cellRules, rowRules);
    } else if (rowRules.length > 0) {
      _cachedEditableCallback = buildRowEditableCallback(rowRules);
    } else {
      _cachedEditableCallback = undefined;
    }
    return _cachedEditableCallback;
  }

  // 初始回调（用于 contextMenu 等需要引用的地方）
  const editableCallback = getEditableCallback();

  const defaultColDef: ColDef = {
    sortable: true,
    filter: 'agTextColumnFilter',
    resizable: true,
    editable: (p: any) => {
      // 汇总行不可编辑
      if (p.node?.rowPinned) return false;
      const cb = getEditableCallback();
      if (cb) return cb(p);
      return true;
    },
    wrapHeaderText: true,
    autoHeaderHeight: true,
    cellClassRules,
    suppressHeaderMenuButton: true
  };

  function wrapColumnEditable(def: ColDef) {
    if (!def || wrappedEditableColumns.has(def)) return;
    const existing = def.editable;
    def.editable = (params: any) => {
      const base = typeof existing === 'function' ? existing(params) : existing !== false;
      // 动态获取最新的 editable 回调，确保 WebSocket 推送后规则立即生效
      const cb = getEditableCallback();
      if (cb) return base && cb(params);
      return base;
    };
    wrappedEditableColumns.add(def);
  }

  // 始终 watch columnDefs，因为规则可能通过 WebSocket 动态添加
  if (params.columnDefs) {
    watch(
      params.columnDefs,
      defs => {
        if (!Array.isArray(defs)) return;
        defs.forEach(def => wrapColumnEditable(def));
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

  const getRowId = (params: any) => {
    const row = params.data;
    if (!row) return '';
    ensureRowKey(row);
    const rowKey = String(row._rowKey ?? '');
    return rowKey;
  };

  // Row class/style rules (from GRID_STYLE config).
  // 动态获取最新规则，确保 WebSocket 推送后样式立即生效
  let _cachedStyleRules: any = null;
  let _cachedRowClassCallback: ((params: any) => string | undefined) | undefined;
  let _cachedRowStyleCallback: ((params: any) => Record<string, string> | undefined) | undefined;

  function getLatestRowClassCallback() {
    const rules = (runtime as any).masterRowClassRules?.value ?? params.rowClassRules ?? [];
    if (rules === _cachedStyleRules) return _cachedRowClassCallback;
    _cachedStyleRules = rules;
    _cachedRowClassCallback = buildRowClassCallback(rules);
    _cachedRowStyleCallback = buildRowStyleCallback(rules);
    return _cachedRowClassCallback;
  }

  function getLatestRowStyleCallback() {
    const rules = (runtime as any).masterRowClassRules?.value ?? params.rowClassRules ?? [];
    if (rules !== _cachedStyleRules) {
      _cachedStyleRules = rules;
      _cachedRowClassCallback = buildRowClassCallback(rules);
      _cachedRowStyleCallback = buildRowStyleCallback(rules);
    }
    return _cachedRowStyleCallback;
  }

  const dataSource = params.dataSource;
  const sumFields = params.sumFields ?? (runtime as any).masterSumFields?.value ?? [];

  /** 更新主表底部汇总行（从当前已渲染的行数据直接计算） */
  function updatePinnedSumRow() {
    if (!sumFields.length) return;
    const api = runtime.masterGridApi?.value;
    if (!api) return;
    // SSRM 下 forEachNode 不可靠，改用 getRenderedNodes 取当前已加载的行
    const renderedNodes = api.getRenderedNodes?.() ?? [];
    const allRows: any[] = [];
    for (const node of renderedNodes) {
      if (node.data && !node.rowPinned) allRows.push(node.data);
    }
    const sumRow = computeSumRow(allRows, sumFields);
    api.setGridOption('pinnedBottomRowData', sumRow ? [sumRow] : []);
  }

  function getRowClass(params: any): string | undefined {
    const classes: string[] = [];
    if (isFlagTrue(params.data?._isDeleted)) classes.push('row-deleted');
    if (isFlagTrue(params.data?._isNew)) classes.push('row-new');
    // 应用 ROW_CLASS 规则（动态获取最新回调）
    const ruleClass = getLatestRowClassCallback()?.(params);
    if (ruleClass) classes.push(ruleClass);
    // 应用元数据样式
    const metaClass = metaRowClassGetter?.(params);
    if (metaClass) classes.push(metaClass);
    return classes.length > 0 ? classes.join(' ') : undefined;
  }

  function getRowStyle(params: any): Record<string, string> | undefined {
    return getLatestRowStyleCallback()?.(params);
  }

  const resolveGridKey = (key?: string | null) => (key && key.trim().length > 0 ? key : 'masterGrid');
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
    customExportConfigs: runtime.customExportConfigs,
    executeCustomExport: runtime.executeCustomExport,
    executeAction: runtime.executeAction,
    masterGridKey,
    masterMenuConfig: params.contextMenuConfig,
    isRowEditable: editableCallback ? (row: any) => editableCallback({ data: row, colDef: {} }) : undefined,
    notifyError: params.notifyError
  });

  function onGridReady(params: GridReadyEvent) {
    if (runtime.masterGridApi) runtime.masterGridApi.value = params.api;
    params.api.addEventListener('columnVisible', (event: any) => {
      const colId = String(event?.column?.getColId?.() ?? '').trim();
      if (!colId) return;
      const lockedByConfig = new Set<string>((params.api as any)?.__lockedHiddenColumns || []);
      const defs = (params.api.getColumnDefs?.() as ColDef[] | undefined) ?? [];
      defs.forEach(def => {
        const field = String(def?.field ?? '').trim();
        if (!field) return;
        if (def.lockVisible === true || (def as any).suppressColumnsToolPanel === true) {
          lockedByConfig.add(field);
        }
      });
      if (!lockedByConfig.has(colId)) return;
      const visible = event?.visible === true || event?.column?.isVisible?.() === true;
      if (!visible) return;
      params.api.applyColumnState({
        state: [{ colId, hide: true }],
        applyOrder: false
      });
    });
    // V3 强制使用 SSRM - 每次 grid-ready 都设置 datasource
    console.log('[DEBUG] onGridReady - dataSource:', dataSource ? 'exists' : 'null');
    if (dataSource) {
      params.api.setGridOption('serverSideDatasource', dataSource);
      console.log('[DEBUG] serverSideDatasource set successfully');
    }
    const currentDefs = (params.api.getColumnDefs?.() as ColDef[] | undefined) ?? [];
    const hasExplicitWidth = currentDefs.some(def => typeof def.width === 'number' && def.width > 0);
    if (gridOptions?.autoSizeColumns) {
      autoSizeColumnsOnReady(params.api, currentDefs, gridOptions);
    } else if (!hasExplicitWidth) {
      params.api.sizeColumnsToFit();
    }
    // SSRM 数据加载后更新汇总行
    if (sumFields.length) {
      params.api.addEventListener('modelUpdated', () => updatePinnedSumRow());
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
    if (!field || masterId == null || event.node?.rowPinned) return;
    if (Object.is(event.oldValue, event.newValue)) return;

    // Ensure downstream calc always reads the latest user-entered value.
    if (!Object.is(row?.[field], event.newValue)) {
      row[field] = event.newValue;
    }

    const source = String((event as any)?.source || '').toLowerCase();
    const isApiChange = source === 'api' || source === 'rowdatachanged';
    const changeType = isApiChange ? 'calc' : 'user';
    runtime.markFieldChange?.(row, field, event.oldValue, event.newValue, changeType);
    runtime.masterGridApi?.value?.refreshCells({ rowNodes: [event.node], columns: [field], force: true });

    if (!isApiChange) {
      const calcChanged = runtime.runMasterCalc?.(event.node, row, { [field]: event.newValue }) || [];
      const changedFields = [field, ...calcChanged].filter(Boolean);
      await runtime.broadcastToDetail?.(masterId, row, changedFields);
    }

    // 任何单元格变化后都重算汇总（calc 联动可能改了求和字段）
    if (sumFields.length) {
      updatePinnedSumRow();
    }
  }

  function onCellClicked(event: any) {
    // 汇总行不响应点击
    if (event.node?.rowPinned) return;
    runtime.onMasterCellClicked?.(event);
  }

  function onSelectionChanged() {
    const rows = runtime.masterGridApi?.value?.getSelectedRows?.() || [];
    params.onSelectionChanged?.(rows);
  }

  function onFilterChanged() {
    // V3 SSRM: AG Grid 会自动感知 filterModel 变化并触发 getRows
    // 无需手动调用 refreshServerSide，否则会导致双重请求
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
    getRowStyle,
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
