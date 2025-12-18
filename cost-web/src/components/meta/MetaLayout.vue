<template>
  <NCard v-if="layoutConfig.type === 'card'" :title="layoutConfig.title" class="mb-12px">
    <slot />
  </NCard>
  <div v-else-if="layoutConfig.type === 'flex'" class="flex gap-12px" :style="layoutStyle">
    <slot />
  </div>
  <div v-else>
    <slot />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { NCard } from 'naive-ui';

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
  return {
    flexDirection: cfg.direction || 'row',
    flexWrap: cfg.wrap ? 'wrap' : 'nowrap'
  };
});
</script>
