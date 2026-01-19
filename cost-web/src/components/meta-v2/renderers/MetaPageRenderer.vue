<template>
  <RendererBoundary
    v-for="component in components"
    :key="component.componentKey"
    :component="component"
    :runtime="runtime"
    :renderer="resolveRenderer(component)"
  />
</template>

<script setup lang="ts">
import { defineComponent, h, onErrorCaptured, ref } from 'vue';
import type { PageComponentWithRules } from '@/composables/meta-v2/types';
import type { MetaRuntime } from '@/composables/meta-v2/runtime/types';
import { resolveComponentRenderer } from '@/composables/meta-v2/component-renderer-registry';
import { initComponentRenderers } from '@/components/meta-v2/renderers/renderers';

initComponentRenderers();

const props = defineProps<{
  components: PageComponentWithRules[];
  runtime: MetaRuntime;
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

const RendererBoundary = defineComponent({
  name: 'MetaRendererBoundary',
  props: {
    component: { type: Object, required: true },
    runtime: { type: Object, required: true },
    renderer: { type: Object, required: true }
  },
  setup(boundaryProps) {
    const hasError = ref(false);
    const errorMessage = ref('');

    onErrorCaptured((err) => {
      hasError.value = true;
      const message = err instanceof Error ? err.message : String(err);
      errorMessage.value = message || 'Renderer failed';

      const runtime = boundaryProps.runtime as MetaRuntime;
      if (runtime?.reportComponentError) {
        runtime.reportComponentError(boundaryProps.component.componentKey, 'render', message, err);
      } else {
        const source = (runtime as any)?.componentStateByKey;
        const stateByKey = source?.value ?? source;
        if (stateByKey?.[boundaryProps.component.componentKey]) {
          stateByKey[boundaryProps.component.componentKey].status = 'error';
          stateByKey[boundaryProps.component.componentKey].error = {
            code: 'RENDER_ERROR',
            message,
            stage: 'render',
            pageCode: runtime?.pageCode || 'unknown',
            componentKey: boundaryProps.component.componentKey,
            raw: err
          };
        }
      }
      return false;
    });

    return () => {
      if (hasError.value) {
        return h('div', { class: 'meta-renderer-error' }, errorMessage.value || 'Render error');
      }
      return h(boundaryProps.renderer as any, {
        component: boundaryProps.component,
        runtime: boundaryProps.runtime
      });
    };
  }
});

function resolveRenderer(component: PageComponentWithRules) {
  return resolveComponentRenderer({ component, runtime: props.runtime }) || MissingRenderer;
}
</script>
<style scoped>
.meta-renderer-error {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 60px;
  padding: 12px;
  color: #d03050;
  background: #fff2f0;
  border: 1px dashed #ffccc7;
  border-radius: 4px;
  font-size: 12px;
}
</style>
