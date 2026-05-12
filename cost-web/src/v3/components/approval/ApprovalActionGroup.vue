<script setup lang="ts">
import { computed, h, ref, unref } from 'vue';
import {
  NButton,
  NDataTable,
  NDropdown,
  NInput,
  NModal,
  NSelect,
  NSpace,
  NTabPane,
  NTabs,
  NTag,
  useMessage
} from 'naive-ui';
import type { DataTableColumns } from 'naive-ui';
import {
  applyApproval,
  approveApproval,
  cancelApproval,
  delegateApproval,
  fetchApprovalProgress,
  rejectApproval,
  type ApprovalRuntimePayload
} from '@/service/api/approval-runtime';
import { fetchAllUsers, type UserSimpleVO } from '@/service/api/role-manage';

const props = defineProps<{
  runtime: any;
  getSelectedRow: () => any | null;
}>();

type ApprovalDetailRow = {
  detailId?: number | string;
  roundNo?: number | string;
  nodeId?: number | string;
  approvalLevel?: number | string;
  nodeName?: string;
  approvalMode?: string;
  targetType?: string;
  targetUserId?: number | string;
  targetUserName?: string;
  targetRoleId?: number | string;
  targetRoleName?: string;
  status?: string;
  operateUserId?: number | string;
  operateUsername?: string;
  operateRealName?: string;
  approveComment?: string;
  approveTime?: string;
  operateTime?: string;
  isForced?: number | string;
};

const message = useMessage();

const loading = ref(false);
const rejectVisible = ref(false);
const cancelVisible = ref(false);
const delegateVisible = ref(false);
const progressVisible = ref(false);
const rejectReason = ref('');
const cancelReason = ref('');
const delegateReason = ref('');
const delegateUserId = ref<number | null>(null);
const delegateUsers = ref<UserSimpleVO[]>([]);
const loadingUsers = ref(false);
const progressData = ref<any>({ main: {}, details: [], logs: [] });

const dropdownOptions = computed(() =>
  [
    { label: '送审', key: 'apply', permission: 'approval.apply' },
    { label: '审批通过', key: 'approve', permission: 'approval.approve' },
    { label: '驳回', key: 'reject', permission: 'approval.reject' },
    { label: '撤销送审', key: 'cancel', permission: 'approval.cancel' },
    { label: '强制委派审批人', key: 'delegate', permission: 'approval.delegate' },
    { label: '查看审批进度', key: 'progress', permission: 'approval.progress' }
  ].filter(item => hasButton(item.permission))
);

const visible = computed(() => dropdownOptions.value.length > 0);

const detailColumns: DataTableColumns<any> = [
  { title: '级别', key: 'approvalLevel', width: 70 },
  { title: '节点', key: 'nodeName', minWidth: 140 },
  { title: '预计审批人', key: 'expectedApprovers', minWidth: 220, ellipsis: { tooltip: true } },
  { title: '实际审批人', key: 'actualApprovers', minWidth: 180, ellipsis: { tooltip: true } },
  {
    title: '状态',
    key: 'status',
    width: 110,
    render: row => renderStatus(row.status)
  }
];

const logColumns: DataTableColumns<any> = [
  { title: '动作', key: 'actionType', width: 120 },
  { title: '操作人', key: 'actionRealName', width: 120, render: row => row.actionRealName || row.actionUsername || '-' },
  { title: '状态', key: 'toStatus', width: 120, render: row => statusText(row.toStatus || row.fromStatus) },
  { title: '意见', key: 'actionComment', minWidth: 180, ellipsis: { tooltip: true } },
  { title: '说明', key: 'detailMessage', minWidth: 220, ellipsis: { tooltip: true } }
];

const mainStatus = computed(() => progressData.value?.main?.status || '');
const mainStatusText = computed(() => statusText(mainStatus.value) || '暂无审批记录');
const groupedDetails = computed(() => buildGroupedDetails(progressData.value?.details || [], progressData.value?.main));

const delegateUserOptions = computed(() =>
  delegateUsers.value.map(user => ({
    label: user.realName ? `${user.realName} (${user.username})` : user.username,
    value: user.id
  }))
);

