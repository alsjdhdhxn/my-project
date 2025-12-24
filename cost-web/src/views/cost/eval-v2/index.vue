<template>
  <div class="eval-v2-page">
    <!-- 工具栏 -->
    <div class="toolbar">
      <NSpace>
        <NButton type="primary" :disabled="!store.isDirty.value" @click="handleSave">
          <template #icon><span class="i-carbon-save" /></template>
          保存
        </NButton>
        <NButton @click="handleRefresh">
          <template #icon><span class="i-carbon-refresh" /></template>
          刷新
        </NButton>
      </NSpace>
      <div class="toolbar-right">
        <!-- Tab 开关按钮 -->
        <NSpace>
          <NButton 
            v-for="tab in store.tabs.value" 
            :key="tab.key"
            :type="tab.visible ? 'primary' : 'default'"
            size="small"
            @click="store.toggleTab(tab.key)"
          >
            {{ tab.title }}
          </NButton>
        </NSpace>
        <span v-if="store.isDirty.value" class="dirty-hint">有未保存的修改</span>
      </div>
    </div>

    <!-- 主表区域 -->
    <div class="master-section">
      <div class="section-title">评估单主表</div>
      <AgGridVue
        style="height: 100%; width: 100%"
        :theme="theme"
        :columnDefs="masterColumnDefs"
        :rowData="masterRowData"
        :defaultColDef="defaultColDef"
        :rowSelection="masterRowSelection"
        :getRowId="getRowId"
        @grid-ready="onMasterGridReady"
        @selection-changed="onMasterSelectionChanged"
        @cell-value-changed="onMasterCellValueChanged"
      />
    </div>

    <!-- 从表区域（多 Tab 并排） -->
    <div class="detail-tabs-container">
      <div 
        v-for="tab in store.visibleTabs.value" 
        :key="tab.key"
        class="detail-tab"
      >
        <div class="tab-header">
          <span class="tab-title">{{ tab.title }}</span>
          <span v-if="store.master.value.id" class="current-master">
            {{ store.master.value.evalNo }}
          </span>
          <NButton 
            text 
            size="small" 
            class="close-btn"
            @click="store.closeTab(tab.key)"
          >
            <span class="i-carbon-close" />
          </NButton>
        </div>
        <AgGridVue
          style="height: 100%; width: 100%"
          :theme="theme"
          :columnDefs="getDetailColumnDefs(tab.key)"
          :rowData="store.details.value[tab.key]"
          :defaultColDef="defaultColDef"
          :rowSelection="detailRowSelection"
          :getRowId="getRowId"
          @grid-ready="(e) => onDetailGridReady(tab.key, e)"
          @cell-value-changed="(e) => onDetailCellValueChanged(tab.key, e)"
        />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { AgGridVue } from 'ag-grid-vue3';
import { ModuleRegistry, AllCommunityModule, themeQuartz } from 'ag-grid-community';
import type { GridApi, ColDef, CellValueChangedEvent, GetRowIdParams } from 'ag-grid-community';
import { NButton, NSpace, useMessage } from 'naive-ui';
import { fetchDynamicData } from '@/service/api';
import { useDataStore, type TabKey } from './useDataStore';
import { useCalcEngine } from './useCalcEngine';

// 注册 AG Grid 模块
if (!(window as any).__AG_GRID_REGISTERED__) {
  ModuleRegistry.registerModules([AllCommunityModule]);
  (window as any).__AG_GRID_REGISTERED__ = true;
}

const theme = themeQuartz;
const message = useMessage();

// 数据存储
const store = useDataStore();
// 计算引擎
const calc = useCalcEngine(store);

// Grid API
const masterGridApi = ref<GridApi>();
const detailGridApis = ref<Record<TabKey, GridApi | undefined>>({
  material: undefined,
  auxiliary: undefined,
  package: undefined
});

