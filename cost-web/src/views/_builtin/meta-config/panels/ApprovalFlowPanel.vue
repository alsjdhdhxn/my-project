<script setup lang="ts">
import { inject, nextTick, onMounted, ref, watch } from 'vue';
import type { Ref } from 'vue';
import { NButton, NPopconfirm, NSpace, useMessage } from 'naive-ui';
import { AgGridVue } from 'ag-grid-vue3';
import type { CellValueChangedEvent, ColDef, GridApi, GridReadyEvent } from 'ag-grid-community';
import {
  deleteApprovalApprover,
  deleteApprovalCondition,
  deleteApprovalFlow,
  deleteApprovalNode,
  fetchApprovalApprovers,
  fetchApprovalConditions,
  fetchApprovalFlows,
  fetchApprovalNodes,
  fetchApprovalReferenceData,
  saveApprovalApprover,
  saveApprovalCondition,
  saveApprovalFlow,
  saveApprovalNode
} from '@/service/api/meta-config';

const message = useMessage();
const filterState = inject<Ref<{ tab: string; pageCode: string } | null>>('filterState');

const flowGridApi = ref<GridApi | null>(null);
const conditionGridApi = ref<GridApi | null>(null);
const nodeGridApi = ref<GridApi | null>(null);
const approverGridApi = ref<GridApi | null>(null);

const flows = ref<any[]>([]);
const conditions = ref<any[]>([]);
const nodes = ref<any[]>([]);
const approvers = ref<any[]>([]);

const selectedFlow = ref<any>(null);
const selectedCondition = ref<any>(null);
const selectedNode = ref<any>(null);
const selectedApprover = ref<any>(null);

const referenceData = ref<Record<string, any[]>>({
  pages: [],
  users: [],
  roles: [],
  departments: []
});

const topHeight = ref(210);
const middleHeight = ref(210);
let resizeTarget: 'top' | 'middle' | null = null;
let startY = 0;
let startHeight = 0;

const conditionModes = ['ALWAYS', 'SQL', 'VISUAL'];
const approvalModes = ['OR', 'AND'];
const targetTypes = ['USER', 'ROLE'];
const onErrorModes = ['REQUIRE_APPROVAL', 'BLOCK'];
const enabledValues = [1, 0];

const largeTextEditorParams = {
  rows: 12,
  cols: 100,
  maxLength: 200000
};

const defaultColDef: ColDef = {
  sortable: true,
  resizable: true,
  flex: 0,
  suppressHeaderMenuButton: true
};

function text(value: unknown) {
  return typeof value === 'string' ? value.trim() : '';
}

function numberValue(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string' && value.trim()) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function summarize(value: unknown, emptyLabel = '双击编辑') {
  const raw = text(value);
  if (!raw) return emptyLabel;
  return raw.length > 80 ? `${raw.slice(0, 80)}...` : raw;
}

function markDirty(row: any) {
  if (row) row._dirty = true;
}

function isDirty(row: any) {
  return Boolean(row?._dirty || row?._isNew);
}

function isNew(row: any) {
  return Boolean(row?._isNew);
}

function normalizeSaveRow(row: any) {
  const copy = { ...row };
  delete copy._dirty;
  delete copy._isNew;
  return copy;
}

function findById(list: any[], id: unknown) {
  const target = numberValue(id);
  if (target === null) return null;
  return list.find(item => numberValue(item.id) === target) || null;
}

function fillApproverNames(row: any) {
  if (!row) return;
  const dept = findById(referenceData.value.departments || [], row.applyDeptId);
  if (dept) row.applyDeptName = dept.deptName;

  if (row.targetType === 'ROLE') {
    const role = findById(referenceData.value.roles || [], row.targetRoleId);
    if (role) {
      row.targetRoleCode = role.roleCode;
      row.targetRoleName = role.roleName;
      row.targetUserId = null;
      row.targetUserName = '';
    }
  } else {
    const user = findById(referenceData.value.users || [], row.targetUserId);
    if (user) {
      row.targetUserName = user.realName || user.username;
      row.targetRoleId = null;
      row.targetRoleCode = '';
      row.targetRoleName = '';
    }
  }
}

