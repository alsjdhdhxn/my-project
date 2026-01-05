/**
 * 通用主从表 Store 工厂
 * 元数据驱动，主从嵌套结构，LRU 缓存管理
 */
import { ref, computed, nextTick, shallowRef } from 'vue';
import { defineStore } from 'pinia';
import {
  type RowData,
  type ParsedPageConfig,
  compileCalcRules,
  compileAggRules,
  calcRowFields,
  calcAggregates,
  generateTempId,
  initRowData,
  clearRowChanges
} from '@/logic/calc-engine';

// ==================== 常量 ====================

const MAX_CACHE_SIZE = 50;
const MAX_CALC_ROUNDS = 3;
const EPSILON = 0.0001;

// ==================== 类型 ====================

/** 从表数据容器 */
export interface DetailContainer {
  loaded: boolean;
  rows: RowData[];
}

/** 主表行（含从表数据） */
export interface MasterRowData extends RowData {
  _details: DetailContainer | null;
}

// ==================== Store 工厂 ====================

export function useMasterDetailStore(pageCode: string) {
  const storeId = `master-detail-${pageCode}`;

  return defineStore(storeId, () => {
    // ==================== State ====================

    const isReady = ref(false);
    const masterRows = ref<MasterRowData[]>([]);
    const currentMasterId = ref<number | null>(null);

    // LRU 访问顺序（masterId 列表，最近访问的在末尾）
    const lruOrder = ref<number[]>([]);

    // 元数据配置
    const config = shallowRef<ParsedPageConfig | null>(null);
    const masterColumns = shallowRef<any[]>([]);
    const detailColumns = shallowRef<any[]>([]);

    // 编译后的规则
    const compiledCalcRules = shallowRef<ReturnType<typeof compileCalcRules>>([]);
    const compiledAggRules = shallowRef<ReturnType<typeof compileAggRules>>([]);
    const compiledMasterCalcRules = shallowRef<ReturnType<typeof compileCalcRules>>([]);

    // 计算防抖标记
    let calcPending = false;
    let aggPending = false;

    // 响应式更新版本号（用于强制触发 watch）
    const updateVersion = ref(0);

    // ==================== Getters ====================

    /** 当前选中的主表行 */
    const currentMaster = computed(() =>
      masterRows.value.find(r => r.id === currentMasterId.value) || null
    );

    /** 可见主表行（排除已删除） */
    const visibleMasterRows = computed(() =>
      masterRows.value.filter(r => !r._isDeleted)
    );

    /** 当前从表数据（直接指向主表的 _details.rows） */
    const detailRows = computed(() =>
      currentMaster.value?._details?.rows || []
    );

    /** 可见从表行（排除已删除） */
    const visibleDetailRows = computed(() =>
      detailRows.value.filter(r => !r._isDeleted)
    );

    /** 按 Tab 分组的从表数据 */
    const detailRowsByTab = computed(() => {
      const result: Record<string, RowData[]> = {};
      const tabs = config.value?.tabs || [];
      const groupField = config.value?.groupField;

      for (const tab of tabs) {
        if (tab.mode === 'group') {
          // groupValues 优先（多个分组值合并到一个 Tab）
          if (tab.groupValues && tab.groupValues.length > 0 && groupField) {
            result[tab.key] = visibleDetailRows.value.filter(
              r => tab.groupValues!.includes(r[groupField] as string)
            );
          }
          // groupValue 为 * 或未设置时，显示所有数据（不分组）
          else if (!tab.groupValue || tab.groupValue === '*' || !groupField) {
            result[tab.key] = visibleDetailRows.value;
          } else {
            result[tab.key] = visibleDetailRows.value.filter(
              r => r[groupField] === tab.groupValue
            );
          }
        } else if (tab.mode === 'multi') {
          result[tab.key] = [];
        }
      }
      return result;
    });

    /** 是否有未保存的修改 */
    const isDirty = computed(() => {
      for (const master of masterRows.value) {
        if (isRowDirty(master)) return true;
        if (master._details?.rows) {
          for (const detail of master._details.rows) {
            if (isRowDirty(detail)) return true;
          }
        }
      }
      return false;
    });

    /** 已加载从表的主表数量 */
    const loadedDetailCount = computed(() =>
      masterRows.value.filter(r => r._details?.loaded).length
    );

    // ==================== Actions ====================

    /** 初始化 Store */
    function init(
      pageConfig: ParsedPageConfig,
      masterCols: any[],
      detailCols: any[]
    ) {
      config.value = pageConfig;
      masterColumns.value = masterCols;
      detailColumns.value = detailCols;

      if (pageConfig.calcRules.length > 0) {
        compiledCalcRules.value = compileCalcRules(pageConfig.calcRules, pageCode);
      }
      if (pageConfig.aggregates.length > 0) {
        compiledAggRules.value = compileAggRules(pageConfig.aggregates, pageCode);
      }
      if (pageConfig.masterCalcRules.length > 0) {
        compiledMasterCalcRules.value = compileCalcRules(pageConfig.masterCalcRules, `${pageCode}-master`);
      }

      isReady.value = true;
    }

    /** 加载主表数据 */
    function loadMaster(data: Record<string, any>[]) {
      masterRows.value = data.map(row => ({
        ...initRowData(row, false),
        _details: null
      })) as MasterRowData[];

      currentMasterId.value = null;
      lruOrder.value = [];
    }

    /** 加载从表数据（挂到当前主表下） */
    function loadDetail(data: Record<string, any>[]) {
      const master = currentMaster.value;
      if (!master) return;

      master._details = {
        loaded: true,
        rows: data.map(row => initRowData(row, false))
      };

      // 更新 LRU
      if (master.id != null) {
        updateLru(master.id);
      }

      // 通知 UI 刷新（不触发计算，加载的数据是干净的）
      triggerReactiveUpdate();
    }

    /** 选择主表行，返回是否需要加载从表 */
    function selectMaster(id: number): boolean {
      if (currentMasterId.value === id) return false;

      currentMasterId.value = id;

      const master = masterRows.value.find(r => r.id === id);
      if (!master) return false;

      // 新增行不需要加载
      if (master._isNew) {
        if (!master._details) {
          master._details = { loaded: true, rows: [] };
        }
        return false;
      }

      // 已加载过，更新 LRU
      if (master._details?.loaded) {
        updateLru(id);
        // 通知 UI 刷新（切换行不触发计算）
        triggerReactiveUpdate();
        return false;
      }

      // 需要加载，先检查 LRU
      checkLruEviction();
      return true;
    }

    /** 更新字段值 */
    function updateField(
      rowId: number,
      field: string,
      value: any,
      changeType: 'user' | 'cascade' = 'user',
      isMaster = false
    ) {
      const row = isMaster
        ? masterRows.value.find(r => r.id === rowId)
        : detailRows.value.find(r => r.id === rowId);

      if (!row) return;

      row[field] = value;
      markChange(row, field, changeType);

      // 触发响应式更新（通知 Grid 刷新）
      triggerReactiveUpdate();

      // 主表广播字段变化 → 触发从表重算（全量）
      if (isMaster && config.value?.broadcast?.includes(field)) {
        triggerDetailCalc();
      }

      // 从表用户修改 → 只计算受影响的规则
      if (!isMaster && changeType === 'user') {
        triggerDetailCalcForField(rowId, field);
        triggerAggCalc();
      }
    }

    /** 新增主表行 */
    function addMasterRow(defaults: Record<string, any> = {}): MasterRowData {
      const tempId = generateTempId();
      const newRow: MasterRowData = {
        ...initRowData({ id: tempId, ...defaults }, true),
        _details: { loaded: true, rows: [] }
      };
      masterRows.value.push(newRow);
      return newRow;
    }

    /** 新增从表行 */
    function addDetailRow(tabKey: string, defaults: Record<string, any> = {}): RowData | null {
      const master = currentMaster.value;
      if (!master?._details) return null;

      const tempId = generateTempId();
      const tab = config.value?.tabs.find(t => t.key === tabKey);
      const rowData: Record<string, any> = { id: tempId, ...defaults };

      if (tab?.mode === 'group' && config.value?.groupField) {
        rowData[config.value.groupField] = tab.groupValue;
      }

      const newRow = initRowData(rowData, true);
      master._details.rows.push(newRow);

      triggerAggCalc();
      return newRow;
    }

    /** 删除行 */
    function deleteRow(rowId: number, isMaster: boolean) {
      if (isMaster) {
        const row = masterRows.value.find(r => r.id === rowId);
        if (!row) return;

        if (row._isNew) {
          const idx = masterRows.value.indexOf(row);
          if (idx > -1) masterRows.value.splice(idx, 1);
        } else {
          row._isDeleted = true;
        }

        // 从 LRU 移除
        const lruIdx = lruOrder.value.indexOf(rowId);
        if (lruIdx > -1) lruOrder.value.splice(lruIdx, 1);
      } else {
        const master = currentMaster.value;
        if (!master?._details) return;

        const row = master._details.rows.find(r => r.id === rowId);
        if (!row) return;

        if (row._isNew) {
          const idx = master._details.rows.indexOf(row);
          if (idx > -1) master._details.rows.splice(idx, 1);
        } else {
          row._isDeleted = true;
        }

        triggerAggCalc();
      }
    }

    /** 清除变更标记（保存成功后） */
    function clearChanges() {
      for (const master of masterRows.value) {
        if (master._isDeleted) continue;

        // 清除主表标记
        Object.assign(master, clearRowChanges(master));

        // 清除从表标记
        if (master._details?.rows) {
          master._details.rows = master._details.rows
            .filter(r => !r._isDeleted)
            .map(r => clearRowChanges(r));
        }
      }

      // 移除已删除的主表行
      masterRows.value = masterRows.value.filter(r => !r._isDeleted);
    }

    /** 重置 Store */
    function reset() {
      masterRows.value = [];
      currentMasterId.value = null;
      lruOrder.value = [];
    }

    // ==================== 内部方法 ====================

    /** 检查行是否有修改 */
    function isRowDirty(row: RowData): boolean {
      if (row._isNew || row._isDeleted) return true;
      return Object.keys(row._changeType || {}).length > 0;
    }

    /** 检查主表及其从表是否有修改 */
    function isMasterDirty(master: MasterRowData): boolean {
      if (isRowDirty(master)) return true;
      if (master._details?.rows) {
        return master._details.rows.some(r => isRowDirty(r));
      }
      return false;
    }

    /** 更新 LRU 顺序 */
    function updateLru(masterId: number) {
      const idx = lruOrder.value.indexOf(masterId);
      if (idx > -1) lruOrder.value.splice(idx, 1);
      lruOrder.value.push(masterId);
    }

    /** LRU 清理检查 */
    function checkLruEviction(): boolean {
      if (loadedDetailCount.value < MAX_CACHE_SIZE) return true;

      // 找最久未访问的、无修改的主表
      for (const masterId of lruOrder.value) {
        const master = masterRows.value.find(r => r.id === masterId);
        if (master && master._details?.loaded && !isMasterDirty(master)) {
          // 清除从表数据
          master._details = null;
          const idx = lruOrder.value.indexOf(masterId);
          if (idx > -1) lruOrder.value.splice(idx, 1);
          return true;
        }
      }

      // 全都有修改，无法清理
      console.warn('[Store] 缓存已满且全部有修改，请先保存数据');
      return false;
    }

    /** 标记字段变更 */
    function markChange(row: RowData, field: string, type: 'user' | 'cascade') {
      if (!row._changeType) row._changeType = {};

      const currentValue = row[field];
      const originalValue = row._originalValues?.[field];

      if (isValueEqual(currentValue, originalValue)) {
        delete row._changeType[field];
      } else {
        row._changeType[field] = type;
      }
    }

    /** 值比较 */
    function isValueEqual(a: any, b: any): boolean {
      if (a === b) return true;
      if (typeof a === 'number' && typeof b === 'number') {
        return Math.abs(a - b) < EPSILON;
      }
      return false;
    }

    /** 触发响应式更新（通知 Grid 刷新单元格样式） */
    function triggerReactiveUpdate() {
      updateVersion.value++;
    }

    /** 触发从表计算（全量） */
    function triggerDetailCalc() {
      if (calcPending || compiledCalcRules.value.length === 0) return;

      calcPending = true;
      nextTick(() => {
        runDetailCalc();
        calcPending = false;
      });
    }

    /** 触发从表计算（单行，只计算受影响的规则） */
    function triggerDetailCalcForField(rowId: number, changedField: string) {
      if (compiledCalcRules.value.length === 0) return;

      nextTick(() => {
        runDetailCalcForRow(rowId, changedField);
      });
    }

    /** 执行从表计算（全量，用于广播字段变化） */
    function runDetailCalc() {
      const master = currentMaster.value;
      if (!master?._details?.rows) return;

      const context: Record<string, any> = {};
      for (const field of config.value?.broadcast || []) {
        context[field] = master[field] ?? 0;
      }

      let hasAnyChange = false;

      for (let round = 0; round < MAX_CALC_ROUNDS; round++) {
        let hasChange = false;

        for (const row of master._details.rows) {
          if (row._isDeleted) continue;

          const results = calcRowFields(row, context, compiledCalcRules.value);

          for (const [field, value] of Object.entries(results)) {
            if (!isValueEqual(row[field], value)) {
              row[field] = value;
              markChange(row, field, 'cascade');
              hasChange = true;
              hasAnyChange = true;
            }
          }
        }

        if (!hasChange) break;
      }

      // 有变化才刷新 UI
      if (hasAnyChange) {
        triggerReactiveUpdate();
      }

      triggerAggCalc();
    }

    /** 执行从表计算（单行，只计算受影响的规则） */
    function runDetailCalcForRow(rowId: number, changedField: string) {
      const master = currentMaster.value;
      if (!master?._details?.rows) return;

      const row = master._details.rows.find(r => r.id === rowId);
      if (!row || row._isDeleted) return;

      const context: Record<string, any> = {};
      for (const field of config.value?.broadcast || []) {
        context[field] = master[field] ?? 0;
      }

      // 只获取受影响的规则
      const affectedRules = compiledCalcRules.value.filter(rule => {
        // 检查 triggerFields
        if (rule.triggerFields?.includes(changedField)) return true;
        // 多公式模式：检查各公式的 triggerFields
        if (rule.formulas) {
          for (const formula of Object.values(rule.formulas)) {
            if (formula.triggerFields?.includes(changedField)) return true;
          }
        }
        return false;
      });

      if (affectedRules.length === 0) return;

      let hasChange = false;

      // 多轮计算支持级联
      for (let round = 0; round < MAX_CALC_ROUNDS; round++) {
        let roundChange = false;
        const results = calcRowFields(row, context, affectedRules);

        for (const [field, value] of Object.entries(results)) {
          if (!isValueEqual(row[field], value)) {
            row[field] = value;
            markChange(row, field, 'cascade');
            roundChange = true;
            hasChange = true;
          }
        }

        if (!roundChange) break;
      }

      if (hasChange) {
        triggerReactiveUpdate();
      }
    }

    /** 触发聚合计算 */
    function triggerAggCalc() {
      console.debug('[Store] triggerAggCalc called, aggRules:', compiledAggRules.value.length, 'masterCalcRules:', compiledMasterCalcRules.value.length);
      if (aggPending || (compiledAggRules.value.length === 0 && compiledMasterCalcRules.value.length === 0)) return;

      aggPending = true;
      nextTick(() => {
        runAggCalc();
        aggPending = false;
      });
    }

    /** 执行聚合计算 */
    function runAggCalc() {
      const master = currentMaster.value;
      if (!master) return;

      const aggResults = calcAggregates(
        visibleDetailRows.value,
        compiledAggRules.value,
        master,
        2,
        config.value?.postProcess
      );

      let hasChange = false;
      for (const [field, value] of Object.entries(aggResults)) {
        if (!isValueEqual(master[field], value)) {
          master[field] = value;
          markChange(master, field, 'cascade');
          hasChange = true;
        }
      }

      // 聚合完成后执行主表计算规则
      if (compiledMasterCalcRules.value.length > 0) {
        const masterResults = calcRowFields(master, {}, compiledMasterCalcRules.value);
        for (const [field, value] of Object.entries(masterResults)) {
          if (!isValueEqual(master[field], value)) {
            master[field] = value;
            markChange(master, field, 'cascade');
            hasChange = true;
          }
        }
      }

      // 有变化才刷新主表 UI
      if (hasChange) {
        triggerReactiveUpdate();
      }
    }

    // ==================== 返回 ====================

    return {
      // State
      isReady,
      masterRows,
      currentMasterId,
      config,
      masterColumns,
      detailColumns,
      updateVersion,

      // Getters
      currentMaster,
      visibleMasterRows,
      detailRows,
      visibleDetailRows,
      detailRowsByTab,
      isDirty,
      loadedDetailCount,

      // Actions
      init,
      loadMaster,
      loadDetail,
      selectMaster,
      updateField,
      addMasterRow,
      addDetailRow,
      deleteRow,
      clearChanges,
      reset,

      // 计算触发
      triggerDetailCalc,
      triggerAggCalc,
      triggerReactiveUpdate
    };
  })();
}

export type MasterDetailStore = ReturnType<typeof useMasterDetailStore>;
