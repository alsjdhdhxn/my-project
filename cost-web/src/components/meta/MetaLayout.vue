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
  return {
    display: 'flex',
    flexDirection: cfg.direction || 'column',
    gap: (cfg.gap || 8) + 'px',
    height: cfg.height || 'auto'
  };
});
</script>

<style scoped>
.meta-layout {
  width: 100%;
}
</style>
