<script setup lang="ts">
import { computed, nextTick, ref, unref } from 'vue';
import {
  NButton,
  NCheckbox,
  NDatePicker,
  NEmpty,
  NInput,
  NInputNumber,
  NModal,
  NPopover,
  NSelect,
  NSpace
} from 'naive-ui';
import { Icon } from '@iconify/vue';
import LookupDialog from '@/v3/components/LookupDialog.vue';

type SearchCondition = {
  key: string;
  field: string;
  fieldLabel: string;
  tableLabel: string;
  operator: string;
  value: any;
  value2?: any;
  enabled: boolean;
  visible: boolean;
  dataType: 'string' | 'number' | 'date' | 'datetime';
  inputMode: 'text' | 'number' | 'date' | 'datetime' | 'select' | 'lookup';
  lookupCode?: string;
  lookupValueField?: string;
  options?: Array<{ label: string; value: string | number }>;
  loadingOptions?: boolean;
};

type LookupDialogExpose = {
  open: () => Promise<void> | void;
};

const props = defineProps<{
  runtime: any;
}>();

const advancedSearch = computed(() => props.runtime?.advancedSearch || {});
const searchConditions = computed<SearchCondition[]>(() => unref(advancedSearch.value.searchConditions) || []);
const visibleConditions = computed<SearchCondition[]>(() => unref(advancedSearch.value.visibleConditions) || []);
const activeFilterSummaries = computed<string[]>(() => unref(advancedSearch.value.activeFilterSummaries) || []);
const showDialog = computed({
  get: () => Boolean(unref(advancedSearch.value.showDialog)),
  set: value => {
    if (!value) {
      advancedSearch.value.close?.();
    } else {
      advancedSearch.value.open?.();
    }
  }
});

const lookupDialogRef = ref<LookupDialogExpose | null>(null);
const currentLookupCondition = ref<SearchCondition | null>(null);

const currentLookupCode = computed(() => currentLookupCondition.value?.lookupCode || '');
const currentLookupMapping = computed(() => {
  const valueField = currentLookupCondition.value?.lookupValueField || currentLookupCondition.value?.field;
  const mapping: Record<string, string> = {};
  if (valueField) {
    mapping.selectedValue = valueField;
  }
  return mapping;
});

function getOperatorOptions(cond: SearchCondition) {
  if (cond.inputMode === 'lookup' || cond.inputMode === 'select') {
    return [
      { label: '等于', value: 'eq' },
      { label: '不等于', value: 'ne' }
    ];
  }
  if (cond.dataType === 'number') {
    return [
      { label: '等于', value: 'eq' },
      { label: '不等于', value: 'ne' },
      { label: '大于', value: 'gt' },
      { label: '大于等于', value: 'ge' },
      { label: '小于', value: 'lt' },
      { label: '小于等于', value: 'le' },
      { label: '介于', value: 'between' },
      { label: 'IN', value: 'in' }
    ];
  }
  if (cond.dataType === 'date' || cond.dataType === 'datetime') {
    return [
      { label: '等于', value: 'eq' },
      { label: '不等于', value: 'ne' },
      { label: '大于', value: 'gt' },
      { label: '大于等于', value: 'ge' },
      { label: '小于', value: 'lt' },
      { label: '小于等于', value: 'le' },
      { label: '介于', value: 'between' }
    ];
  }
  return [
    { label: '包含', value: 'like' },
    { label: '等于', value: 'eq' },
    { label: '不等于', value: 'ne' },
    { label: '开头是', value: 'likeLeft' },
    { label: '结尾是', value: 'likeRight' },
    { label: 'IN', value: 'in' }
  ];
}

function handleOperatorChange(cond: SearchCondition, operator: string) {
  cond.operator = operator;
  if (operator !== 'between') {
    cond.value2 = '';
  }
  if (operator === 'in') {
    if (cond.inputMode === 'select') {
      cond.value = Array.isArray(cond.value) ? cond.value : [];
    } else if (Array.isArray(cond.value)) {
      cond.value = cond.value.join(',');
    }
  } else if (Array.isArray(cond.value)) {
    cond.value = cond.value[0] ?? '';
  }
}

function shouldUseLookupInput(cond: SearchCondition) {
  return cond.inputMode === 'lookup';
}

function shouldUseSelectInput(cond: SearchCondition) {
  return cond.inputMode === 'select';
}

function shouldUseNumberInput(cond: SearchCondition) {
  return cond.inputMode === 'number' && cond.operator !== 'between' && cond.operator !== 'in';
}

function shouldUseNumberRangeInput(cond: SearchCondition) {
  return cond.inputMode === 'number' && cond.operator === 'between';
}

function shouldUseDateInput(cond: SearchCondition) {
  return (cond.inputMode === 'date' || cond.inputMode === 'datetime') && cond.operator !== 'between';
}

