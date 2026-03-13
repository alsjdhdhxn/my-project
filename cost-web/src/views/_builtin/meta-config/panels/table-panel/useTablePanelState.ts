import { computed, inject, ref, watch } from 'vue';
import type { Ref } from 'vue';
import { useMessage } from 'naive-ui';
import type { DataTableColumns, DataTableRowKey } from 'naive-ui';
import type { CellValueChangedEvent, ColDef, GridApi, GridReadyEvent } from 'ag-grid-community';
import {
  deleteColumnMeta,
  deleteTableMeta,
  fetchAllTableMeta,
  fetchColumnsByTableId,
  fetchTablesByPageCode,
  fetchViewColumns,
  saveColumnMeta,
  saveTableMeta
} from '@/service/api/meta-config';

const COLUMN_VALIDATION_FIELDS = ['columnName', 'queryColumn', 'targetColumn'];
const COLUMN_DATA_TYPES = ['text', 'number', 'date', 'select', 'checkbox'];
const AUDIT_COLUMNS = new Set(['CREATE_TIME', 'UPDATE_TIME', 'CREATE_BY', 'UPDATE_BY', 'DELETED']);

const defaultColDef: ColDef = { sortable: true, resizable: true, flex: 0, suppressHeaderMenuButton: true };

const tableColDefs: ColDef[] = [
  { field: 'id', headerName: 'ID', width: 70, editable: false },
  { field: 'tableCode', headerName: 'tableCode', width: 140, editable: true },
  { field: 'tableName', headerName: '表名称', width: 140, editable: true },
  { field: 'queryView', headerName: 'queryView', width: 180, editable: true },
  { field: 'targetTable', headerName: 'targetTable', width: 180, editable: true },
  { field: 'sequenceName', headerName: '序列名', width: 160, editable: true },
  { field: 'pkColumn', headerName: '主键列', width: 100, editable: true },
  { field: 'parentTableCode', headerName: '父表Code', width: 130, editable: true },
  { field: 'parentFkColumn', headerName: '外键列', width: 120, editable: true }
];

const viewColTableColumns: DataTableColumns = [
  { type: 'selection' },
  { title: 'COLUMN_NAME', key: 'COLUMN_NAME', width: 200 },
  { title: 'DATA_TYPE', key: 'DATA_TYPE', width: 120 },
  { title: 'DATA_LENGTH', key: 'DATA_LENGTH', width: 100 },
  { title: 'DATA_PRECISION', key: 'DATA_PRECISION', width: 120 },
  { title: 'DATA_SCALE', key: 'DATA_SCALE', width: 100 },
  { title: 'COLUMN_ID', key: 'COLUMN_ID', width: 100 }
];

function normalizeDbColumnName(value: unknown) {
  return typeof value === 'string' ? value.trim().toUpperCase() : '';
}

function createNumericBooleanSetter(field: string) {
  return (params: any) => ((params.data[field] = params.newValue ? 1 : 0), true);
}

function buildDraftTableRow() {
  return {
    _isNew: true,
    id: null,
    tableCode: '',
    tableName: '',
    queryView: '',
    targetTable: '',
    sequenceName: '',
    pkColumn: 'ID',
    parentTableCode: '',
    parentFkColumn: ''
  };
}

function buildDraftColumnRow(tableMetadataId: number) {
  return {
    _isNew: true,
    id: null,
    tableMetadataId,
    columnName: '',
    queryColumn: '',
    targetColumn: '',
    headerText: '',
    dataType: 'text',
    displayOrder: 0,
    sortable: 1,
    filterable: 1,
    isVirtual: 0,
    dictType: ''
  };
}

function mapOracleType(oracleType: string) {
  if (!oracleType) return 'text';
  const typeName = oracleType.toUpperCase();
  if (['NUMBER', 'FLOAT', 'DECIMAL', 'INTEGER'].some(token => typeName.includes(token))) return 'number';
  if (typeName.includes('DATE') || typeName.includes('TIMESTAMP')) return 'date';
  return 'text';
}

function appendDraftRow(rowsRef: Ref<any[]>, apiRef: Ref<GridApi | null>, row: any, colKey: string) {
  rowsRef.value = [...rowsRef.value, row];
  setTimeout(() => {
    const rowIndex = rowsRef.value.length - 1;
    apiRef.value?.ensureIndexVisible(rowIndex);
    apiRef.value?.startEditingCell({ rowIndex, colKey });
  }, 100);
}

