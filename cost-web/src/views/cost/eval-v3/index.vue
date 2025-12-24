<template>
  <div class="eval-v3-page">
    <!-- 工具栏 -->
    <MetaToolbar
      :isDirty="masterStore.isDirty.value || detailStores.material.isDirty.value || detailStores.auxiliary.isDirty.value || detailStores.package.isDirty.value"
      :hasSelection="selectedDetails.length > 0"
      :showAdd="false"
      :showDelete="false"
      @save="handleSave"
      @refresh="handleRefresh"
      @search="handleSearch"
      @advancedQuery="handleAdvancedQuery"
    >
      <template #buttons>
        <!-- Tab 开关按钮 -->
        <NButton 
          v-for="tab in tabs" 
          :key="tab.key"
          :type="tab.visible ? 'primary' : 'default'"
          size="small"
          @click="toggleTab(tab.key)"
        >
          {{ tab.title }}
        </NButton>
      </template>
    </MetaToolbar>

    <!-- 主表区域 -->
    <div class="master-section">
      <div class="section-title">评估单主表</div>
      <MetaGrid
        ref="masterGridRef"
        :columns="masterColumns"
        :store="masterStore"
        height="100%"
        @selectionChanged="onMasterSelectionChanged"
        @cellChanged="onMasterCellChanged"
      />
    </div>

    <!-- 从表区域（多 Tab 并排） -->
    <div class="detail-tabs-container">
      <div 
        v-for="tab in visibleTabs" 
        :key="tab.key"
        class="detail-tab"
      >
        <div class="tab-header">
          <span class="tab-title">{{ tab.title }}</span>
          <span v-if="currentMaster" class="current-master">{{ currentMaster.evalNo }}</span>
          <NButton text size="small" class="close-btn" @click="closeTab(tab.key)">
            <span class="i-carbon-close" />
          </NButton>
        </div>
        <MetaGrid
          :ref="(el) => setDetailGridRef(tab.key, el)"
          :columns="getDetailColumns(tab.key)"
          :store="detailStores[tab.key]"
          :calcEngine="detailCalcEngines[tab.key]"
          height="100%"
          selectionMode="multi"
          showCheckbox
          @selectionChanged="(rows) => onDetailSelectionChanged(tab.key, rows)"
          @cellChanged="(params) => onDetailCellChanged(tab.key, params)"
        />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue';
import { NButton, useMessage } from 'naive-ui';
import type { ColDef } from 'ag-grid-community';
import { fetchDynamicData } from '@/service/api';
import { useGridStore } from '@/composables/useGridStore';
import { useCalcEngine, type CalcRule, type AggRule } from '@/composables/useCalcEngine';
import MetaGrid from '@/components/meta-v2/MetaGrid.vue';
import MetaToolbar from '@/components/meta-v2/MetaToolbar.vue';

type TabKey = 'material' | 'auxiliary' | 'package';

const message = useMessage();

// ========== 数据存储 ==========
const masterStore = useGridStore();
const detailStores = {
  material: useGridStore(),
  auxiliary: useGridStore(),
  package: useGridStore()
};

// ========== 计算引擎 ==========
// 原料/辅料计算规则
const materialCalcRules: CalcRule[] = [
  { field: 'batchQty', expression: 'apexPl * perHl / 100 / yield * 100', dependencies: ['perHl'], order: 1 },
  { field: 'costBatch', expression: 'batchQty * price', dependencies: ['batchQty', 'price'], order: 2 }
];

// 包材计算规则
const packageCalcRules: CalcRule[] = [
  { field: 'packQty', expression: 'apexPl * 1000', dependencies: [], order: 1 },
  { field: 'packCost', expression: 'packQty * price', dependencies: ['packQty', 'price'], order: 2 }
];

// 创建计算引擎
const detailCalcEngines = {
  material: useCalcEngine(detailStores.material),
  auxiliary: useCalcEngine(detailStores.auxiliary),
  package: useCalcEngine(detailStores.package)
};

// 注册计算规则
detailCalcEngines.material.registerCalcRules(materialCalcRules);
detailCalcEngines.auxiliary.registerCalcRules(materialCalcRules);
detailCalcEngines.package.registerCalcRules(packageCalcRules);

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

function closeTab(key: TabKey) {
  const tab = tabs.value.find(t => t.key === key);
  if (tab) tab.visible = false;
}

