<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { NButton, NDataTable, useMessage } from 'naive-ui';
import { fetchApprovalFlows } from '@/service/api/meta-config';

const props = defineProps<{
  pageCode: string;
}>();

const message = useMessage();
const flows = ref<any[]>([]);
const loading = ref(false);

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
</style>