// 主表列定义
const masterColumnDefs = computed<ColDef[]>(() => [
  { field: 'evalNo', headerName: '评估单号', width: 120, editable: false },
  { field: 'productName', headerName: '产品名称', width: 150, editable: true, cellStyle: getCellStyle },
  { field: 'apexPl', headerName: '批量(万片)', width: 100, editable: true, cellStyle: getCellStyle },
  { field: 'yield', headerName: '收率(%)', width: 80, editable: true, cellStyle: getCellStyle },
  { field: 'outPriceRmb', headerName: '出厂价', width: 100, editable: true, cellStyle: getCellStyle },
  { field: 'totalYl', headerName: '原料合计', width: 100, editable: false, cellStyle: getCellStyle },
  { field: 'totalFl', headerName: '辅料合计', width: 100, editable: false, cellStyle: getCellStyle },
  { field: 'totalPack', headerName: '包材合计', width: 100, editable: false, cellStyle: getCellStyle },
  { field: 'totalCost', headerName: '总成本', width: 100, editable: false, cellStyle: getCellStyle }
]);

// 原料/辅料列定义
const materialColumnDefs: ColDef[] = [
  { field: 'materialName', headerName: '物料名称', width: 150, editable: true, cellStyle: getCellStyle },
  { field: 'perHl', headerName: '百万片用量', width: 100, editable: true, cellStyle: getCellStyle },
  { field: 'price', headerName: '单价', width: 100, editable: true, cellStyle: getCellStyle },
  { field: 'batchQty', headerName: '批用量', width: 100, editable: false, cellStyle: getCellStyle },
  { field: 'costBatch', headerName: '批成本', width: 100, editable: false, cellStyle: getCellStyle }
];

// 包材列定义（独立字段）
const packageColumnDefs: ColDef[] = [
  { field: 'materialName', headerName: '包材名称', width: 150, editable: true, cellStyle: getCellStyle },
  { field: 'packSpec', headerName: '规格', width: 100, editable: true, cellStyle: getCellStyle },
  { field: 'price', headerName: '单价', width: 100, editable: true, cellStyle: getCellStyle },
  { field: 'packQty', headerName: '包装数量', width: 100, editable: false, cellStyle: getCellStyle },
  { field: 'packCost', headerName: '包装成本', width: 100, editable: false, cellStyle: getCellStyle }
];

// 根据 Tab 类型获取列定义
function getDetailColumnDefs(tabKey: TabKey): ColDef[] {
  if (tabKey === 'package') return packageColumnDefs;
  return materialColumnDefs;
}

const defaultColDef: ColDef = {
  resizable: true,
  sortable: true
};

const masterRowSelection = { mode: 'singleRow', checkboxes: false, enableClickSelection: true } as const;
const detailRowSelection = { mode: 'multiRow', checkboxes: true, enableClickSelection: true } as const;

// 主表数据
const masterRowData = computed(() => masterList.value);
const masterList = ref<any[]>([]);

// 获取行 ID
function getRowId(params: GetRowIdParams) {
  return String(params.data.id);
}

// 单元格样式
function getCellStyle(params: any) {
  const changeType = params.data?._changeType?.[params.colDef.field];
  if (changeType === 'user') return { backgroundColor: '#e6ffe6' };
  if (changeType === 'cascade') return { backgroundColor: '#fffde6' };
  return null;
}

// 主表 Grid 就绪
function onMasterGridReady(params: { api: GridApi }) {
  masterGridApi.value = params.api;
  loadMasterList();
}

// 从表 Grid 就绪
function onDetailGridReady(tabKey: TabKey, params: { api: GridApi }) {
  detailGridApis.value[tabKey] = params.api;
}

// 加载主表列表
async function loadMasterList() {
  const { data, error } = await fetchDynamicData('CostEval', {});
  if (!error && data) {
    masterList.value = data.list || [];
    if (masterList.value.length > 0) {
      setTimeout(() => {
        masterGridApi.value?.getDisplayedRowAtIndex(0)?.setSelected(true);
      }, 100);
    }
  }
}

