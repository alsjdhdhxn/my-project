<template>
  <div class="master-detail-page">
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
        <NButton size="small" quaternary @click="handleRefresh">
          <template #icon><icon-ant-design-reload-outlined /></template>
        </NButton>
      </div>
      <div v-if="tabs.length > 1" class="toolbar-row">
        <NButton
          v-for="tab in tabs"
          :key="tab.key"
          :type="visibleTabKeys.has(tab.key) ? 'primary' : 'default'"
          size="small"
          @click="toggleTab(tab.key)"
        >
          {{ tab.title }}
        </NButton>
      </div>
    </MetaFloatToolbar>

    <!-- 主从表分隔区域 -->
    <NSplit
      v-if="store.isReady"
      direction="vertical"
      :default-size="0.5"
      :min="0.2"
      :max="0.8"
      class="split-container"
    >
      <!-- 主表 -->
      <template #1>
        <div class="master-section">
          <AgGridVue
            class="ag-theme-alpine"
            style="width: 100%; height: 100%"
            :rowData="store.visibleMasterRows"
            :columnDefs="masterColumnDefs"
            :defaultColDef="defaultColDef"
            :getRowId="getRowId"
            :rowSelection="masterRowSelection"
            @grid-ready="onMasterGridReady"
            @selection-changed="onMasterSelectionChanged"
            @cell-value-changed="onMasterCellValueChanged"
            @cell-editing-started="masterAdapter.onCellEditingStarted"
            @cell-editing-stopped="masterAdapter.onCellEditingStopped"
          />
        </div>
      </template>

      <!-- 从表 Tabs -->
      <template #2>
        <div class="detail-section">
          <MetaTabs
            :tabs="tabs"
            :visibleKeys="visibleTabKeys"
            :store="store"
            :detailColumnDefs="detailColumnDefs"
            :defaultColDef="defaultColDef"
            @cell-value-changed="onDetailCellValueChanged"
          />
        </div>
      </template>
    </NSplit>

    <!-- 加载中 -->
    <div v-else class="loading-container">
      <NSpin size="large" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, shallowRef, computed, onMounted, onUnmounted, watch } from 'vue';
import { NButton, NInput, NSplit, NSpin, useMessage } from 'naive-ui';
import { AgGridVue } from 'ag-grid-vue3';
import { ModuleRegistry, AllCommunityModule, themeQuartz } from 'ag-grid-community';
import type { GridApi, ColDef, GridReadyEvent, CellValueChangedEvent } from 'ag-grid-community';
import { useMasterDetailStore } from '@/store/modules/master-detail';
import { useGridAdapter, getCellClassRules } from '@/composables/useGridAdapter';
import { parsePageComponents, buildSaveParams, type ParsedPageConfig } from '@/logic/calc-engine';
import { fetchDynamicData, fetchPageComponents, saveDynamicData } from '@/service/api';
import { loadTableMeta } from '@/composables/useMetaColumns';
import MetaFloatToolbar from './MetaFloatToolbar.vue';
import MetaTabs from './MetaTabs.vue';

// 注册 AG Grid 模块（全局只注册一次）
if (!(window as any).__AG_GRID_REGISTERED__) {
  ModuleRegistry.registerModules([AllCommunityModule]);
  (window as any).__AG_GRID_REGISTERED__ = true;
}

// ==================== Props ====================

const props = defineProps<{
  pageCode: string;
}>();

const message = useMessage();

// ==================== Store ====================

const store = useMasterDetailStore(props.pageCode);

// ==================== State ====================

const masterGridApi = shallowRef<GridApi | null>(null);
const searchText = ref('');
const visibleTabKeys = ref(new Set<string>());

// ==================== Computed ====================

const tabs = computed(() => store.config?.tabs || []);

const masterColumnDefs = computed<ColDef[]>(() => {
  return store.masterColumns.map(col => ({
    ...col,
    cellClassRules: getCellClassRules()
  }));
});

const detailColumnDefs = computed<ColDef[]>(() => {
  return store.detailColumns.map(col => ({
    ...col,
    cellClassRules: getCellClassRules()
  }));
});

const defaultColDef: ColDef = {
  sortable: true,
  filter: true,
  resizable: true,
  minWidth: 80
};

const masterRowSelection = { mode: 'singleRow', checkboxes: false, enableClickSelection: true } as const;

// ==================== Adapter ====================

const masterAdapter = useGridAdapter({
  gridApi: masterGridApi,
  rowsGetter: () => store.visibleMasterRows,
  onFieldUpdate: (rowId, field, value) => {
    store.updateField(rowId, field, value, 'user', true);
  }
});

// ==================== Grid Helpers ====================

function getRowId(params: any) {
  return String(params.data?.id);
}

// ==================== Event Handlers ====================

function onMasterGridReady(params: GridReadyEvent) {
  masterGridApi.value = params.api;
}

async function onMasterSelectionChanged() {
  const api = masterGridApi.value;
  if (!api) return;

  const selectedRows = api.getSelectedRows();
  if (selectedRows.length !== 1) return;

  const masterId = selectedRows[0].id;
  const needLoad = store.selectMaster(masterId);

  if (needLoad) {
    await loadDetailData(masterId);
  }
}