const flowColDefs: ColDef[] = [
  { field: 'flowId', headerName: 'ID', width: 72, editable: false },
  { field: 'pageCode', headerName: '页面编码', width: 150, editable: true },
  { field: 'pageName', headerName: '页面名称', width: 150, editable: false },
  { field: 'flowName', headerName: '流程名称', width: 180, editable: true },
  { field: 'flowPriority', headerName: '优先级', width: 90, editable: true, cellDataType: 'number' },
  { field: 'flowVersion', headerName: '版本', width: 80, editable: true, cellDataType: 'number' },
  {
    field: 'isEnabled',
    headerName: '启用',
    width: 86,
    editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: enabledValues },
    valueFormatter: p => (Number(p.value) === 1 ? '是' : '否')
  },
  { field: 'remark', headerName: '备注', flex: 1, minWidth: 200, editable: true }
];

const conditionColDefs: ColDef[] = [
  { field: 'conditionId', headerName: 'ID', width: 72, editable: false },
  { field: 'conditionName', headerName: '入口条件名称', width: 180, editable: true },
  {
    field: 'conditionMode',
    headerName: '条件类型',
    width: 110,
    editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: conditionModes }
  },
  {
    field: 'sqlExpr',
    headerName: 'SQL条件',
    flex: 1,
    minWidth: 260,
    editable: true,
    cellEditor: 'agLargeTextCellEditor',
    cellEditorPopup: true,
    cellEditorParams: largeTextEditorParams,
    valueFormatter: p => summarize(p.value, 'ALWAYS时可为空'),
    tooltipValueGetter: p => text(p.value)
  },
  {
    field: 'logicTree',
    headerName: '可视化条件JSON',
    width: 180,
    editable: true,
    cellEditor: 'agLargeTextCellEditor',
    cellEditorPopup: true,
    cellEditorParams: largeTextEditorParams,
    valueFormatter: p => summarize(p.value)
  },
  {
    field: 'onError',
    headerName: '异常策略',
    width: 140,
    editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: onErrorModes }
  },
  {
    field: 'isEnabled',
    headerName: '启用',
    width: 86,
    editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: enabledValues },
    valueFormatter: p => (Number(p.value) === 1 ? '是' : '否')
  }
];

const nodeColDefs: ColDef[] = [
  { field: 'nodeId', headerName: 'ID', width: 72, editable: false },
  { field: 'approvalLevel', headerName: '级别', width: 82, editable: true, cellDataType: 'number' },
  { field: 'nodeName', headerName: '节点名称', width: 150, editable: true },
  {
    field: 'approvalMode',
    headerName: '审批模式',
    width: 110,
    editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: approvalModes }
  },
  {
    field: 'conditionMode',
    headerName: '本级条件',
    width: 110,
    editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: conditionModes }
  },
  {
    field: 'sqlExpr',
    headerName: '本级SQL条件',
    flex: 1,
    minWidth: 260,
    editable: true,
    cellEditor: 'agLargeTextCellEditor',
    cellEditorPopup: true,
    cellEditorParams: largeTextEditorParams,
    valueFormatter: p => summarize(p.value, 'ALWAYS时可为空'),
    tooltipValueGetter: p => text(p.value)
  },
  {
    field: 'onError',
    headerName: '异常策略',
    width: 140,
    editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: onErrorModes }
  },
  {
    field: 'isEnabled',
    headerName: '启用',
    width: 86,
    editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: enabledValues },
    valueFormatter: p => (Number(p.value) === 1 ? '是' : '否')
  }
];

