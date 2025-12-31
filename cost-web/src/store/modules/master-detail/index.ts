/**
 * 通用主从表 Store 工厂
 * 元数据驱动，支持 group/multi 模式
 */
import { ref, computed, watch, nextTick, shallowRef } from 'vue';
import { defineStore } from 'pinia';
import {
  type RowData,
  type CalcRule,
  type AggRule,
  type TabConfig,
  type ParsedPageConfig,
  compileCalcRules,
  compileAggRules,
  calcRowFields,
  calcAggregates,
  generateTempId,
  initRowData,
  isRowChanged,
  checkDirty,
  clearRowChanges
} from '@/logic/calc-engine';

// ==================== 常量 ====================

const MAX_CACHE_SIZE = 10;
const MAX_CALC_ROUNDS = 3;
const EPSILON = 0.0001;

// ==================== 类型 ====================

export interface MasterDetailStoreState {
  pageCode: string;
  isReady: boolean;
  masterRows: RowData[];
  currentMasterId: number | null;
  detailRows: RowData[];
  // 元数据
  config: ParsedPageConfig | null;
  masterColumns: any[];
  detailColumns: any[];
}

export interface MasterDetailStoreOptions {
  pageCode: string;
}

// ==================== Store 工厂 ====================

/**
 * 创建主从表 Store
 * 每个 pageCode 对应一个独立的 Store 实例
 */
