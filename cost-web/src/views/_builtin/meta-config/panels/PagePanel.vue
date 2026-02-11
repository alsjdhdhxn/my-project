<script setup lang="ts">
import { ref, onMounted, inject, watch } from 'vue';
import type { Ref } from 'vue';
import { NButton, NSpace, NPopconfirm, NTabs, NTabPane, useMessage } from 'naive-ui';
import { AgGridVue } from 'ag-grid-vue3';
import type { GridApi, GridReadyEvent, ColDef, CellValueChangedEvent, GetContextMenuItemsParams, ICellRendererParams } from 'ag-grid-community';
import ButtonConfigDialog from './ButtonConfigDialog.vue';
import ColumnOverrideDialog from './ColumnOverrideDialog.vue';
import GridOptionsDialog from './GridOptionsDialog.vue';
import GridStyleDialog from './GridStyleDialog.vue';
import RuleConfigDialog from './RuleConfigDialog.vue';
import CellEditableDialog from './CellEditableDialog.vue';
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
  {
    field: 'pageCode', headerName: '页面编码', width: 160, editable: true,
    valueFormatter: (params: any) => {
      const name = params.data?.pageName;
      return name ? `${name} (${params.value})` : params.value || '';
    }
  },
  { field: 'componentKey', headerName: '组件标识', width: 130, editable: true },
  {
    field: 'componentType', headerName: '类型', width: 110, editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: ['GRID', 'DETAIL_GRID', 'FORM', 'TAB_CONTAINER', 'TOOLBAR'] },
    valueFormatter: (params: any) => {
      const map: Record<string, string> = { GRID: '主表格', DETAIL_GRID: '从表格', FORM: '表单', TAB_CONTAINER: '标签容器', TOOLBAR: '工具栏' };
      return map[params.value] || params.value || '';
    }
  },
  { field: 'parentKey', headerName: '父组件', width: 120, editable: true },
  {
    field: 'refTableCode', headerName: '关联表', width: 180, editable: true,
    valueFormatter: (params: any) => {
      const name = params.data?.refTableName;
      return name ? `${name} (${params.value})` : params.value || '';
    }
  },
  { field: 'slotName', headerName: '插槽名', width: 100, editable: true },
  { field: 'sortOrder', headerName: '排序', width: 70, editable: true, cellDataType: 'number' },
  { field: 'description', headerName: '描述', width: 150, editable: true },
  {
    field: 'componentConfig', headerName: '按钮配置', width: 200,
    editable: false,
    cellRenderer: (params: ICellRendererParams) => {
      const el = document.createElement('span');
      let count = 0;
      try {
        const cfg = params.value ? JSON.parse(params.value) : {};
        if (cfg.tabs) {
          count = cfg.tabs.reduce((sum: number, t: any) => sum + (t.buttons?.length || 0), 0);
        } else {
          count = cfg.buttons?.length || 0;
        }
      } catch { /* ignore */ }
      el.textContent = count > 0 ? `⚙ 配置按钮(${count})` : '⚙ 配置按钮';
      el.style.cursor = 'pointer';
      el.style.color = count > 0 ? '#18a058' : '#999';
      el.style.fontWeight = count > 0 ? '500' : 'normal';
      el.addEventListener('click', () => openBtnConfigDialog(params.data));
      return el;
    }
  }
];

// ==================== 下半区: 规则 ====================
const ruleGridApi = ref<GridApi | null>(null);
const ruleRows = ref<any[]>([]);
const selectedRule = ref<any>(null);