const approverColDefs: ColDef[] = [
  { field: 'id', headerName: 'ID', width: 72, editable: false },
  { field: 'sortOrder', headerName: '排序', width: 82, editable: true, cellDataType: 'number' },
  { field: 'applyDeptId', headerName: '发起部门ID', width: 120, editable: true, cellDataType: 'number' },
  { field: 'applyDeptName', headerName: '发起部门', width: 140, editable: true },
  {
    field: 'targetType',
    headerName: '审批对象',
    width: 110,
    editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: targetTypes }
  },
  { field: 'targetUserId', headerName: '用户ID', width: 100, editable: true, cellDataType: 'number' },
  { field: 'targetUserName', headerName: '用户名称', width: 130, editable: true },
  { field: 'targetRoleId', headerName: '角色ID', width: 100, editable: true, cellDataType: 'number' },
  { field: 'targetRoleCode', headerName: '角色编码', width: 120, editable: true },
  { field: 'targetRoleName', headerName: '角色名称', width: 130, editable: true },
  {
    field: 'conditionMode',
    headerName: '分支条件',
    width: 110,
    editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: conditionModes }
  },
  {
    field: 'sqlExpr',
    headerName: '分支SQL条件',
    flex: 1,
    minWidth: 240,
    editable: true,
    cellEditor: 'agLargeTextCellEditor',
    cellEditorPopup: true,
    cellEditorParams: largeTextEditorParams,
    valueFormatter: p => summarize(p.value, 'ALWAYS时可为空'),
    tooltipValueGetter: p => text(p.value)
  },
  {
    field: 'isEnabled',
    headerName: '启用',
    width: 86,
    editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: enabledValues },
    valueFormatter: p => (Number(p.value) === 1 ? '是' : '否')
  }
];

async function loadReferenceData() {
  referenceData.value = await fetchApprovalReferenceData();
}

async function loadFlows(targetId?: number | null) {
  try {
    flows.value = await fetchApprovalFlows();
    await nextTick();
    flowGridApi.value?.autoSizeAllColumns();
    if (targetId) selectGridRow(flowGridApi.value, 'flowId', targetId);
    else if (filterState?.value?.tab === 'approval' && filterState.value.pageCode) {
      selectFlowByPageCode(filterState.value.pageCode);
    }
  } catch {
    message.error('加载审批流失败');
  }
}

async function loadConditions(flowId?: number | null) {
  conditions.value = flowId ? await fetchApprovalConditions(flowId) : [];
  selectedCondition.value = null;
}

async function loadNodes(flowId?: number | null, targetNodeId?: number | null) {
  nodes.value = flowId ? await fetchApprovalNodes(flowId) : [];
  selectedNode.value = null;
  approvers.value = [];
  selectedApprover.value = null;
  await nextTick();
  nodeGridApi.value?.autoSizeAllColumns();
  if (targetNodeId) selectGridRow(nodeGridApi.value, 'nodeId', targetNodeId);
}

async function loadApprovers(nodeId?: number | null) {
  approvers.value = nodeId ? await fetchApprovalApprovers(nodeId) : [];
  selectedApprover.value = null;
  await nextTick();
  approverGridApi.value?.autoSizeAllColumns();
}

function selectGridRow(api: GridApi | null, idField: string, id: number) {
  api?.forEachNode(node => {
    if (Number(node.data?.[idField]) === Number(id)) {
      node.setSelected(true, true);
      api.ensureNodeVisible(node);
    }
  });
}

function selectFlowByPageCode(pageCode: string) {
  let found = false;
  flowGridApi.value?.forEachNode(node => {
    if (!found && node.data?.pageCode === pageCode) {
      node.setSelected(true, true);
      flowGridApi.value?.ensureNodeVisible(node);
      found = true;
    }
  });
  if (!found) {
    message.info(`当前页面还没有配置审批流：${pageCode}`);
  }
}

function onFlowReady(params: GridReadyEvent) {
  flowGridApi.value = params.api;
  params.api.autoSizeAllColumns();
}

function onConditionReady(params: GridReadyEvent) {
  conditionGridApi.value = params.api;
  params.api.autoSizeAllColumns();
}

function onNodeReady(params: GridReadyEvent) {
  nodeGridApi.value = params.api;
  params.api.autoSizeAllColumns();
}

