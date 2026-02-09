<script setup lang="ts">
import { ref, onMounted, inject, watch } from 'vue';
import type { Ref } from 'vue';
import { NButton, NSpace, NPopconfirm, NTabs, NTabPane, useMessage } from 'naive-ui';
import { AgGridVue } from 'ag-grid-vue3';
import type { GridApi, GridReadyEvent, ColDef, CellValueChangedEvent, GetContextMenuItemsParams } from 'ag-grid-community';
import {
  fetchAllPageComponents, savePageComponent, deletePageComponent,
  fetchRulesByComponent, savePageRule, deletePageRule
} from '@/service/api/meta-config';

const message = useMessage();
const navigateTo = inject<(tab: string, pageCode: string) => void>('navigateTo')!;
const filterState = inject<Ref<{ tab: string; pageCode: string } | null>>('filterState');

// ==================== 上半区: 页面组件 ====================
const compGridApi = ref<GridApi | null>(null);
const compRows = ref<any[]>([]);
const selectedComp = ref<any>(null);

const compColDefs: ColDef[] = [
  { field: 'id', headerName: 'ID', width: 70, editable: false },
  { field: 'pageCode', headerName: 'pageCode', width: 130, editable: true },
  { field: 'componentKey', headerName: 'componentKey', width: 130, editable: true },
  {
    field: 'componentType', headerName: '类型', width: 100, editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: ['GRID', 'DETAIL_GRID', 'FORM', 'TAB_CONTAINER', 'TOOLBAR'] }
  },
  { field: 'parentKey', headerName: 'parentKey', width: 120, editable: true },
  { field: 'refTableCode', headerName: 'refTableCode', width: 130, editable: true },
  { field: 'slotName', headerName: 'slotName', width: 100, editable: true },
  { field: 'sortOrder', headerName: '排序', width: 70, editable: true, cellDataType: 'number' },
  { field: 'description', headerName: '描述', width: 150, editable: true },
  {
    field: 'componentConfig', headerName: 'componentConfig', width: 200, editable: true,
    cellEditor: 'agLargeTextCellEditor', cellEditorPopup: true
  }
];

// ==================== 下半区: 规则 ====================
const ruleGridApi = ref<GridApi | null>(null);
const ruleRows = ref<any[]>([]);
const selectedRule = ref<any>(null);

const ruleColDefs: ColDef[] = [
  { field: 'id', headerName: 'ID', width: 70, editable: false },
  { field: 'pageCode', headerName: 'pageCode', width: 120, editable: false },
  { field: 'componentKey', headerName: 'componentKey', width: 120, editable: false },
  {
    field: 'ruleType', headerName: '规则类型', width: 140, editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: ['COLUMN_OVERRIDE', 'CALC', 'TOOLBAR', 'CONTEXT_MENU', 'STYLE', 'VALIDATION', 'LOOKUP', 'BATCH_SELECT', 'DETAIL_LINK', 'BUTTON'] }
  },
  {
    field: 'rules', headerName: '规则内容(JSON)', flex: 1, editable: true,
    cellEditor: 'agLargeTextCellEditor', cellEditorPopup: true
  },
  { field: 'sortOrder', headerName: '排序', width: 70, editable: true, cellDataType: 'number' },
  { field: 'description', headerName: '描述', width: 150, editable: true }
];

const defaultColDef: ColDef = { sortable: true, resizable: true, flex: 0, suppressHeaderMenuButton: true };

async function loadComponents() {
  try {
    const res = await fetchAllPageComponents();
    compRows.value = (res || []).filter((r: any) => r.componentType !== 'LAYOUT');
    setTimeout(() => compGridApi.value?.autoSizeAllColumns(), 100);
  } catch { message.error('加载页面组件失败'); }
}

async function loadRules(pageCode: string, componentKey: string) {
  try {
    const res = await fetchRulesByComponent(pageCode, componentKey);
    ruleRows.value = res || [];
    setTimeout(() => ruleGridApi.value?.autoSizeAllColumns(), 100);
  } catch { message.error('加载规则失败'); }
}

function onCompGridReady(params: GridReadyEvent) { compGridApi.value = params.api; params.api.autoSizeAllColumns(); }
function onRuleGridReady(params: GridReadyEvent) { ruleGridApi.value = params.api; params.api.autoSizeAllColumns(); }