function renderStatus(status: string) {
  const type =
    status === 'APPROVED' || status === 'AUTO_APPROVED'
      ? 'success'
      : status === 'REJECTED'
        ? 'error'
        : status === 'PENDING' || status === 'APPROVING'
          ? 'warning'
          : 'default';
  return hTag(statusText(status) || '-', type);
}

function statusText(status?: string) {
  const statusMap: Record<string, string> = {
    DRAFT: '草稿',
    APPROVING: '审批中',
    PENDING: '待审批',
    APPROVED: '已通过',
    REJECTED: '已驳回',
    CANCELED: '已撤销',
    WAITING: '等待中',
    SKIPPED: '已跳过',
    AUTO_APPROVED: '自动通过'
  };
  return status ? statusMap[status] || status : '-';
}

function hasButton(buttonKey: string) {
  return props.runtime?.permissions?.hasButton?.(buttonKey) === true;
}

function hTag(label: string, type: any) {
  return h(NTag, { size: 'small', type, bordered: false }, { default: () => label });
}

function detailDisplayName(row: ApprovalDetailRow) {
  if (row.targetType === 'ROLE') {
    return row.targetRoleName || '-';
  }
  return row.targetUserName || '-';
}

function uniqueJoin(values: Array<string | null | undefined>) {
  const items = Array.from(
    new Set(
      values
        .map(value => (value || '').trim())
        .filter(Boolean)
    )
  );
  return items.length ? items.join('、') : '-';
}

function normalizeForced(value: number | string | undefined) {
  return Number(value || 0) === 1;
}

function resolveGroupNodeName(rows: ApprovalDetailRow[]) {
  const normalName = rows.find(row => !normalizeForced(row.isForced) && row.nodeName)?.nodeName;
  return normalName || rows.find(row => row.nodeName)?.nodeName || '-';
}

function summarizeGroupStatus(rows: ApprovalDetailRow[]) {
  const statuses = rows.map(row => row.status).filter(Boolean) as string[];
  if (statuses.includes('REJECTED')) return 'REJECTED';
  if (statuses.includes('PENDING')) return 'PENDING';
  if (statuses.includes('APPROVING')) return 'APPROVING';
  if (statuses.includes('APPROVED')) return 'APPROVED';
  if (statuses.includes('AUTO_APPROVED')) return 'AUTO_APPROVED';
  if (statuses.includes('CANCELED')) return 'CANCELED';
  if (statuses.includes('SKIPPED')) return 'SKIPPED';
  return rows[0]?.status || '';
}

function buildGroupedDetails(details: ApprovalDetailRow[], main?: any) {
  const rows = Array.isArray(details) ? details : [];
  const latestRound =
    Number(main?.currentRound || 0) ||
    rows.reduce((max, row) => Math.max(max, Number(row.roundNo || 0)), 0);
  const roundRows = latestRound > 0 ? rows.filter(row => Number(row.roundNo || 0) === latestRound) : rows;
  const levelNodeNameMap = new Map<number, string>();

  for (const row of roundRows) {
    const level = Number(row.approvalLevel || 0);
    if (!levelNodeNameMap.has(level) && !normalizeForced(row.isForced) && row.nodeName) {
      levelNodeNameMap.set(level, row.nodeName);
    }
  }

  const groups = new Map<string, ApprovalDetailRow[]>();
  for (const row of roundRows) {
    const level = Number(row.approvalLevel || 0);
    const nodeName = normalizeForced(row.isForced) ? levelNodeNameMap.get(level) || row.nodeName || '-' : row.nodeName || '-';
    const key = `${level}|${nodeName}`;
    if (!groups.has(key)) {
      groups.set(key, []);
    }
    groups.get(key)!.push(row);
  }

  return Array.from(groups.values()).map(groupRows => {
    const actualRows = groupRows.filter(row => ['APPROVED', 'REJECTED'].includes(row.status || ''));

    return {
      approvalLevel: groupRows[0]?.approvalLevel,
      nodeName: resolveGroupNodeName(groupRows),
      expectedApprovers: uniqueJoin(
        groupRows.map(row =>
          normalizeForced(row.isForced) ? null : detailDisplayName(row)
        )
      ),
      actualApprovers: uniqueJoin(
        actualRows.map(row => {
          const name = row.operateRealName || row.operateUsername || '-';
          return normalizeForced(row.isForced) ? `${name}（强制委派）` : name;
        })
      ),
      status: summarizeGroupStatus(groupRows)
    };
  });
}

