<template>
  <div class="meta-form">
    <component
      v-if="customRenderer"
      :is="customRenderer"
      :component="component"
      :runtime="runtime"
    />
    <div v-else class="meta-form-placeholder">
      {{ placeholder }}
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { PageComponentWithRules } from '@/composables/meta-v2/types';

const props = defineProps<{
  component: PageComponentWithRules;
  runtime: any;
}>();

function resolveComponentState(): Record<string, any> {
  const source = props.runtime?.componentStateByKey;
  const stateByKey = source?.value ?? source;
  if (!stateByKey) return {};
  return stateByKey[props.component.componentKey] || {};
}

const state = computed(() => resolveComponentState());
const customRenderer = computed(() => state.value.renderer);
const placeholder = computed(() => state.value.placeholder || `Form "${props.component.componentKey}" not configured`);
</script>

<style scoped>
.meta-form {
  width: 100%;
}

.meta-form-placeholder {
  padding: 12px;
  border: 1px dashed #d9d9d9;
  border-radius: 4px;
  color: #666;
  font-size: 12px;
}
</style>
