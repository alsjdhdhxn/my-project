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

// 记录每个 Tab 是否已加载当前主表数据
const loadedTabs = ref<Set<string>>(new Set());

function getTabLabel(child: Api.Metadata.PageComponent): string {
  try {
    const cfg = JSON.parse(child.componentConfig || '{}');
    return cfg.tabLabel || child.componentKey;
  } catch {
    return child.componentKey;
  }
}

const masterGridKey = computed(() => tabsConfig.value.masterGrid);

// 监听主表选中行变化
watch(
  () => props.pageContext.selectedRows[masterGridKey.value],
  (selected) => {
    if (selected?.length === 1) {
      // 主表切换，清空缓存标记
      loadedTabs.value.clear();
      // 只刷新当前激活的 Tab
      loadedTabs.value.add(activeTab.value);
      props.pageContext.refresh[activeTab.value]?.();
    }
  },
  { deep: true }
);

// 切换 Tab 时，检查是否需要加载数据
watch(activeTab, (newTab) => {
  if (!loadedTabs.value.has(newTab)) {
    loadedTabs.value.add(newTab);
    props.pageContext.refresh[newTab]?.();
  }
});
</script>
