<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { NButton, NDataTable, NModal, NSpace, useMessage } from 'naive-ui';
import { fetchAllExportConfigs, deleteExportConfig, saveExportConfig } from '@/service/api/meta-config';
import ExportConfigPanel from '../../ExportConfigPanel.vue';

const props = defineProps<{
  pageCode: string;
}>();

const message = useMessage();
const configs = ref<any[]>([]);
const loading = ref(false);
const showExportEditor = ref(false);

const columns = [
  { title: '导出名称', key: 'exportName' },
  { title: '导出编码', key: 'exportCode' },
  { title: '主表Sheet', key: 'masterSheetName' },
  { title: '排序', key: 'displayOrder', width: 60 }
];

async function loadConfigs() {
  loading.value = true;
  try {
    const all = await fetchAllExportConfigs();
    configs.value = (all || []).filter((c: any) => c.pageCode === props.pageCode);
  } catch {
    message.error('加载导出配置失败');
  } finally {
    loading.value = false;
  }
}

function openEditor() {
  showExportEditor.value = true;
}

onMounted(loadConfigs);
</script>

<template>
  <div class="section-export">
    <NDataTable
      v-if="configs.length > 0"
      :columns="columns"
      :data="configs"
      :row-key="(row: any) => row.id"
      size="small"
      :bordered="false"
      :loading="loading"
    />
    <p v-else class="empty-hint">暂无导出配置</p>
    <div class="export-actions">
      <NButton size="small" @click="openEditor">管理导出配置</NButton>
    </div>

    <NModal
      v-model:show="showExportEditor"
      preset="card"
      title="导出配置管理"
      :style="{ width: '900px', maxHeight: '80vh' }"
      :body-style="{ overflow: 'auto' }"
    >
      <ExportConfigPanel />
    </NModal>
  </div>
</template>

<style scoped>
.section-export {
  padding: 8px 0;
}
.empty-hint {
  color: #999;
  font-size: 13px;
}
.export-actions {
  margin-top: 8px;
}
</style>