function onCompSelectionChanged() {
  const rows = compGridApi.value?.getSelectedRows() || [];
  selectedComp.value = rows[0] || null;
  if (selectedComp.value?.pageCode && selectedComp.value?.componentKey) {
    loadRules(selectedComp.value.pageCode, selectedComp.value.componentKey);
  } else {
    ruleRows.value = [];
  }
}

function onCompRowClicked(event: any) {
  if (event.node?.data) {
    event.node.setSelected(true, true);
  }
}

function onRuleSelectionChanged() {
  const rows = ruleGridApi.value?.getSelectedRows() || [];
  selectedRule.value = rows[0] || null;
}

function onRuleRowClicked(event: any) {
  if (event.node?.data) {
    event.node.setSelected(true, true);
  }
}

// ---- 组件操作 ----
function addComponent() {
  const newRow = {
    _isNew: true, id: null, pageCode: '', componentKey: '',
    componentType: 'GRID', parentKey: '', refTableCode: '',
    slotName: '', sortOrder: 0, description: '', componentConfig: ''
  };
  compRows.value = [...compRows.value, newRow];
  setTimeout(() => {
    const idx = compRows.value.length - 1;
    compGridApi.value?.ensureIndexVisible(idx);
    compGridApi.value?.startEditingCell({ rowIndex: idx, colKey: 'pageCode' });
  }, 100);
}

async function saveComp() {
  const row = selectedComp.value;
  if (!row) { message.warning('请先选中一行'); return; }
  if (!row.pageCode || !row.componentKey) { message.warning('pageCode和componentKey不能为空'); return; }
  try {
    await savePageComponent(row);
    message.success('保存成功');
    await loadComponents();
  } catch { message.error('保存失败'); }
}

async function removeComp() {
  if (!selectedComp.value) return;
  if (selectedComp.value._isNew) {
    compRows.value = compRows.value.filter(r => r !== selectedComp.value);
    return;
  }
  try {
    await deletePageComponent(selectedComp.value.id);
    message.success('删除成功');
    await loadComponents();
    ruleRows.value = [];
  } catch { message.error('删除失败'); }
}

// ---- 规则操作 ----
function addRule() {
  if (!selectedComp.value?.pageCode) { message.warning('请先选中一个组件'); return; }
  const newRow = {
    _isNew: true, id: null,
    pageCode: selectedComp.value.pageCode,
    componentKey: selectedComp.value.componentKey,
    ruleType: 'COLUMN_OVERRIDE', rules: '[]', sortOrder: 0, description: ''
  };
  ruleRows.value = [...ruleRows.value, newRow];
  setTimeout(() => {
    const idx = ruleRows.value.length - 1;
    ruleGridApi.value?.ensureIndexVisible(idx);
    ruleGridApi.value?.startEditingCell({ rowIndex: idx, colKey: 'ruleType' });
  }, 100);
}

async function saveRule() {
  const row = selectedRule.value;
  if (!row) { message.warning('请先选中一条规则'); return; }
  if (!row.ruleType) { message.warning('规则类型不能为空'); return; }
  try {
    await savePageRule(row);
    message.success('保存成功');
    if (selectedComp.value?.pageCode && selectedComp.value?.componentKey) {
      await loadRules(selectedComp.value.pageCode, selectedComp.value.componentKey);
    }
  } catch { message.error('保存失败'); }
}

async function removeRule() {
  if (!selectedRule.value) return;
  if (selectedRule.value._isNew) {
    ruleRows.value = ruleRows.value.filter(r => r !== selectedRule.value);
    return;
  }
  try {
    await deletePageRule(selectedRule.value.id);
    message.success('删除成功');
    if (selectedComp.value?.pageCode && selectedComp.value?.componentKey) {
      await loadRules(selectedComp.value.pageCode, selectedComp.value.componentKey);
    }
  } catch { message.error('删除失败'); }
}

function markDirty(event: CellValueChangedEvent) {
  if (event.data) event.data._dirty = true;
}

// ---- 拖动调整大小 ----
const topHeight = ref(300);
let startY = 0;
let startHeight = 0;

function onResizeStart(e: MouseEvent) {
  startY = e.clientY;
  startHeight = topHeight.value;
  document.addEventListener('mousemove', onResizeMove);
  document.addEventListener('mouseup', onResizeEnd);
  document.body.style.cursor = 'row-resize';
  document.body.style.userSelect = 'none';
}

function onResizeMove(e: MouseEvent) {
  const delta = e.clientY - startY;
  topHeight.value = Math.max(80, startHeight + delta);
}