function shouldUseDateRangeInput(cond: SearchCondition) {
  return (cond.inputMode === 'date' || cond.inputMode === 'datetime') && cond.operator === 'between';
}

function shouldUseTextInput(cond: SearchCondition) {
  if (cond.operator === 'between') {
    return false;
  }
  if (
    shouldUseLookupInput(cond) ||
    shouldUseSelectInput(cond) ||
    shouldUseNumberInput(cond) ||
    shouldUseDateInput(cond) ||
    shouldUseDateRangeInput(cond) ||
    shouldUseNumberRangeInput(cond)
  ) {
    return false;
  }
  return true;
}

function markEnabled(cond: SearchCondition) {
  if (Array.isArray(cond.value)) {
    cond.enabled = cond.value.length > 0;
    return;
  }
  cond.enabled = String(cond.value ?? '').trim().length > 0;
}

function clearConditionValue(cond: SearchCondition) {
  cond.value = '';
  cond.value2 = '';
  cond.enabled = false;
}

function handleSingleValueChange(cond: SearchCondition, value: any) {
  cond.value = value ?? '';
  markEnabled(cond);
}

function handleSelectValueChange(cond: SearchCondition, value: any) {
  cond.value = value ?? (cond.operator === 'in' ? [] : null);
  markEnabled(cond);
}

function handleRangeValueChange(cond: SearchCondition, edge: 'start' | 'end', value: number | null) {
  if (edge === 'start') {
    cond.value = value;
  } else {
    cond.value2 = value;
  }
  cond.enabled = cond.value !== null && cond.value !== '' && cond.value2 !== null && cond.value2 !== '';
}

function getDatePickerType(cond: SearchCondition) {
  return cond.inputMode === 'datetime' ? 'datetime' : 'date';
}

function getDateValueFormat(cond: SearchCondition) {
  return cond.inputMode === 'datetime' ? 'yyyy-MM-dd HH:mm:ss' : 'yyyy-MM-dd';
}

function getDateRangePickerType(cond: SearchCondition) {
  return cond.inputMode === 'datetime' ? 'datetimerange' : 'daterange';
}

function formatSingleDateValue(value: unknown) {
  return typeof value === 'string' ? value : null;
}

function getDateRangeValue(cond: SearchCondition): [string, string] | null {
  if (!cond.value || !cond.value2) return null;
  return [String(cond.value), String(cond.value2)];
}

function handleDateRangeChange(cond: SearchCondition, value: [string, string] | null) {
  cond.value = value?.[0] || '';
  cond.value2 = value?.[1] || '';
  cond.enabled = Boolean(cond.value && cond.value2);
}

function formatLookupValue(value: unknown) {
  return value === null || value === undefined ? '' : String(value);
}

async function openLookup(cond: SearchCondition) {
  await advancedSearch.value.ensureLookupConditionReady?.(cond);
  currentLookupCondition.value = cond;
  await nextTick();
  await lookupDialogRef.value?.open?.();
}

function handleLookupSelect(fillData: Record<string, any>) {
  if (!currentLookupCondition.value) return;
  currentLookupCondition.value.value = fillData.selectedValue ?? '';
  currentLookupCondition.value.enabled = String(currentLookupCondition.value.value ?? '').trim().length > 0;
  currentLookupCondition.value = null;
}

function handleLookupCancel() {
  currentLookupCondition.value = null;
}
</script>

