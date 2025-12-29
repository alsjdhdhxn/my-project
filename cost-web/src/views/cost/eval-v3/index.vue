<template>
  <div class="eval-v3-page">
    <!-- 悬浮工具栏 -->
    <MetaFloatToolbar>
      <div class="toolbar-row">
        <NInput
          v-model:value="searchText"
          placeholder="搜索..."
          clearable
          size="small"
          style="width: 150px"
          @update:value="handleSearch"
        />
        <NButton size="small" @click="handleAdvancedQuery">高级查询</NButton>
        <NButton size="small" quaternary @click="handleRefresh">
          <template #icon><icon-ant-design-reload-outlined /></template>
        </NButton>
      </div>
      <div class="toolbar-row">
        <NButton 
          v-for="tab in tabs" 
          :key="tab.key"
          :type="tab.visible ? 'primary' : 'default'"
          size="small"
          @click="toggleTab(tab.key)"
        >
          {{ tab.title }}
        </NButton>
      </div>
    </MetaFloatToolbar>

    <!-- 可拖动分隔的主从表区域 -->
    <NSplit
      v-if="isMetaLoaded"
      direction="vertical"
      :default-size="0.5"
      :min="0.2"
      :max="0.8"
      class="split-container"
    >
      <!-- 主表区域 -->
      <template #1>
        <div class="master-section">
          <MetaGrid
            ref="masterGridRef"
            :columns="masterColumns"
            :store="masterStore"
            :defaultNewRow="getMasterDefaultRow()"
            firstEditableField="productName"
            height="100%"
            @selectionChanged="onMasterSelectionChanged"
            @cellChanged="onMasterCellChanged"
            @rowsDeleted="onMasterRowsDeleted"
          />
        </div>
      </template>

      <!-- 从表区域 -->
      <template #2>
        <div class="detail-section">
          <!-- 从表内容（多 Tab 并排） -->
          <div class="detail-grids">
        <div 
          v-for="tab in visibleTabs" 
          :key="tab.key"
          class="detail-grid-wrapper"
        >
          <MetaGrid
            :ref="(el) => setDetailGridRef(tab.key, el)"
            :columns="getDetailColumns(tab.key)"
            :store="detailStores[tab.key]"
            :calcEngine="detailCalcEngines[tab.key]"
            :defaultNewRow="getDetailDefaultRow(tab.key)"
            firstEditableField="materialName"
            height="100%"
            selectionMode="multi"
            showCheckbox
            @selectionChanged="(rows) => onDetailSelectionChanged(tab.key, rows)"
            @cellChanged="(params) => onDetailCellChanged(tab.key, params)"
            @rowsDeleted="() => onDetailRowsDeleted(tab.key)"
          />
        </div>
      </div>
    </div>
      </template>
    </NSplit>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, onUnmounted } from 'vue';
import { NButton, NInput, NSplit, useMessage } from 'naive-ui';
import type { ColDef } from 'ag-grid-community';
import { fetchDynamicData, fetchPageComponents, saveDynamicData } from '@/service/api';
import { useGridStore } from '@/composables/useGridStore';
import { useCalcEngine } from '@/composables/useCalcEngine';
import { useAggEngine, extractAggRules } from '@/composables/useAggEngine';
import { loadTableMeta } from '@/composables/useMetaColumns';
import { extractValidateRules, validateRows, type ValidateRule } from '@/composables/useValidator';
import MetaGrid from '@/components/meta-v2/MetaGrid.vue';
import MetaFloatToolbar from '@/components/meta-v2/MetaFloatToolbar.vue';

type TabKey = 'material' | 'auxiliary' | 'package';

const message = useMessage();

// ========== 元数据加载状态 ==========
const isMetaLoaded = ref(false);

// ========== 数据存储 ==========
const masterStore = useGridStore();
const detailStores = {
  material: useGridStore(),
  auxiliary: useGridStore(),
  package: useGridStore()
};

// ========== 计算引擎 ==========
const detailCalcEngines = {
  material: useCalcEngine(detailStores.material),
  auxiliary: useCalcEngine(detailStores.auxiliary),
  package: useCalcEngine(detailStores.package)
};

// ========== 聚合引擎 ==========
const aggEngine = useAggEngine();