const ruleColDefs: ColDef[] = [
  { field: 'id', headerName: 'ID', width: 70, editable: false },
  { field: 'pageCode', headerName: '页面编码', width: 120, editable: false },
  { field: 'componentKey', headerName: '组件标识', width: 120, editable: false },
  {
    field: 'ruleType', headerName: '规则类型', width: 140, editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: ['COLUMN_OVERRIDE', 'GRID_STYLE', 'GRID_OPTIONS', 'CALC', 'VALIDATION', 'LOOKUP', 'BUTTON', 'BATCH_SELECT', 'DETAIL_LINK', 'ROW_EDITABLE', 'CELL_EDITABLE', 'BROADCAST', 'SUMMARY_CONFIG'] }
  },
  {
    field: 'rules', headerName: '规则内容(JSON)', flex: 1,
    editable: (params: any) => params.data?.ruleType !== 'COLUMN_OVERRIDE' && params.data?.ruleType !== 'GRID_OPTIONS' && params.data?.ruleType !== 'GRID_STYLE' && params.data?.ruleType !== 'CALC' && params.data?.ruleType !== 'AGGREGATE' && params.data?.ruleType !== 'VALIDATION' && params.data?.ruleType !== 'CELL_EDITABLE',
    cellEditor: 'agLargeTextCellEditor', cellEditorPopup: true,
    cellRenderer: (params: ICellRendererParams) => {
      if (params.data?.ruleType === 'COLUMN_OVERRIDE') {
        const el = document.createElement('span');
        let count = 0;
        try {
          const arr = params.value ? JSON.parse(params.value) : [];
          count = Array.isArray(arr) ? arr.length : 0;
        } catch { /* ignore */ }
        el.textContent = count > 0 ? `⚙ 列覆盖配置(${count})` : '⚙ 列覆盖配置';
        el.style.cursor = 'pointer';
        el.style.color = count > 0 ? '#2080f0' : '#999';
        el.style.fontWeight = count > 0 ? '500' : 'normal';
        el.addEventListener('click', () => openColOverrideDialog(params.data));
        return el;
      }
      if (params.data?.ruleType === 'GRID_OPTIONS') {
        const el = document.createElement('span');
        let summary = '';
        try {
          const obj = params.value ? JSON.parse(params.value) : {};
          const labels: string[] = [];
          if (obj.cellSelection) labels.push('范围选择');
          if (obj.sideBar) labels.push('侧边栏');
          if (obj.autoSizeColumns) labels.push('列宽自适应');
          summary = labels.length > 0 ? labels.join('、') : '未配置';
        } catch { summary = '解析错误'; }
        el.textContent = `⚙ 表格选项: ${summary}`;
        el.style.cursor = 'pointer';
        el.style.color = summary !== '未配置' ? '#2080f0' : '#999';
        el.style.fontWeight = summary !== '未配置' ? '500' : 'normal';
        el.addEventListener('click', () => openGridOptionsDialog(params.data));
        return el;
      }
      if (params.data?.ruleType === 'GRID_STYLE') {
        const el = document.createElement('span');
        let count = 0;
        try {
          const arr = params.value ? JSON.parse(params.value) : [];
          count = Array.isArray(arr) ? arr.length : 0;
        } catch { /* ignore */ }
        el.textContent = count > 0 ? `🎨 样式规则(${count})` : '🎨 样式规则';
        el.style.cursor = 'pointer';
        el.style.color = count > 0 ? '#18a058' : '#999';
        el.style.fontWeight = count > 0 ? '500' : 'normal';
        el.addEventListener('click', () => openGridStyleDialog(params.data));
        return el;
      }
      // 其他类型正常显示文本
      const ruleType = params.data?.ruleType;
      if (ruleType === 'CALC' || ruleType === 'AGGREGATE' || ruleType === 'VALIDATION') {
        const el = document.createElement('span');
        let count = 0;
        const labelMap: Record<string, string> = { CALC: '📐 计算规则', AGGREGATE: '📊 聚合规则', VALIDATION: '✅ 校验规则' };
        try {
          const arr = params.value ? JSON.parse(params.value) : [];
          count = Array.isArray(arr) ? arr.length : 0;
        } catch { /* ignore */ }
        el.textContent = count > 0 ? `${labelMap[ruleType]}(${count})` : labelMap[ruleType];
        el.style.cursor = 'pointer';
        el.style.color = count > 0 ? '#2080f0' : '#999';
        el.style.fontWeight = count > 0 ? '500' : 'normal';
        el.addEventListener('click', () => openRuleConfigDialog(params.data));
        return el;
      }
      // CELL_EDITABLE 可视化配置
      if (ruleType === 'CELL_EDITABLE') {
        const el = document.createElement('span');
        let count = 0;
        try {
          const arr = params.value ? JSON.parse(params.value) : [];
          count = Array.isArray(arr) ? arr.length : 0;
        } catch { /* ignore */ }
        el.textContent = count > 0 ? `🔒 可编辑规则(${count})` : '🔒 可编辑规则';
        el.style.cursor = 'pointer';
        el.style.color = count > 0 ? '#f0a020' : '#999';
        el.style.fontWeight = count > 0 ? '500' : 'normal';
        el.addEventListener('click', () => openCellEditableDialog(params.data));
        return el;
      }
      const el = document.createElement('span');
      el.textContent = params.value || '';
      el.style.overflow = 'hidden';
      el.style.textOverflow = 'ellipsis';
      el.style.whiteSpace = 'nowrap';
      return el;
    }
  },
  { field: 'sortOrder', headerName: '排序', width: 70, editable: true, cellDataType: 'number' },
  { field: 'description', headerName: '描述', width: 150, editable: true }
];

