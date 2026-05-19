<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { NButton, NDataTable, NModal, useMessage } from 'naive-ui';
import { fetchApprovalFlows } from '@/service/api/meta-config';
import ApprovalFlowPanel from '../../ApprovalFlowPanel.vue';

const props = defineProps<{
  pageCode: string;
}>();

const message = useMessage();
const flows = ref<any[]>([]);
const loading = ref(false);
const showApprovalEditor = ref(false);

const columns = [
  { title: '流程名称', key: 'flowName' },
  { title: '状态', key: 'isEnabled', width: 60, render: (row: any) => row.isEnabled ? '启用' : '禁用' }
];

async function loadFlows() {
  loading.value = true;
  try {
    const all = await fetchApprovalFlows();
    flows.value = (all || []).filter((f: any) => f.pageCode === props.pageCode);
  } catch {
    message.error('加载审批流失败');
  } finally {
    loading.value = false;
  }
}

function openEditor() {
  showApprovalEditor.value = true;
}

onMounted(loadFlows);
</script>

<template>
  <div class="section-approval">
    <NDataTable
      v-if="flows.length > 0"
      :columns="columns"
      :data="flows"
      :row-key="(row: any) => row.id || row.flowId"
      size="small"
      :bordered="false"
      :loading="loading"
    />
    <p v-else class="empty-hint">暂无审批流配置</p>
    <div class="approval-actions">
      <NButton size="small" @click="openEditor">管理审批流</NButton>
    </div>

    <NModal
      v-model:show="showApprovalEditor"
      preset="card"
      title="审批流配置"
      :style="{ width: '1000px', maxHeight: '80vh' }"
      :body-style="{ overflow: 'auto', height: '70vh' }"
    >
      <ApprovalFlowPanel />
    </NModal>
  </div>
</template>

<style scoped>
.section-approval {
  padding: 8px 0;
}
.empty-hint {
  color: #999;
  font-size: 13px;
}
.approval-actions {
  margin-top: 8px;
}
</style>