function onMasterCellValueChanged(event: CellValueChangedEvent) {
  masterAdapter.onCellValueChanged(event);
}

function onDetailCellValueChanged(event: { tabKey: string; rowId: number; field: string; value: any }) {
  store.updateField(event.rowId, event.field, event.value, 'user', false);
}

// ==================== Data Loading ====================

async function loadMetadata() {
  // 1. 加载页面组件配置
  const pageRes = await fetchPageComponents(props.pageCode);

  if (pageRes.error || !pageRes.data) {
    message.error('加载页面配置失败');
    return;
  }

  const pageConfig = parsePageComponents(pageRes.data);
  if (!pageConfig) {
    message.error('解析页面配置失败');
    return;
  }

  // 2. 加载主从表元数据并转换为 ColDef
  const [masterMeta, detailMeta] = await Promise.all([
    loadTableMeta(pageConfig.masterTableCode),
    loadTableMeta(pageConfig.detailTableCode)
  ]);

  if (!masterMeta || !detailMeta) {
    message.error('加载表元数据失败');
    return;
  }

  // 3. 初始化 Store（传入转换后的 ColDef 和原始列元数据）
  store.init(
    pageConfig,
    masterMeta.columns,      // AG Grid ColDef[]
    detailMeta.columns,      // AG Grid ColDef[]
    masterMeta.rawColumns,   // 原始列元数据，用于验证等
    detailMeta.rawColumns
  );

  // 4. 初始化可见 Tab
  pageConfig.tabs.forEach(tab => visibleTabKeys.value.add(tab.key));
}

async function loadMasterData() {
  const tableCode = store.config?.masterTableCode;
  if (!tableCode) return;

  const { data, error } = await fetchDynamicData(tableCode, {});
  if (error) {
    message.error('加载主表数据失败');
    return;
  }

  store.loadMaster(data?.list || []);

  // 自动选中第一行
  if (store.masterRows.length > 0) {
    setTimeout(() => {
      masterGridApi.value?.forEachNode((node, index) => {
        if (index === 0) node.setSelected(true);
      });
    }, 100);
  }
}

async function loadDetailData(masterId: number) {
  const tableCode = store.config?.detailTableCode;
  const fkColumn = 'evalId'; // TODO: 从 TABLE_METADATA.PARENT_FK_COLUMN 读取

  if (!tableCode) return;

  const { data, error } = await fetchDynamicData(tableCode, { [fkColumn]: masterId });
  if (error) {
    message.error('加载从表数据失败');
    return;
  }

  store.loadDetail(data?.list || []);
}

// ==================== Toolbar Actions ====================

function toggleTab(key: string) {
  if (visibleTabKeys.value.has(key)) {
    visibleTabKeys.value.delete(key);
  } else {
    visibleTabKeys.value.add(key);
  }
}

function handleSearch(text: string) {
  masterGridApi.value?.setGridOption('quickFilterText', text);
}

async function handleRefresh() {
  store.reset();
  await loadMasterData();
}

async function handleSave() {
  if (!store.isDirty) {
    message.info('没有需要保存的数据');
    return;
  }

  // TODO: 验证

  const params = buildSaveParams(
    props.pageCode,
    store.masterRows,
    new Map(), // detailCache - 从 store 内部获取
    store.currentMasterId,
    store.detailRows,
    store.config?.detailTableCode || '',
    'evalId' // TODO: 从元数据读取
  );

  if (params.length === 0) {
    message.warning('没有有效的保存数据');
    return;
  }

  try {
    for (const param of params) {
      const { error } = await saveDynamicData(param);
      if (error) {
        message.error('保存失败: ' + (error.msg || '未知错误'));
        return;
      }
    }

    message.success('保存成功');
    store.clearChanges();
    await handleRefresh();
  } catch (e: any) {
    message.error('保存失败: ' + (e.message || '网络错误'));
  }
}

// ==================== Keyboard Shortcuts ====================

function onKeyDown(e: KeyboardEvent) {
  if (e.ctrlKey && e.key === 's') {
    e.preventDefault();
    handleSave();
  }
}

// ==================== Lifecycle ====================

onMounted(async () => {
  document.addEventListener('keydown', onKeyDown);
  window.addEventListener('beforeunload', onBeforeUnload);

  await loadMetadata();
  await loadMasterData();
});

onUnmounted(() => {
  document.removeEventListener('keydown', onKeyDown);
  window.removeEventListener('beforeunload', onBeforeUnload);
});

function onBeforeUnload(e: BeforeUnloadEvent) {
  if (store.isDirty) {
    e.preventDefault();
    e.returnValue = '';
  }
}
</script>

<style scoped>
.master-detail-page {
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

.master-section,
.detail-section {
  height: 100%;
  background: #fff;
  border-radius: 4px;
  overflow: hidden;
}

.loading-container {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
}

.toolbar-row {
  display: flex;
  gap: 8px;
  align-items: center;
}
</style>
