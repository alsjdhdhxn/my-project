<template>
  <div class="meta-layout" :style="layoutStyle">
    <slot />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';

const props = defineProps<{
  config: Api.Metadata.PageComponent;
  pageContext: any;
}>();

const layoutConfig = computed(() => {
  try {
    return JSON.parse(props.config.componentConfig || '{}');
  } catch {
    return {};
  }
});

const layoutStyle = computed(() => {
  const cfg = layoutConfig.value;
  // direction: vertical -> 上下排列(column), horizontal -> 左右排列(row)
  const dir = cfg.direction === 'vertical' ? 'column' : cfg.direction === 'horizontal' ? 'row' : 'column';
  return {
    display: 'flex',
    flexDirection: dir,
    gap: (cfg.gap || 16) + 'px',
    height: '100%',
    minHeight: 0
  };
});
</script>

<style scoped>
.meta-layout {
  width: 100%;
  flex: 1;
  overflow: hidden;
}
</style>