// 数据源映射（组件Key → Store）
// 注意：数据库配置的 source 是 detailGrid，但实际我们按 useFlag 分成了三个 store
// 这里需要创建一个虚拟的 detailGrid store，合并三个从表数据
const detailGridStore = useGridStore();

function syncDetailGridStore() {
  // 合并三个从表的数据到 detailGrid
  const allRows = [
    ...detailStores.material.visibleRows.value,
    ...detailStores.auxiliary.visibleRows.value,
    ...detailStores.package.visibleRows.value
  ];
  detailGridStore.load(allRows, true);
}

// ========== Tab 配置 ==========
const tabs = ref([
  { key: 'material' as TabKey, title: '原料', visible: true },
  { key: 'auxiliary' as TabKey, title: '辅料', visible: true },
  { key: 'package' as TabKey, title: '包材', visible: true }
]);

const visibleTabs = computed(() => tabs.value.filter(t => t.visible));

function toggleTab(key: TabKey) {
  const tab = tabs.value.find(t => t.key === key);
  if (tab) tab.visible = !tab.visible;
}

// ========== 列定义（从元数据加载） ==========
const masterColumns = ref<ColDef[]>([]);
const detailColumns = ref<ColDef[]>([]);
const masterDefaultValues = ref<Record<string, any>>({});
const detailDefaultValues = ref<Record<string, any>>({});

// ========== 验证规则 ==========
const masterValidateRules = ref<Map<string, ValidateRule[]>>(new Map());
const detailValidateRules = ref<Map<string, ValidateRule[]>>(new Map());

// 原料/辅料使用的字段
const materialFields = ['evalId', 'materialName', 'useFlag', 'perHl', 'price', 'batchQty', 'costBatch'];
// 包材使用的字段
const packageFields = ['evalId', 'materialName', 'useFlag', 'packSpec', 'price', 'packQty', 'packCost'];

function getDetailColumns(tabKey: TabKey): ColDef[] {
  const fields = tabKey === 'package' ? packageFields : materialFields;
  return detailColumns.value.filter(col => fields.includes(col.field as string));
}

// ========== 加载元数据 ==========
async function loadMetadata() {
  const [masterMeta, detailMeta, pageComponents] = await Promise.all([
    loadTableMeta('CostEval'),
    loadTableMeta('CostEvalDetail'),
    fetchPageComponents('cost-eval')
  ]);

  if (masterMeta) {
    masterColumns.value = masterMeta.columns;
    masterDefaultValues.value = masterMeta.defaultValues;
    // 提取主表验证规则
    masterValidateRules.value = extractValidateRules(masterMeta.rawColumns || []);
  }

  if (detailMeta) {
    detailColumns.value = detailMeta.columns;
    detailDefaultValues.value = detailMeta.defaultValues;
    // 提取从表验证规则
    detailValidateRules.value = extractValidateRules(detailMeta.rawColumns || []);
    
    // 从元数据注册计算规则
    if (detailMeta.calcRules.length > 0) {
      detailCalcEngines.material.registerCalcRules(detailMeta.calcRules);
      detailCalcEngines.auxiliary.registerCalcRules(detailMeta.calcRules);
      detailCalcEngines.package.registerCalcRules(detailMeta.calcRules);
    }
  }

  // 从页面组件配置加载聚合规则
  if (pageComponents.data) {
    const aggRules = extractAggRules(pageComponents.data);
    if (aggRules.length > 0) {
      aggEngine.registerAggRules(aggRules);
      // 设置数据源映射
      aggEngine.setDataSources({
        detailGrid: detailGridStore,
        masterGrid: masterStore
      });
    }
  }

  isMetaLoaded.value = true;
}

// ========== 默认新增行配置 ==========
function getMasterDefaultRow() {
  return {
    ...masterDefaultValues.value,
    evalNo: `EVAL-${Date.now()}`
  };
}

function getDetailDefaultRow(tabKey: TabKey) {
  return {
    ...detailDefaultValues.value,
    evalId: currentMaster.value?.id,
    useFlag: tabKey === 'material' ? '原料' : tabKey === 'auxiliary' ? '辅料' : '包材'
  };
}

