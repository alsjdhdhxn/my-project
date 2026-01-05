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
    <template v-if="store.isReady">
      <!-- 有从表：上下分隔 -->
      <NSplit
        v-if="hasDetail"
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
              :getRowClass="masterGetRowClass"
              :rowSelection="masterRowSelection"
              :suppressContextMenu="true"
              :preventDefaultOnContextMenu="true"
              @grid-ready="onMasterGridReady"
              @selection-changed="onMasterSelectionChanged"
              @cell-value-changed="onMasterCellValueChanged"
              @cell-context-menu="onMasterContextMenu"
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
              :getRowClass="detailGetRowClass"
              @cell-value-changed="onDetailCellValueChanged"
              @cell-clicked="onDetailCellClicked"
              @context-menu="onDetailContextMenu"
            />
          </div>
        </template>
      </NSplit>

      <!-- 无从表：主表铺满 -->
      <div v-else class="master-section full">
        <AgGridVue
          class="ag-theme-alpine"
          style="width: 100%; height: 100%"
          :rowData="store.visibleMasterRows"
          :columnDefs="masterColumnDefs"
          :defaultColDef="defaultColDef"
          :getRowId="getRowId"
          :getRowClass="masterGetRowClass"
          :rowSelection="masterRowSelection"
          :suppressContextMenu="true"
          :preventDefaultOnContextMenu="true"
          @grid-ready="onMasterGridReady"
          @cell-value-changed="onMasterCellValueChanged"
          @cell-context-menu="onMasterContextMenu"
          @cell-editing-started="masterAdapter.onCellEditingStarted"
          @cell-editing-stopped="masterAdapter.onCellEditingStopped"
        />
      </div>
    </template>

    <!-- 加载中 -->
    <div v-else class="loading-container">
      <NSpin size="large" />
    </div>

    <!-- Lookup 弹窗 -->
    <LookupDialog
      v-if="currentLookupRule"
      ref="lookupDialogRef"
      :lookupCode="currentLookupRule.lookupCode"
      :mapping="currentLookupRule.mapping"
      @select="onLookupSelect"
      @cancel="onLookupCancel"
    />

    <!-- 右键菜单 -->
    <NDropdown
      placement="bottom-start"
      trigger="manual"
      :x="contextMenuX"
      :y="contextMenuY"
      :options="contextMenuOptions"
      :show="contextMenuVisible"
      @select="onContextMenuSelect"
      @clickoutside="onContextMenuClickOutside"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, shallowRef, computed, onMounted, onUnmounted, watch, h } from 'vue';
import { NButton, NInput, NSplit, NSpin, NDropdown, useMessage } from 'naive-ui';
import type { DropdownOption } from 'naive-ui';
import { AgGridVue } from 'ag-grid-vue3';
import { ModuleRegistry, AllCommunityModule } from 'ag-grid-community';
import type { GridApi, ColDef, GridReadyEvent, CellValueChangedEvent, CellContextMenuEvent } from 'ag-grid-community';
import { useMasterDetailStore } from '@/store/modules/master-detail';
import { useGridAdapter, getCellClassRules, cellStyleCSS } from '@/composables/useGridAdapter';
import {
  parsePageComponents,
  buildSaveParams,
  parseValidationRules,
  validateRows,
  formatValidationErrors,
  generateTempId,
  type ParsedPageConfig,
  type ValidationRule
} from '@/logic/calc-engine';
import { fetchDynamicData, fetchPageComponents, saveDynamicData } from '@/service/api';
import { loadTableMeta, type RowStyleRule, type LookupRule, extractLookupRules } from '@/composables/useMetaColumns';
import MetaFloatToolbar from './MetaFloatToolbar.vue';
import MetaTabs from './MetaTabs.vue';
import LookupDialog from './LookupDialog.vue';

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

// 验证规则
const masterValidationRules = shallowRef<ValidationRule[]>([]);
const detailValidationRules = shallowRef<ValidationRule[]>([]);

// 原始列元数据（用于验证时获取 headerText）
const masterColumnMeta = shallowRef<any[]>([]);
const detailColumnMeta = shallowRef<any[]>([]);

// 从表外键字段名（从元数据读取）
const detailFkColumn = ref<string>('');

// 行样式类函数
const masterGetRowClass = shallowRef<((params: any) => string | undefined) | undefined>(undefined);
const detailGetRowClass = shallowRef<((params: any) => string | undefined) | undefined>(undefined);

// Lookup 规则
const detailLookupRules = shallowRef<LookupRule[]>([]);

// Lookup 弹窗状态
const lookupDialogRef = ref<InstanceType<typeof LookupDialog> | null>(null);
const currentLookupRule = ref<LookupRule | null>(null);
const currentLookupRowId = ref<number | null>(null);

// 右键菜单状态
const contextMenuVisible = ref(false);
const contextMenuX = ref(0);
const contextMenuY = ref(0);
const contextMenuTarget = ref<{ isMaster: boolean; rowData: any; tabKey?: string } | null>(null);

// ==================== Computed ====================

const tabs = computed(() => store.config?.tabs || []);

