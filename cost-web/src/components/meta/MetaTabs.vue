<template>
  <NTabs v-model:value="activeTab" type="line" size="small">
    <NTabPane
      v-for="child in sortedChildren"
      :key="child.componentKey"
      :name="child.componentKey"
      :tab="getTabLabel(child)"
      display-directive="show"
    >
      <MetaComponent :config="child" :page-context="pageContext" />
    </NTabPane>
  </NTabs>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { NTabs, NTabPane } from 'naive-ui';
import MetaComponent from './MetaComponent.vue';

const props = defineProps<{
  config: Api.Metadata.PageComponent;
  pageContext: any;
}>();

const tabsConfig = computed(() => {
  try {
    return JSON.parse(props.config.componentConfig || '{}');
  } catch {
    return {};
  }
});

const sortedChildren = computed(() => {
  return [...(props.config.children || [])].sort((a, b) => a.sortOrder - b.sortOrder);
});

const activeTab = ref(sortedChildren.value[0]?.componentKey || '');

function getTabLabel(child: Api.Metadata.PageComponent): string {
  try {
    const cfg = JSON.parse(child.componentConfig || '{}');
    return cfg.tabLabel || child.componentKey;
  } catch {
    return child.componentKey;
  }
}

// 监听主表选中行变化，刷新从表
const masterGridKey = computed(() => tabsConfig.value.masterGrid);

watch(
  () => props.pageContext.selectedRows[masterGridKey.value],
  (selected) => {
    if (selected?.length === 1) {
      // 通知从表刷新
      sortedChildren.value.forEach(child => {
        props.pageContext.refresh[child.componentKey]?.();
      });
    }
  },
  { deep: true }
);
</script>