export function useMasterDetailStore(pageCode: string) {
  const storeId = `master-detail-${pageCode}`;

  return defineStore(storeId, () => {
    // ==================== State ====================

    const isReady = ref(false);
    const masterRows = ref<RowData[]>([]);
    const currentMasterId = ref<number | null>(null);
    const detailRows = ref<RowData[]>([]);

    // 从表缓存（LRU）
    const detailCache = new Map<number, RowData[]>();
    const cacheOrder = ref<number[]>([]);

    // 元数据配置
    const config = shallowRef<ParsedPageConfig | null>(null);
    const masterColumns = shallowRef<any[]>([]);
    const detailColumns = shallowRef<any[]>([]);

    // 编译后的规则（缓存）
    const compiledCalcRules = shallowRef<ReturnType<typeof compileCalcRules>>([]);
    const compiledAggRules = shallowRef<ReturnType<typeof compileAggRules>>([]);

    // 计算防抖标记
    let calcPending = false;
    let aggPending = false;

    // ==================== Getters ====================

    const currentMaster = computed(() =>
      masterRows.value.find(r => r.id === currentMasterId.value)
    );

    const visibleMasterRows = computed(() =>
      masterRows.value.filter(r => !r._isDeleted)
    );

    const visibleDetailRows = computed(() =>
      detailRows.value.filter(r => !r._isDeleted)
    );

    // 按 Tab 分组的从表数据（group 模式）
    const detailRowsByTab = computed(() => {
      const result: Record<string, RowData[]> = {};
      const tabs = config.value?.tabs || [];
      const groupField = config.value?.groupField;

      for (const tab of tabs) {
        if (tab.mode === 'group' && groupField) {
          result[tab.key] = visibleDetailRows.value.filter(
            r => r[groupField] === tab.groupValue
          );
        } else if (tab.mode === 'multi') {
          // multi 模式：每个 tab 独立数据源，暂不实现
          result[tab.key] = [];
        }
      }
      return result;
    });

    const isDirty = computed(() =>
      checkDirty(masterRows.value, detailRows.value, detailCache)
    );

    // ==================== Actions ====================

    /**
     * 初始化 Store（设置元数据）
     */
    function init(
      pageConfig: ParsedPageConfig,
      masterCols: any[],
      detailCols: any[],
      masterRawCols?: any[],
      detailRawCols?: any[]
    ) {
      config.value = pageConfig;
      masterColumns.value = masterCols;
      detailColumns.value = detailCols;

      // 编译计算规则
      if (pageConfig.calcRules.length > 0) {
        compiledCalcRules.value = compileCalcRules(pageConfig.calcRules, pageCode);
      }
      if (pageConfig.aggregates.length > 0) {
        compiledAggRules.value = compileAggRules(pageConfig.aggregates, pageCode);
      }

      isReady.value = true;
    }

    /**
     * 加载主表数据
     */
    function loadMaster(data: Record<string, any>[]) {
      masterRows.value = data.map(row => initRowData(row, false));

      // 清空从表和缓存
      currentMasterId.value = null;
      detailRows.value = [];
      detailCache.clear();
      cacheOrder.value = [];
    }

    /**
     * 加载从表数据
     */
    function loadDetail(data: Record<string, any>[]) {
      detailRows.value = data.map(row => initRowData(row, false));

      // 缓存当前从表
      if (currentMasterId.value != null) {
        saveToCache(currentMasterId.value, detailRows.value);
      }

      // 触发初始计算
      triggerDetailCalc();
    }

    /**
     * 选择主表行
     */
    function selectMaster(id: number): boolean {
      if (currentMasterId.value === id) return false;

      // 缓存当前从表
      if (currentMasterId.value != null) {
        saveToCache(currentMasterId.value, [...detailRows.value]);
      }

      currentMasterId.value = id;

      // 检查是否是新增行
      const masterRow = masterRows.value.find(r => r.id === id);
      if (masterRow?._isNew) {
        detailRows.value = [];
        return false; // 不需要加载
      }

      // 从缓存恢复
      if (detailCache.has(id)) {
        detailRows.value = detailCache.get(id)!;
        updateCacheOrder(id);
        return false; // 不需要加载
      }

      // 需要从 API 加载
      detailRows.value = [];
      return true;
    }

    /**
     * 更新字段值
     * @param isMaster 明确指定是主表还是从表，避免 ID 冲突
     */
    function updateField(
      rowId: number,
      field: string,
      value: any,
      changeType: 'user' | 'cascade' = 'user',
      isMaster = false
    ) {
      const rows = isMaster ? masterRows.value : detailRows.value;
      const row = rows.find(r => r.id === rowId);

      if (!row) return;

      // 更新值
      row[field] = value;

      // 标记变更
      markChange(row, field, changeType);

      // 如果是主表广播字段变化，触发从表重算
      if (isMaster && config.value?.broadcast?.includes(field)) {
        triggerDetailCalc();
      }

      // 如果是从表字段变化，触发该行重算 + 聚合重算
      if (!isMaster && changeType === 'user') {
        // 先触发行级计算
        triggerDetailCalc();
        // 即使没有行级计算规则，也要触发聚合（因为字段值已变化）
        triggerAggCalc();
      }
    }

    /**
     * 批量更新字段
     */
    function updateFields(rowId: number, fields: Record<string, any>, changeType: 'user' | 'cascade' = 'user') {
      let row = masterRows.value.find(r => r.id === rowId);
      if (!row) {
        row = detailRows.value.find(r => r.id === rowId);
      }
      if (!row) return;

      for (const [field, value] of Object.entries(fields)) {
        row[field] = value;
        markChange(row, field, changeType);
      }
    }

    /**
     * 新增主表行
     */
    function addMasterRow(defaults: Record<string, any> = {}): RowData {
      const tempId = generateTempId();
      const newRow = initRowData({ id: tempId, ...defaults }, true);
      masterRows.value.push(newRow);
      return newRow;
    }

    /**
     * 新增从表行
     */
    function addDetailRow(tabKey: string, defaults: Record<string, any> = {}): RowData {
      const tempId = generateTempId();
      const tab = config.value?.tabs.find(t => t.key === tabKey);

      const rowData: Record<string, any> = { id: tempId, ...defaults };

      // 设置分组字段
      if (tab?.mode === 'group' && config.value?.groupField) {
        rowData[config.value.groupField] = tab.groupValue;
      }

      const newRow = initRowData(rowData, true);
      detailRows.value.push(newRow);

      // 触发聚合重算
      triggerAggCalc();

      return newRow;
    }

    /**
     * 删除行
     */
    function deleteRow(rowId: number, isMaster: boolean) {
      const rows = isMaster ? masterRows.value : detailRows.value;
      const row = rows.find(r => r.id === rowId);
      if (!row) return;

      if (row._isNew) {
        // 新增行直接移除
        const idx = rows.indexOf(row);
        if (idx > -1) rows.splice(idx, 1);
      } else {
        // 已有行标记删除
        row._isDeleted = true;
      }

      // 如果删除主表行，清理缓存
      if (isMaster && detailCache.has(rowId)) {
        detailCache.delete(rowId);
        const idx = cacheOrder.value.indexOf(rowId);
        if (idx > -1) cacheOrder.value.splice(idx, 1);
      }

      // 如果删除从表行，触发聚合重算
      if (!isMaster) {
        triggerAggCalc();
      }
    }

    /**
     * 清除变更标记（保存成功后调用）
     */
    function clearChanges() {
      // 清除主表
      masterRows.value = masterRows.value
        .filter(r => !r._isDeleted)
        .map(r => clearRowChanges(r));

      // 清除从表
      detailRows.value = detailRows.value
        .filter(r => !r._isDeleted)
        .map(r => clearRowChanges(r));

      // 清除缓存
      detailCache.clear();
      cacheOrder.value = [];
    }

    /**
     * 重置 Store
     */
    function reset() {
      masterRows.value = [];
      currentMasterId.value = null;
      detailRows.value = [];
      detailCache.clear();
      cacheOrder.value = [];
    }

    // ==================== 内部方法 ====================

    /**
     * 保存到缓存（LRU）
     */
    function saveToCache(masterId: number, rows: RowData[]) {
      // LRU 清理
      if (detailCache.size >= MAX_CACHE_SIZE && !detailCache.has(masterId)) {
        const oldest = cacheOrder.value.shift();
        if (oldest != null) {
          detailCache.delete(oldest);
        }
      }

      detailCache.set(masterId, rows);
      updateCacheOrder(masterId);
    }

    /**
     * 更新缓存访问顺序
     */
    function updateCacheOrder(masterId: number) {
      const idx = cacheOrder.value.indexOf(masterId);
      if (idx > -1) {
        cacheOrder.value.splice(idx, 1);
      }
      cacheOrder.value.push(masterId);
    }

    /**
     * 标记字段变更
     */
    function markChange(row: RowData, field: string, type: 'user' | 'cascade') {
      if (!row._changeType) row._changeType = {};

      const currentValue = row[field];
      const originalValue = row._originalValues?.[field];

      const isEqual = isValueEqual(currentValue, originalValue);

      if (isEqual) {
        delete row._changeType[field];
      } else {
        row._changeType[field] = type;
      }
    }

    /**
     * 值比较（处理浮点数精度）
     */
    function isValueEqual(a: any, b: any): boolean {
      if (a === b) return true;
      if (typeof a === 'number' && typeof b === 'number') {
        return Math.abs(a - b) < EPSILON;
      }
      return false;
    }

    /**
     * 触发从表计算
     */
    function triggerDetailCalc() {
      if (calcPending || compiledCalcRules.value.length === 0) return;

      calcPending = true;
      nextTick(() => {
        runDetailCalc();
        calcPending = false;
      });
    }

    /**
     * 执行从表计算
     */
    function runDetailCalc() {
      const master = currentMaster.value;
      if (!master) return;

      // 构建上下文（广播字段）
      const context: Record<string, any> = {};
      for (const field of config.value?.broadcast || []) {
        context[field] = master[field] ?? 0;
      }

      // 多轮计算直到稳定
      for (let round = 0; round < MAX_CALC_ROUNDS; round++) {
        let hasChange = false;

        for (const row of detailRows.value) {
          if (row._isDeleted) continue;

          const results = calcRowFields(row, context, compiledCalcRules.value);

          for (const [field, value] of Object.entries(results)) {
            if (!isValueEqual(row[field], value)) {
              row[field] = value;
              markChange(row, field, 'cascade');
              hasChange = true;
            }
          }
        }

        if (!hasChange) break;
      }

      // 触发聚合重算
      triggerAggCalc();
    }

    /**
     * 触发聚合计算
     */
    function triggerAggCalc() {
      if (aggPending || compiledAggRules.value.length === 0) return;

      aggPending = true;
      nextTick(() => {
        runAggCalc();
        aggPending = false;
      });
    }

    /**
     * 执行聚合计算
     */
    function runAggCalc() {
      const master = currentMaster.value;
      if (!master) return;

      const aggResults = calcAggregates(
        visibleDetailRows.value,
        compiledAggRules.value,
        master
      );

      for (const [field, value] of Object.entries(aggResults)) {
        if (!isValueEqual(master[field], value)) {
          master[field] = value;
          markChange(master, field, 'cascade');
        }
      }
    }

    // ==================== 返回 ====================

    return {
      // State
      isReady,
      masterRows,
      currentMasterId,
      detailRows,
      config,
      masterColumns,
      detailColumns,

      // Getters
      currentMaster,
      visibleMasterRows,
      visibleDetailRows,
      detailRowsByTab,
      isDirty,

      // Actions
      init,
      loadMaster,
      loadDetail,
      selectMaster,
      updateField,
      updateFields,
      addMasterRow,
      addDetailRow,
      deleteRow,
      clearChanges,
      reset,

      // 计算触发
      triggerDetailCalc,
      triggerAggCalc
    };
  })();
}

// 类型导出
export type MasterDetailStore = ReturnType<typeof useMasterDetailStore>;
