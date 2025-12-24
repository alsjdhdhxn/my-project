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

    <!-- 主表区域 -->
    <div class="master-section">
      <MetaGrid
        ref="masterGridRef"
        :columns="masterColumns"
        :store="masterStore"
        :defaultNewRow="masterDefaultRow"
        firstEditableField="productName"
        height="100%"
        @selectionChanged="onMasterSelectionChanged"
        @cellChanged="onMasterCellChanged"
        @rowsDeleted="onMasterRowsDeleted"
      />
    </div>

    <!-- 从表区域 -->
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
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, onUnmounted } from 'vue';
import { NButton, NDivider, NInput, useMessage } from 'naive-ui';
import type { ColDef } from 'ag-grid-community';
import { fetchDynamicData } from '@/service/api';
import { useGridStore } from '@/composables/useGridStore';
import { useCalcEngine, type CalcRule } from '@/composables/useCalcEngine';
import MetaGrid from '@/components/meta-v2/MetaGrid.vue';
import MetaFloatToolbar from '@/components/meta-v2/MetaFloatToolbar.vue';

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
const materialCalcRules: CalcRule[] = [
  { field: 'batchQty', expression: 'apexPl * perHl / 100 / yield * 100', dependencies: ['perHl'], order: 1 },
  { field: 'costBatch', expression: 'batchQty * price', dependencies: ['batchQty', 'price'], order: 2 }
];

const packageCalcRules: CalcRule[] = [
  { field: 'packQty', expression: 'apexPl * 1000', dependencies: [], order: 1 },
  { field: 'packCost', expression: 'packQty * price', dependencies: ['packQty', 'price'], order: 2 }
];

const detailCalcEngines = {
  material: useCalcEngine(detailStores.material),
  auxiliary: useCalcEngine(detailStores.auxiliary),
  package: useCalcEngine(detailStores.package)
};

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

// ========== 默认新增行配置 ==========
const masterDefaultRow = {
  evalNo: `EVAL-${Date.now()}`,
  productName: '',
  apexPl: 0,
  yield: 100,
  outPriceRmb: 0,
  totalYl: 0,
  totalFl: 0,
  totalPack: 0,
  totalCost: 0
};

function getDetailDefaultRow(tabKey: TabKey) {
  return {
    evalId: currentMaster.value?.id,
    useFlag: tabKey === 'material' ? '原料' : tabKey === 'auxiliary' ? '辅料' : '包材',
    materialName: '',
    perHl: 0,
    price: 0,
    batchQty: 0,
    costBatch: 0,
    packSpec: '',
    packQty: 0,
    packCost: 0
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
  detailCache[masterId] = {
    material: JSON.parse(JSON.stringify(detailStores.material.rows.value)),
    auxiliary: JSON.parse(JSON.stringify(detailStores.auxiliary.rows.value)),
    package: JSON.parse(JSON.stringify(detailStores.package.rows.value))
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

  const totalYl = detailStores.material.visibleRows.value.reduce((sum, r) => sum + (Number(r.costBatch) || 0), 0);
  const totalFl = detailStores.auxiliary.visibleRows.value.reduce((sum, r) => sum + (Number(r.costBatch) || 0), 0);
  const totalPack = detailStores.package.visibleRows.value.reduce((sum, r) => sum + (Number(r.packCost) || 0), 0);
  const totalCost = totalYl + totalFl + totalPack;

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
  return masterStore.isDirty.value || 
    detailStores.material.isDirty.value || 
    detailStores.auxiliary.isDirty.value || 
    detailStores.package.isDirty.value;
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
  flex: 1;
  min-height: 0;
  background: #fff;
  border-radius: 4px;
  overflow: hidden;
}

.detail-section {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
  background: #fff;
  border-radius: 4px;
  overflow: hidden;
}

.detail-header {
  padding: 6px 8px;
  border-bottom: 1px solid #e8e8e8;
  display: flex;
  gap: 4px;
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
