<template>
  <NSpace class="mb-12px">
    <NButton v-if="hasPermission('CREATE')" type="primary" @click="handleCreate">
      <template #icon><span class="i-carbon-add" /></template>
      新增
    </NButton>
    <NButton v-if="hasPermission('EDIT')" :disabled="!hasSelection" @click="handleEdit">
      <template #icon><span class="i-carbon-edit" /></template>
      编辑
    </NButton>
    <NButton v-if="hasPermission('DELETE')" :disabled="!hasSelection" @click="handleDelete">
      <template #icon><span class="i-carbon-trash-can" /></template>
      删除
    </NButton>
    <NButton v-if="hasPermission('EXPORT')" @click="handleExport">
      <template #icon><span class="i-carbon-download" /></template>
      导出
    </NButton>
  </NSpace>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { NSpace, NButton, useDialog, useMessage } from 'naive-ui';
import { deleteDynamicData } from '@/service/api';

const props = defineProps<{
  config: Api.Metadata.PageComponent;
  pageContext: any;
}>();

const emit = defineEmits<{
  create: [];
  edit: [row: any];
}>();

const dialog = useDialog();
const message = useMessage();

const buttonConfig = computed(() => {
  try {
    return JSON.parse(props.config.componentConfig || '{}');
  } catch {
    return {};
  }
});

// 关联的 Grid 组件 key
const gridKey = computed(() => buttonConfig.value.targetGrid || '');

const hasSelection = computed(() => {
  const selected = props.pageContext.selectedRows[gridKey.value];
  return selected && selected.length > 0;
});

// 权限检查（暂时全部允许，后续对接权限）
function hasPermission(action: string): boolean {
  return true;
}

function handleCreate() {
  emit('create');
}

function handleEdit() {
  const selected = props.pageContext.selectedRows[gridKey.value];
  if (selected?.length === 1) {
    emit('edit', selected[0]);
  } else {
    message.warning('请选择一条数据');
  }
}

async function handleDelete() {
  const selected = props.pageContext.selectedRows[gridKey.value];
  if (!selected?.length) {
    message.warning('请选择要删除的数据');
    return;
  }

  dialog.warning({
    title: '确认删除',
    content: `确定要删除选中的 ${selected.length} 条数据吗？`,
    positiveText: '确定',
    negativeText: '取消',
    onPositiveClick: async () => {
      const tableCode = buttonConfig.value.tableCode;
      if (!tableCode) return;

      for (const row of selected) {
        await deleteDynamicData(tableCode, row.id);
      }
      message.success('删除成功');
      // 刷新表格
      props.pageContext.refresh[gridKey.value]?.();
    }
  });
}

function handleExport() {
  message.info('导出功能开发中');
}
</script>