// ========== Grid Refs ==========
const masterGridRef = ref<InstanceType<typeof MetaGrid>>();
const detailGridRefs = reactive<Record<TabKey, InstanceType<typeof MetaGrid> | null>>({
  material: null,
  auxiliary: null,
  package: null
});

function setDetailGridRef(key: TabKey, el: any) {
  detailGridRefs[key] = el;
}

// ========== 状态 ==========
const currentMaster = ref<any>(null);
const selectedDetails = ref<any[]>([]);
const searchText = ref('');
const detailCache = reactive<Record<number, { material: any[]; auxiliary: any[]; package: any[] }>>({});

// ========== 事件处理 ==========
async function onMasterSelectionChanged(rows: any[]) {
  if (rows.length === 1) {
    const newMaster = rows[0];
    if (currentMaster.value) {
      saveDetailToCache(currentMaster.value.id);
    }
    currentMaster.value = newMaster;
    await loadDetails(newMaster.id);
  }
}

function saveDetailToCache(masterId: number) {
  // 深拷贝时保留变更标记（_changeType, _isNew, _isDeleted）
  detailCache[masterId] = {
    material: detailStores.material.rows.value.map(r => ({ ...r })),
    auxiliary: detailStores.auxiliary.rows.value.map(r => ({ ...r })),
    package: detailStores.package.rows.value.map(r => ({ ...r }))
  };
}

function onMasterCellChanged(params: { field: string; rowId: any; newValue: any }) {
  const { field, newValue } = params;
  if (currentMaster.value) {
    currentMaster.value[field] = newValue;
  }
  if (['apexPl', 'yield'].includes(field)) {
    const context = { apexPl: currentMaster.value?.apexPl || 0, yield: currentMaster.value?.yield || 100 };
    (['material', 'auxiliary', 'package'] as TabKey[]).forEach(tabKey => {
      detailCalcEngines[tabKey].setContext(context);
      detailCalcEngines[tabKey].onContextChange(field);
      // Grid 可能因为 Tab 隐藏而不存在，但数据已经在 store 里更新了
      detailGridRefs[tabKey]?.refreshAll();
    });
    // 重新聚合（因为从表数据变了）
    updateMasterAggregates();
  }
  masterGridRef.value?.refreshRow(params.rowId);
}

function onDetailSelectionChanged(_tabKey: TabKey, rows: any[]) {
  selectedDetails.value = rows;
}

function onDetailCellChanged(tabKey: TabKey, params: { field: string; rowId: any }) {
  detailGridRefs[tabKey]?.refreshRow(params.rowId);
  updateMasterAggregates();
  if (currentMaster.value) {
    masterGridRef.value?.refreshRow(currentMaster.value.id);
  }
}

// ========== 数据加载 ==========
async function loadMasterList() {
  const { data, error } = await fetchDynamicData('CostEval', {});
  if (!error && data) {
    masterStore.load(data.list || []);
    if (masterStore.rows.value.length > 0) {
      setTimeout(() => {
        masterGridRef.value?.gridApi?.getDisplayedRowAtIndex(0)?.setSelected(true);
      }, 100);
    }
  }
}

async function loadDetails(masterId: number) {
  if (detailCache[masterId]) {
    const cached = detailCache[masterId];
    detailStores.material.load(cached.material, true);
    detailStores.auxiliary.load(cached.auxiliary, true);
    detailStores.package.load(cached.package, true);
  } else {
    const { data, error } = await fetchDynamicData('CostEvalDetail', { EVAL_ID: masterId });
    if (!error && data) {
      const list = data.list || [];
      detailStores.material.load(list.filter((r: any) => r.useFlag === '原料'));
      detailStores.auxiliary.load(list.filter((r: any) => r.useFlag === '辅料'));
      detailStores.package.load(list.filter((r: any) => r.useFlag === '包材'));
    }
  }

  const context = { apexPl: currentMaster.value?.apexPl || 0, yield: currentMaster.value?.yield || 100 };
  (['material', 'auxiliary', 'package'] as TabKey[]).forEach(tabKey => {
    detailCalcEngines[tabKey].setContext(context);
    if (!detailCache[masterId]) {
      detailCalcEngines[tabKey].initCalc();
    }
  });

  (['material', 'auxiliary', 'package'] as TabKey[]).forEach(tabKey => {
    detailGridRefs[tabKey]?.refreshAll();
  });

  updateMasterAggregates();
  if (currentMaster.value) {
    masterGridRef.value?.refreshRow(currentMaster.value.id);
  }
}