/** 是否有从表 */
const hasDetail = computed(() => !!store.config?.detailTableCode);

const masterColumnDefs = computed<ColDef[]>(() => {
  return store.masterColumns.map(col => ({
    ...col,
    cellClassRules: {
      ...col.cellClassRules,  // 保留元数据中的样式规则
      ...getCellClassRules()  // 添加变更状态样式
    }
  }));
});

const detailColumnDefs = computed<ColDef[]>(() => {
  return store.detailColumns.map(col => ({
    ...col,
    cellClassRules: {
      ...col.cellClassRules,  // 保留元数据中的样式规则
      ...getCellClassRules()  // 添加变更状态样式
    }
  }));
});

const defaultColDef: ColDef = {
  sortable: true,
  filter: true,
  resizable: true,
  minWidth: 50,
  wrapHeaderText: true,
  autoHeaderHeight: true
};

const masterRowSelection = { mode: 'singleRow', checkboxes: false, enableClickSelection: true } as const;

// ==================== Context Menu ====================

const contextMenuOptions = computed<DropdownOption[]>(() => {
  const hasSelection = !!contextMenuTarget.value?.rowData;
  const options: DropdownOption[] = [
    { label: '新增行', key: 'add', icon: renderIcon('plus') }
  ];
  
  if (hasSelection) {
    options.push(
      { label: '复制行', key: 'copy', icon: renderIcon('copy') },
      { type: 'divider', key: 'd1' },
      { label: '删除行', key: 'delete', icon: renderIcon('delete'), props: { style: { color: '#d03050' } } }
    );
  }
  
  return options;
});

function renderIcon(type: string) {
  const icons: Record<string, string> = {
    plus: '➕',
    copy: '📋',
    delete: '🗑️'
  };
  return () => h('span', { style: { marginRight: '8px' } }, icons[type] || '');
}

function onMasterContextMenu(event: CellContextMenuEvent) {
  const e = event.event as MouseEvent;
  if (!e) return;
  
  contextMenuX.value = e.clientX;
  contextMenuY.value = e.clientY;
  contextMenuTarget.value = { isMaster: true, rowData: event.data };
  contextMenuVisible.value = true;
}

function onContextMenuSelect(key: string) {
  contextMenuVisible.value = false;
  const target = contextMenuTarget.value;
  if (!target) return;

  if (key === 'add') {
    if (target.isMaster) {
      const newRow = store.addMasterRow();
      setTimeout(() => {
        masterGridApi.value?.forEachNode(node => {
          if (node.data?.id === newRow.id) node.setSelected(true);
        });
      }, 50);
    } else if (target.tabKey) {
      store.addDetailRow(target.tabKey, {});
    }
  } else if (key === 'copy' && target.rowData) {
    const sourceData = { ...target.rowData };
    delete sourceData.id;
    delete sourceData._isNew;
    delete sourceData._isDeleted;
    delete sourceData._changeType;
    delete sourceData._originalValues;
    
    if (target.isMaster) {
      // 复制主表时，连带复制从表数据
      const sourceDetails = sourceData._details;
      delete sourceData._details;
      
      const newRow = store.addMasterRow(sourceData);
      
      // 复制从表数据
      if (sourceDetails?.rows?.length > 0) {
        const fkField = detailFkColumn.value;
        for (const detailRow of sourceDetails.rows) {
          if (detailRow._isDeleted) continue;
          
          const detailCopy = { ...detailRow };
          delete detailCopy.id;
          delete detailCopy._isNew;
          delete detailCopy._isDeleted;
          delete detailCopy._changeType;
          delete detailCopy._originalValues;
          
          // 设置新的外键关联（临时 ID）
          if (fkField) {
            detailCopy[fkField] = newRow.id;
          }
          
          // 直接添加到新主表的从表中
          const newDetailId = generateTempId();
          newRow._details!.rows.push({
            ...detailCopy,
            id: newDetailId,
            _isNew: true,
            _changeType: {},
            _originalValues: {}
          });
        }
      }
      
      setTimeout(() => {
        masterGridApi.value?.forEachNode(node => {
          if (node.data?.id === newRow.id) node.setSelected(true);
        });
      }, 50);
    } else if (target.tabKey) {
      delete sourceData._details;
      store.addDetailRow(target.tabKey, sourceData);
    }
  } else if (key === 'delete' && target.rowData) {
    store.deleteRow(target.rowData.id, target.isMaster);
  }
}

function onContextMenuClickOutside() {
  contextMenuVisible.value = false;
}

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

function onDetailCellClicked(event: { tabKey: string; rowId: number; field: string; data: any }) {
  // 检查是否有 lookup 配置
  const rule = detailLookupRules.value.find(r => r.fieldName === event.field);
  if (!rule) return;
  
  // 保存当前上下文，打开弹窗
  currentLookupRule.value = rule;
  currentLookupRowId.value = event.rowId;
  lookupDialogRef.value?.open();
}