// ========== 列定义 ==========
const masterColumns: ColDef[] = [
  { field: 'evalNo', headerName: '评估单号', width: 120, editable: false },
  { field: 'productName', headerName: '产品名称', width: 150, editable: true },
  { field: 'apexPl', headerName: '批量(万片)', width: 100, editable: true },
  { field: 'yield', headerName: '收率(%)', width: 80, editable: true },
  { field: 'outPriceRmb', headerName: '出厂价', width: 100, editable: true },
  { field: 'totalYl', headerName: '原料合计', width: 100, editable: false },
  { field: 'totalFl', headerName: '辅料合计', width: 100, editable: false },
  { field: 'totalPack', headerName: '包材合计', width: 100, editable: false },
  { field: 'totalCost', headerName: '总成本', width: 100, editable: false }
];

const materialColumns: ColDef[] = [
  { field: 'materialName', headerName: '物料名称', width: 150, editable: true },
  { field: 'perHl', headerName: '百万片用量', width: 100, editable: true },
  { field: 'price', headerName: '单价', width: 100, editable: true },
  { field: 'batchQty', headerName: '批用量', width: 100, editable: false },
  { field: 'costBatch', headerName: '批成本', width: 100, editable: false }
];

const packageColumns: ColDef[] = [
  { field: 'materialName', headerName: '包材名称', width: 150, editable: true },
  { field: 'packSpec', headerName: '规格', width: 100, editable: true },
  { field: 'price', headerName: '单价', width: 100, editable: true },
  { field: 'packQty', headerName: '包装数量', width: 100, editable: false },
  { field: 'packCost', headerName: '包装成本', width: 100, editable: false }
];

function getDetailColumns(tabKey: TabKey): ColDef[] {
  return tabKey === 'package' ? packageColumns : materialColumns;
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

// 从表数据缓存（按 masterId 存储）
const detailCache = reactive<Record<number, {
  material: any[];
  auxiliary: any[];
  package: any[];
}>>({});

// ========== 事件处理 ==========
async function onMasterSelectionChanged(rows: any[]) {
  if (rows.length === 1) {
    const newMaster = rows[0];
    
    // 保存当前从表数据到缓存
    if (currentMaster.value) {
      saveDetailToCache(currentMaster.value.id);
    }
    
    currentMaster.value = newMaster;
    await loadDetails(newMaster.id);
  }
}

// 保存从表数据到缓存
function saveDetailToCache(masterId: number) {
  detailCache[masterId] = {
    material: JSON.parse(JSON.stringify(detailStores.material.rows.value)),
    auxiliary: JSON.parse(JSON.stringify(detailStores.auxiliary.rows.value)),
    package: JSON.parse(JSON.stringify(detailStores.package.rows.value))
  };
}

function onMasterCellChanged(params: { field: string; rowId: any; newValue: any }) {
  const { field, newValue } = params;
  
  // 更新当前主表数据
  if (currentMaster.value) {
    currentMaster.value[field] = newValue;
  }

  // 如果是影响从表计算的字段，触发从表重算
  if (['apexPl', 'yield'].includes(field)) {
    const context = { apexPl: currentMaster.value?.apexPl || 0, yield: currentMaster.value?.yield || 100 };
    
    (['material', 'auxiliary', 'package'] as TabKey[]).forEach(tabKey => {
      detailCalcEngines[tabKey].setContext(context);
      detailCalcEngines[tabKey].onContextChange(field);
      detailGridRefs[tabKey]?.refreshAll();
    });
  }

  // 重新聚合
  updateMasterAggregates();
  masterGridRef.value?.refreshRow(params.rowId);
}

function onDetailSelectionChanged(tabKey: TabKey, rows: any[]) {
  selectedDetails.value = rows;
}

function onDetailCellChanged(tabKey: TabKey, params: { field: string; rowId: any }) {
  // 刷新当前行
  detailGridRefs[tabKey]?.refreshRow(params.rowId);
  // 重新聚合
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
    // 默认选中第一行
    if (masterStore.rows.value.length > 0) {
      setTimeout(() => {
        masterGridRef.value?.gridApi?.getDisplayedRowAtIndex(0)?.setSelected(true);
      }, 100);
    }
  }
}