async function handleSelect(key: string) {
  if (key === 'reject') {
    if (!hasButton('approval.reject')) return;
    if (!buildPayload()) return;
    rejectReason.value = '';
    rejectVisible.value = true;
    return;
  }

  if (key === 'progress') {
    if (!hasButton('approval.progress')) return;
    await openProgress();
    return;
  }

  if (key === 'cancel') {
    if (!hasButton('approval.cancel')) return;
    if (!buildPayload()) return;
    cancelReason.value = '';
    cancelVisible.value = true;
    return;
  }

  if (key === 'delegate') {
    if (!hasButton('approval.delegate')) return;
    await openDelegate();
    return;
  }

  if (key === 'apply') {
    if (!hasButton('approval.apply')) return;
    await runAction(() => applyApproval(requiredPayload()), '送审完成');
    return;
  }

  if (key === 'approve') {
    if (!hasButton('approval.approve')) return;
    await runAction(() => approveApproval(requiredPayload()), '审批通过');
  }
}

async function submitReject() {
  if (!rejectReason.value.trim()) {
    message.warning('请填写驳回原因');
    return;
  }
  await runAction(
    () =>
      rejectApproval({
        ...requiredPayload(),
        comment: rejectReason.value.trim()
      }),
    '已驳回'
  );
  rejectVisible.value = false;
}

async function submitCancel() {
  await runAction(
    () =>
      cancelApproval({
        ...requiredPayload(),
        comment: cancelReason.value.trim()
      }),
    '已撤销送审'
  );
  cancelVisible.value = false;
}

async function openDelegate() {
  if (!buildPayload()) return;
  delegateUserId.value = null;
  delegateReason.value = '';
  delegateVisible.value = true;
  if (delegateUsers.value.length > 0) return;
  loadingUsers.value = true;
  try {
    delegateUsers.value = await fetchAllUsers();
  } finally {
    loadingUsers.value = false;
  }
}

async function submitDelegate() {
  if (!delegateUserId.value) {
    message.warning('请选择审批人');
    return;
  }
  await runAction(
    () =>
      delegateApproval({
        ...requiredPayload(),
        targetUserId: delegateUserId.value,
        reason: delegateReason.value.trim()
      }),
    '已强制委派审批人'
  );
  delegateVisible.value = false;
}

async function openProgress() {
  const payload = buildPayload();
  if (!payload) return;

  loading.value = true;
  try {
    const { data, error } = await fetchApprovalProgress({
      pageCode: payload.pageCode,
      tableCode: payload.tableCode,
      billId: payload.billId
    });
    if (error) {
      message.error(error.message || '查询审批进度失败');
      return;
    }
    progressData.value = data || { main: {}, details: [], logs: [] };
    progressVisible.value = true;
  } finally {
    loading.value = false;
  }
}

async function runAction(action: () => Promise<any>, fallbackMessage: string) {
  loading.value = true;
  try {
    const { data, error } = await action();
    if (error) {
      message.error(error.message || `${fallbackMessage}失败`);
      return;
    }
    message.success(data?.message || fallbackMessage);
    refreshGrid();
  } finally {
    loading.value = false;
  }
}

function requiredPayload() {
  const payload = buildPayload();
  if (!payload) {
    throw new Error('请选择一条单据');
  }
  return payload;
}

