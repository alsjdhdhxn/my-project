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

type SelectedKind = 'flow' | 'condition' | 'node' | 'approver' | '';

type ApprovalTreeNode = TreeOption & {
  kind: SelectedKind;
  payload?: any;
  nodeId?: number;
  meta?: string;
};

const message = useMessage();
const filterState = inject<Ref<{ tab: string; pageCode: string } | null>>('filterState');

const flows = ref<any[]>([]);
const conditions = ref<any[]>([]);
const nodes = ref<any[]>([]);
const approversByNode = ref<Record<number, any[]>>({});
const referenceData = ref<Record<string, any[]>>({ pages: [], users: [], roles: [], departments: [] });

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
  { label: 'SQL 条件', value: 'SQL' },
  { label: '可视化条件', value: 'VISUAL' }
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

const visibleFlows = computed(() => {
  if (!activePageCodeFilter.value) return flows.value;
  return flows.value.filter(flow => flow.pageCode === activePageCodeFilter.value);
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
  if (!selectedFlow.value) return [];

  const conditionChildren = conditions.value.map(condition => ({
    key: `condition:${condition.conditionId || condition._tempKey}`,
    label: condition.conditionName || '入口条件',
    kind: 'condition' as const,
    payload: condition,
    meta: condition.conditionMode || 'ALWAYS'
  }));

  const nodeChildren = [...nodes.value]
    .sort((a, b) => Number(a.approvalLevel || 0) - Number(b.approvalLevel || 0))
    .map(node => {
      const nodeId = Number(node.nodeId);
      const approvers = approversByNode.value[nodeId] || [];

      return {
        key: `node:${node.nodeId || node._tempKey}`,
        label: `${node.approvalLevel || '-'}级审批：${node.nodeName || '未命名节点'}`,
        kind: 'node' as const,
        payload: node,
        nodeId,
        meta: `${node.approvalMode || 'OR'} / ${node.conditionMode || 'ALWAYS'}`,
        children: approvers.map((approver, index) => ({
          key: `approver:${approver.id || approver._tempKey}`,
          label: `审批人分支 ${index + 1}：${approverLabel(approver)}`,
          kind: 'approver' as const,
          payload: approver,
          nodeId,
          meta: approver.conditionMode || 'ALWAYS'
        }))
      };
    });

  return [
    {
      key: `flow:${selectedFlow.value.flowId || selectedFlow.value._tempKey || 'new'}`,
      label: selectedFlow.value.flowName || '审批流',
      kind: 'flow',
      payload: selectedFlow.value,
      meta: selectedFlow.value.pageCode,
      children: [
        {
          key: 'entrance',
          label: '总入口条件',
          kind: '',
          children: conditionChildren
        },
        ...nodeChildren
      ]
    }
  ];
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

function setEditor(kind: SelectedKind, payload?: any, key?: string | number | null) {
  selectedKind.value = kind;
  selectedPayload.value = payload || null;
  selectedKey.value = key ? String(key) : null;
  draft.value = clone(payload || {});
}

async function loadReferenceData() {
  referenceData.value = await fetchApprovalReferenceData();
}

async function loadFlows(targetFlowId?: number | null) {
  loading.value = true;
  try {
    flows.value = await fetchApprovalFlows();
    const target =
      flows.value.find(flow => Number(flow.flowId) === Number(targetFlowId)) ||
      (activePageCodeFilter.value ? flows.value.find(flow => flow.pageCode === activePageCodeFilter.value) : null) ||
      visibleFlows.value[0] ||
      null;
    await selectFlow(target);
  } finally {
    loading.value = false;
  }
}

async function selectFlow(flow: any) {
  selectedFlow.value = flow;
  conditions.value = [];
  nodes.value = [];
  approversByNode.value = {};

  if (!flow) {
    setEditor('', null, null);
    return;
  }

  if (!flow.flowId) {
    setEditor('flow', flow, flow._tempKey || null);
    return;
  }

  const [nextConditions, nextNodes] = await Promise.all([
    fetchApprovalConditions(flow.flowId),
    fetchApprovalNodes(flow.flowId)
  ]);
  conditions.value = nextConditions;
  nodes.value = nextNodes;

  const entries = await Promise.all(
    nextNodes
      .filter(node => node.nodeId)
      .map(async node => [Number(node.nodeId), await fetchApprovalApprovers(node.nodeId)] as const)
  );
  approversByNode.value = Object.fromEntries(entries);

  await nextTick();
  expandedKeys.value = collectDefaultExpandedKeys();
  setEditor('flow', selectedFlow.value, `flow:${flow.flowId}`);
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
  setEditor(node.kind, node.payload, node.key);
}

function renderLabel({ option }: { option: TreeOption }) {
  const item = option as ApprovalTreeNode;
  const tagType =
    item.kind === 'flow'
      ? 'info'
      : item.kind === 'node'
        ? 'success'
        : item.kind === 'approver'
          ? 'warning'
          : 'default';

  return h('div', { class: ['tree-line', item.kind ? `tree-line-${item.kind}` : 'tree-line-folder'] }, [
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
  const pageCode = activePageCodeFilter.value || '';
  const row = {
    _isNew: true,
    _tempKey: tempKey('flow'),
    flowId: null,
    pageCode,
    pageName: '',
    flowName: '新审批流',
    flowVersion: 1,
    flowPriority: 100,
    isEnabled: 1,
    remark: ''
  };
  flows.value = [row, ...flows.value];
  selectFlow(row);
}

function addCondition() {
  if (!selectedFlow.value?.flowId) {
    message.warning('请先保存审批流，再新增入口条件');
    return;
  }
  const row = {
    _isNew: true,
    _tempKey: tempKey('condition'),
    conditionId: null,
    flowId: selectedFlow.value.flowId,
    conditionName: '总入口条件',
    conditionMode: 'ALWAYS',
    sqlExpr: '',
    logicTree: '',
    onError: 'REQUIRE_APPROVAL',
    isEnabled: 1
  };
  conditions.value = [...conditions.value, row];
  expandedKeys.value = [...new Set([...expandedKeys.value, 'entrance'])];
  setEditor('condition', row, `condition:${row._tempKey}`);
}

function addNode() {
  if (!selectedFlow.value?.flowId) {
    message.warning('请先保存审批流，再新增审批级别');
    return;
  }
  const maxLevel = Math.max(0, ...nodes.value.map(node => Number(node.approvalLevel) || 0));
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
  nodes.value = [...nodes.value, row];
  setEditor('node', row, `node:${row._tempKey}`);
}

function addApprover() {
  const currentNode =
    selectedKind.value === 'node'
      ? selectedPayload.value
      : selectedKind.value === 'approver'
        ? nodes.value.find(node => Number(node.nodeId) === Number(selectedPayload.value?.nodeId))
        : null;

  if (!currentNode?.nodeId) {
    message.warning('请先保存并选中一个审批节点');
    return;
  }

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
    sortOrder: (approversByNode.value[currentNode.nodeId] || []).length + 1,
    isEnabled: 1
  };
  approversByNode.value = {
    ...approversByNode.value,
    [currentNode.nodeId]: [...(approversByNode.value[currentNode.nodeId] || []), row]
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
      message.warning('页面编码和流程名称不能为空');
      return;
    }
    const saved = await saveApprovalFlow(prepareSavePayload());
    message.success('审批流已保存');
    await loadFlows(saved.flowId);
    return;
  }

  if (selectedKind.value === 'condition') {
    const saved = await saveApprovalCondition(prepareSavePayload());
    message.success('入口条件已保存');
    await selectFlow(selectedFlow.value);
    setEditor('condition', saved, `condition:${saved.conditionId}`);
    return;
  }

  if (selectedKind.value === 'node') {
    if (!text(draft.value.nodeName)) {
      message.warning('节点名称不能为空');
      return;
    }
    const saved = await saveApprovalNode(prepareSavePayload());
    message.success('审批节点已保存');
    await selectFlow(selectedFlow.value);
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
    message.success('审批人分支已保存');
    await selectFlow(selectedFlow.value);
    setEditor('approver', saved, `approver:${saved.id}`);
  }
}

async function deleteCurrent() {
  if (!selectedKind.value) return;

  if (selectedKind.value === 'flow') {
    await removeSelectedFlow();
    return;
  }

  if (selectedKind.value === 'condition') {
    if (draft.value.conditionId) await deleteApprovalCondition(draft.value.conditionId);
    conditions.value = conditions.value.filter(item => item !== selectedPayload.value);
    message.success('入口条件已删除');
    await selectFlow(selectedFlow.value);
    return;
  }

  if (selectedKind.value === 'node') {
    if (draft.value.nodeId) await deleteApprovalNode(draft.value.nodeId);
    nodes.value = nodes.value.filter(item => item !== selectedPayload.value);
    message.success('审批节点已删除');
    await selectFlow(selectedFlow.value);
    return;
  }

  if (selectedKind.value === 'approver') {
    if (draft.value.id) await deleteApprovalApprover(draft.value.id);
    const nodeId = Number(draft.value.nodeId);
    approversByNode.value = {
      ...approversByNode.value,
      [nodeId]: (approversByNode.value[nodeId] || []).filter(item => item !== selectedPayload.value)
    };
    message.success('审批人分支已删除');
    await selectFlow(selectedFlow.value);
  }
}

async function removeSelectedFlow() {
  if (!selectedFlow.value) return;
  if (!selectedFlow.value.flowId) {
    flows.value = flows.value.filter(flow => flow !== selectedFlow.value);
    await selectFlow(visibleFlows.value[0] || null);
    return;
  }
  await deleteApprovalFlow(selectedFlow.value.flowId);
  message.success('审批流已删除');
  await loadFlows();
}

function updateEnabled(value: boolean) {
  draft.value.isEnabled = value ? 1 : 0;
}

function clearPageFilter() {
  activePageCodeFilter.value = '';
  loadFlows();
}

async function applyPageFilter(pageCode: string) {
  activePageCodeFilter.value = pageCode;
  await nextTick();
  const flow = flows.value.find(item => item.pageCode === pageCode);
  if (flow) {
    await selectFlow(flow);
  } else {
    await selectFlow(null);
    message.info(`当前页面还没有配置审批流：${pageCode}`);
  }
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
    <aside class="flow-list">
      <div class="panel-head">
        <div>
          <div class="title">审批流</div>
          <div v-if="activePageCodeFilter" class="subtitle">当前页面：{{ activePageCodeFilter }}</div>
        </div>
        <NSpace size="small">
          <NButton v-if="activePageCodeFilter" size="small" quaternary @click="clearPageFilter">全部</NButton>
          <NButton size="small" type="primary" @click="addFlow">新增</NButton>
          <NPopconfirm @positive-click="removeSelectedFlow">
            <template #trigger>
              <NButton size="small" type="error" :disabled="!selectedFlow">删除</NButton>
            </template>
            删除审批流会同时删除入口条件、审批节点和审批人分支，确定继续？
          </NPopconfirm>
        </NSpace>
      </div>
      <div class="flow-items">
        <button
          v-for="flow in visibleFlows"
          :key="flow.flowId || flow._tempKey"
          class="flow-item"
          :class="{ active: selectedFlow === flow || selectedFlow?.flowId === flow.flowId }"
          type="button"
          @click="selectFlow(flow)"
        >
          <span class="flow-name">{{ flow.flowName || '未命名审批流' }}</span>
          <span class="flow-meta">{{ flow.pageCode || '-' }} · 优先级 {{ flow.flowPriority ?? '-' }}</span>
        </button>
        <NEmpty v-if="!visibleFlows.length && !loading" description="暂无审批流" />
      </div>
    </aside>

    <main class="tree-panel">
      <div class="panel-head">
        <div>
          <div class="title">{{ selectedFlow?.flowName || '请选择审批流' }}</div>
          <div class="subtitle">树中只展示真实配置项：入口条件、审批级别、审批人分支。</div>
        </div>
        <NSpace size="small">
          <NButton size="small" :disabled="!selectedFlow?.flowId" @click="addCondition">新增入口条件</NButton>
          <NButton size="small" :disabled="!selectedFlow?.flowId" @click="addNode">新增审批级别</NButton>
          <NButton size="small" :disabled="selectedKind !== 'node' && selectedKind !== 'approver'" @click="addApprover">
            新增审批分支
          </NButton>
        </NSpace>
      </div>

      <div class="tree-shell">
        <NAlert type="info" :bordered="false" class="help-box">
          总入口条件不满足：无需审批，自动通过。入口条件满足后按审批级别顺序执行。
          本级条件不满足：系统管理员自动驳回。本级条件满足但没有审批分支命中：该级无人认领自动通过。
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
        <NEmpty v-else description="请选择或新建审批流" />
      </div>
    </main>

    <aside class="editor-panel">
      <div class="panel-head">
        <div>
          <div class="title">属性编辑</div>
          <div class="subtitle">{{ selectedKind || '未选择' }}</div>
        </div>
        <NSpace v-if="selectedKind" size="small">
          <NButton size="small" type="primary" @click="saveCurrent">保存</NButton>
          <NPopconfirm @positive-click="deleteCurrent">
            <template #trigger>
              <NButton size="small" type="error">删除</NButton>
            </template>
            确定删除当前配置？
          </NPopconfirm>
        </NSpace>
      </div>

      <div class="editor-body">
        <NEmpty v-if="!selectedKind" description="选择树上的流程、条件、节点或分支进行编辑" />

        <NForm v-else label-placement="top" size="small">
          <template v-if="selectedKind === 'flow'">
            <NFormItem label="页面编码">
              <NInput v-model:value="draft.pageCode" />
            </NFormItem>
            <NFormItem label="流程名称">
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
            <NFormItem label="启用">
              <NSwitch :value="Number(draft.isEnabled) === 1" @update:value="updateEnabled" />
            </NFormItem>
            <NFormItem label="备注">
              <NInput v-model:value="draft.remark" type="textarea" :autosize="{ minRows: 3, maxRows: 6 }" />
            </NFormItem>
          </template>

          <template v-if="selectedKind === 'condition'">
            <NFormItem label="入口条件名称">
              <NInput v-model:value="draft.conditionName" />
            </NFormItem>
            <NFormItem label="条件类型">
              <NSelect v-model:value="draft.conditionMode" :options="conditionModeOptions" />
            </NFormItem>
            <NFormItem label="SQL 条件">
              <NInput
                v-model:value="draft.sqlExpr"
                type="textarea"
                placeholder="例如：M.URGENCY_LEVEL = '紧急'"
                :autosize="{ minRows: 4, maxRows: 10 }"
              />
            </NFormItem>
            <NFormItem label="可视化条件 JSON">
              <NInput v-model:value="draft.logicTree" type="textarea" :autosize="{ minRows: 3, maxRows: 8 }" />
            </NFormItem>
            <NFormItem label="异常策略">
              <NSelect v-model:value="draft.onError" :options="onErrorOptions" />
            </NFormItem>
            <NFormItem label="启用">
              <NSwitch :value="Number(draft.isEnabled) === 1" @update:value="updateEnabled" />
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
            <NFormItem label="本级条件类型">
              <NSelect v-model:value="draft.conditionMode" :options="conditionModeOptions" />
            </NFormItem>
            <NFormItem label="本级 SQL 条件">
              <NInput
                v-model:value="draft.sqlExpr"
                type="textarea"
                placeholder="本级条件不满足时：系统管理员自动驳回"
                :autosize="{ minRows: 4, maxRows: 10 }"
              />
            </NFormItem>
            <NFormItem label="异常策略">
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
  grid-template-columns: 280px minmax(460px, 1fr) 360px;
  gap: 12px;
  height: 100%;
  min-height: 0;
}

.flow-list,
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

.flow-items,
.tree-shell,
.editor-body {
  flex: 1;
  min-height: 0;
  overflow: auto;
  padding: 10px;
}

.flow-item {
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

.flow-item:hover {
  background: #f5f7fb;
}

.flow-item.active {
  border-color: #646cff;
  background: #eef2ff;
}

.flow-name {
  color: #202636;
  font-weight: 700;
}

.flow-meta {
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

.tree-line-folder .tree-label {
  color: #4b5565;
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