async function loadDetails(masterId: number) {
  // 优先从缓存加载
  if (detailCache[masterId]) {
    const cached = detailCache[masterId];
    detailStores.material.load(cached.material, true);  // 保留状态
    detailStores.auxiliary.load(cached.auxiliary, true);
    detailStores.package.load(cached.package, true);
  } else {
    // 缓存没有，从后端加载
    const { data, error } = await fetchDynamicData('CostEvalDetail', { EVAL_ID: masterId });
    if (!error && data) {
      const list = data.list || [];
      
      // 按 useFlag 分组
      detailStores.material.load(list.filter((r: any) => r.useFlag === '原料'));
      detailStores.auxiliary.load(list.filter((r: any) => r.useFlag === '辅料'));
      detailStores.package.load(list.filter((r: any) => r.useFlag === '包材'));
    }
  }

  // 设置计算上下文
  const context = { apexPl: currentMaster.value?.apexPl || 0, yield: currentMaster.value?.yield || 100 };
  (['material', 'auxiliary', 'package'] as TabKey[]).forEach(tabKey => {
    detailCalcEngines[tabKey].setContext(context);
    // 只有从后端加载时才初始化计算（缓存数据已经计算过了）
    if (!detailCache[masterId]) {
      detailCalcEngines[tabKey].initCalc();
    }
  });

  // 刷新所有从表
  (['material', 'auxiliary', 'package'] as TabKey[]).forEach(tabKey => {
    detailGridRefs[tabKey]?.refreshAll();
  });

  // 更新主表聚合
  updateMasterAggregates();
  if (currentMaster.value) {
    masterGridRef.value?.refreshRow(currentMaster.value.id);
  }
}

// ========== 聚合计算 ==========
function updateMasterAggregates() {
  if (!currentMaster.value) return;

  // 原料合计
  const totalYl = detailStores.material.visibleRows.value.reduce(
    (sum, r) => sum + (Number(r.costBatch) || 0), 0
  );
  // 辅料合计
  const totalFl = detailStores.auxiliary.visibleRows.value.reduce(
    (sum, r) => sum + (Number(r.costBatch) || 0), 0
  );
  // 包材合计
  const totalPack = detailStores.package.visibleRows.value.reduce(
    (sum, r) => sum + (Number(r.packCost) || 0), 0
  );
  // 总成本
  const totalCost = totalYl + totalFl + totalPack;

  // 更新主表
  const round2 = (v: number) => Math.round(v * 100) / 100;
  masterStore.updateFields(currentMaster.value.id, {
    totalYl: round2(totalYl),
    totalFl: round2(totalFl),
    totalPack: round2(totalPack),
    totalCost: round2(totalCost)
  });
  masterStore.markChange(currentMaster.value.id, 'totalYl', 'cascade');
  masterStore.markChange(currentMaster.value.id, 'totalFl', 'cascade');
  masterStore.markChange(currentMaster.value.id, 'totalPack', 'cascade');
  masterStore.markChange(currentMaster.value.id, 'totalCost', 'cascade');

  // 同步到 currentMaster
  currentMaster.value.totalYl = round2(totalYl);
  currentMaster.value.totalFl = round2(totalFl);
  currentMaster.value.totalPack = round2(totalPack);
  currentMaster.value.totalCost = round2(totalCost);
}

// ========== 工具栏事件 ==========
function handleSave() {
  message.info('保存功能待实现');
}

function handleRefresh() {
  masterStore.reset();
  detailStores.material.reset();
  detailStores.auxiliary.reset();
  detailStores.package.reset();
  // 清空缓存
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

// ========== 初始化 ==========
loadMasterList();
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

.master-section {
  height: 200px;
  min-height: 150px;
  display: flex;
  flex-direction: column;
  background: #fff;
  border-radius: 4px;
  overflow: hidden;
  flex-shrink: 0;
}

.section-title {
  padding: 8px 12px;
  font-size: 14px;
  font-weight: 500;
  border-bottom: 1px solid #e8e8e8;
}

.detail-tabs-container {
  flex: 1;
  min-height: 0;
  display: flex;
  gap: 8px;
  overflow: hidden;
}

.detail-tab {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  background: #fff;
  border-radius: 4px;
  overflow: hidden;
}

.tab-header {
  padding: 8px 12px;
  font-size: 14px;
  font-weight: 500;
  border-bottom: 1px solid #e8e8e8;
  display: flex;
  align-items: center;
  gap: 8px;
}

.tab-title {
  font-weight: 500;
}

.current-master {
  font-size: 12px;
  color: #666;
  font-weight: normal;
}

.close-btn {
  margin-left: auto;
  color: #999;
}

.close-btn:hover {
  color: #f5222d;
}
</style>