const defaultColDef: ColDef = { sortable: true, resizable: true, flex: 0, suppressHeaderMenuButton: true };

// ---- 按钮配置弹窗 ----
const btnDialogShow = ref(false);
const btnDialogConfig = ref('');
const btnDialogCompKey = ref('');
let btnDialogTargetRow: any = null;

function openBtnConfigDialog(row: any) {
  btnDialogConfig.value = row.componentConfig || '';
  btnDialogCompKey.value = row.componentKey || '';
  btnDialogTargetRow = row;
  btnDialogShow.value = true;
}

function onBtnConfigSave(config: string) {
  if (btnDialogTargetRow) {
    btnDialogTargetRow.componentConfig = config;
    compGridApi.value?.refreshCells({ force: true });
  }
}

// ---- 列覆盖配置弹窗 ----
const colOverrideShow = ref(false);
const colOverrideJson = ref('');
const colOverridePageCode = ref('');
const colOverrideCompKey = ref('');
let colOverrideTargetRow: any = null;

function openColOverrideDialog(row: any) {
  colOverrideJson.value = row.rules || '[]';
  colOverridePageCode.value = row.pageCode || '';
  colOverrideCompKey.value = row.componentKey || '';
  colOverrideTargetRow = row;
  colOverrideShow.value = true;
}

function onColOverrideSave(json: string) {
  if (colOverrideTargetRow) {
    colOverrideTargetRow.rules = json;
    if (selectedComp.value?.pageCode && selectedComp.value?.componentKey) {
      loadRules(selectedComp.value.pageCode, selectedComp.value.componentKey);
    }
  }
}

// ---- 表格选项配置弹窗 ----
const gridOptionsShow = ref(false);
const gridOptionsJson = ref('');
const gridOptionsCompKey = ref('');
let gridOptionsTargetRow: any = null;

function openGridOptionsDialog(row: any) {
  gridOptionsJson.value = row.rules || '{}';
  gridOptionsCompKey.value = row.componentKey || '';
  gridOptionsTargetRow = row;
  gridOptionsShow.value = true;
}

function onGridOptionsSave(json: string) {
  if (gridOptionsTargetRow) {
    gridOptionsTargetRow.rules = json;
    if (selectedComp.value?.pageCode && selectedComp.value?.componentKey) {
      loadRules(selectedComp.value.pageCode, selectedComp.value.componentKey);
    }
  }
}

// ---- Grid 样式规则弹窗 ----
const gridStyleShow = ref(false);
const gridStyleJson = ref('');
const gridStylePageCode = ref('');
const gridStyleCompKey = ref('');
let gridStyleTargetRow: any = null;

function openGridStyleDialog(row: any) {
  gridStyleJson.value = row.rules || '[]';
  gridStylePageCode.value = row.pageCode || '';
  gridStyleCompKey.value = row.componentKey || '';
  gridStyleTargetRow = row;
  gridStyleShow.value = true;
}

function onGridStyleSave(json: string) {
  if (gridStyleTargetRow) {
    gridStyleTargetRow.rules = json;
    if (selectedComp.value?.pageCode && selectedComp.value?.componentKey) {
      loadRules(selectedComp.value.pageCode, selectedComp.value.componentKey);
    }
  }
}

// ---- 规则可视化配置弹窗 (CALC / AGGREGATE / VALIDATION) ----
const ruleConfigShow = ref(false);
const ruleConfigJson = ref('');
const ruleConfigType = ref<'CALC' | 'AGGREGATE' | 'VALIDATION'>('CALC');
const ruleConfigPageCode = ref('');
const ruleConfigCompKey = ref('');
let ruleConfigTargetRow: any = null;

function openRuleConfigDialog(row: any) {
  ruleConfigJson.value = row.rules || '[]';
  ruleConfigType.value = row.ruleType as 'CALC' | 'AGGREGATE' | 'VALIDATION';
  ruleConfigPageCode.value = row.pageCode || '';
  ruleConfigCompKey.value = row.componentKey || '';
  ruleConfigTargetRow = row;
  ruleConfigShow.value = true;
}

function onRuleConfigSave(json: string) {
  if (ruleConfigTargetRow) {
    ruleConfigTargetRow.rules = json;
    if (selectedComp.value?.pageCode && selectedComp.value?.componentKey) {
      loadRules(selectedComp.value.pageCode, selectedComp.value.componentKey);
    }
  }
}

// ---- 单元格可编辑规则弹窗 ----
const cellEditableShow = ref(false);
const cellEditableJson = ref('');
const cellEditablePageCode = ref('');
const cellEditableCompKey = ref('');
let cellEditableTargetRow: any = null;