function onResizeEnd() {
  document.removeEventListener('mousemove', onResizeMove);
  document.removeEventListener('mouseup', onResizeEnd);
  document.body.style.cursor = '';
  document.body.style.userSelect = '';
}

// ---- 右键菜单 ----
function getContextMenuItems(params: GetContextMenuItemsParams) {
  const row = params.node?.data;
  const pageCode = row?.pageCode;
  if (!pageCode) return [];
  return [
    { name: '跳转到 表管理', action: () => navigateTo('table', pageCode) }
  ];
}

onMounted(() => {
  if (filterState?.value?.tab === 'page') return;
  loadComponents();
});

// 从目录管理跳转过来时，按 pageCode 过滤组件
watch(() => filterState?.value, async (state) => {
  if (!state || state.tab !== 'page') return;
  const pageCode = state.pageCode;
  try {
    const res = await fetchAllPageComponents();
    compRows.value = (res || []).filter((r: any) => r.componentType !== 'LAYOUT' && r.pageCode === pageCode);
    setTimeout(() => compGridApi.value?.autoSizeAllColumns(), 100);
  } catch { message.error('加载页面组件失败'); }
}, { immediate: true });
</script>

<template>
  <div class="panel-container">
    <!-- 上半区: 页面组件 -->
    <div class="section" :style="{ flex: `0 0 ${topHeight}px` }">
      <div class="section-toolbar">
        <NSpace size="small">
          <NButton size="small" type="primary" @click="addComponent">新增组件</NButton>
          <NPopconfirm @positive-click="removeComp">
            <template #trigger>
              <NButton size="small" type="error" :disabled="!selectedComp">删除组件</NButton>
            </template>
            确定删除？
          </NPopconfirm>
          <NButton size="small" @click="saveComp">保存</NButton>
          <NButton size="small" quaternary @click="loadComponents">刷新</NButton>
        </NSpace>
      </div>
      <div class="grid-wrapper">
        <AgGridVue
          class="ag-theme-quartz"
          style="width: 100%; height: 100%"
          :rowData="compRows"
          :columnDefs="compColDefs"
          :defaultColDef="defaultColDef"
          :rowSelection="{ mode: 'singleRow', checkboxes: false }"
          :getContextMenuItems="getContextMenuItems"
          @grid-ready="onCompGridReady"
          @selection-changed="onCompSelectionChanged"
          @row-clicked="onCompRowClicked"
          @cell-value-changed="markDirty"
        />
      </div>
    </div>

    <!-- 拖动条 -->
    <div class="resizer" @mousedown="onResizeStart" />

    <!-- 下半区: 规则 -->
    <div class="section" style="flex: 1">
      <div class="section-toolbar">
        <NSpace size="small">
          <NButton size="small" type="primary" @click="addRule" :disabled="!selectedComp?.id && !selectedComp?._isNew">新增规则</NButton>
          <NPopconfirm @positive-click="removeRule">
            <template #trigger>
              <NButton size="small" type="error" :disabled="!selectedRule">删除规则</NButton>
            </template>
            确定删除？
          </NPopconfirm>
          <NButton size="small" @click="saveRule" :disabled="!selectedRule">保存规则</NButton>
        </NSpace>
      </div>
      <div class="grid-wrapper">
        <AgGridVue
          class="ag-theme-quartz"
          style="width: 100%; height: 100%"
          :rowData="ruleRows"
          :columnDefs="ruleColDefs"
          :defaultColDef="defaultColDef"
          :rowSelection="{ mode: 'singleRow', checkboxes: false }"
          @grid-ready="onRuleGridReady"
          @selection-changed="onRuleSelectionChanged"
          @row-clicked="onRuleRowClicked"
          @cell-value-changed="markDirty"
        />
      </div>
    </div>
  </div>
</template>

<style scoped>
.panel-container {
  display: flex;
  flex-direction: column;
  height: 100%;
}
.section {
  display: flex;
  flex-direction: column;
  min-height: 80px;
  overflow: hidden;
}
.section-toolbar {
  flex-shrink: 0;
  padding: 4px 0;
}
.grid-wrapper {
  flex: 1;
  min-height: 0;
}
.resizer {
  flex-shrink: 0;
  height: 6px;
  cursor: row-resize;
  background: #e8e8e8;
  border-radius: 3px;
  margin: 2px 0;
  transition: background 0.2s;
}
.resizer:hover {
  background: #4096ff;
}
</style>
