<template>
  <div class="meta-layout" :style="layoutStyle">
    <MetaPageRenderer :components="component.children || []" :runtime="runtime" />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { CSSProperties } from 'vue';
import MetaPageRenderer from '@/components/meta-v2/renderers/MetaPageRenderer.vue';
import type { PageComponentWithRules } from '@/composables/meta-v2/types';

type LayoutConfig = {
  direction?: 'vertical' | 'horizontal';
  gap?: number | string;
  align?: string;
  justify?: string;
};

const props = defineProps<{
  component: PageComponentWithRules;
  runtime: any;
}>();

function parseLayoutConfig(config?: string): LayoutConfig {
  if (!config) return {};
  try {
    return JSON.parse(config) as LayoutConfig;
  } catch (error) {
    console.warn('[MetaV2] layout config parse failed', error);
    return {};
  }
}

const layoutStyle = computed<CSSProperties>(() => {
  const config = parseLayoutConfig(props.component.componentConfig);
  const gap = config.gap != null ? (typeof config.gap === 'number' ? `${config.gap}px` : config.gap) : undefined;
  return {
    display: 'flex',
    flexDirection: config.direction === 'horizontal' ? 'row' : 'column',
    gap,
    alignItems: config.align,
    justifyContent: config.justify,
    width: '100%',
    height: '100%'
  } as CSSProperties;
});
</script>

<style scoped>
.meta-layout {
  width: 100%;
  height: 100%;
}
</style>