function openCellEditableDialog(row: any) {
  cellEditableJson.value = row.rules || '[]';
  cellEditablePageCode.value = row.pageCode || '';
  cellEditableCompKey.value = row.componentKey || '';
  cellEditableTargetRow = row;
  cellEditableShow.value = true;
}

function onCellEditableSave(json: string) {
  if (cellEditableTargetRow) {
    cellEditableTargetRow.rules = json;
    if (selectedComp.value?.pageCode && selectedComp.value?.componentKey) {
      loadRules(selectedComp.value.pageCode, selectedComp.value.componentKey);
    }
  }
}

async function loadComponents() {
  try {
    const res = await fetchAllPageComponents();
    compRows.value = (res || []).filter((r: any) => r.componentType !== 'LAYOUT');
    setTimeout(() => compGridApi.value?.autoSizeAllColumns(), 100);
  } catch { message.error('加载页面组件失败'); }
}

// 隐藏的规则类型（系统内部使用，不需要用户看到）
const hiddenRuleTypes = new Set(['ROLE_BINDING', 'RELATION', 'SUMMARY_CONFIG', 'NESTED_CONFIG']);

async function loadRules(pageCode: string, componentKey: string) {
  try {
    const res = await fetchRulesByComponent(pageCode, componentKey);
    ruleRows.value = (res || []).filter((r: any) => !hiddenRuleTypes.has(r.ruleType));
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
  // 收集所有修改过或新增的行
  const dirtyRows = compRows.value.filter(r => r._dirty || r._isNew);
  if (dirtyRows.length === 0) { message.info('没有需要保存的修改'); return; }
  for (const row of dirtyRows) {
    if (!row.pageCode || !row.componentKey) { message.warning(`组件 pageCode 和 componentKey 不能为空`); return; }
  }
  try {
    await Promise.all(dirtyRows.map(r => savePageComponent(r)));
    message.success(`已保存 ${dirtyRows.length} 条组件`);
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
  // 收集所有修改过或新增的规则行
  const dirtyRows = ruleRows.value.filter(r => r._dirty || r._isNew);
  if (dirtyRows.length === 0) { message.info('没有需要保存的修改'); return; }
  for (const row of dirtyRows) {
    if (!row.ruleType) { message.warning('规则类型不能为空'); return; }
  }
  try {
    await Promise.all(dirtyRows.map(r => savePageRule(r)));
    message.success(`已保存 ${dirtyRows.length} 条规则`);
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
          <NButton size="small" @click="saveRule">保存规则</NButton>
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
    <!-- 按钮配置弹窗 -->
    <ButtonConfigDialog
      v-model:show="btnDialogShow"
      :componentConfig="btnDialogConfig"
      :componentKey="btnDialogCompKey"
      :compRow="btnDialogTargetRow"
      @save="onBtnConfigSave"
    />
    <!-- 列覆盖配置弹窗 -->
    <ColumnOverrideDialog
      v-model:show="colOverrideShow"
      :rulesJson="colOverrideJson"
      :pageCode="colOverridePageCode"
      :componentKey="colOverrideCompKey"
      :ruleRow="colOverrideTargetRow"
      @save="onColOverrideSave"
    />
    <!-- 表格选项配置弹窗 -->
    <GridOptionsDialog
      v-model:show="gridOptionsShow"
      :rulesJson="gridOptionsJson"
      :componentKey="gridOptionsCompKey"
      :ruleRow="gridOptionsTargetRow"
      @save="onGridOptionsSave"
    />
    <!-- Grid 样式规则弹窗 -->
    <GridStyleDialog
      v-model:show="gridStyleShow"
      :rulesJson="gridStyleJson"
      :pageCode="gridStylePageCode"
      :componentKey="gridStyleCompKey"
      :ruleRow="gridStyleTargetRow"
      @save="onGridStyleSave"
    />
    <!-- 规则可视化配置弹窗 (CALC / AGGREGATE / VALIDATION) -->
    <RuleConfigDialog
      v-model:show="ruleConfigShow"
      :rulesJson="ruleConfigJson"
      :ruleType="ruleConfigType"
      :pageCode="ruleConfigPageCode"
      :componentKey="ruleConfigCompKey"
      :ruleRow="ruleConfigTargetRow"
      @save="onRuleConfigSave"
    />
    <!-- 单元格可编辑规则弹窗 -->
    <CellEditableDialog
      v-model:show="cellEditableShow"
      :rulesJson="cellEditableJson"
      :pageCode="cellEditablePageCode"
      :componentKey="cellEditableCompKey"
      :ruleRow="cellEditableTargetRow"
      @save="onCellEditableSave"
    />
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
