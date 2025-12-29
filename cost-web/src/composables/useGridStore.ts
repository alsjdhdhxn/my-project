/**
 * 通用表格数据存储
 * 支持单表、主从、多Tab场景
 */
import { ref, computed, type Ref } from 'vue';

export interface RowData {
  id: number | null;
  _changeType?: Record<string, 'user' | 'cascade'>;
  _originalValues?: Record<string, any>;
  _isNew?: boolean;
  _isDeleted?: boolean;
  [key: string]: any;
}

export interface GridStoreOptions {
  /** 主键字段，默认 'id' */
  pkField?: string;
}

export function useGridStore<T extends RowData = RowData>(options: GridStoreOptions = {}) {
  const { pkField = 'id' } = options;

  const rows: Ref<T[]> = ref([]);
  const isLoaded = ref(false);

  /**
   * 加载数据
   */
  function load(data: Record<string, any>[], preserveState = false) {
    rows.value = data.map(row => {
      // 保存原始值快照（排除内部字段）
      const originalValues: Record<string, any> = {};
      for (const [key, value] of Object.entries(row)) {
        if (!key.startsWith('_')) {
          originalValues[key] = value;
        }
      }
      return {
        ...row,
        _changeType: preserveState ? (row._changeType || {}) : {},
        _originalValues: preserveState ? (row._originalValues || originalValues) : originalValues
      };
    }) as T[];
    isLoaded.value = true;
  }

  /**
   * 获取行
   */
  function getRow(rowId: number | string): T | undefined {
    return rows.value.find(r => r[pkField] === rowId);
  }

  /**
   * 更新字段
   */
  function updateField(rowId: number | string, field: string, value: any) {
    const row = getRow(rowId);
    if (row) {
      row[field] = value;
    }
  }

  /**
   * 批量更新字段
   */
  function updateFields(rowId: number | string, fields: Record<string, any>) {
    const row = getRow(rowId);
    if (row) {
      Object.assign(row, fields);
    }
  }

  /**
   * 标记变更类型
   * 只有当前值与原始值不同时才标记
   */
  function markChange(rowId: number | string, field: string, type: 'user' | 'cascade') {
    const row = getRow(rowId);
    if (row) {
      if (!row._changeType) row._changeType = {};
      
      const currentValue = row[field];
      const originalValue = row._originalValues?.[field];
      
      // 比较当前值和原始值（处理数字精度问题）
      const isEqual = currentValue === originalValue || 
        (typeof currentValue === 'number' && typeof originalValue === 'number' && 
         Math.abs(currentValue - originalValue) < 0.0001);
      
      if (isEqual) {
        // 值恢复到原始值，移除变更标记
        delete row._changeType[field];
      } else {
        // 值确实变了，标记变更
        row._changeType[field] = type;
      }
    }
  }

  /**
   * 新增行
   */
  function addRow(data: Partial<T> = {}): T {
    // 生成临时ID（负数，避免和数据库ID冲突）
    const tempId = -Date.now() - Math.random();
    const newRow = {
      [pkField]: tempId,
      ...data,
      _changeType: {},
      _isNew: true
    } as T;
    rows.value.push(newRow);
    return newRow;
  }

  /**
   * 删除行（标记删除）
   */
  function deleteRow(rowId: number | string) {
    const row = getRow(rowId);
    if (row) {
      if (row._isNew) {
        // 新增行直接移除
        const idx = rows.value.findIndex(r => r[pkField] === rowId);
        if (idx > -1) rows.value.splice(idx, 1);
      } else {
        // 已有行标记删除
        row._isDeleted = true;
      }
    }
  }

  /**
   * 重置
   */
  function reset() {
    rows.value = [];
    isLoaded.value = false;
  }

  /**
   * 清除变更标记
   * 保存成功后调用，更新原始值快照
   */
  function clearChanges() {
    rows.value.forEach(row => {
      // 更新原始值快照为当前值
      const originalValues: Record<string, any> = {};
      for (const [key, value] of Object.entries(row)) {
        if (!key.startsWith('_')) {
          originalValues[key] = value;
        }
      }
      row._originalValues = originalValues;
      row._changeType = {};
      row._isNew = false;
    });
    // 移除已删除的行
    rows.value = rows.value.filter(r => !r._isDeleted);
  }

  /**
   * 是否有未保存的修改
   */
  const isDirty = computed(() => {
    return rows.value.some(row => 
      row._isNew || 
      row._isDeleted || 
      Object.keys(row._changeType || {}).length > 0
    );
  });

  /**
   * 获取变更数据（用于保存）
   */
  const changedRows = computed(() => {
    return rows.value.filter(row => 
      row._isNew || 
      row._isDeleted || 
      Object.keys(row._changeType || {}).length > 0
    );
  });

  /**
   * 获取可见行（排除已删除）
   */
  const visibleRows = computed(() => {
    return rows.value.filter(r => !r._isDeleted);
  });

  return {
    rows,
    visibleRows,
    isLoaded,
    isDirty,
    changedRows,
    load,
    getRow,
    updateField,
    updateFields,
    markChange,
    addRow,
    deleteRow,
    reset,
    clearChanges
  };
}

export type GridStore = ReturnType<typeof useGridStore>;