// ========== 聚合计算 ==========
function updateMasterAggregates() {
  if (!currentMaster.value) return;

  // 同步从表数据到虚拟的 detailGrid store
  syncDetailGridStore();
  
  // 设置目标并执行聚合计算
  aggEngine.setTarget(masterStore, currentMaster.value.id);
  const results = aggEngine.calculate();
  
  // 同步到 currentMaster 引用
  if (results) {
    Object.assign(currentMaster.value, results);
  }
}

// ========== 工具栏事件 ==========
async function handleSave() {
  // 先把当前从表存入缓存
  if (currentMaster.value) {
    saveDetailToCache(currentMaster.value.id);
  }

  // 检查是否有数据需要保存（包括缓存中的）
  const hasMasterChanges = masterStore.isDirty.value;
  const hasCacheChanges = Object.values(detailCache).some(cache => 
    [...cache.material, ...cache.auxiliary, ...cache.package].some(
      row => row._isNew || row._isDeleted || Object.keys(row._changeType || {}).length > 0
    )
  );
  
  if (!hasMasterChanges && !hasCacheChanges) {
    message.info('没有需要保存的数据');
    return;
  }

  // ========== 前端验证 ==========
  // 1. 验证主表
  if (masterValidateRules.value.size > 0) {
    const masterRows = masterStore.changedRows.value.filter(r => !r._isDeleted);
    const masterResult = validateRows(masterRows, masterValidateRules.value);
    if (!masterResult.valid) {
      message.error(`主表验证失败: ${masterResult.message}`);
      return;
    }
  }

  // 2. 验证从表（当前 store + 缓存）
  if (detailValidateRules.value.size > 0) {
    // 当前选中主表的从表
    const currentDetailRows = [
      ...detailStores.material.rows.value,
      ...detailStores.auxiliary.rows.value,
      ...detailStores.package.rows.value
    ].filter(r => !r._isDeleted && (r._isNew || Object.keys(r._changeType || {}).length > 0));
    
    const currentResult = validateRows(currentDetailRows, detailValidateRules.value);
    if (!currentResult.valid) {
      message.error(`从表验证失败: ${currentResult.message}`);
      return;
    }

    // 缓存中的从表
    for (const [masterIdStr, cached] of Object.entries(detailCache)) {
      if (Number(masterIdStr) === currentMaster.value?.id) continue; // 已验证
      
      const cachedRows = [...cached.material, ...cached.auxiliary, ...cached.package]
        .filter(r => !r._isDeleted && (r._isNew || Object.keys(r._changeType || {}).length > 0));
      
      const cachedResult = validateRows(cachedRows, detailValidateRules.value);
      if (!cachedResult.valid) {
        message.error(`从表验证失败: ${cachedResult.message}`);
        return;
      }
    }
  }

  // 构建保存参数（支持多主从）
  const saveParams = buildSaveParams();
  if (saveParams.length === 0) {
    message.warning('没有有效的保存数据');
    return;
  }

  try {
    // 逐个保存（后端会执行后端验证 + 执行器）
    for (const param of saveParams) {
      const { error } = await saveDynamicData(param);
      if (error) {
        message.error('保存失败: ' + (error.msg || '未知错误'));
        return;
      }
    }
    
    message.success('保存成功');
    
    // 清除变更标记
    masterStore.clearChanges();
    detailStores.material.clearChanges();
    detailStores.auxiliary.clearChanges();
    detailStores.package.clearChanges();
    
    // 清除缓存，重新加载
    Object.keys(detailCache).forEach(key => delete detailCache[Number(key)]);
    
    // 刷新数据
    await loadMasterList();
  } catch (e: any) {
    message.error('保存失败: ' + (e.message || '网络错误'));
  }
}

/**
 * 构建保存参数（支持多主从）
 */