function onLookupSelect(fillData: Record<string, any>) {
  if (!currentLookupRowId.value) return;
  
  // 回填数据到当前行
  for (const [field, value] of Object.entries(fillData)) {
    store.updateField(currentLookupRowId.value, field, value, 'user', false);
  }
  
  // 清理状态
  currentLookupRule.value = null;
  currentLookupRowId.value = null;
}

function onLookupCancel() {
  currentLookupRule.value = null;
  currentLookupRowId.value = null;
}

function onDetailContextMenu(payload: { tabKey: string; rowData: any; x: number; y: number }) {
  contextMenuX.value = payload.x;
  contextMenuY.value = payload.y;
  contextMenuTarget.value = { isMaster: false, rowData: payload.rowData, tabKey: payload.tabKey };
  contextMenuVisible.value = true;
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

  // 2. 加载主表元数据
  const masterMeta = await loadTableMeta(pageConfig.masterTableCode);
  if (!masterMeta) {
    message.error('加载主表元数据失败');
    return;
  }

  // 保存原始列元数据（用于验证）
  masterColumnMeta.value = masterMeta.rawColumns || [];
  masterValidationRules.value = parseValidationRules(masterColumnMeta.value);
  
  // 保存行样式类函数
  masterGetRowClass.value = masterMeta.getRowClass;

  // 3. 加载从表元数据（如果有）
  let detailCols: ColDef[] = [];
  if (pageConfig.detailTableCode) {
    const detailMeta = await loadTableMeta(pageConfig.detailTableCode);
    if (!detailMeta) {
      message.error('加载从表元数据失败');
      return;
    }

    detailColumnMeta.value = detailMeta.rawColumns || [];
    detailValidationRules.value = parseValidationRules(detailColumnMeta.value);
    detailCols = detailMeta.columns;
    
    // 保存从表行样式类函数
    detailGetRowClass.value = detailMeta.getRowClass;
    
    // 提取 lookup 规则
    detailLookupRules.value = detailMeta.lookupRules || [];

    // 保存从表外键字段名（数据库列名转驼峰）
    const fkCol = detailMeta.metadata?.parentFkColumn;
    if (fkCol) {
      detailFkColumn.value = fkCol
        .toLowerCase()
        .replace(/_([a-z])/g, (_: string, c: string) => c.toUpperCase());
    }

    // 初始化可见 Tab
    pageConfig.tabs.forEach(tab => visibleTabKeys.value.add(tab.key));
    
    // 合并从表列元数据中的计算规则（RULES_CONFIG 中定义的）
    if (detailMeta.calcRules && detailMeta.calcRules.length > 0) {
      pageConfig.calcRules = [...pageConfig.calcRules, ...detailMeta.calcRules];
    }
  }

  // 4. 初始化 Store
  store.init(
    pageConfig,
    masterMeta.columns,
    detailCols
  );
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
  const fkColumn = detailFkColumn.value;

  if (!tableCode || !fkColumn) return;

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

  // 验证主表数据
  const masterResult = validateRows(
    store.masterRows,
    masterValidationRules.value,
    masterColumnMeta.value
  );
  if (!masterResult.valid) {
    message.error('主表数据验证失败:\n' + formatValidationErrors(masterResult.errors));
    return;
  }

  // 验证从表数据（所有主表的从表）
  for (const master of store.masterRows) {
    if (master._isDeleted || !master._details?.rows) continue;

    const detailResult = validateRows(
      master._details.rows,
      detailValidationRules.value,
      detailColumnMeta.value
    );
    if (!detailResult.valid) {
      message.error(`从表数据验证失败 (主表ID: ${master.id}):\n` + formatValidationErrors(detailResult.errors));
      return;
    }
  }

  const params = buildSaveParams(
    props.pageCode,
    store.masterRows as any,
    store.config?.masterTableCode || '',
    store.config?.detailTableCode || '',
    detailFkColumn.value
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

// ==================== Watch ====================

// 监听 updateVersion 变化，刷新主表 Grid 单元格样式
watch(
  () => store.updateVersion,
  () => {
    masterGridApi.value?.refreshCells({ force: true });
  }
);

// ==================== Lifecycle ====================

onMounted(async () => {
  document.addEventListener('keydown', onKeyDown);
  window.addEventListener('beforeunload', onBeforeUnload);

  // 注入单元格样式
  if (!document.getElementById('cell-change-styles')) {
    const style = document.createElement('style');
    style.id = 'cell-change-styles';
    style.textContent = cellStyleCSS;
    document.head.appendChild(style);
  }

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

.master-section.full {
  flex: 1;
  min-height: 0;
}

/* 表头自动换行 */
.master-section :deep(.ag-header-cell-label),
.detail-section :deep(.ag-header-cell-label) {
  white-space: normal !important;
  word-wrap: break-word;
  line-height: 1.4;
  display: flex;
  align-items: center;
  justify-content: center;
  text-align: center;
}

.master-section :deep(.ag-header-cell),
.detail-section :deep(.ag-header-cell) {
  padding-top: 4px;
  padding-bottom: 4px;
}

.master-section :deep(.ag-header-cell-text),
.detail-section :deep(.ag-header-cell-text) {
  white-space: normal !important;
  word-wrap: break-word;
  overflow: visible !important;
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
