<script setup lang="ts">
import { computed, h, nextTick, onMounted, ref } from 'vue';
import {
  NAlert,
  NButton,
  NCheckbox,
  NDynamicInput,
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
import type { SelectOption, TreeOption } from 'naive-ui';
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

const props = defineProps<{
  pageCode: string;
}>();

type SelectedKind = 'flow' | 'node' | 'approver' | '';

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

const flows = ref<any[]>([]);
const referenceData = ref<Record<string, any[]>>({ pages: [], users: [], roles: [], departments: [] });
const flowDetails = ref<Record<number, FlowDetail>>({});

const selectedFlow = ref<any>(null);
const selectedKey = ref<string | null>(null);
const selectedKind = ref<SelectedKind>('');
const selectedPayload = ref<any>(null);
const draft = ref<any>({});
const expandedKeys = ref<Array<string | number>>([]);
const loading = ref(false);

// --- Options ---
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
const actionModeOptions = [
  { label: '后台自动执行', value: 'AUTO' },
  { label: '前台手动传参', value: 'MANUAL' }
];
const actionParamTypeOptions = [
  { label: '文本', value: 'STRING' },
  { label: '数字', value: 'NUMBER' },
  { label: '多行文本', value: 'TEXTAREA' }
];

// --- Computed ---
const pageFlows = computed(() => {
  return flows.value
    .filter(flow => flow.pageCode === props.pageCode)
    .sort((a, b) => Number(a.flowPriority || 0) - Number(b.flowPriority || 0) || Number(a.flowId || 0) - Number(b.flowId || 0));
});

const userOptions = computed(() =>
  (referenceData.value.users || []).map(user => ({
    label: `${user.realName || user.username} (${user.id})`,
    value: Number(user.id),
    searchText: [user.realName, user.username, user.id].filter(Boolean).join(' ').toLowerCase()
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
      kind: 'flow' as const,
      payload: flow,
      flowId: Number(flow.flowId || 0),
      meta: flowMeta(flow),
      children: nodes.map(node => {
        const nodeId = Number(node.nodeId);
        const approvers = groupApprovers(detail.approversByNode[nodeId] || []);
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

// --- Helpers ---
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
  const options = { requireApplicantForSubmit: Number(row.requireApplicantForSubmit) === 1 };
  return options.requireApplicantForSubmit ? JSON.stringify({ text: plainText, options }) : plainText;
}

function getFlowOption(flow: any, key: string) {
  return Boolean(parseFlowRemark(flow?.remark).options[key]);
}

function userLabelById(userId: unknown) {
  const user = optionById(referenceData.value.users || [], userId);
  if (!user) return '';
  return user.realName || user.username || '';
}

function normalizeUserIds(value: unknown): number[] {
  const values = Array.isArray(value) ? value : value == null || value === '' ? [] : [value];
  return Array.from(new Set(values.map(item => numberValue(item)).filter((item): item is number => item !== null)));
}

function approverGroupKey(approver: any) {
  if (approver?.targetType !== 'USER') {
    return `single:${approver?.id || approver?._tempKey || approver?.targetRoleId || ''}`;
  }
  return [
    approver.nodeId ?? '', approver.applyDeptId ?? '', approver.conditionMode || 'ALWAYS',
    text(approver.sqlExpr), approver.onError || 'REQUIRE_APPROVAL', approver.sortOrder ?? '', approver.isEnabled ?? 1
  ].join('|');
}

function groupApprovers(approvers: any[]) {
  const grouped: any[] = [];
  const indexMap = new Map<string, number>();
  for (const approver of approvers) {
    if (approver?.targetType !== 'USER') {
      grouped.push({ ...approver, _members: [approver], targetUserIds: approver.targetUserId ? [Number(approver.targetUserId)] : [] });
      continue;
    }
    const key = approverGroupKey(approver);
    const existingIndex = indexMap.get(key);
    if (existingIndex == null) {
      grouped.push({ ...approver, _members: [approver], targetUserIds: approver.targetUserId ? [Number(approver.targetUserId)] : [] });
      indexMap.set(key, grouped.length - 1);
      continue;
    }
    const current = grouped[existingIndex];
    current._members.push(approver);
    if (approver.targetUserId != null) {
      current.targetUserIds = Array.from(new Set([...(current.targetUserIds || []), Number(approver.targetUserId)]));
    }
  }
  for (const approver of grouped) {
    approver.targetUserNames = normalizeUserIds(approver.targetUserIds).map(id => userLabelById(id)).filter(Boolean);
  }
  return grouped;
}

function approverLabel(approver: any) {
  if (approver.targetType === 'ROLE') {
    return approver.targetRoleName || approver.targetRoleCode || `角色 ${approver.targetRoleId || '-'}`;
  }
  const names = Array.isArray(approver.targetUserNames) ? approver.targetUserNames.filter(Boolean) : [];
  if (names.length) return names.join('、');
  return approver.targetUserName || `用户 ${approver.targetUserId || '-'}`;
}

function filterUserOption(pattern: string, option: SelectOption | undefined) {
  const keyword = text(pattern).toLowerCase();
  if (!keyword) return true;
  const searchText = typeof option?.searchText === 'string' ? option.searchText : '';
  const label = typeof option?.label === 'string' ? option.label : '';
  return (searchText || label).toLowerCase().includes(keyword);
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

function approverEditorDraft(approver: any) {
  const row = clone(approver || {});
  row.targetUserIds = normalizeUserIds(row.targetUserIds ?? row.targetUserId);
  row.targetUserNames = row.targetUserIds.map((id: number) => userLabelById(id)).filter(Boolean);
  row._members = Array.isArray(approver?._members) ? clone(approver._members) : approver ? [clone(approver)] : [];
  return row;
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

function parseNodeActionConfig(raw?: string) {
  const defaultValue = {
    approveProcedure: '', approveMode: 'AUTO', approveParams: [] as any[],
    rejectProcedure: '', rejectMode: 'AUTO', rejectParams: [] as any[]
  };
  if (!text(raw)) return defaultValue;
  try {
    const parsed = JSON.parse(raw || '{}');
    return {
      approveProcedure: text(parsed?.approve?.procedure),
      approveMode: parsed?.approve?.mode === 'MANUAL' ? 'MANUAL' : 'AUTO',
      approveParams: normalizeActionParams(parsed?.approve?.params),
      rejectProcedure: text(parsed?.reject?.procedure),
      rejectMode: parsed?.reject?.mode === 'MANUAL' ? 'MANUAL' : 'AUTO',
      rejectParams: normalizeActionParams(parsed?.reject?.params)
    };
  } catch {
    return defaultValue;
  }
}

function normalizeActionParams(params: any) {
  if (!Array.isArray(params)) return [];
  return params.map(item => ({
    name: text(item?.name), label: text(item?.label),
    type: ['NUMBER', 'TEXTAREA'].includes(item?.type) ? item.type : 'STRING',
    required: Boolean(item?.required),
    defaultValue: item?.defaultValue == null ? '' : String(item.defaultValue)
  })).filter(item => item.name);
}

function nodeEditorDraft(node: any) {
  const row = clone(node || {});
  Object.assign(row, parseNodeActionConfig(row.actionConfig));
  return row;
}

function buildNodeActionConfig(row: any) {
  const config: Record<string, any> = {};
  if (text(row.approveProcedure)) {
    config.approve = { procedure: text(row.approveProcedure), mode: row.approveMode === 'MANUAL' ? 'MANUAL' : 'AUTO', params: normalizeActionParams(row.approveParams) };
  }
  if (text(row.rejectProcedure)) {
    config.reject = { procedure: text(row.rejectProcedure), mode: row.rejectMode === 'MANUAL' ? 'MANUAL' : 'AUTO', params: normalizeActionParams(row.rejectParams) };
  }
  return Object.keys(config).length ? JSON.stringify(config) : '';
}

function createActionParam() {
  return { name: '', label: '', type: 'STRING', required: false, defaultValue: '' };
}

// --- Editor state ---
function setEditor(kind: SelectedKind, payload?: any, key?: string | number | null) {
  selectedKind.value = kind;
  selectedPayload.value = payload || null;
  selectedKey.value = key ? String(key) : null;
  draft.value =
    kind === 'flow' ? flowEditorDraft(payload || {})
      : kind === 'node' ? nodeEditorDraft(payload || {})
        : kind === 'approver' ? approverEditorDraft(payload || {})
          : clone(payload || {});
}

// --- Data loading ---
async function loadReferenceData() {
  referenceData.value = await fetchApprovalReferenceData();
}

async function loadFlows() {
  loading.value = true;
  try {
    flows.value = await fetchApprovalFlows();
    await loadPageFlowDetails();
  } finally {
    loading.value = false;
  }
}

async function loadPageFlowDetails() {
  const targetFlows = flows.value.filter(flow => flow.pageCode === props.pageCode && flow.flowId);
  const nextDetails: Record<number, FlowDetail> = { ...flowDetails.value };
  await Promise.all(
    targetFlows.map(async flow => {
      const flowId = Number(flow.flowId);
      const [conditions, nodes] = await Promise.all([fetchApprovalConditions(flowId), fetchApprovalNodes(flowId)]);
      const entries = await Promise.all(
        nodes.filter(node => node.nodeId).map(async node => [Number(node.nodeId), await fetchApprovalApprovers(Number(node.nodeId))] as const)
      );
      nextDetails[flowId] = { conditions, nodes, approversByNode: Object.fromEntries(entries) };
    })
  );
  flowDetails.value = nextDetails;
  await nextTick();
  expandedKeys.value = collectDefaultExpandedKeys();
}

// --- Tree helpers ---
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
      ? h(NTag, { size: 'small', type: tagType as any, bordered: false, class: 'tree-tag' }, { default: () => item.meta })
      : null
  ]);
}

// --- CRUD ---
function addFlow() {
  const row = {
    _isNew: true, _tempKey: tempKey('flow'), flowId: null,
    pageCode: props.pageCode, pageName: '', flowName: '新审批项目',
    flowVersion: 1, flowPriority: 100, isEnabled: 1, remark: '',
    remarkText: '', requireApplicantForSubmit: 0
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
    _isNew: true, _tempKey: tempKey('node'), nodeId: null,
    flowId: selectedFlow.value.flowId, approvalLevel: maxLevel + 1,
    nodeName: `${maxLevel + 1}级审批`, approvalMode: 'OR',
    conditionMode: 'ALWAYS', sqlExpr: '', logicTree: '',
    onError: 'REQUIRE_APPROVAL', actionConfig: '',
    approveProcedure: '', approveMode: 'AUTO', approveParams: [],
    rejectProcedure: '', rejectMode: 'AUTO', rejectParams: [], isEnabled: 1
  };
  flowDetails.value = {
    ...flowDetails.value,
    [selectedFlow.value.flowId]: { ...detail, nodes: [...detail.nodes, row] }
  };
  setEditor('node', row, `node:${row._tempKey}`);
}

function addApprover() {
  const currentNode =
    selectedKind.value === 'node' ? selectedPayload.value
      : selectedKind.value === 'approver'
        ? getFlowDetail(selectedFlow.value?.flowId).nodes.find(node => Number(node.nodeId) === Number(selectedPayload.value?.nodeId))
        : null;
  if (!currentNode?.nodeId) {
    message.warning('请先保存并选中一个审批节点');
    return;
  }
  const detail = getFlowDetail(selectedFlow.value.flowId);
  const row = {
    _isNew: true, _tempKey: tempKey('approver'), id: null, nodeId: currentNode.nodeId,
    applyDeptId: null, applyDeptName: '', targetType: 'USER',
    targetUserId: null, targetUserName: '', targetUserIds: [], targetUserNames: [],
    targetRoleId: null, targetRoleCode: '', targetRoleName: '',
    conditionMode: 'ALWAYS', sqlExpr: '', logicTree: '', onError: 'REQUIRE_APPROVAL',
    sortOrder: (detail.approversByNode[currentNode.nodeId] || []).length + 1, isEnabled: 1
  };
  flowDetails.value = {
    ...flowDetails.value,
    [selectedFlow.value.flowId]: {
      ...detail,
      approversByNode: { ...detail.approversByNode, [currentNode.nodeId]: [...(detail.approversByNode[currentNode.nodeId] || []), row] }
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
      logicTree: '', sqlExpr: flowPayload.sqlExpr || '',
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
    if (next) {
      selectedFlow.value = next;
      setEditor('flow', next, `flow:${next.flowId}`);
    }
    return;
  }

  if (selectedKind.value === 'node') {
    if (!text(draft.value.nodeName)) {
      message.warning('节点名称不能为空');
      return;
    }
    const payload = prepareSavePayload();
    payload.actionConfig = buildNodeActionConfig(payload);
    delete payload.approveProcedure;
    delete payload.approveMode;
    delete payload.approveParams;
    delete payload.rejectProcedure;
    delete payload.rejectMode;
    delete payload.rejectParams;
    const saved = await saveApprovalNode(payload);
    message.success('审批节点已保存');
    await loadPageFlowDetails();
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
    const memberRows = Array.isArray(selectedPayload.value?._members) ? selectedPayload.value._members : selectedPayload.value ? [selectedPayload.value] : [];
    let saved: any = null;

    if (draft.value.targetType !== 'ROLE') {
      const userIds = normalizeUserIds(draft.value.targetUserIds);
      if (!userIds.length) {
        message.warning('用户审批分支必须选择用户');
        return;
      }
      const existingByUserId = new Map(
        memberRows.map((item: any) => [numberValue(item.targetUserId), item] as const)
          .filter((entry: readonly [number | null, any]) => entry[0] !== null) as Array<[number, any]>
      );
      const retainedIds = new Set<number>();
      for (const userId of userIds) {
        const payload = prepareSavePayload();
        const user = optionById(referenceData.value.users || [], userId);
        payload.targetType = 'USER';
        payload.targetUserId = userId;
        payload.targetUserName = user ? user.realName || user.username : '';
        payload.targetRoleId = null;
        payload.targetRoleCode = '';
        payload.targetRoleName = '';
        const existing = existingByUserId.get(userId);
        payload.id = existing?.id || null;
        const currentSaved = await saveApprovalApprover(payload);
        if (currentSaved?.id) retainedIds.add(Number(currentSaved.id));
        if (!saved) saved = currentSaved;
      }
      for (const item of memberRows) {
        if (item?.id && !retainedIds.has(Number(item.id))) {
          await deleteApprovalApprover(Number(item.id));
        }
      }
    } else {
      const payload = prepareSavePayload();
      payload.targetUserId = null;
      payload.targetUserName = '';
      payload.id = memberRows[0]?.id || payload.id || null;
      saved = await saveApprovalApprover(payload);
      for (const item of memberRows.slice(1)) {
        if (item?.id) await deleteApprovalApprover(Number(item.id));
      }
    }
    message.success('分支条件已保存');
    await loadPageFlowDetails();
    const node = getFlowDetail(selectedFlow.value?.flowId).nodes.find(item => Number(item.nodeId) === Number(draft.value.nodeId));
    setEditor(node ? 'node' : 'flow', node || selectedFlow.value, node ? `node:${node.nodeId}` : `flow:${selectedFlow.value?.flowId}`);
  }
}

async function deleteCurrent() {
  if (selectedKind.value === 'flow') {
    if (!selectedFlow.value) return;
    if (!selectedFlow.value.flowId) {
      flows.value = flows.value.filter(flow => flow !== selectedFlow.value);
      selectedFlow.value = null;
      setEditor('', null, null);
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
    setEditor('', null, null);
    return;
  }

  if (selectedKind.value === 'node') {
    if (draft.value.nodeId) await deleteApprovalNode(draft.value.nodeId);
    message.success('审批节点已删除');
    await loadPageFlowDetails();
    setEditor('flow', selectedFlow.value, `flow:${selectedFlow.value?.flowId}`);
    return;
  }

  if (selectedKind.value === 'approver') {
    const memberRows = Array.isArray(selectedPayload.value?._members) ? selectedPayload.value._members : draft.value.id ? [{ id: draft.value.id }] : [];
    if (memberRows.length) {
      for (const item of memberRows) {
        if (item?.id) await deleteApprovalApprover(Number(item.id));
      }
    } else if (draft.value._tempKey && selectedFlow.value?.flowId) {
      const detail = getFlowDetail(selectedFlow.value.flowId);
      flowDetails.value = {
        ...flowDetails.value,
        [selectedFlow.value.flowId]: {
          ...detail,
          approversByNode: {
            ...detail.approversByNode,
            [draft.value.nodeId]: (detail.approversByNode[draft.value.nodeId] || []).filter(item => item._tempKey !== draft.value._tempKey)
          }
        }
      };
    }
    message.success('分支条件已删除');
    await loadPageFlowDetails();
    const node = getFlowDetail(selectedFlow.value?.flowId).nodes.find(item => Number(item.nodeId) === Number(draft.value.nodeId));
    setEditor(node ? 'node' : 'flow', node || selectedFlow.value, node ? `node:${node.nodeId}` : `flow:${selectedFlow.value?.flowId}`);
  }
}

async function deleteAllFlows() {
  await deleteApprovalPage(props.pageCode);
  message.success('当前页面下的审批配置已全部删除');
  flows.value = flows.value.filter(flow => flow.pageCode !== props.pageCode);
  flowDetails.value = {};
  selectedFlow.value = null;
  setEditor('', null, null);
}

function updateEnabled(value: boolean) {
  draft.value.isEnabled = value ? 1 : 0;
}

function updateConditionEnabled(value: boolean) {
  draft.value.conditionEnabled = value ? 1 : 0;
}

onMounted(async () => {
  await loadReferenceData();
  await loadFlows();
});
</script>

<template>
  <div class="section-approval-inline">
    <!-- 工具栏 -->
    <div class="toolbar">
      <NSpace size="small">
        <NButton size="small" type="primary" @click="addFlow">新增审批项目</NButton>
        <NButton size="small" :disabled="!selectedFlow?.flowId" @click="addNode">新增审批节点</NButton>
        <NButton size="small" :disabled="selectedKind !== 'node' && selectedKind !== 'approver'" @click="addApprover">新增分支条件</NButton>
      </NSpace>
      <NPopconfirm @positive-click="deleteAllFlows">
        <template #trigger>
          <NButton size="small" type="error" quaternary :disabled="!pageFlows.length">清空全部</NButton>
        </template>
        删除该页面下所有审批配置？此操作不可撤销。
      </NPopconfirm>
    </div>

    <!-- 主体：左树 + 右编辑 -->
    <div class="main-body">
      <!-- 左侧树 -->
      <div class="tree-side">
        <NAlert type="info" :bordered="false" class="help-tip">
          入口条件不满足：无需审批。节点条件不满足：管理员驳回。分支无命中：该级自动通过。
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
        <NEmpty v-else-if="!loading" description="暂无审批流配置，点击「新增审批项目」开始" />
      </div>

      <!-- 右侧编辑区 -->
      <div class="editor-side">
        <NEmpty v-if="!selectedKind" description="点击左侧树节点进行编辑" />

        <template v-else>
          <div class="editor-header">
            <span class="editor-title">
              {{ selectedKind === 'flow' ? '审批项目' : selectedKind === 'node' ? '审批节点' : '分支条件' }}
            </span>
            <NSpace size="small">
              <NButton size="small" type="primary" @click="saveCurrent">保存</NButton>
              <NPopconfirm @positive-click="deleteCurrent">
                <template #trigger>
                  <NButton size="small" type="error">删除</NButton>
                </template>
                确定删除当前配置及其下级数据？
              </NPopconfirm>
            </NSpace>
          </div>

          <NForm label-placement="top" size="small" class="editor-form">
            <!-- 审批项目 -->
            <template v-if="selectedKind === 'flow'">
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
                <NInput v-model:value="draft.sqlExpr" type="textarea" placeholder="例如：M.URGENCY_LEVEL = '紧急'" :autosize="{ minRows: 3, maxRows: 8 }" />
              </NFormItem>
              <NFormItem label="入口异常策略">
                <NSelect v-model:value="draft.onError" :options="onErrorOptions" />
              </NFormItem>
              <div class="form-grid">
                <NFormItem label="启用">
                  <NSwitch :value="Number(draft.isEnabled) === 1" @update:value="updateEnabled" />
                </NFormItem>
                <NFormItem label="入口条件启用">
                  <NSwitch :value="Number(draft.conditionEnabled) === 1" @update:value="updateConditionEnabled" />
                </NFormItem>
              </div>
              <NFormItem label="申请人限制">
                <NSwitch :value="Number(draft.requireApplicantForSubmit) === 1" @update:value="(v: boolean) => (draft.requireApplicantForSubmit = v ? 1 : 0)" />
              </NFormItem>
              <NFormItem label="备注">
                <NInput v-model:value="draft.remarkText" type="textarea" :autosize="{ minRows: 2, maxRows: 5 }" />
              </NFormItem>
            </template>

            <!-- 审批节点 -->
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
                <NInput v-model:value="draft.sqlExpr" type="textarea" placeholder="节点条件不满足时：系统管理员自动驳回" :autosize="{ minRows: 3, maxRows: 8 }" />
              </NFormItem>
              <NFormItem label="节点异常策略">
                <NSelect v-model:value="draft.onError" :options="onErrorOptions" />
              </NFormItem>
              <NFormItem label="通过后存储过程">
                <NInput v-model:value="draft.approveProcedure" placeholder="例如：P_DEMAND_APPROVAL_SET_RECEIVER" />
              </NFormItem>
              <NFormItem label="通过后执行模式">
                <NSelect v-model:value="draft.approveMode" :options="actionModeOptions" />
              </NFormItem>
              <NFormItem v-if="draft.approveMode === 'MANUAL'" label="通过后手动参数">
                <NDynamicInput v-model:value="draft.approveParams" :on-create="createActionParam">
                  <template #default="{ value }">
                    <div class="action-param-row">
                      <NInput v-model:value="value.name" placeholder="参数名" />
                      <NInput v-model:value="value.label" placeholder="显示名" />
                      <NSelect v-model:value="value.type" :options="actionParamTypeOptions" />
                      <NInput v-model:value="value.defaultValue" placeholder="默认值" />
                      <NCheckbox v-model:checked="value.required">必填</NCheckbox>
                    </div>
                  </template>
                </NDynamicInput>
              </NFormItem>
              <NFormItem label="拒绝后存储过程">
                <NInput v-model:value="draft.rejectProcedure" placeholder="例如：P_DEMAND_APPROVAL_SET_RECEIVER" />
              </NFormItem>
              <NFormItem label="拒绝后执行模式">
                <NSelect v-model:value="draft.rejectMode" :options="actionModeOptions" />
              </NFormItem>
              <NFormItem v-if="draft.rejectMode === 'MANUAL'" label="拒绝后手动参数">
                <NDynamicInput v-model:value="draft.rejectParams" :on-create="createActionParam">
                  <template #default="{ value }">
                    <div class="action-param-row">
                      <NInput v-model:value="value.name" placeholder="参数名" />
                      <NInput v-model:value="value.label" placeholder="显示名" />
                      <NSelect v-model:value="value.type" :options="actionParamTypeOptions" />
                      <NInput v-model:value="value.defaultValue" placeholder="默认值" />
                      <NCheckbox v-model:checked="value.required">必填</NCheckbox>
                    </div>
                  </template>
                </NDynamicInput>
              </NFormItem>
              <NFormItem label="启用">
                <NSwitch :value="Number(draft.isEnabled) === 1" @update:value="updateEnabled" />
              </NFormItem>
            </template>

            <!-- 分支条件 -->
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
                <NSelect v-model:value="draft.targetUserIds" multiple filterable :options="userOptions" :filter="filterUserOption" />
              </NFormItem>
              <NAlert v-if="draft.targetType !== 'ROLE'" type="info" :bordered="false" style="margin-bottom: 12px;">
                同一分支可同时选择多位审批人，保存后会按同条件拆成多条审批记录。
              </NAlert>
              <NFormItem label="分支条件类型">
                <NSelect v-model:value="draft.conditionMode" :options="conditionModeOptions" />
              </NFormItem>
              <NFormItem label="分支 SQL 条件">
                <NInput v-model:value="draft.sqlExpr" type="textarea" placeholder="条件命中时，该分支认领本级审批" :autosize="{ minRows: 3, maxRows: 8 }" />
              </NFormItem>
              <NFormItem label="启用">
                <NSwitch :value="Number(draft.isEnabled) === 1" @update:value="updateEnabled" />
              </NFormItem>
            </template>
          </NForm>
        </template>
      </div>
    </div>
  </div>
</template>

<style scoped>
.section-approval-inline {
  padding: 8px 0;
}

.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
  padding-bottom: 10px;
  border-bottom: 1px solid #f0f0f0;
}

.main-body {
  display: grid;
  grid-template-columns: minmax(320px, 1fr) 340px;
  gap: 12px;
  min-height: 360px;
}

.tree-side {
  border: 1px solid #e8e8e8;
  border-radius: 6px;
  padding: 10px;
  overflow-y: auto;
  max-height: 560px;
}

.help-tip {
  margin-bottom: 8px;
  font-size: 12px;
  line-height: 1.6;
}

.tree-side :deep(.n-tree-node-content) {
  min-height: 32px;
}

.tree-line {
  display: flex;
  align-items: center;
  gap: 6px;
  min-width: 0;
}

.tree-label {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: #1f2633;
}

.tree-line-flow .tree-label {
  font-weight: 600;
}

.tree-tag {
  flex-shrink: 0;
}

.editor-side {
  border: 1px solid #e8e8e8;
  border-radius: 6px;
  padding: 12px;
  overflow-y: auto;
  max-height: 560px;
}

.editor-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
  padding-bottom: 8px;
  border-bottom: 1px solid #f0f0f0;
}

.editor-title {
  font-weight: 600;
  font-size: 14px;
  color: #1f2633;
}

.editor-form {
  max-width: 100%;
}

.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}

.action-param-row {
  display: grid;
  grid-template-columns: 1fr 1fr 80px 1fr 50px;
  gap: 6px;
  align-items: center;
  width: 100%;
}

@media (max-width: 900px) {
  .main-body {
    grid-template-columns: 1fr;
  }
  .tree-side,
  .editor-side {
    max-height: 400px;
  }
}
</style>