function buildSaveParams(): Array<{ pageCode: string; master: any; details?: Record<string, any[]> }> {
  const result: Array<{ pageCode: string; master: any; details?: Record<string, any[]> }> = [];
  
  // 遍历所有变更的主表行
  const changedMasters = masterStore.changedRows.value;
  
  for (const masterRow of changedMasters) {
    const masterId = masterRow.id;
    
    // 获取对应的从表数据（从缓存或当前 store）
    let detailRows: any[];
    if (masterId === currentMaster.value?.id) {
      // 当前选中的主表，从 store 取
      detailRows = [
        ...detailStores.material.rows.value,
        ...detailStores.auxiliary.rows.value,
        ...detailStores.package.rows.value
      ];
    } else if (detailCache[masterId]) {
      // 其他主表，从缓存取
      const cached = detailCache[masterId];
      detailRows = [...cached.material, ...cached.auxiliary, ...cached.package];
    } else {
      // 没有从表数据
      detailRows = [];
    }
    
    // 构建主表 RecordItem
    const masterItem = buildRecordItem(masterRow, 'CostEval');
    
    // 构建从表数据（只包含有变更的行）
    const detailItems = detailRows
      .filter(row => row._isNew || row._isDeleted || Object.keys(row._changeType || {}).length > 0)
      .map(row => buildRecordItem(row, 'CostEvalDetail', masterId));
    
    const param: { pageCode: string; master: any; details?: Record<string, any[]> } = { 
      pageCode: 'cost-eval',
      master: masterItem 
    };
    if (detailItems.length > 0) {
      param.details = { CostEvalDetail: detailItems };
    }
    
    result.push(param);
  }
  
  // 检查是否有只修改从表但主表未变的情况
  // 遍历缓存，找出主表未变但从表有变更的
  for (const [masterIdStr, cached] of Object.entries(detailCache)) {
    const masterId = Number(masterIdStr);
    const masterRow = masterStore.getRow(masterId);
    
    // 如果主表已经在 changedMasters 中，跳过
    if (changedMasters.some(m => m.id === masterId)) continue;
    
    const detailRows = [...cached.material, ...cached.auxiliary, ...cached.package];
    const hasDetailChanges = detailRows.some(
      row => row._isNew || row._isDeleted || Object.keys(row._changeType || {}).length > 0
    );
    
    if (hasDetailChanges && masterRow) {
      const masterItem = buildRecordItem(masterRow, 'CostEval');
      const detailItems = detailRows
        .filter(row => row._isNew || row._isDeleted || Object.keys(row._changeType || {}).length > 0)
        .map(row => buildRecordItem(row, 'CostEvalDetail', masterId));
      
      result.push({
        pageCode: 'cost-eval',
        master: masterItem,
        details: { CostEvalDetail: detailItems }
      });
    }
  }
  
  // 当前选中主表的从表变更（如果主表本身没变）
  if (currentMaster.value) {
    const masterId = currentMaster.value.id;
    const alreadyIncluded = result.some(r => r.master.id === masterId);
    
    if (!alreadyIncluded) {
      const detailRows = [
        ...detailStores.material.rows.value,
        ...detailStores.auxiliary.rows.value,
        ...detailStores.package.rows.value
      ];
      const hasDetailChanges = detailRows.some(
        row => row._isNew || row._isDeleted || Object.keys(row._changeType || {}).length > 0
      );
      
      if (hasDetailChanges) {
        const masterRow = masterStore.getRow(masterId);
        if (masterRow) {
          const masterItem = buildRecordItem(masterRow, 'CostEval');
          const detailItems = detailRows
            .filter(row => row._isNew || row._isDeleted || Object.keys(row._changeType || {}).length > 0)
            .map(row => buildRecordItem(row, 'CostEvalDetail', masterId));
          
          result.push({
            pageCode: 'cost-eval',
            master: masterItem,
            details: { CostEvalDetail: detailItems }
          });
        }
      }
    }
  }
  
  return result;
}

/**
 * 构建单条记录的保存参数
 */
