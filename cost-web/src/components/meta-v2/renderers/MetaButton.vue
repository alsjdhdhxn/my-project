<template>
  <div class="meta-button">
    <div v-if="status === 'error'" class="meta-button-error">
      {{ errorMessage }}
    </div>
    <NButton v-else :type="buttonType" :size="buttonSize" :disabled="isDisabled" @click="handleClick">
      {{ label }}
    </NButton>
  </div>
</template>

<script setup lang="ts">
import { computed, unref } from 'vue';
import { NButton } from 'naive-ui';
import type { ButtonProps } from 'naive-ui';
import type { PageComponentWithRules } from '@/composables/meta-v2/types';
import type { ComponentStateByKey, MetaRuntime } from '@/composables/meta-v2/runtime/types';

type ButtonConfig = {
  text?: string;
  label?: string;
  type?: string;
  size?: string;
  disabled?: boolean;
  action?: string;
  tableCode?: string;
  actionData?: Record<string, any>;
};

const props = defineProps<{
  component: PageComponentWithRules;
  runtime: MetaRuntime;
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
  const stateByKey = (source && 'value' in source ? source.value : source) as ComponentStateByKey | undefined;
  if (!stateByKey) return {};
  return stateByKey[props.component.componentKey] || {};
}

const config = computed(() => parseButtonConfig(props.component.componentConfig));
const state = computed(() => resolveComponentState());

const label = computed(() => config.value.label || config.value.text || props.component.componentKey);
const buttonType = computed<ButtonProps['type']>(() => (config.value.type as ButtonProps['type']) || 'default');
const buttonSize = computed<ButtonProps['size']>(() => (config.value.size as ButtonProps['size']) || 'medium');
const isDisabled = computed(() => Boolean(config.value.disabled || unref(state.value.disabled) || status.value === 'error'));
const status = computed(() => state.value.status || 'ready');
const errorMessage = computed(() => state.value.error?.message || 'Button render failed');

function handleClick() {
  if (typeof state.value.onClick === 'function') {
    state.value.onClick({ component: props.component, runtime: props.runtime });
    return;
  }
  const action = config.value.action;
  if (action) {
    const runtime = props.runtime as Record<string, any>;
    if (typeof runtime[action] === 'function') {
      runtime[action](props.component);
      return;
    }
    if (typeof runtime.executeAction === 'function') {
      runtime.executeAction(action, {
        tableCode: config.value.tableCode,
        data: config.value.actionData
      });
    }
  }
}
</script>

<style scoped>
.meta-button {
  display: inline-flex;
}

.meta-button-error {
  padding: 6px 10px;
  border: 1px dashed #ffccc7;
  border-radius: 4px;
  color: #d03050;
  background: #fff2f0;
  font-size: 12px;
}
</style>
