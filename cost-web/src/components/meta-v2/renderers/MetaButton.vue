<template>
  <div class="meta-button">
    <NButton :type="buttonType" :size="buttonSize" :disabled="isDisabled" @click="handleClick">
      {{ label }}
    </NButton>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { NButton } from 'naive-ui';
import type { ButtonProps } from 'naive-ui';
import type { PageComponentWithRules } from '@/composables/meta-v2/types';

type ButtonConfig = {
  text?: string;
  label?: string;
  type?: string;
  size?: string;
  disabled?: boolean;
  action?: string;
};

const props = defineProps<{
  component: PageComponentWithRules;
  runtime: any;
}>();

function parseButtonConfig(config?: string): ButtonConfig {
  if (!config) return {};
  try {
    return JSON.parse(config) as ButtonConfig;
  } catch (error) {
    console.warn('[MetaV2] button config parse failed', error);
    return {};
  }
}

function resolveComponentState(): Record<string, any> {
  const source = props.runtime?.componentStateByKey;
  const stateByKey = source?.value ?? source;
  if (!stateByKey) return {};
  return stateByKey[props.component.componentKey] || {};
}

const config = computed(() => parseButtonConfig(props.component.componentConfig));
const state = computed(() => resolveComponentState());

const label = computed(() => config.value.label || config.value.text || props.component.componentKey);
const buttonType = computed<ButtonProps['type']>(() => (config.value.type as ButtonProps['type']) || 'default');
const buttonSize = computed<ButtonProps['size']>(() => (config.value.size as ButtonProps['size']) || 'medium');
const isDisabled = computed(() => Boolean(config.value.disabled || state.value.disabled));

function handleClick() {
  if (typeof state.value.onClick === 'function') {
    state.value.onClick({ component: props.component, runtime: props.runtime });
    return;
  }
  const action = config.value.action;
  if (action && typeof props.runtime?.[action] === 'function') {
    props.runtime[action](props.component);
  }
}
</script>

<style scoped>
.meta-button {
  display: inline-flex;
}
</style>