// 主表选中变化
async function onMasterSelectionChanged() {
  const selected = masterGridApi.value?.getSelectedRows() || [];
  if (selected.length === 1) {
    const row = selected[0];
    store.loadMaster(row);
    await loadDetails(row.id);
  }
}

// 加载从表数据
async function loadDetails(masterId: number) {
  const { data, error } = await fetchDynamicData('CostEvalDetail', { EVAL_ID: masterId });
  if (!error && data) {
    store.loadDetails(data.list || []);
    calc.initCalc();
    // 刷新所有从表 Grid
    refreshAllDetailGrids();
    refreshMasterGrid();
  }
}

// 刷新所有从表 Grid
function refreshAllDetailGrids() {
  (['material', 'auxiliary', 'package'] as TabKey[]).forEach(tabKey => {
    const api = detailGridApis.value[tabKey];
    if (api) {
      api.setGridOption('rowData', store.details.value[tabKey]);
    }
  });
}

// 刷新主表 Grid
function refreshMasterGrid() {
  const masterRow = masterList.value.find(r => r.id === store.master.value.id);
  if (masterRow) {
    masterRow.totalYl = store.master.value.totalYl;
    masterRow.totalFl = store.master.value.totalFl;
    masterRow.totalPack = store.master.value.totalPack;
    masterRow.totalCost = store.master.value.totalCost;
    masterRow._changeType = store.master.value._changeType;
    masterGridApi.value?.applyTransaction({ update: [masterRow] });
  }
}

// 主表单元格值变化
function onMasterCellValueChanged(event: CellValueChangedEvent) {
  const field = event.colDef.field;
  if (!field) return;

  // 同步更新 masterList 中的行（AG Grid 已经更新了 event.data）
  const masterRow = masterList.value.find(r => r.id === event.data.id);
  if (masterRow) {
    masterRow[field] = event.newValue;
    if (!masterRow._changeType) masterRow._changeType = {};
    masterRow._changeType[field] = 'user';
  }

  // 同步更新 store.master
  store.markMasterChange(field, 'user');
  store.updateMasterField(field as any, event.newValue);
  calc.onMasterChange(field);
  
  // 刷新所有从表
  (['material', 'auxiliary', 'package'] as TabKey[]).forEach(tabKey => {
    const api = detailGridApis.value[tabKey];
    if (api) {
      api.applyTransaction({ update: [...store.details.value[tabKey]] });
    }
  });
  
  refreshMasterGrid();
}

// 从表单元格值变化
function onDetailCellValueChanged(tabKey: TabKey, event: CellValueChangedEvent) {
  const field = event.colDef.field;
  const rowId = event.data?.id;
  
  if (!field || rowId === undefined || rowId === null) return;

  store.markDetailChange(tabKey, rowId, field, 'user');
  store.updateDetailField(tabKey, rowId, field as any, event.newValue);
  calc.onDetailChange(tabKey, rowId, field);
  
  // 刷新当前 Tab 的行
  const api = detailGridApis.value[tabKey];
  const updatedRow = store.details.value[tabKey].find(r => r.id === rowId);
  if (api && updatedRow) {
    api.applyTransaction({ update: [updatedRow] });
  }
  
  refreshMasterGrid();
}

// 保存
function handleSave() {
  message.info('保存功能待实现');
}

// 刷新
function handleRefresh() {
  store.reset();
  loadMasterList();
}
</script>

<style scoped>
.eval-v2-page {
  height: 100%;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  padding: 8px;
  gap: 8px;
}

.toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px;
  background: #fff;
  border-radius: 4px;
  flex-shrink: 0;
}

.toolbar-right {
  display: flex;
  align-items: center;
  gap: 12px;
}

.dirty-hint {
  color: #f5222d;
  font-size: 12px;
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

/* 多 Tab 并排容器 */
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
