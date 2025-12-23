import { reactive, computed } from 'vue';

export interface FieldChange {
  field: string;
  oldValue: any;
  newValue: any;
}

export interface RecordItem {
  id: number | null;
  status: 'added' | 'modified' | 'deleted' | 'unchanged';
  data: Record<string, any>;
  changes: FieldChange[];
  updateTime?: string;
}

export interface DirtyData {
  master: RecordItem | null;
  details: Record<string, RecordItem[]>;
}

/**
 * 变更追踪 Hook
 * 用于追踪主从表数据的增删改操作
 */
export function useChangeTracker() {
  const dirtyData = reactive<DirtyData>({
    master: null,
    details: {}
  });

  // 原始数据快照
  const originalData = reactive<{
    master: Record<string, any> | null;
    details: Record<string, Record<string, any>[]>;
  }>({
    master: null,
    details: {}
  });

  // 是否有未保存的修改
  const isDirty = computed(() => {
    if (dirtyData.master?.status === 'modified' || dirtyData.master?.status === 'added') {
      return true;
    }
    for (const items of Object.values(dirtyData.details)) {
      if (items.some(item => item.status !== 'unchanged')) {
        return true;
      }
    }
    return false;
  });

  /**
   * 初始化主表数据
   */
  function initMaster(tableCode: string, data: Record<string, any>) {
    originalData.master = JSON.parse(JSON.stringify(data));
    dirtyData.master = {
      id: data.id,
      status: 'unchanged',
      data: { ...data, _tableCode: tableCode },
      changes: [],
      updateTime: data.updateTime
    };
  }

  /**
   * 初始化从表数据
   */
  function initDetails(tableCode: string, rows: Record<string, any>[]) {
    originalData.details[tableCode] = JSON.parse(JSON.stringify(rows));
    dirtyData.details[tableCode] = rows.map(row => ({
      id: row.id,
      status: 'unchanged' as const,
      data: { ...row },
      changes: [],
      updateTime: row.updateTime
    }));
  }

  /**
   * 记录主表字段修改
   */
  function trackMasterChange(field: string, oldValue: any, newValue: any) {
    if (!dirtyData.master) return;
    
    dirtyData.master.status = 'modified';
    dirtyData.master.data[field] = newValue;

    // 更新或添加变更记录
    const existingChange = dirtyData.master.changes.find(c => c.field === field);
    if (existingChange) {
      existingChange.newValue = newValue;
      // 如果改回原值，移除变更记录
      if (existingChange.oldValue === newValue) {
        dirtyData.master.changes = dirtyData.master.changes.filter(c => c.field !== field);
      }
    } else {
      dirtyData.master.changes.push({ field, oldValue, newValue });
    }

    // 如果没有变更记录了，恢复 unchanged 状态
    if (dirtyData.master.changes.length === 0) {
      dirtyData.master.status = 'unchanged';
    }
  }

  /**
   * 记录从表行修改
   */
  function trackDetailChange(tableCode: string, rowId: number, field: string, oldValue: any, newValue: any) {
    const items = dirtyData.details[tableCode];
    if (!items) return;

    const item = items.find(i => i.id === rowId);
    if (!item) return;

    if (item.status === 'unchanged') {
      item.status = 'modified';
    }
    item.data[field] = newValue;

    const existingChange = item.changes.find(c => c.field === field);
    if (existingChange) {
      existingChange.newValue = newValue;
      if (existingChange.oldValue === newValue) {
        item.changes = item.changes.filter(c => c.field !== field);
      }
    } else {
      item.changes.push({ field, oldValue, newValue });
    }

    if (item.changes.length === 0 && item.status === 'modified') {
      item.status = 'unchanged';
    }
  }

  /**
   * 添加从表行
   */
  function addDetailRow(tableCode: string, row: Record<string, any>) {
    if (!dirtyData.details[tableCode]) {
      dirtyData.details[tableCode] = [];
    }
    dirtyData.details[tableCode].push({
      id: null,
      status: 'added',
      data: { ...row },
      changes: []
    });
  }

  /**
   * 删除从表行
   */
  function deleteDetailRow(tableCode: string, rowId: number) {
    const items = dirtyData.details[tableCode];
    if (!items) return;

    const idx = items.findIndex(i => i.id === rowId);
    if (idx < 0) return;

    const item = items[idx];
    if (item.status === 'added') {
      // 新增的直接移除
      items.splice(idx, 1);
    } else {
      // 已有的标记为删除
      item.status = 'deleted';
    }
  }

  /**
   * 获取保存参数 - 只包含变更的字段
   */
  function getSaveParam() {
    // 处理主表：只提交变更的字段
    let masterParam = null;
    if (dirtyData.master && dirtyData.master.status !== 'unchanged') {
      const changedData: Record<string, any> = { _tableCode: dirtyData.master.data._tableCode };
      if (dirtyData.master.status === 'modified') {
        // 只放变更的字段
        dirtyData.master.changes.forEach(c => {
          changedData[c.field] = c.newValue;
        });
      } else {
        // 新增时放全部数据
        Object.assign(changedData, dirtyData.master.data);
      }
      masterParam = {
        id: dirtyData.master.id,
        status: dirtyData.master.status,
        data: changedData,
        changes: dirtyData.master.changes
      };
    }

    // 处理从表：只提交变更的字段
    const detailsParam: Record<string, any[]> = {};
    for (const [tableCode, items] of Object.entries(dirtyData.details)) {
      const changedItems = items
        .filter(item => item.status !== 'unchanged')
        .map(item => {
          if (item.status === 'modified') {
            // 只放变更的字段
            const changedData: Record<string, any> = {};
            item.changes.forEach(c => {
              changedData[c.field] = c.newValue;
            });
            return {
              id: item.id,
              status: item.status,
              data: changedData,
              changes: item.changes
            };
          }
          // 新增/删除时放全部数据或只放id
          return {
            id: item.id,
            status: item.status,
            data: item.status === 'added' ? item.data : undefined,
            changes: item.changes
          };
        });
      if (changedItems.length > 0) {
        detailsParam[tableCode] = changedItems;
      }
    }

    return {
      master: masterParam,
      details: Object.keys(detailsParam).length > 0 ? detailsParam : undefined
    };
  }

  /**
   * 重置所有变更
   */
  function reset() {
    dirtyData.master = null;
    dirtyData.details = {};
    originalData.master = null;
    originalData.details = {};
  }

  /**
   * 获取从表当前数据（用于 Tab 切换时恢复）
   */
  function getDetailData(tableCode: string): Record<string, any>[] {
    const items = dirtyData.details[tableCode];
    if (!items) return [];
    return items.filter(i => i.status !== 'deleted').map(i => i.data);
  }

  return {
    dirtyData,
    isDirty,
    initMaster,
    initDetails,
    trackMasterChange,
    trackDetailChange,
    addDetailRow,
    deleteDetailRow,
    getSaveParam,
    getDetailData,
    reset
  };
}