function buildPayload(): ApprovalRuntimePayload | null {
  const row = props.getSelectedRow?.();
  if (!row) {
    message.warning('请先选择一条单据');
    return null;
  }

  const pageCode = props.runtime?.pageCode || '';
  const pageConfig = unref(props.runtime?.meta?.pageConfig);
  const tableCode = pageConfig?.masterTableCode || '';
  const billId = row.id ?? row.ID;

  if (!pageCode || !tableCode || billId == null) {
    message.warning('当前页面缺少审批所需参数');
    return null;
  }

  return {
    pageCode,
    pageName: pageCode,
    tableCode,
    billId,
    billNo: firstText(row.billNo, row.BILL_NO, row.batchNo, row.BATCH_NO, row.code, row.CODE),
    billTitle: firstText(
      row.billTitle,
      row.BILL_TITLE,
      row.projectOrCustomerCode,
      row.PROJECT_OR_CUSTOMER_CODE,
      row.inspectionName,
      row.INSPECTION_NAME,
      `${pageCode}#${billId}`
    ),
    conditionJson: ''
  };
}

function firstText(...values: any[]) {
  for (const value of values) {
    if (value !== null && value !== undefined && String(value).trim()) {
      return String(value);
    }
  }
  return '';
}

function refreshGrid() {
  const api = props.runtime?.masterGridApi?.value;
  api?.refreshServerSide?.({ purge: false });
}
</script>

<template>
  <NDropdown v-if="visible" trigger="click" :options="dropdownOptions" @select="handleSelect">
    <NButton type="primary" size="small" :loading="loading">送审</NButton>
  </NDropdown>

  <NModal
    v-model:show="rejectVisible"
    preset="dialog"
    title="驳回审批"
    positive-text="确认驳回"
    negative-text="取消"
    :mask-closable="false"
    @positive-click="submitReject"
  >
    <NInput v-model:value="rejectReason" type="textarea" placeholder="请输入驳回原因" :autosize="{ minRows: 4, maxRows: 8 }" />
  </NModal>

  <NModal
    v-model:show="cancelVisible"
    preset="dialog"
    title="撤销送审"
    positive-text="确认撤销"
    negative-text="取消"
    :mask-closable="false"
    @positive-click="submitCancel"
  >
    <NInput
      v-model:value="cancelReason"
      type="textarea"
      placeholder="请输入撤销原因，可选"
      :autosize="{ minRows: 4, maxRows: 8 }"
    />
  </NModal>

  <NModal
    v-model:show="delegateVisible"
    preset="dialog"
    title="强制委派审批人"
    positive-text="确认委派"
    negative-text="取消"
    :mask-closable="false"
    @positive-click="submitDelegate"
  >
    <NSpace vertical size="small">
      <NSelect
        v-model:value="delegateUserId"
        :options="delegateUserOptions"
        :loading="loadingUsers"
        filterable
        clearable
        placeholder="请选择审批人"
      />
      <NInput
        v-model:value="delegateReason"
        type="textarea"
        placeholder="委派原因，可选"
        :autosize="{ minRows: 3, maxRows: 6 }"
      />
    </NSpace>
  </NModal>

  <NModal v-model:show="progressVisible" preset="card" title="审批进度" class="approval-progress-modal">
    <NSpace vertical size="small">
      <div class="approval-main">
        <span>审批状态：</span>
        <NTag size="small" :type="mainStatus === 'APPROVED' ? 'success' : mainStatus === 'REJECTED' ? 'error' : 'info'">
          {{ mainStatusText }}
        </NTag>
        <span v-if="progressData.main?.approvalId">审批ID：{{ progressData.main.approvalId }}</span>
      </div>
      <NTabs type="line" animated>
        <NTabPane name="details" tab="审批节点">
          <NDataTable size="small" :columns="detailColumns" :data="groupedDetails" :pagination="false" />
        </NTabPane>
        <NTabPane name="logs" tab="审批记录">
          <NDataTable size="small" :columns="logColumns" :data="progressData.logs || []" :pagination="false" />
        </NTabPane>
      </NTabs>
    </NSpace>
  </NModal>
</template>

<style scoped>
.approval-main {
  display: flex;
  align-items: center;
  gap: 10px;
  color: #4b5565;
  font-size: 13px;
}
</style>

<style>
.approval-progress-modal {
  width: min(980px, 92vw);
}
</style>
