<script setup lang="ts">
import { computed, h, inject, nextTick, onMounted, ref, watch } from 'vue';
import type { Ref } from 'vue';
import {
  NAlert,
  NButton,
  NEmpty,
  NForm,
  NFormItem,
  NInput,
  NInputNumber,
  NPopconfirm,
  NSelect,
  NSpace,
  NSwitch,
  NTag,
  NTree,
  useMessage
} from 'naive-ui';
import type { TreeOption } from 'naive-ui';
import {
  deleteApprovalApprover,
  deleteApprovalFlow,
  deleteApprovalNode,
  deleteApprovalPage,
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

type SelectedKind = 'page' | 'flow' | 'node' | 'approver' | '';

type ApprovalTreeNode = TreeOption & {
  kind: SelectedKind;
  payload?: any;
  flowId?: number;
  nodeId?: number;
  meta?: string;
};

type FlowDetail = {
  conditions: any[];
  nodes: any[];
  approversByNode: Record<number, any[]>;
};

const message = useMessage();
const filterState = inject<Ref<{ tab: string; pageCode: string } | null>>('filterState');

const flows = ref<any[]>([]);
const referenceData = ref<Record<string, any[]>>({ pages: [], users: [], roles: [], departments: [] });
const flowDetails = ref<Record<number, FlowDetail>>({});

const selectedPageCode = ref('');
const selectedFlow = ref<any>(null);
const selectedKey = ref<string | null>(null);
const selectedKind = ref<SelectedKind>('');
const selectedPayload = ref<any>(null);
const draft = ref<any>({});
const expandedKeys = ref<Array<string | number>>([]);
const activePageCodeFilter = ref('');
const loading = ref(false);

const conditionModeOptions = [
  { label: '总是满足', value: 'ALWAYS' },
  { label: 'SQL 条件', value: 'SQL' }
];

const approvalModeOptions = [
  { label: '或签 OR', value: 'OR' },
  { label: '会签 AND', value: 'AND' }
];

const targetTypeOptions = [
  { label: '指定用户', value: 'USER' },
  { label: '指定角色', value: 'ROLE' }
];

const onErrorOptions = [
  { label: '失败时按不满足处理', value: 'REQUIRE_APPROVAL' },
  { label: '失败时阻断流程', value: 'BLOCK' }
];

const visiblePages = computed(() => {
  const pages = referenceData.value.pages || [];
  if (activePageCodeFilter.value) {
    return pages.filter(page => page.pageCode === activePageCodeFilter.value);
  }
  return pages;
});

const pageFlows = computed(() => {
  if (!selectedPageCode.value) return [];
  return flows.value
    .filter(flow => flow.pageCode === selectedPageCode.value)
    .sort((a, b) => Number(a.flowPriority || 0) - Number(b.flowPriority || 0) || Number(a.flowId || 0) - Number(b.flowId || 0));
});

const selectedPage = computed(() => {
  return (referenceData.value.pages || []).find(page => page.pageCode === selectedPageCode.value) || null;
});

const userOptions = computed(() =>
  (referenceData.value.users || []).map(user => ({
    label: `${user.realName || user.username} (${user.id})`,
    value: Number(user.id)
  }))
);

const roleOptions = computed(() =>
  (referenceData.value.roles || []).map(role => ({
    label: `${role.roleName || role.roleCode} (${role.id})`,
    value: Number(role.id)
  }))
);

const deptOptions = computed(() =>
  (referenceData.value.departments || []).map(dept => ({
    label: `${dept.deptName || dept.deptCode} (${dept.id})`,
    value: Number(dept.id)
  }))
);

const treeData = computed<ApprovalTreeNode[]>(() => {
  return pageFlows.value.map(flow => {
    const detail = getFlowDetail(flow.flowId);
    const nodes = [...detail.nodes].sort(
      (a, b) => Number(a.approvalLevel || 0) - Number(b.approvalLevel || 0) || Number(a.nodeId || 0) - Number(b.nodeId || 0)
    );

    return {
      key: `flow:${flow.flowId || flow._tempKey}`,
      label: flow.flowName || '未命名审批项目',
      kind: 'flow',
      payload: flow,
      flowId: Number(flow.flowId || 0),
      meta: flowMeta(flow),
      children: nodes.map(node => {
        const nodeId = Number(node.nodeId);
        const approvers = detail.approversByNode[nodeId] || [];

        return {
          key: `node:${node.nodeId || node._tempKey}`,
          label: `${node.approvalLevel || '-'}级审批：${node.nodeName || '未命名节点'}`,
          kind: 'node' as const,
          payload: node,
          flowId: Number(flow.flowId || 0),
          nodeId,
          meta: `${node.approvalMode || 'OR'} / ${node.conditionMode || 'ALWAYS'}`,
          children: approvers.map((approver, index) => ({
            key: `approver:${approver.id || approver._tempKey}`,
            label: `分支 ${index + 1}：${approverLabel(approver)}`,
            kind: 'approver' as const,
            payload: approver,
            flowId: Number(flow.flowId || 0),
            nodeId,
            meta: approver.conditionMode || 'ALWAYS'
          }))
        };
      })
    };
  });
});

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

function clone<T>(value: T): T {
  return JSON.parse(JSON.stringify(value || {}));
}

function tempKey(prefix: string) {
  return `${prefix}-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function getFlowDetail(flowId: unknown): FlowDetail {
  const id = Number(flowId || 0);
  return flowDetails.value[id] || { conditions: [], nodes: [], approversByNode: {} };
}

function firstEntranceCondition(flow: any) {
  return getFlowDetail(flow?.flowId).conditions[0] || null;
}

function flowMeta(flow: any) {
  const condition = firstEntranceCondition(flow);
  const mode = condition?.conditionMode || 'ALWAYS';
  return `优先级 ${flow.flowPriority ?? '-'} / ${mode}${getFlowOption(flow, 'requireApplicantForSubmit') ? ' / 申请人' : ''}`;
}

function parseFlowRemark(remark?: string) {
  const value = text(remark);
  if (!value.startsWith('{')) return { text: value, options: {} as Record<string, any> };
  try {
    const parsed = JSON.parse(value);
    return {
      text: typeof parsed.text === 'string' ? parsed.text : '',
      options: parsed.options && typeof parsed.options === 'object' ? parsed.options : {}
    };
  } catch {
    return { text: value, options: {} as Record<string, any> };
  }
}

function buildFlowRemark(row: any) {
  const plainText = text(row.remarkText);
  const options = {
    requireApplicantForSubmit: Number(row.requireApplicantForSubmit) === 1
  };
  return options.requireApplicantForSubmit ? JSON.stringify({ text: plainText, options }) : plainText;
}

function getFlowOption(flow: any, key: string) {
  return Boolean(parseFlowRemark(flow?.remark).options[key]);
}

function pageLabel(page: any) {
  return page.resourceName || page.pageName || page.pageCode || '未命名页面';
}

function approverLabel(approver: any) {
  if (approver.targetType === 'ROLE') {
    return approver.targetRoleName || approver.targetRoleCode || `角色 ${approver.targetRoleId || '-'}`;
  }
  return approver.targetUserName || `用户 ${approver.targetUserId || '-'}`;
}

function optionById(list: any[], id: unknown) {
  const target = numberValue(id);
  if (target === null) return null;
  return list.find(item => Number(item.id) === target) || null;
}

function fillNamesForApprover(row: any) {
  const dept = optionById(referenceData.value.departments || [], row.applyDeptId);
  row.applyDeptName = dept ? dept.deptName : row.applyDeptName || '';

  if (row.targetType === 'ROLE') {
    const role = optionById(referenceData.value.roles || [], row.targetRoleId);
    row.targetRoleCode = role ? role.roleCode : row.targetRoleCode || '';
    row.targetRoleName = role ? role.roleName : row.targetRoleName || '';
    row.targetUserId = null;
    row.targetUserName = '';
    return;
  }

  const user = optionById(referenceData.value.users || [], row.targetUserId);
  row.targetUserName = user ? user.realName || user.username : row.targetUserName || '';
  row.targetRoleId = null;
  row.targetRoleCode = '';
  row.targetRoleName = '';
}

function flowEditorDraft(flow: any) {
  const row = clone(flow || {});
  const remark = parseFlowRemark(row.remark);
  const condition = firstEntranceCondition(flow);
  row.remarkText = remark.text;
  row.requireApplicantForSubmit = remark.options.requireApplicantForSubmit ? 1 : 0;
  row.entranceConditionId = condition?.conditionId || null;
  row.conditionName = condition?.conditionName || '入口条件';
  row.conditionMode = condition?.conditionMode || 'ALWAYS';
  row.sqlExpr = condition?.sqlExpr || '';
  row.onError = condition?.onError || 'REQUIRE_APPROVAL';
  row.conditionEnabled = condition?.isEnabled ?? 1;
  return row;
}

function setEditor(kind: SelectedKind, payload?: any, key?: string | number | null) {
  selectedKind.value = kind;
  selectedPayload.value = payload || null;
  selectedKey.value = key ? String(key) : null;
  draft.value = kind === 'flow' ? flowEditorDraft(payload || {}) : clone(payload || {});
}

async function loadReferenceData() {
  referenceData.value = await fetchApprovalReferenceData();
}

async function loadFlows() {
  loading.value = true;
  try {
    flows.value = await fetchApprovalFlows();
    if (!selectedPageCode.value) {
      const firstPage = activePageCodeFilter.value
        ? visiblePages.value.find(page => page.pageCode === activePageCodeFilter.value)
        : visiblePages.value[0];
      if (firstPage) await selectPage(firstPage.pageCode);
    } else {
      await loadPageFlowDetails(selectedPageCode.value);
    }
  } finally {
    loading.value = false;
  }
}

async function loadPageFlowDetails(pageCode: string) {
  const targetFlows = flows.value.filter(flow => flow.pageCode === pageCode && flow.flowId);
  const nextDetails: Record<number, FlowDetail> = { ...flowDetails.value };

  await Promise.all(
    targetFlows.map(async flow => {
      const flowId = Number(flow.flowId);
      const [conditions, nodes] = await Promise.all([fetchApprovalConditions(flowId), fetchApprovalNodes(flowId)]);
      const entries = await Promise.all(
        nodes
          .filter(node => node.nodeId)
          .map(async node => [Number(node.nodeId), await fetchApprovalApprovers(Number(node.nodeId))] as const)
      );
      nextDetails[flowId] = {
        conditions,
        nodes,
        approversByNode: Object.fromEntries(entries)
      };
    })
  );

  flowDetails.value = nextDetails;
  await nextTick();
  expandedKeys.value = collectDefaultExpandedKeys();
}

async function selectPage(pageCode: string) {
  selectedPageCode.value = pageCode;
  selectedFlow.value = null;
  setEditor('page', selectedPage.value || { pageCode }, `page:${pageCode}`);
  await loadPageFlowDetails(pageCode);
}

async function selectFlow(flow: any) {
  selectedFlow.value = flow;
  if (flow?.flowId) await loadPageFlowDetails(flow.pageCode);
  setEditor('flow', flow, `flow:${flow.flowId || flow._tempKey}`);
}

function collectDefaultExpandedKeys() {
  const keys: string[] = [];
  const visit = (items: ApprovalTreeNode[]) => {
    for (const item of items) {
      keys.push(String(item.key));
      if (item.children?.length) visit(item.children as ApprovalTreeNode[]);
    }
  };
  visit(treeData.value);
  return keys;
}

function findNodeByKey(items: ApprovalTreeNode[], key: string | number): ApprovalTreeNode | null {
  for (const item of items) {
    if (String(item.key) === String(key)) return item;
    const matched = item.children?.length ? findNodeByKey(item.children as ApprovalTreeNode[], key) : null;
    if (matched) return matched;
  }
  return null;
}

function handleTreeSelect(keys: Array<string | number>) {
  const key = keys[0];
  if (!key) return;
  const node = findNodeByKey(treeData.value, key);
  if (!node || !node.kind) return;
  if (node.kind === 'flow') selectedFlow.value = node.payload;
  if (node.flowId) selectedFlow.value = flows.value.find(flow => Number(flow.flowId) === Number(node.flowId)) || selectedFlow.value;
  setEditor(node.kind, node.payload, node.key);
}

function renderLabel({ option }: { option: TreeOption }) {
  const item = option as ApprovalTreeNode;
  const tagType = item.kind === 'flow' ? 'info' : item.kind === 'node' ? 'success' : 'warning';

  return h('div', { class: ['tree-line', `tree-line-${item.kind}`] }, [
    h('span', { class: 'tree-label' }, String(item.label || '')),
    item.meta
      ? h(
          NTag,
          {
            size: 'small',
            type: tagType as any,
            bordered: false,
            class: 'tree-tag'
          },
          { default: () => item.meta }
        )
      : null
  ]);
}

function addFlow() {
  if (!selectedPageCode.value) {
    message.warning('请先选择页面');
    return;
  }
  const page = selectedPage.value;
  const row = {
    _isNew: true,
    _tempKey: tempKey('flow'),
    flowId: null,
    pageCode: selectedPageCode.value,
    pageName: pageLabel(page),
    flowName: '新审批项目',
    flowVersion: 1,
    flowPriority: 100,
    isEnabled: 1,
    remark: '',
    remarkText: '',
    requireApplicantForSubmit: 0
  };
  flows.value = [row, ...flows.value];
  selectedFlow.value = row;
  setEditor('flow', row, `flow:${row._tempKey}`);
}

function addNode() {
  if (!selectedFlow.value?.flowId) {
    message.warning('请先保存并选中一个审批项目');
    return;
  }
  const detail = getFlowDetail(selectedFlow.value.flowId);
  const maxLevel = Math.max(0, ...detail.nodes.map(node => Number(node.approvalLevel) || 0));
  const row = {
    _isNew: true,
    _tempKey: tempKey('node'),
    nodeId: null,
    flowId: selectedFlow.value.flowId,
    approvalLevel: maxLevel + 1,
    nodeName: `${maxLevel + 1}级审批`,
    approvalMode: 'OR',
    conditionMode: 'ALWAYS',
    sqlExpr: '',
    logicTree: '',
    onError: 'REQUIRE_APPROVAL',
    isEnabled: 1
  };
  flowDetails.value = {
    ...flowDetails.value,
    [selectedFlow.value.flowId]: {
      ...detail,
      nodes: [...detail.nodes, row]
    }
  };
  setEditor('node', row, `node:${row._tempKey}`);
}

function addApprover() {
  const currentNode =
    selectedKind.value === 'node'
      ? selectedPayload.value
      : selectedKind.value === 'approver'
        ? getFlowDetail(selectedFlow.value?.flowId).nodes.find(node => Number(node.nodeId) === Number(selectedPayload.value?.nodeId))
        : null;

  if (!currentNode?.nodeId) {
    message.warning('请先保存并选中一个审批节点');
    return;
  }

  const detail = getFlowDetail(selectedFlow.value.flowId);
  const row = {
    _isNew: true,
    _tempKey: tempKey('approver'),
    id: null,
    nodeId: currentNode.nodeId,
    applyDeptId: null,
    applyDeptName: '',
    targetType: 'USER',
    targetUserId: null,
    targetUserName: '',
    targetRoleId: null,
    targetRoleCode: '',
    targetRoleName: '',
    conditionMode: 'ALWAYS',
    sqlExpr: '',
    logicTree: '',
    onError: 'REQUIRE_APPROVAL',
    sortOrder: (detail.approversByNode[currentNode.nodeId] || []).length + 1,
    isEnabled: 1
  };
  flowDetails.value = {
    ...flowDetails.value,
    [selectedFlow.value.flowId]: {
      ...detail,
      approversByNode: {
        ...detail.approversByNode,
        [currentNode.nodeId]: [...(detail.approversByNode[currentNode.nodeId] || []), row]
      }
    }
  };
  expandedKeys.value = [...new Set([...expandedKeys.value, `node:${currentNode.nodeId}`])];
  setEditor('approver', row, `approver:${row._tempKey}`);
}

function prepareSavePayload() {
  const payload = clone(draft.value);
  delete payload._isNew;
  delete payload._tempKey;
  return payload;
}

async function saveCurrent() {
  if (!selectedKind.value) return;

  if (selectedKind.value === 'flow') {
    if (!text(draft.value.pageCode) || !text(draft.value.flowName)) {
      message.warning('页面编码和审批项目名称不能为空');
      return;
    }

    const flowPayload = prepareSavePayload();
    flowPayload.remark = buildFlowRemark(flowPayload);
    const conditionPayload = {
      conditionId: flowPayload.entranceConditionId || null,
      flowId: flowPayload.flowId || null,
      conditionName: flowPayload.conditionName || '入口条件',
      conditionMode: flowPayload.conditionMode || 'ALWAYS',
      logicTree: '',
      sqlExpr: flowPayload.sqlExpr || '',
      onError: flowPayload.onError || 'REQUIRE_APPROVAL',
      isEnabled: flowPayload.conditionEnabled ?? 1
    };

    delete flowPayload.entranceConditionId;
    delete flowPayload.conditionName;
    delete flowPayload.conditionMode;
    delete flowPayload.sqlExpr;
    delete flowPayload.onError;
    delete flowPayload.conditionEnabled;
    delete flowPayload.remarkText;
    delete flowPayload.requireApplicantForSubmit;

    const saved = await saveApprovalFlow(flowPayload);
    conditionPayload.flowId = saved.flowId;
    await saveApprovalCondition(conditionPayload);
    message.success('审批项目已保存');
    await loadFlows();
    const next = flows.value.find(flow => Number(flow.flowId) === Number(saved.flowId));
    if (next) await selectFlow(next);
    return;
  }

  if (selectedKind.value === 'node') {
    if (!text(draft.value.nodeName)) {
      message.warning('节点名称不能为空');
      return;
    }
    const saved = await saveApprovalNode(prepareSavePayload());
    message.success('审批节点已保存');
    await loadPageFlowDetails(selectedPageCode.value);
    const flow = flows.value.find(item => Number(item.flowId) === Number(saved.flowId));
    if (flow) selectedFlow.value = flow;
    setEditor('node', saved, `node:${saved.nodeId}`);
    return;
  }

  if (selectedKind.value === 'approver') {
    fillNamesForApprover(draft.value);
    if (draft.value.targetType === 'ROLE' && !numberValue(draft.value.targetRoleId)) {
      message.warning('角色审批分支必须选择角色');
      return;
    }
    if (draft.value.targetType !== 'ROLE' && !numberValue(draft.value.targetUserId)) {
      message.warning('用户审批分支必须选择用户');
      return;
    }
    const saved = await saveApprovalApprover(prepareSavePayload());
    message.success('分支条件已保存');
    await loadPageFlowDetails(selectedPageCode.value);
    setEditor('approver', saved, `approver:${saved.id}`);
  }
}

async function deleteCurrent() {
  if (selectedKind.value === 'page') {
    await removeSelectedPage();
    return;
  }

  if (selectedKind.value === 'flow') {
    await removeSelectedFlow();
    return;
  }

  if (selectedKind.value === 'node') {
    if (draft.value.nodeId) await deleteApprovalNode(draft.value.nodeId);
    message.success('审批节点已删除');
    await loadPageFlowDetails(selectedPageCode.value);
    setEditor('flow', selectedFlow.value, `flow:${selectedFlow.value?.flowId}`);
    return;
  }

  if (selectedKind.value === 'approver') {
    if (draft.value.id) await deleteApprovalApprover(draft.value.id);
    message.success('分支条件已删除');
    await loadPageFlowDetails(selectedPageCode.value);
    const node = getFlowDetail(selectedFlow.value?.flowId).nodes.find(item => Number(item.nodeId) === Number(draft.value.nodeId));
    setEditor(node ? 'node' : 'flow', node || selectedFlow.value, node ? `node:${node.nodeId}` : `flow:${selectedFlow.value?.flowId}`);
  }
}

async function removeSelectedPage() {
  if (!selectedPageCode.value) return;
  await deleteApprovalPage(selectedPageCode.value);
  message.success('当前页面下的审批配置已全部删除');
  flows.value = flows.value.filter(flow => flow.pageCode !== selectedPageCode.value);
  flowDetails.value = {};
  selectedFlow.value = null;
  setEditor('page', selectedPage.value || { pageCode: selectedPageCode.value }, `page:${selectedPageCode.value}`);
}

async function removeSelectedFlow() {
  if (!selectedFlow.value) return;
  if (!selectedFlow.value.flowId) {
    flows.value = flows.value.filter(flow => flow !== selectedFlow.value);
    selectedFlow.value = null;
    setEditor('page', selectedPage.value || { pageCode: selectedPageCode.value }, `page:${selectedPageCode.value}`);
    return;
  }
  await deleteApprovalFlow(selectedFlow.value.flowId);
  message.success('审批项目已删除');
  const deletedFlowId = Number(selectedFlow.value.flowId);
  flows.value = flows.value.filter(flow => Number(flow.flowId) !== deletedFlowId);
  const nextDetails = { ...flowDetails.value };
  delete nextDetails[deletedFlowId];
  flowDetails.value = nextDetails;
  selectedFlow.value = null;
  setEditor('page', selectedPage.value || { pageCode: selectedPageCode.value }, `page:${selectedPageCode.value}`);
}

function updateEnabled(value: boolean) {
  draft.value.isEnabled = value ? 1 : 0;
}

function updateConditionEnabled(value: boolean) {
  draft.value.conditionEnabled = value ? 1 : 0;
}

function clearPageFilter() {
  activePageCodeFilter.value = '';
  selectedPageCode.value = '';
  loadFlows();
}

async function applyPageFilter(pageCode: string) {
  activePageCodeFilter.value = pageCode;
  await nextTick();
  const page = visiblePages.value.find(item => item.pageCode === pageCode) || { pageCode };
  await selectPage(page.pageCode);
}

onMounted(async () => {
  if (filterState?.value?.tab === 'approval' && filterState.value.pageCode) {
    activePageCodeFilter.value = filterState.value.pageCode;
  }
  await loadReferenceData();
  await loadFlows();
});

watch(
  () => filterState?.value,
  state => {
    if (state?.tab === 'approval' && state.pageCode) {
      applyPageFilter(state.pageCode);
    }
  }
);
</script>

<template>
  <div class="approval-workbench">
    <aside class="page-list">
      <div class="panel-head">
        <div>
          <div class="title">页面</div>
          <div v-if="activePageCodeFilter" class="subtitle">当前页面：{{ activePageCodeFilter }}</div>
        </div>
        <NSpace size="small">
          <NButton v-if="activePageCodeFilter" size="small" quaternary @click="clearPageFilter">全部</NButton>
          <NPopconfirm @positive-click="removeSelectedPage">
            <template #trigger>
              <NButton size="small" type="error" :disabled="!selectedPageCode">删除</NButton>
            </template>
            删除页面审批配置会硬删该页面下所有审批项目、节点、分支和相关审批实例，确定继续？
          </NPopconfirm>
        </NSpace>
      </div>
      <div class="page-items">
        <button
          v-for="page in visiblePages"
          :key="page.pageCode"
          class="page-item"
          :class="{ active: selectedPageCode === page.pageCode }"
          type="button"
          @click="selectPage(page.pageCode)"
        >
          <span class="page-name">{{ pageLabel(page) }}</span>
          <span class="page-meta">{{ page.pageCode }}</span>
        </button>
        <NEmpty v-if="!visiblePages.length && !loading" description="暂无页面" />
      </div>
    </aside>

    <main class="tree-panel">
      <div class="panel-head">
        <div>
          <div class="title">{{ selectedPage ? pageLabel(selectedPage) : '请选择页面' }}</div>
          <div class="subtitle">点击审批项目可直接填写入口条件；点击审批节点可填写节点条件。</div>
        </div>
        <NSpace size="small">
          <NButton size="small" type="primary" :disabled="!selectedPageCode" @click="addFlow">新增审批项目</NButton>
          <NButton size="small" :disabled="!selectedFlow?.flowId" @click="addNode">新增审批节点</NButton>
          <NButton size="small" :disabled="selectedKind !== 'node' && selectedKind !== 'approver'" @click="addApprover">
            新增分支条件
          </NButton>
        </NSpace>
      </div>

      <div class="tree-shell">
        <NAlert type="info" :bordered="false" class="help-box">
          入口条件不满足：无需审批，自动通过。节点条件不满足：系统管理员自动驳回。节点条件满足但没有分支命中：该级无人认领自动通过。
        </NAlert>

        <NTree
          v-if="treeData.length"
          v-model:expanded-keys="expandedKeys"
          block-line
          expand-on-click
          :data="treeData"
          :selected-keys="selectedKey ? [selectedKey] : []"
          :render-label="renderLabel"
          @update:selected-keys="handleTreeSelect"
        />
        <NEmpty v-else description="当前页面暂无审批项目" />
      </div>
    </main>

    <aside class="editor-panel">
      <div class="panel-head">
        <div>
          <div class="title">属性编辑</div>
          <div class="subtitle">{{ selectedKind || '未选择' }}</div>
        </div>
        <NSpace v-if="selectedKind" size="small">
          <NButton v-if="selectedKind !== 'page'" size="small" type="primary" @click="saveCurrent">保存</NButton>
          <NPopconfirm @positive-click="deleteCurrent">
            <template #trigger>
              <NButton size="small" type="error">删除</NButton>
            </template>
            确定硬删当前配置及其下级数据？
          </NPopconfirm>
        </NSpace>
      </div>

      <div class="editor-body">
        <NEmpty v-if="!selectedKind" description="选择页面、审批项目、审批节点或分支条件进行编辑" />

        <NForm v-else label-placement="top" size="small">
          <template v-if="selectedKind === 'page'">
            <NFormItem label="页面名称">
              <NInput :value="pageLabel(draft)" readonly />
            </NFormItem>
            <NFormItem label="页面编码">
              <NInput :value="draft.pageCode" readonly />
            </NFormItem>
            <NAlert type="warning" :bordered="false">
              删除页面会删除该页面下所有审批项目、审批节点、分支条件和相关审批实例。
            </NAlert>
          </template>

          <template v-if="selectedKind === 'flow'">
            <NFormItem label="页面编码">
              <NInput v-model:value="draft.pageCode" readonly />
            </NFormItem>
            <NFormItem label="审批项目名称">
              <NInput v-model:value="draft.flowName" />
            </NFormItem>
            <div class="form-grid">
              <NFormItem label="优先级">
                <NInputNumber v-model:value="draft.flowPriority" :min="1" />
              </NFormItem>
              <NFormItem label="版本">
                <NInputNumber v-model:value="draft.flowVersion" :min="1" />
              </NFormItem>
            </div>
            <NFormItem label="入口条件名称">
              <NInput v-model:value="draft.conditionName" />
            </NFormItem>
            <NFormItem label="入口条件类型">
              <NSelect v-model:value="draft.conditionMode" :options="conditionModeOptions" />
            </NFormItem>
            <NFormItem label="入口 SQL 条件">
              <NInput
                v-model:value="draft.sqlExpr"
                type="textarea"
                placeholder="例如：M.URGENCY_LEVEL = '紧急'"
                :autosize="{ minRows: 4, maxRows: 10 }"
              />
            </NFormItem>
            <NFormItem label="入口异常策略">
              <NSelect v-model:value="draft.onError" :options="onErrorOptions" />
            </NFormItem>
            <div class="form-grid">
              <NFormItem label="审批项目启用">
                <NSwitch :value="Number(draft.isEnabled) === 1" @update:value="updateEnabled" />
              </NFormItem>
              <NFormItem label="入口条件启用">
                <NSwitch :value="Number(draft.conditionEnabled) === 1" @update:value="updateConditionEnabled" />
              </NFormItem>
            </div>
            <NFormItem label="申请人限制">
              <NSwitch
                :value="Number(draft.requireApplicantForSubmit) === 1"
                @update:value="value => (draft.requireApplicantForSubmit = value ? 1 : 0)"
              />
            </NFormItem>
            <NFormItem label="备注">
              <NInput v-model:value="draft.remarkText" type="textarea" :autosize="{ minRows: 3, maxRows: 6 }" />
            </NFormItem>
          </template>

          <template v-if="selectedKind === 'node'">
            <div class="form-grid">
              <NFormItem label="审批级别">
                <NInputNumber v-model:value="draft.approvalLevel" :min="1" />
              </NFormItem>
              <NFormItem label="审批模式">
                <NSelect v-model:value="draft.approvalMode" :options="approvalModeOptions" />
              </NFormItem>
            </div>
            <NFormItem label="节点名称">
              <NInput v-model:value="draft.nodeName" />
            </NFormItem>
            <NFormItem label="节点条件类型">
              <NSelect v-model:value="draft.conditionMode" :options="conditionModeOptions" />
            </NFormItem>
            <NFormItem label="节点 SQL 条件">
              <NInput
                v-model:value="draft.sqlExpr"
                type="textarea"
                placeholder="节点条件不满足时：系统管理员自动驳回"
                :autosize="{ minRows: 4, maxRows: 10 }"
              />
            </NFormItem>
            <NFormItem label="节点异常策略">
              <NSelect v-model:value="draft.onError" :options="onErrorOptions" />
            </NFormItem>
            <NFormItem label="启用">
              <NSwitch :value="Number(draft.isEnabled) === 1" @update:value="updateEnabled" />
            </NFormItem>
          </template>

          <template v-if="selectedKind === 'approver'">
            <div class="form-grid">
              <NFormItem label="排序">
                <NInputNumber v-model:value="draft.sortOrder" :min="1" />
              </NFormItem>
              <NFormItem label="审批对象">
                <NSelect v-model:value="draft.targetType" :options="targetTypeOptions" />
              </NFormItem>
            </div>
            <NFormItem label="发起部门限制">
              <NSelect v-model:value="draft.applyDeptId" clearable filterable :options="deptOptions" />
            </NFormItem>
            <NFormItem v-if="draft.targetType === 'ROLE'" label="审批角色">
              <NSelect v-model:value="draft.targetRoleId" filterable :options="roleOptions" />
            </NFormItem>
            <NFormItem v-else label="审批用户">
              <NSelect v-model:value="draft.targetUserId" filterable :options="userOptions" />
            </NFormItem>
            <NFormItem label="分支条件类型">
              <NSelect v-model:value="draft.conditionMode" :options="conditionModeOptions" />
            </NFormItem>
            <NFormItem label="分支 SQL 条件">
              <NInput
                v-model:value="draft.sqlExpr"
                type="textarea"
                placeholder="条件命中时，该分支认领本级审批"
                :autosize="{ minRows: 4, maxRows: 10 }"
              />
            </NFormItem>
            <NFormItem label="启用">
              <NSwitch :value="Number(draft.isEnabled) === 1" @update:value="updateEnabled" />
            </NFormItem>
          </template>
        </NForm>
      </div>
    </aside>
  </div>
</template>

<style scoped>
.approval-workbench {
  display: grid;
  grid-template-columns: 280px minmax(520px, 1fr) 360px;
  gap: 12px;
  height: 100%;
  min-height: 0;
}

.page-list,
.tree-panel,
.editor-panel {
  display: flex;
  flex-direction: column;
  min-height: 0;
  border: 1px solid #d9deea;
  border-radius: 8px;
  background: #fff;
}

.panel-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-shrink: 0;
  min-height: 52px;
  padding: 10px 12px;
  border-bottom: 1px solid #edf0f5;
}

.title {
  color: #1f2633;
  font-size: 14px;
  font-weight: 700;
}

.subtitle {
  margin-top: 3px;
  color: #6b7280;
  font-size: 12px;
}

.page-items,
.tree-shell,
.editor-body {
  flex: 1;
  min-height: 0;
  overflow: auto;
  padding: 10px;
}

.page-item {
  display: flex;
  width: 100%;
  flex-direction: column;
  align-items: flex-start;
  gap: 4px;
  padding: 10px;
  border: 1px solid transparent;
  border-radius: 6px;
  background: transparent;
  cursor: pointer;
  text-align: left;
}

.page-item:hover {
  background: #f5f7fb;
}

.page-item.active {
  border-color: #646cff;
  background: #eef2ff;
}

.page-name {
  color: #202636;
  font-weight: 700;
}

.page-meta {
  color: #6b7280;
  font-size: 12px;
}

.help-box {
  margin-bottom: 10px;
  line-height: 1.7;
}

.tree-shell :deep(.n-tree-node-content) {
  min-height: 34px;
}

.tree-line {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
}

.tree-label {
  overflow: hidden;
  color: #1f2633;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.tree-line-flow .tree-label {
  font-weight: 700;
}

.tree-tag {
  flex-shrink: 0;
}

.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}

@media (max-width: 1180px) {
  .approval-workbench {
    grid-template-columns: 220px minmax(420px, 1fr);
  }

  .editor-panel {
    grid-column: 1 / -1;
    min-height: 280px;
  }
}
</style>