<template>
  <NModal v-model:show="showDialog" preset="card" class="advanced-search-modal">
    <template #header>
      <div class="advanced-search-header">
        <span>查询条件</span>
        <NPopover trigger="click" placement="bottom-end">
          <template #trigger>
            <NButton quaternary circle size="small">
              <template #icon>
                <Icon icon="mdi:cog-outline" />
              </template>
            </NButton>
          </template>
          <div class="field-settings">
            <div class="settings-title">显示字段</div>
            <div v-for="cond in searchConditions" :key="cond.key" class="field-setting-item">
              <NCheckbox v-model:checked="cond.visible" size="small">
                {{ cond.tableLabel }} · {{ cond.fieldLabel }}
              </NCheckbox>
            </div>
          </div>
        </NPopover>
      </div>
    </template>

    <div class="advanced-search-body">
      <div v-for="cond in visibleConditions" :key="cond.key" class="search-condition-row">
        <div class="condition-label-wrap">
          <NCheckbox v-model:checked="cond.enabled" class="condition-label">
            {{ cond.fieldLabel }}
          </NCheckbox>
          <span class="condition-table-label">{{ cond.tableLabel }}</span>
        </div>
        <NSelect
          v-model:value="cond.operator"
          :options="getOperatorOptions(cond)"
          size="small"
          class="condition-operator"
          @update:value="value => handleOperatorChange(cond, value)"
        />
        <div class="condition-value-wrap">
          <NInput
            v-if="shouldUseTextInput(cond)"
            v-model:value="cond.value"
            size="small"
            class="condition-value"
            :placeholder="cond.operator === 'in' ? '多个值用逗号分隔' : '请输入'"
            @input="() => markEnabled(cond)"
            @keyup.enter="advancedSearch.executeSearch"
          />

          <div v-else-if="shouldUseLookupInput(cond)" class="lookup-value-group">
            <NInput
              :value="formatLookupValue(cond.value)"
              size="small"
              class="condition-value"
              placeholder="请选择"
              readonly
              clearable
              @clear="clearConditionValue(cond)"
            />
            <NButton size="small" class="lookup-trigger" @click="openLookup(cond)">
              <template #icon>
                <Icon icon="mdi:magnify" />
              </template>
            </NButton>
          </div>

          <NSelect
            v-else-if="shouldUseSelectInput(cond)"
            :value="cond.value"
            :options="cond.options || []"
            :multiple="cond.operator === 'in'"
            :loading="!!cond.loadingOptions"
            size="small"
            class="condition-value"
            filterable
            clearable
            @update:value="value => handleSelectValueChange(cond, value)"
          />

          <NInputNumber
            v-else-if="shouldUseNumberInput(cond)"
            :value="cond.value"
            size="small"
            class="condition-value"
            clearable
            @update:value="value => handleSingleValueChange(cond, value)"
          />

          <div v-else-if="shouldUseNumberRangeInput(cond)" class="range-value-group">
            <NInputNumber
              :value="cond.value"
              size="small"
              class="range-value-item"
              clearable
              @update:value="value => handleRangeValueChange(cond, 'start', value)"
            />
            <span class="range-separator">至</span>
            <NInputNumber
              :value="cond.value2"
              size="small"
              class="range-value-item"
              clearable
              @update:value="value => handleRangeValueChange(cond, 'end', value)"
            />
          </div>

          <NDatePicker
            v-else-if="shouldUseDateInput(cond)"
            :type="getDatePickerType(cond)"
            :formatted-value="formatSingleDateValue(cond.value)"
            :value-format="getDateValueFormat(cond)"
            size="small"
            class="condition-value"
            clearable
            @update:formatted-value="value => handleSingleValueChange(cond, value)"
          />

          <NDatePicker
            v-else-if="shouldUseDateRangeInput(cond)"
            :type="getDateRangePickerType(cond)"
            :formatted-value="getDateRangeValue(cond)"
            :value-format="getDateValueFormat(cond)"
            size="small"
            class="condition-value"
            clearable
            @update:formatted-value="value => handleDateRangeChange(cond, value)"
          />
        </div>
      </div>
      <NEmpty v-if="visibleConditions.length === 0" description="暂无可显示的查询条件" size="small" />
    </div>

    <template #footer>
      <div class="advanced-search-footer">
        <div class="advanced-search-summary">
          <span v-if="activeFilterSummaries.length > 0">已启用 {{ activeFilterSummaries.length }} 项</span>
        </div>
        <NSpace :size="8">
          <NButton size="small" @click="advancedSearch.clearSearch">重置</NButton>
          <NButton size="small" @click="advancedSearch.close">取消</NButton>
          <NButton type="primary" size="small" @click="advancedSearch.executeSearch">查询</NButton>
        </NSpace>
      </div>
    </template>
  </NModal>

  <LookupDialog
    ref="lookupDialogRef"
    :lookup-code="currentLookupCode"
    :mapping="currentLookupMapping"
    @select="handleLookupSelect"
    @cancel="handleLookupCancel"
  />
</template>

<style scoped>
.advanced-search-modal {
  width: 920px;
}

.advanced-search-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
}

.advanced-search-body {
  max-height: 56vh;
  overflow-y: auto;
}

.search-condition-row {
  display: grid;
  grid-template-columns: 180px 120px 1fr;
  gap: 12px;
  align-items: center;
  margin-bottom: 12px;
}

.condition-label-wrap {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.condition-label {
  width: fit-content;
}

.condition-table-label {
  padding-left: 24px;
  color: #8c8c8c;
  font-size: 12px;
  line-height: 1.2;
}

.condition-value-wrap {
  min-width: 0;
}

.condition-value {
  width: 100%;
}

.range-value-group,
.lookup-value-group {
  display: flex;
  align-items: center;
  gap: 8px;
}

.range-value-item {
  flex: 1;
  min-width: 0;
}

.range-separator {
  color: #8c8c8c;
  font-size: 12px;
}

.lookup-trigger {
  flex-shrink: 0;
}

.field-settings {
  max-height: 320px;
  min-width: 280px;
  overflow-y: auto;
}

.settings-title {
  margin-bottom: 8px;
  font-weight: 600;
}

.field-setting-item {
  margin-bottom: 6px;
}

.advanced-search-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.advanced-search-summary {
  color: #8c8c8c;
  font-size: 12px;
}
</style>