function buildRecordItem(row: any, tableCode: string, parentId?: number) {
  const isNew = row._isNew === true;
  const isDeleted = row._isDeleted === true;
  const changeType = row._changeType || {};
  const hasChanges = Object.keys(changeType).length > 0;

  // 确定状态
  let status: string;
  if (isDeleted) {
    status = 'deleted';
  } else if (isNew) {
    status = 'added';
  } else if (hasChanges) {
    status = 'modified';
  } else {
    status = 'unchanged';
  }

  // 构建数据（排除内部字段）
  const data: Record<string, any> = { _tableCode: tableCode };
  for (const [key, value] of Object.entries(row)) {
    if (key.startsWith('_')) continue; // 跳过内部字段
    data[key] = value;
  }

  // 如果是新增的从表行，设置外键
  if (isNew && parentId && tableCode === 'CostEvalDetail') {
    data.evalId = parentId;
  }

  // 构建变更记录（只记录用户编辑的字段）
  const changes: Array<{ field: string; oldValue: any; newValue: any; changeType: string }> = [];
  for (const [field, type] of Object.entries(changeType)) {
    changes.push({
      field,
      oldValue: null, // 暂时不记录原值
      newValue: row[field],
      changeType: type as string
    });
  }

  return {
    id: isNew ? null : row.id,
    status,
    data,
    changes: changes.length > 0 ? changes : undefined,
    updateTime: row.updateTime
  };
}

function handleRefresh() {
  masterStore.reset();
  detailStores.material.reset();
  detailStores.auxiliary.reset();
  detailStores.package.reset();
  Object.keys(detailCache).forEach(key => delete detailCache[Number(key)]);
  currentMaster.value = null;
  loadMasterList();
}

function handleSearch(text: string) {
  masterGridRef.value?.quickFilter(text);
}

function handleAdvancedQuery() {
  message.info('高级查询功能待实现');
}

// ========== 删除回调 ==========
function onMasterRowsDeleted(rows: any[]) {
  rows.forEach(row => {
    if (detailCache[row.id]) {
      delete detailCache[row.id];
    }
  });
  if (rows.some(r => r.id === currentMaster.value?.id)) {
    currentMaster.value = null;
    detailStores.material.reset();
    detailStores.auxiliary.reset();
    detailStores.package.reset();
  }
}

function onDetailRowsDeleted(_tabKey: TabKey) {
  updateMasterAggregates();
  if (currentMaster.value) {
    masterGridRef.value?.refreshRow(currentMaster.value.id);
  }
}

// ========== 全局快捷键 ==========
function onGlobalKeyDown(e: KeyboardEvent) {
  if (e.ctrlKey && e.key === 's') {
    e.preventDefault();
    handleSave();
  }
}

// ========== 关闭页面拦截 ==========
function checkDirty() {
  // 检查主表
  if (masterStore.isDirty.value) return true;
  
  // 检查当前从表
  if (detailStores.material.isDirty.value || 
      detailStores.auxiliary.isDirty.value || 
      detailStores.package.isDirty.value) {
    return true;
  }
  
  // 检查缓存中的从表
  for (const cached of Object.values(detailCache)) {
    const allRows = [...cached.material, ...cached.auxiliary, ...cached.package];
    if (allRows.some(row => row._isNew || row._isDeleted || Object.keys(row._changeType || {}).length > 0)) {
      return true;
    }
  }
  
  return false;
}

function onBeforeUnload(e: BeforeUnloadEvent) {
  if (checkDirty()) {
    e.preventDefault();
    e.returnValue = '';
  }
}

onMounted(() => {
  document.addEventListener('keydown', onGlobalKeyDown);
  window.addEventListener('beforeunload', onBeforeUnload);
});

onUnmounted(() => {
  document.removeEventListener('keydown', onGlobalKeyDown);
  window.removeEventListener('beforeunload', onBeforeUnload);
});

// ========== 初始化 ==========
async function init() {
  await loadMetadata();
  await loadMasterList();
}

init();
</script>

<style scoped>
.eval-v3-page {
  height: 100%;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  padding: 8px;
  gap: 8px;
}

.split-container {
  flex: 1;
  min-height: 0;
}

.master-section {
  height: 100%;
  background: #fff;
  border-radius: 4px;
  overflow: hidden;
}

.detail-section {
  height: 100%;
  display: flex;
  flex-direction: column;
  background: #fff;
  border-radius: 4px;
  overflow: hidden;
}

.detail-grids {
  flex: 1;
  min-height: 0;
  display: flex;
  gap: 1px;
  background: #e8e8e8;
}

.detail-grid-wrapper {
  flex: 1;
  min-width: 0;
  background: #fff;
}
</style>