function onApproverReady(params: GridReadyEvent) {
  approverGridApi.value = params.api;
  params.api.autoSizeAllColumns();
}

async function onFlowSelectionChanged() {
  const row = flowGridApi.value?.getSelectedRows()?.[0] || null;
  selectedFlow.value = row;
  await Promise.all([loadConditions(row?.flowId || null), loadNodes(row?.flowId || null)]);
}

function onConditionSelectionChanged() {
  selectedCondition.value = conditionGridApi.value?.getSelectedRows()?.[0] || null;
}

async function onNodeSelectionChanged() {
  const row = nodeGridApi.value?.getSelectedRows()?.[0] || null;
  selectedNode.value = row;
  await loadApprovers(row?.nodeId || null);
}

function onApproverSelectionChanged() {
  selectedApprover.value = approverGridApi.value?.getSelectedRows()?.[0] || null;
}

function selectClicked(event: any) {
  event.node?.setSelected(true, true);
}

function addFlow() {
  const newRow = {
    _isNew: true,
    flowId: null,
    pageCode: '',
    pageName: '',
    flowName: '新审批流',
    flowVersion: 1,
    flowPriority: 100,
    isEnabled: 1,
    remark: ''
  };
  flows.value = [...flows.value, newRow];
  nextTick(() => flowGridApi.value?.startEditingCell({ rowIndex: flows.value.length - 1, colKey: 'pageCode' }));
}

function addCondition() {
  if (!selectedFlow.value?.flowId) {
    message.warning('请先保存并选中审批流');
    return;
  }
  const newRow = {
    _isNew: true,
    conditionId: null,
    flowId: selectedFlow.value.flowId,
    conditionName: '总入口条件',
    conditionMode: 'ALWAYS',
    logicTree: '',
    sqlExpr: '',
    onError: 'REQUIRE_APPROVAL',
    isEnabled: 1
  };
  conditions.value = [...conditions.value, newRow];
}

function addNode() {
  if (!selectedFlow.value?.flowId) {
    message.warning('请先保存并选中审批流');
    return;
  }
  const maxLevel = Math.max(0, ...nodes.value.map(row => Number(row.approvalLevel) || 0));
  const newRow = {
    _isNew: true,
    nodeId: null,
    flowId: selectedFlow.value.flowId,
    approvalLevel: maxLevel + 1,
    nodeName: `第${maxLevel + 1}级审批`,
    approvalMode: 'OR',
    conditionMode: 'ALWAYS',
    logicTree: '',
    sqlExpr: '',
    onError: 'REQUIRE_APPROVAL',
    isEnabled: 1
  };
  nodes.value = [...nodes.value, newRow];
}

function addApprover() {
  if (!selectedNode.value?.nodeId) {
    message.warning('请先保存并选中审批节点');
    return;
  }
  const newRow = {
    _isNew: true,
    id: null,
    nodeId: selectedNode.value.nodeId,
    applyDeptId: null,
    applyDeptName: '',
    targetType: 'USER',
    targetUserId: null,
    targetUserName: '',
    targetRoleId: null,
    targetRoleCode: '',
    targetRoleName: '',
    conditionMode: 'ALWAYS',
    logicTree: '',
    sqlExpr: '',
    onError: 'REQUIRE_APPROVAL',
    sortOrder: approvers.value.length + 1,
    isEnabled: 1
  };
  approvers.value = [...approvers.value, newRow];
}

async function saveFlows() {
  flowGridApi.value?.stopEditing();
  const dirtyRows = flows.value.filter(isDirty);
  if (!dirtyRows.length) {
    message.info('没有需要保存的审批流');
    return;
  }
  for (const row of dirtyRows) {
    if (!text(row.pageCode) || !text(row.flowName)) {
      message.warning('页面编码和流程名称不能为空');
      return;
    }
  }
  try {
    const saved = await Promise.all(dirtyRows.map(row => saveApprovalFlow(normalizeSaveRow(row))));
    message.success(`已保存 ${saved.length} 条审批流`);
    await loadFlows(saved.at(-1)?.flowId || selectedFlow.value?.flowId || null);
  } catch {
    message.error('保存审批流失败');
  }
}

