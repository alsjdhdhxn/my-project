/**
 * AG Grid 适配器
 * 负责 Store ↔ Grid 双向同步
 */
import { ref, watch, type Ref, type ShallowRef } from 'vue';
import type { GridApi, CellValueChangedEvent, CellEditingStartedEvent, CellEditingStoppedEvent } from 'ag-grid-community';
import type { RowData } from '@/logic/calc-engine';

// ==================== 类型定义 ====================

export interface GridAdapterOptions {
  /** Grid API 引用 */
  gridApi: Ref<GridApi | null> | ShallowRef<GridApi | null>;
  /** 行数据 getter */
  rowsGetter: () => RowData[];
  /** 主键字段，默认 'id' */
  pkField?: string;
  /** 字段更新回调 */
  onFieldUpdate?: (rowId: number, field: string, value: any) => void;
}

export interface EditingCell {
  rowId: number;
  field: string;
}

// ==================== 单元格样式规则 ====================

/**
 * 获取单元格样式规则（用于 AG Grid cellClassRules）
 */
export function getCellClassRules() {
  return {
    'cell-user-changed': (params: any) => {
      const changeType = params.data?._changeType;
      const field = params.colDef?.field;
      return changeType?.[field] === 'user';
    },
    'cell-cascade-changed': (params: any) => {
      const changeType = params.data?._changeType;
      const field = params.colDef?.field;
      return changeType?.[field] === 'cascade';
    },
    'cell-new-row': (params: any) => {
      return params.data?._isNew === true;
    }
  };
}

/**
 * 获取单元格样式 CSS
 */
export const cellStyleCSS = `
.cell-user-changed {
  background-color: #e6ffe6 !important;
}
.cell-cascade-changed {
  background-color: #fffde6 !important;
}
.cell-new-row {
  background-color: #f0f9ff !important;
}
`;

// ==================== 适配器 ====================

/**
 * 创建 Grid 适配器
 */
export function useGridAdapter(options: GridAdapterOptions) {
  const { gridApi, rowsGetter, pkField = 'id', onFieldUpdate } = options;

  // 当前正在编辑的单元格
  const editingCell = ref<EditingCell | null>(null);

  // 监听数据变化，同步到 Grid
  watch(
    rowsGetter,
    newRows => {
      syncToGrid(newRows);
    },
    { deep: true }
  );

  /**
   * 同步数据到 Grid（使用 applyTransaction 增量更新）
   */
  function syncToGrid(newRows: RowData[]) {
    const api = gridApi.value;
    if (!api) return;

    // 获取当前 Grid 中的行 ID
    const currentIds = new Set<number>();
    api.forEachNode(node => {
      if (node.data?.[pkField] != null) {
        currentIds.add(node.data[pkField]);
      }
    });

    // 分类：新增、更新、删除
    const toAdd: RowData[] = [];
    const toUpdate: RowData[] = [];
    const toRemove: RowData[] = [];

    const newIds = new Set<number>();
    for (const row of newRows) {
      const rowId = row[pkField];
      if (rowId == null) continue;

      newIds.add(rowId);

      if (currentIds.has(rowId)) {
        toUpdate.push(row);
      } else {
        toAdd.push(row);
      }
    }

    // 找出需要删除的行
    api.forEachNode(node => {
      const rowId = node.data?.[pkField];
      if (rowId != null && !newIds.has(rowId)) {
        toRemove.push(node.data);
      }
    });

    // 应用事务
    if (toAdd.length > 0 || toUpdate.length > 0 || toRemove.length > 0) {
      api.applyTransaction({
        add: toAdd,
        update: toUpdate,
        remove: toRemove
      });
    }

    // 刷新单元格样式（排除正在编辑的单元格）
    refreshCellStyles(api);
  }

  /**
   * 刷新单元格样式
   */
  function refreshCellStyles(api: GridApi) {
    const rowNodes: any[] = [];

    api.forEachNode(node => {
      // 正在编辑的行，只刷新非编辑列
      if (editingCell.value && node.data?.[pkField] === editingCell.value.rowId) {
        const columns = Object.keys(node.data || {}).filter(
          c => c !== editingCell.value!.field && !c.startsWith('_')
        );
        if (columns.length > 0) {
          api.refreshCells({
            rowNodes: [node],
            columns,
            force: true
          });
        }
      } else {
        rowNodes.push(node);
      }
    });

    if (rowNodes.length > 0) {
      api.refreshCells({ rowNodes, force: true });
    }
  }

  /**
   * 单元格值变化事件处理
   */
  function onCellValueChanged(event: CellValueChangedEvent) {
    const field = event.colDef.field;
    const rowId = event.data?.[pkField];

    if (!field || rowId == null) return;

    // 通知 Store 更新（会设置 _changeType）
    onFieldUpdate?.(rowId, field, event.newValue);

    // 刷新当前单元格样式（因为 _changeType 是在值变化后才设置的）
    const api = gridApi.value;
    if (api && event.node) {
      api.refreshCells({
        rowNodes: [event.node],
        columns: [field],
        force: true
      });
    }
  }

  /**
   * 开始编辑事件处理
   */
  function onCellEditingStarted(event: CellEditingStartedEvent) {
    const rowId = event.data?.[pkField];
    const field = event.colDef?.field;

    if (rowId != null && field) {
      editingCell.value = { rowId, field };
    }
  }

  /**
   * 结束编辑事件处理
   */
  function onCellEditingStopped(_event: CellEditingStoppedEvent) {
    editingCell.value = null;
  }

  /**
   * 强制刷新 Grid
   */
  function forceRefresh() {
    const api = gridApi.value;
    if (!api) return;

    api.refreshCells({ force: true });
  }

  /**
   * 设置行数据（完全替换）
   */
  function setRowData(rows: RowData[]) {
    const api = gridApi.value;
    if (!api) return;

    api.setGridOption('rowData', rows);
  }

  return {
    editingCell,
    onCellValueChanged,
    onCellEditingStarted,
    onCellEditingStopped,
    forceRefresh,
    setRowData,
    syncToGrid
  };
}

export type GridAdapter = ReturnType<typeof useGridAdapter>;