export function useTablePanelState() {
  const message = useMessage();
  const filterState = inject<Ref<{ tab: string; pageCode: string } | null>>('filterState');
  const tableGridApi = ref<GridApi | null>(null);
  const tableRows = ref<any[]>([]);
  const selectedTable = ref<any>(null);
  const colGridApi = ref<GridApi | null>(null);
  const colRows = ref<any[]>([]);
  const selectedCol = ref<any>(null);
  const queryViewColumnOptions = ref<Array<{ label: string; value: string }>>([]);
  const queryViewColumnSet = ref(new Set<string>());
  const targetTableColumnSet = ref(new Set<string>());
  const showViewColModal = ref(false);
  const viewColLoading = ref(false);
  const viewColRows = ref<any[]>([]);
  const viewColCheckedKeys = ref<DataTableRowKey[]>([]);
  let tableContextRequestSeq = 0;
  const viewImportTargetTableCols = new Set<string>();

  const hasSelectedTable = computed(() => Boolean(selectedTable.value));
  const hasSelectedColumn = computed(() => Boolean(selectedCol.value));
  const canImportColumns = computed(() => Boolean(selectedTable.value?.id && selectedTable.value?.queryView));

  function refreshColumnValidationCells(api: GridApi | null | undefined = colGridApi.value, node?: any) {
    api?.refreshCells({ rowNodes: node ? [node] : undefined, columns: COLUMN_VALIDATION_FIELDS, force: true });
  }

  function setColumnContext(options: string[] = [], targetColumns: Iterable<string> = [], rows: any[] = colRows.value) {
    colRows.value = rows;
    selectedCol.value = null;
    queryViewColumnOptions.value = options.map(value => ({ label: value, value }));
    queryViewColumnSet.value = new Set(options.map(value => value.toUpperCase()));
    targetTableColumnSet.value = new Set(targetColumns);
    refreshColumnValidationCells();
  }

  function getColumnNameState(row: any): 'normal' | 'invalid' | 'virtual' {
    if (!row) return 'normal';
    const columnName = normalizeDbColumnName(row.columnName);
    if (columnName && queryViewColumnSet.value.size > 0 && !queryViewColumnSet.value.has(columnName)) return 'invalid';
    return Number(row.isVirtual) === 1 ? 'virtual' : 'normal';
  }

  function getColumnNameCellStyle(params: any) {
    const state = getColumnNameState(params.data);
    if (state === 'invalid') return { backgroundColor: '#fff1f0', color: '#cf1322', fontWeight: '600' };
    if (state === 'virtual') return { backgroundColor: '#fffbe6', color: '#ad6800', fontWeight: '600' };
    return undefined;
  }

  function getColumnNameTooltip(params: any) {
    const state = getColumnNameState(params.data);
    if (state === 'invalid') {
      return Number(params.data?.isVirtual) === 1 ? '物理列不存在，当前仍标记为虚拟列' : '物理列不存在，且未标记为虚拟列';
    }
    return state === 'virtual' ? '虚拟列' : params.value || '';
  }

  function getAvailableColumnNameValues(row: any) {
    const currentValue = typeof row?.columnName === 'string' ? row.columnName.trim() : '';
    const usedByOthers = new Set(
      colRows.value
        .filter(item => item !== row)
        .map(item => normalizeDbColumnName(item?.columnName))
        .filter(Boolean)
    );
    const values = queryViewColumnOptions.value
      .map(option => option.value)
      .filter(value => !usedByOthers.has(normalizeDbColumnName(value)));

    if (currentValue && !values.some(value => normalizeDbColumnName(value) === normalizeDbColumnName(currentValue))) {
      values.unshift(currentValue);
    }
    return values;
  }

  function syncLinkedFieldsFromColumnName(row: any, oldColumnName: unknown, newColumnName: unknown) {
    if (!row) return;
    const nextColumnName = typeof newColumnName === 'string' ? newColumnName.trim() : '';
    const shouldSync = (value: unknown) => {
      const current = typeof value === 'string' ? value.trim() : '';
      const oldColumn = typeof oldColumnName === 'string' ? oldColumnName.trim() : '';
      return !current || (oldColumn && normalizeDbColumnName(current) === normalizeDbColumnName(oldColumn));
    };

    if (nextColumnName && shouldSync(row.queryColumn)) row.queryColumn = nextColumnName;
    if (!shouldSync(row.targetColumn)) return;
    row.targetColumn = nextColumnName && targetTableColumnSet.value.has(normalizeDbColumnName(nextColumnName)) ? nextColumnName : '';
  }

  function setColumnNameValue(params: any) {
    const row = params.data;
    const nextColumnName = typeof params.newValue === 'string' ? params.newValue.trim() : '';
    const oldColumnName = typeof row?.columnName === 'string' ? row.columnName.trim() : '';
    if (!row || oldColumnName === nextColumnName) return false;
    row.columnName = nextColumnName;
    row._dirty = true;
    syncLinkedFieldsFromColumnName(row, oldColumnName, nextColumnName);
    refreshColumnValidationCells(params.api, params.node);
    return true;
  }

  const colColDefs: ColDef[] = [
    { field: 'id', headerName: 'ID', width: 70, editable: false },
    {
      field: 'columnName',
      headerName: 'columnName',
      width: 140,
      editable: true,
      cellEditor: 'agSelectCellEditor',
      cellEditorParams: (params: any) => ({ values: getAvailableColumnNameValues(params.data) }),
      valueSetter: setColumnNameValue,
      cellStyle: getColumnNameCellStyle,
      tooltipValueGetter: getColumnNameTooltip
    },
    { field: 'queryColumn', headerName: 'queryColumn', width: 140, editable: true },
    { field: 'targetColumn', headerName: 'targetColumn', width: 130, editable: true },
    { field: 'headerText', headerName: '列标题', width: 120, editable: true },
    {
      field: 'dataType',
      headerName: '数据类型',
      width: 100,
      editable: true,
      cellEditor: 'agSelectCellEditor',
      cellEditorParams: { values: COLUMN_DATA_TYPES }
    },
    { field: 'displayOrder', headerName: '排序', width: 70, editable: true, cellDataType: 'number' },
    {
      field: 'sortable',
      headerName: '可排序',
      width: 80,
      editable: true,
      cellRenderer: 'agCheckboxCellRenderer',
      cellEditor: 'agCheckboxCellEditor',
      valueGetter: (params: any) => params.data?.sortable === 1,
      valueSetter: createNumericBooleanSetter('sortable')
    },
    {
      field: 'filterable',
      headerName: '可筛选',
      width: 80,
      editable: true,
      cellRenderer: 'agCheckboxCellRenderer',
      cellEditor: 'agCheckboxCellEditor',
      valueGetter: (params: any) => params.data?.filterable === 1,
      valueSetter: createNumericBooleanSetter('filterable')
    },
    {
      field: 'isVirtual',
      headerName: '虚拟列',
      width: 80,
      editable: true,
      cellRenderer: 'agCheckboxCellRenderer',
      cellEditor: 'agCheckboxCellEditor',
      valueGetter: (params: any) => params.data?.isVirtual === 1,
      valueSetter: createNumericBooleanSetter('isVirtual')
    },
    { field: 'dictType', headerName: '字典类型', width: 120, editable: true }
  ];

  async function loadPhysicalColumnContext(tableRow: any) {
    const [queryRows, targetRows] = await Promise.all([
      tableRow?.queryView ? fetchViewColumns(tableRow.queryView) : Promise.resolve([]),
      tableRow?.targetTable ? fetchViewColumns(tableRow.targetTable) : Promise.resolve([])
    ]);
    const queryColumns = (queryRows || []).map((row: any) => String(row.COLUMN_NAME || '').trim()).filter(Boolean);
    return {
      queryColumns,
      targetColumns: (targetRows || []).map((row: any) => normalizeDbColumnName(row.COLUMN_NAME)).filter(Boolean)
    };
  }

  async function loadSelectedTableContext(tableRow: any) {
    const requestSeq = ++tableContextRequestSeq;
    if (!tableRow?.id) {
      setColumnContext([], []);
      return;
    }

    try {
      const [columnRows, physicalContext] = await Promise.all([
        fetchColumnsByTableId(tableRow.id),
        loadPhysicalColumnContext(tableRow)
      ]);
      if (requestSeq !== tableContextRequestSeq || selectedTable.value?.id !== tableRow.id) return;
      setColumnContext(physicalContext.queryColumns, physicalContext.targetColumns, columnRows || []);
      setTimeout(() => colGridApi.value?.autoSizeAllColumns(), 100);
    } catch {
      if (requestSeq !== tableContextRequestSeq) return;
      setColumnContext([], []);
      message.error('加载列元数据失败');
    }
  }

  async function refreshPhysicalColumnsForSelectedTable(tableRow: any) {
    const requestSeq = ++tableContextRequestSeq;
    try {
      const physicalContext = tableRow?.id ? await loadPhysicalColumnContext(tableRow) : { queryColumns: [], targetColumns: [] };
      if (requestSeq !== tableContextRequestSeq || selectedTable.value?.id !== tableRow?.id) return;
      setColumnContext(physicalContext.queryColumns, physicalContext.targetColumns);
    } catch {
      if (requestSeq !== tableContextRequestSeq) return;
      setColumnContext([], []);
      message.error('加载物理列失败');
    }
  }

  function applyTableRows(rows: any[], selectedTableId?: number | null) {
    tableRows.value = rows;
    selectedTable.value = null;
    setColumnContext([], []);
    setTimeout(() => {
      tableGridApi.value?.autoSizeAllColumns();
      if (!rows.length) return;
      let matchedNode: any = null;
      if (selectedTableId != null) {
        tableGridApi.value?.forEachNode?.((node: any) => {
          if (!matchedNode && node?.data?.id === selectedTableId) matchedNode = node;
        });
      }
      (matchedNode ?? tableGridApi.value?.getDisplayedRowAtIndex(0))?.setSelected?.(true, true);
    }, 100);
  }

  async function reloadTables(selectedTableId?: number | null, pageCode?: string) {
    try {
      const rows = pageCode ? await fetchTablesByPageCode(pageCode) : (await fetchAllTableMeta()) || [];
      if (pageCode && !rows.length) message.warning(`pageCode="${pageCode}" 未关联任何表`);
      applyTableRows(rows, pageCode ? rows[0]?.id ?? null : selectedTableId);
    } catch {
      message.error(pageCode ? '查询关联表失败' : '加载表元数据失败');
    }
  }

  function loadTables(selectedTableId?: number | null) {
    return reloadTables(selectedTableId);
  }

  async function saveDirtyRows(params: {
    gridApi: Ref<GridApi | null>;
    rows: any[];
    validate: (row: any) => string | null;
    saveRow: (row: any) => Promise<any>;
    successLabel: string;
    reload: () => Promise<void>;
  }) {
    params.gridApi.value?.stopEditing();
    const dirtyRows = params.rows.filter(row => row._dirty || row._isNew);
    if (!dirtyRows.length) return void message.info('没有需要保存的修改');
    for (const row of dirtyRows) {
      const errorMessage = params.validate(row);
      if (errorMessage) return void message.warning(errorMessage);
    }
    try {
      await Promise.all(dirtyRows.map(params.saveRow));
      message.success(`已保存 ${dirtyRows.length} 条${params.successLabel}`);
      await params.reload();
    } catch {
      message.error('保存失败');
    }
  }

  function addTable() {
    appendDraftRow(tableRows, tableGridApi, buildDraftTableRow(), 'tableCode');
  }

  function saveTable() {
    return saveDirtyRows({
      gridApi: tableGridApi,
      rows: tableRows.value,
      validate: row => (!row.tableCode || !row.tableName ? 'tableCode和表名称不能为空' : null),
      saveRow: saveTableMeta,
      successLabel: '表记录',
      reload: () => loadTables(selectedTable.value?.id ?? null)
    });
  }

  async function removeTable() {
    if (!selectedTable.value) return;
    if (selectedTable.value._isNew) {
      tableRows.value = tableRows.value.filter(row => row !== selectedTable.value);
      selectedTable.value = null;
      return void setColumnContext([], []);
    }
    try {
      await deleteTableMeta(selectedTable.value.id);
      message.success('删除成功');
      tableContextRequestSeq++;
      await loadTables();
    } catch {
      message.error('删除失败');
    }
  }

  function addColumn() {
    if (!selectedTable.value?.id) return void message.warning('请先选中一个表');
    appendDraftRow(colRows, colGridApi, buildDraftColumnRow(selectedTable.value.id), 'columnName');
  }

  async function openViewColModal() {
    if (!selectedTable.value?.id) return void message.warning('请先选中一个表');
    if (!selectedTable.value.queryView) return void message.warning('当前表未配置 queryView');
    showViewColModal.value = true;
    viewColLoading.value = true;
    viewColCheckedKeys.value = [];
    viewImportTargetTableCols.clear();

    try {
      const [viewRows, targetRows] = await Promise.all([
        fetchViewColumns(selectedTable.value.queryView),
        selectedTable.value.targetTable ? fetchViewColumns(selectedTable.value.targetTable) : Promise.resolve([])
      ]);
      (targetRows || []).forEach((row: any) => viewImportTargetTableCols.add(String(row.COLUMN_NAME || '').toUpperCase()));

      const existingCols = new Set(colRows.value.map((col: any) => String(col.columnName || '').toUpperCase()));
      viewColRows.value = (viewRows || [])
        .filter((row: any) => {
          const columnName = String(row.COLUMN_NAME || '').toUpperCase();
          return !existingCols.has(columnName) && !AUDIT_COLUMNS.has(columnName);
        })
        .map((row: any) => ({ ...row, _key: row.COLUMN_NAME }));
    } catch {
      viewColRows.value = [];
      message.error('查询视图列失败');
    } finally {
      viewColLoading.value = false;
    }
  }

  function closeViewColModal() {
    showViewColModal.value = false;
  }

  function confirmAddViewCols() {
    if (!viewColCheckedKeys.value.length) return void message.warning('请至少选择一列');
    const existingOrder = colRows.value.length;
    const newRows = viewColRows.value
      .filter(row => viewColCheckedKeys.value.includes(row._key))
      .map((row, index) => {
        const columnName = row.COLUMN_NAME;
        const inTargetTable = viewImportTargetTableCols.has(String(columnName || '').toUpperCase());
        return {
          _isNew: true,
          id: null,
          tableMetadataId: selectedTable.value.id,
          columnName,
          queryColumn: columnName,
          targetColumn: inTargetTable ? columnName : '',
          headerText: columnName,
          dataType: mapOracleType(row.DATA_TYPE),
          displayOrder: existingOrder + index + 1,
          sortable: 1,
          filterable: 1,
          isVirtual: inTargetTable ? 0 : 1,
          dictType: ''
        };
      });

    colRows.value = [...colRows.value, ...newRows];
    closeViewColModal();
    setTimeout(() => colGridApi.value?.autoSizeAllColumns(), 100);
    message.success(`已添加 ${newRows.length} 列，请编辑后保存`);
  }

  function saveColumn() {
    return saveDirtyRows({
      gridApi: colGridApi,
      rows: colRows.value,
      validate: row => (!row.columnName ? 'columnName不能为空' : null),
      saveRow: saveColumnMeta,
      successLabel: '列记录',
      reload: async () => {
        if (selectedTable.value?.id) await loadSelectedTableContext(selectedTable.value);
      }
    });
  }

  async function removeColumn() {
    if (!selectedCol.value) return;
    if (selectedCol.value._isNew) {
      colRows.value = colRows.value.filter(row => row !== selectedCol.value);
      selectedCol.value = null;
      return;
    }
    try {
      await deleteColumnMeta(selectedCol.value.id);
      message.success('删除成功');
      if (selectedTable.value?.id) await loadSelectedTableContext(selectedTable.value);
    } catch {
      message.error('删除失败');
    }
  }

  function markDirty(event: CellValueChangedEvent) {
    if (event.data) event.data._dirty = true;
    const field = event.colDef?.field;
    if (event.api === colGridApi.value && (field === 'columnName' || field === 'isVirtual')) {
      if (field === 'columnName') syncLinkedFieldsFromColumnName(event.data, event.oldValue, event.newValue);
      refreshColumnValidationCells(event.api, event.node);
    }
    if (event.api === tableGridApi.value && (field === 'queryView' || field === 'targetTable') && selectedTable.value === event.data) {
      void refreshPhysicalColumnsForSelectedTable(event.data);
    }
  }

  function onTableGridReady(params: GridReadyEvent) {
    tableGridApi.value = params.api;
    params.api.autoSizeAllColumns();
  }

  function onColGridReady(params: GridReadyEvent) {
    colGridApi.value = params.api;
    params.api.autoSizeAllColumns();
  }

  function onTableSelectionChanged() {
    selectedTable.value = tableGridApi.value?.getSelectedRows?.()[0] || null;
  }

  function onColSelectionChanged() {
    selectedCol.value = colGridApi.value?.getSelectedRows?.()[0] || null;
  }

  function onRowClicked(event: any) {
    if (event.node?.data) event.node.setSelected(true, true);
  }

  watch(selectedTable, tableRow => {
    void loadSelectedTableContext(tableRow);
  });

  watch(
    () => filterState?.value,
    async state => {
      await reloadTables(undefined, state?.tab === 'table' ? state.pageCode : undefined);
    },
    { immediate: true }
  );

  return {
    tableRows,
    selectedTable,
    tableColDefs,
    colRows,
    colColDefs,
    defaultColDef,
    hasSelectedTable,
    hasSelectedColumn,
    canImportColumns,
    loadTables,
    addTable,
    removeTable,
    saveTable,
    addColumn,
    removeColumn,
    saveColumn,
    markDirty,
    onTableGridReady,
    onTableSelectionChanged,
    onTableRowClicked: onRowClicked,
    onColGridReady,
    onColSelectionChanged,
    onColRowClicked: onRowClicked,
    showViewColModal,
    viewColLoading,
    viewColRows,
    viewColCheckedKeys,
    viewColTableColumns,
    openViewColModal,
    closeViewColModal,
    confirmAddViewCols
  };
}
