<template>
  <NCard :title="formConfig.title || '查询条件'" size="small" class="mb-12px">
    <NForm ref="formRef" :model="formData" label-placement="left" :label-width="80" inline>
      <NFormItem v-for="col in searchableColumns" :key="col.fieldName" :label="col.headerText">
        <NInput
          v-if="col.dataType === 'text'"
          v-model:value="formData[col.fieldName]"
          :placeholder="'请输入' + col.headerText"
          clearable
        />
        <NInputNumber
          v-else-if="col.dataType === 'number'"
          v-model:value="formData[col.fieldName]"
          :placeholder="'请输入' + col.headerText"
          clearable
        />
        <NDatePicker
          v-else-if="col.dataType === 'date'"
          v-model:value="formData[col.fieldName]"
          type="date"
          clearable
        />
        <NSelect
          v-else-if="col.dataType === 'select'"
          v-model:value="formData[col.fieldName]"
          :options="dictOptions[col.dictType || ''] || []"
          :placeholder="'请选择' + col.headerText"
          clearable
        />
      </NFormItem>
      <NFormItem>
        <NSpace>
          <NButton type="primary" @click="handleSearch">查询</NButton>
          <NButton @click="handleReset">重置</NButton>
        </NSpace>
      </NFormItem>
    </NForm>
  </NCard>
</template>

<script setup lang="ts">
import { ref, computed, reactive, onMounted } from 'vue';
import { NCard, NForm, NFormItem, NInput, NInputNumber, NDatePicker, NSelect, NButton, NSpace } from 'naive-ui';
import { fetchDictItems } from '@/service/api';

const props = defineProps<{
  config: Api.Metadata.PageComponent;
  pageContext: any;
}>();

const emit = defineEmits<{
  search: [data: Record<string, any>];
}>();

const formRef = ref();
const formData = reactive<Record<string, any>>({});
const dictOptions = ref<Record<string, { label: string; value: string }[]>>({});

const formConfig = computed(() => {
  try {
    return JSON.parse(props.config.componentConfig || '{}');
  } catch {
    return {};
  }
});

const metadata = computed(() => {
  return props.pageContext.metadata[props.config.refTableCode || ''];
});

const searchableColumns = computed(() => {
  if (!metadata.value?.columns) return [];
  return metadata.value.columns.filter(col => col.searchable).sort((a, b) => a.displayOrder - b.displayOrder);
});

// 加载字典
async function loadDicts() {
  const dictTypes = new Set<string>();
  searchableColumns.value.forEach(col => {
    if (col.dictType) dictTypes.add(col.dictType);
  });

  await Promise.all(
    Array.from(dictTypes).map(async type => {
      const { data } = await fetchDictItems(type);
      if (data) {
        dictOptions.value[type] = data.map(item => ({
          label: item.label,
          value: item.value
        }));
      }
    })
  );
}

function handleSearch() {
  emit('search', { ...formData });
}

function handleReset() {
  Object.keys(formData).forEach(key => {
    formData[key] = undefined;
  });
}

onMounted(loadDicts);
</script>
