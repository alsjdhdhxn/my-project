<template>
  <div class="dynamic-page">
    <NSpin :show="loading" class="h-full">
      <template v-if="components.length">
        <MetaComponent
          v-for="comp in components"
          :key="comp.componentKey"
          :config="comp"
          :page-context="pageContext"
        />
      </template>
      <NEmpty v-else-if="!loading" description="页面配置为空" />
    </NSpin>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, provide } from 'vue';
import { NSpin, NEmpty } from 'naive-ui';
import { fetchPageComponents, fetchTableMetadata } from '@/service/api';
import MetaComponent from './MetaComponent.vue';

const props = defineProps<{
  pageCode: string;
}>();

const loading = ref(false);
const components = ref<Api.Metadata.PageComponent[]>([]);

const pageContext = reactive({
  pageCode: props.pageCode,
  metadata: {} as Record<string, Api.Metadata.TableMetadata>,
  data: {} as Record<string, any>,
  selectedRows: {} as Record<string, any[]>,
  refresh: {} as Record<string, () => void>
});

provide('pageContext', pageContext);

async function loadPage() {
  loading.value = true;
  try {
    const { data, error } = await fetchPageComponents(props.pageCode);
    if (!error && data) {
      components.value = data;
      await preloadMetadata(data);
    }
  } finally {
    loading.value = false;
  }
}

async function preloadMetadata(list: Api.Metadata.PageComponent[]) {
  const tableCodes = new Set<string>();
  function collect(items: Api.Metadata.PageComponent[]) {
    items.forEach(item => {
      if (item.refTableCode) tableCodes.add(item.refTableCode);
      if (item.children?.length) collect(item.children);
    });
  }
  collect(list);

  await Promise.all(
    Array.from(tableCodes).map(async code => {
      const { data } = await fetchTableMetadata(code);
      if (data) pageContext.metadata[code] = data;
    })
  );
}

onMounted(loadPage);
</script>

<style scoped>
.dynamic-page {
  height: 100%;
  padding: 8px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
</style>