async function saveConditions() {
  conditionGridApi.value?.stopEditing();
  const dirtyRows = conditions.value.filter(isDirty);
  if (!dirtyRows.length) {
    message.info('没有需要保存的总入口条件');
    return;
  }
  try {
    const saved = await Promise.all(dirtyRows.map(row => saveApprovalCondition(normalizeSaveRow(row))));
    message.success(`已保存 ${saved.length} 条总入口条件`);
    await loadConditions(selectedFlow.value?.flowId || null);
  } catch {
    message.error('保存总入口条件失败');
  }
}

async function saveNodes() {
  nodeGridApi.value?.stopEditing();
  const dirtyRows = nodes.value.filter(isDirty);
  if (!dirtyRows.length) {
    message.info('没有需要保存的审批节点');
    return;
  }
  for (const row of dirtyRows) {
    if (!text(row.nodeName)) {
      message.warning('节点名称不能为空');
      return;
    }
  }
  try {
    const saved = await Promise.all(dirtyRows.map(row => saveApprovalNode(normalizeSaveRow(row))));
    message.success(`已保存 ${saved.length} 个审批节点`);
    await loadNodes(selectedFlow.value?.flowId || null, saved.at(-1)?.nodeId || selectedNode.value?.nodeId || null);
  } catch {
    message.error('保存审批节点失败');
  }
}

async function saveApprovers() {
  approverGridApi.value?.stopEditing();
  const dirtyRows = approvers.value.filter(isDirty);
  if (!dirtyRows.length) {
    message.info('没有需要保存的审批人分支');
    return;
  }
  for (const row of dirtyRows) {
    fillApproverNames(row);
    if (row.targetType === 'ROLE' && !numberValue(row.targetRoleId)) {
      message.warning('角色审批分支必须填写角色ID');
      return;
    }
    if (row.targetType !== 'ROLE' && !numberValue(row.targetUserId)) {
      message.warning('用户审批分支必须填写用户ID');
      return;
    }
  }
  try {
    const saved = await Promise.all(dirtyRows.map(row => saveApprovalApprover(normalizeSaveRow(row))));
    message.success(`已保存 ${saved.length} 条审批人分支`);
    await loadApprovers(selectedNode.value?.nodeId || null);
  } catch {
    message.error('保存审批人分支失败');
  }
}

async function removeFlow() {
  if (!selectedFlow.value) return;
  if (isNew(selectedFlow.value)) {
    flows.value = flows.value.filter(row => row !== selectedFlow.value);
    selectedFlow.value = null;
    return;
  }
  try {
    await deleteApprovalFlow(selectedFlow.value.flowId);
    message.success('已删除审批流');
    await loadFlows();
    conditions.value = [];
    nodes.value = [];
    approvers.value = [];
  } catch {
    message.error('删除审批流失败');
  }
}

async function removeCondition() {
  if (!selectedCondition.value) return;
  if (isNew(selectedCondition.value)) {
    conditions.value = conditions.value.filter(row => row !== selectedCondition.value);
    selectedCondition.value = null;
    return;
  }
  await deleteApprovalCondition(selectedCondition.value.conditionId);
  message.success('已删除总入口条件');
  await loadConditions(selectedFlow.value?.flowId || null);
}

async function removeNode() {
  if (!selectedNode.value) return;
  if (isNew(selectedNode.value)) {
    nodes.value = nodes.value.filter(row => row !== selectedNode.value);
    selectedNode.value = null;
    approvers.value = [];
    return;
  }
  await deleteApprovalNode(selectedNode.value.nodeId);
  message.success('已删除审批节点');
  await loadNodes(selectedFlow.value?.flowId || null);
}

async function removeApprover() {
  if (!selectedApprover.value) return;
  if (isNew(selectedApprover.value)) {
    approvers.value = approvers.value.filter(row => row !== selectedApprover.value);
    selectedApprover.value = null;
    return;
  }
  await deleteApprovalApprover(selectedApprover.value.id);
  message.success('已删除审批人分支');
  await loadApprovers(selectedNode.value?.nodeId || null);
}

