<script setup lang="ts">
import { reactive, ref } from 'vue';
import { NButton, NForm, NFormItem, NInput, NSpace, useMessage } from 'naive-ui';
import { saveResource } from '@/service/api/meta-config';

const props = defineProps<{
  resource: any;
}>();

const emit = defineEmits<{
  (e: 'refresh'): void;
}>();

const message = useMessage();
const saving = ref(false);

const form = reactive({
  resourceName: props.resource.resourceName || '',
  icon: props.resource.icon || '',
  route: props.resource.route || '',
  sortOrder: props.resource.sortOrder ?? 0
});

async function handleSave() {
  saving.value = true;
  try {
    await saveResource({
      ...props.resource,
      resourceName: form.resourceName,
      icon: form.icon,
      route: form.route,
      sortOrder: form.sortOrder
    });
    message.success('保存成功');
    emit('refresh');
  } catch (e: any) {
    message.error(e?.message || '保存失败');
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <div class="section-basic-info">
    <NForm label-placement="left" label-width="80px" inline>
      <NFormItem label="页面名称">
        <NInput v-model:value="form.resourceName" style="width: 200px" />
      </NFormItem>
      <NFormItem label="页面编码">
        <NInput :value="resource.pageCode" disabled style="width: 200px" />
      </NFormItem>
      <NFormItem label="路由">
        <NInput v-model:value="form.route" style="width: 200px" />
      </NFormItem>
      <NFormItem label="图标">
        <NInput v-model:value="form.icon" style="width: 150px" />
      </NFormItem>
      <NFormItem label="排序">
        <NInput v-model:value="form.sortOrder" style="width: 80px" />
      </NFormItem>
      <NFormItem>
        <NButton type="primary" size="small" :loading="saving" @click="handleSave">保存</NButton>
      </NFormItem>
    </NForm>
  </div>
</template>

<style scoped>
.section-basic-info {
  padding: 8px 0;
}
</style>
