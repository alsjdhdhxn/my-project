<template>
  <component
    v-for="component in components"
    :is="resolveRenderer(component)"
    :key="component.componentKey"
    :component="component"
    :runtime="runtime"
  />
</template>

<script setup lang="ts">
import { defineComponent, h } from 'vue';
import type { PageComponentWithRules } from '@/composables/meta-v2/types';
import { resolveComponentRenderer } from '@/composables/meta-v2/component-renderer-registry';
import { initComponentRenderers } from '@/components/meta-v2/renderers/renderers';

initComponentRenderers();

const props = defineProps<{
  components: PageComponentWithRules[];
  runtime: any;
}>();

const MissingRenderer = defineComponent({
  name: 'MissingRenderer',
  props: {
    component: { type: Object, required: true },
    runtime: { type: Object, required: false }
  },
  setup(missingProps) {
    console.warn('[MetaV2] missing renderer for component', missingProps.component);
    return () => h('div', { class: 'meta-missing-renderer' }, 'Unsupported component');
  }
});

function resolveRenderer(component: PageComponentWithRules) {
  return resolveComponentRenderer({ component, runtime: props.runtime }) || MissingRenderer;
}
</script>