function onCellValueChanged(event: CellValueChangedEvent) {
  markDirty(event.data);
  if (event.api === approverGridApi.value) {
    fillApproverNames(event.data);
    event.api.refreshCells({ force: true });
  }
}

function onResizeStart(target: 'top' | 'middle', event: MouseEvent) {
  resizeTarget = target;
  startY = event.clientY;
  startHeight = target === 'top' ? topHeight.value : middleHeight.value;
  document.addEventListener('mousemove', onResizeMove);
  document.addEventListener('mouseup', onResizeEnd);
  document.body.style.cursor = 'row-resize';
  document.body.style.userSelect = 'none';
}

function onResizeMove(event: MouseEvent) {
  if (!resizeTarget) return;
  const next = Math.max(150, startHeight + event.clientY - startY);
  if (resizeTarget === 'top') topHeight.value = next;
  if (resizeTarget === 'middle') middleHeight.value = next;
}

function onResizeEnd() {
  resizeTarget = null;
  document.removeEventListener('mousemove', onResizeMove);
  document.removeEventListener('mouseup', onResizeEnd);
  document.body.style.cursor = '';
  document.body.style.userSelect = '';
}

onMounted(async () => {
  await loadReferenceData();
  await loadFlows();
});

watch(
  () => filterState?.value,
  async state => {
    if (!state || state.tab !== 'approval') return;
    if (!flows.value.length) {
      await loadFlows();
      return;
    }
    selectFlowByPageCode(state.pageCode);
  }
);
</script>

<template>
  <div class="approval-panel">
    <div class="section" :style="{ flex: `0 0 ${topHeight}px` }">
      <div class="toolbar">
        <NSpace size="small">
          <NButton size="small" type="primary" @click="addFlow">新增流程</NButton>
          <NPopconfirm @positive-click="removeFlow">
            <template #trigger>
              <NButton size="small" type="error" :disabled="!selectedFlow">删除流程</NButton>
            </template>
            删除流程会同时删除入口条件、节点和审批人分支，确定继续？
          </NPopconfirm>
          <NButton size="small" @click="saveFlows">保存流程</NButton>
          <NButton size="small" quaternary @click="loadFlows(selectedFlow?.flowId)">刷新</NButton>
        </NSpace>
        <div class="section-title">审批流</div>
      </div>
      <div class="grid-wrapper">
        <AgGridVue
          class="ag-theme-quartz grid-host"
          :row-data="flows"
          :column-defs="flowColDefs"
          :default-col-def="defaultColDef"
          :row-selection="{ mode: 'singleRow', checkboxes: false }"
          :cell-selection="true"
          @grid-ready="onFlowReady"
          @selection-changed="onFlowSelectionChanged"
          @row-clicked="selectClicked"
          @cell-value-changed="onCellValueChanged"
        />
      </div>
    </div>

    <div class="resizer" @mousedown="event => onResizeStart('top', event)" />

    <div class="split-row" :style="{ flex: `0 0 ${middleHeight}px` }">
      <div class="section">
        <div class="toolbar">
          <NSpace size="small">
            <NButton size="small" type="primary" :disabled="!selectedFlow?.flowId" @click="addCondition">
              新增入口条件
            </NButton>
            <NPopconfirm @positive-click="removeCondition">
              <template #trigger>
                <NButton size="small" type="error" :disabled="!selectedCondition">删除</NButton>
              </template>
              确定删除当前总入口条件？
            </NPopconfirm>
            <NButton size="small" @click="saveConditions">保存入口条件</NButton>
          </NSpace>
          <div class="section-title">总入口条件</div>
        </div>
        <div class="grid-wrapper">
          <AgGridVue
            class="ag-theme-quartz grid-host"
            :row-data="conditions"
            :column-defs="conditionColDefs"
            :default-col-def="defaultColDef"
            :row-selection="{ mode: 'singleRow', checkboxes: false }"
            :cell-selection="true"
            @grid-ready="onConditionReady"
            @selection-changed="onConditionSelectionChanged"
            @row-clicked="selectClicked"
            @cell-value-changed="onCellValueChanged"
          />
        </div>
      </div>

      <div class="section">
        <div class="toolbar">
          <NSpace size="small">
            <NButton size="small" type="primary" :disabled="!selectedFlow?.flowId" @click="addNode">
              新增节点
            </NButton>
            <NPopconfirm @positive-click="removeNode">
              <template #trigger>
                <NButton size="small" type="error" :disabled="!selectedNode">删除节点</NButton>
              </template>
              删除节点会同时删除审批人分支，确定继续？
            </NPopconfirm>
            <NButton size="small" @click="saveNodes">保存节点</NButton>
          </NSpace>
          <div class="section-title">审批节点</div>
        </div>
        <div class="grid-wrapper">
          <AgGridVue
            class="ag-theme-quartz grid-host"
            :row-data="nodes"
            :column-defs="nodeColDefs"
            :default-col-def="defaultColDef"
            :row-selection="{ mode: 'singleRow', checkboxes: false }"
            :cell-selection="true"
            @grid-ready="onNodeReady"
            @selection-changed="onNodeSelectionChanged"
            @row-clicked="selectClicked"
            @cell-value-changed="onCellValueChanged"
          />
        </div>
      </div>
    </div>

    <div class="resizer" @mousedown="event => onResizeStart('middle', event)" />

    <div class="section fill-section">
      <div class="toolbar">
        <NSpace size="small">
          <NButton size="small" type="primary" :disabled="!selectedNode?.nodeId" @click="addApprover">
            新增审批人分支
          </NButton>
          <NPopconfirm @positive-click="removeApprover">
            <template #trigger>
              <NButton size="small" type="error" :disabled="!selectedApprover">删除分支</NButton>
            </template>
            确定删除当前审批人分支？
          </NPopconfirm>
          <NButton size="small" @click="saveApprovers">保存审批人分支</NButton>
          <NButton size="small" quaternary :disabled="!selectedNode?.nodeId" @click="loadApprovers(selectedNode?.nodeId)">
            刷新分支
          </NButton>
        </NSpace>
        <div class="section-title">审批人分支：{{ selectedNode?.nodeName || '-' }}</div>
      </div>
      <div class="grid-wrapper">
        <AgGridVue
          class="ag-theme-quartz grid-host"
          :row-data="approvers"
          :column-defs="approverColDefs"
          :default-col-def="defaultColDef"
          :row-selection="{ mode: 'singleRow', checkboxes: false }"
          :cell-selection="true"
          @grid-ready="onApproverReady"
          @selection-changed="onApproverSelectionChanged"
          @row-clicked="selectClicked"
          @cell-value-changed="onCellValueChanged"
        />
      </div>
    </div>
  </div>
</template>

<style scoped>
.approval-panel {
  display: flex;
  flex-direction: column;
  height: 100%;
  min-height: 0;
}

.section {
  display: flex;
  flex-direction: column;
  min-height: 140px;
  overflow: hidden;
}

.split-row {
  display: grid;
  grid-template-columns: minmax(360px, 0.9fr) minmax(460px, 1.1fr);
  gap: 10px;
  min-height: 170px;
  overflow: hidden;
}

.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-shrink: 0;
  padding: 4px 0;
}

.section-title {
  color: #4b5565;
  font-size: 13px;
  font-weight: 600;
  white-space: nowrap;
}

.grid-wrapper {
  flex: 1;
  min-height: 0;
}

.grid-host {
  width: 100%;
  height: 100%;
}

.fill-section {
  flex: 1;
}

.resizer {
  flex-shrink: 0;
  height: 6px;
  margin: 2px 0;
  border-radius: 3px;
  background: #e7eaf0;
  cursor: row-resize;
}

.resizer:hover {
  background: #5b5bd6;
}

@media (max-width: 980px) {
  .split-row {
    grid-template-columns: 1fr;
  }
}
</style>
