<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import {
  NModal, NButton, NSpace, NSwitch, NInputNumber, NInput, NSelect,
  NEmpty, NPopconfirm, NTag, NIcon, useMessage
} from 'naive-ui';
import { fetchColumnsByTableId, fetchTablesByPageCode } from '@/service/api/meta-config';

const props = defineProps<{
  show: boolean;
  rulesJson: string;
  pageCode: string;
  componentKey: string;
}>();

const emit = defineEmits<{
  (e: 'update:show', value: boolean): void;
  (e: 'save', json: string): void;
}>();

const message = useMessage();

type OverrideItem = {
  field: string;
  fieldName?: string;
  visible?: boolean;
  editable?: boolean;
  searchable?: boolean;
  required?: boolean;
  width?: number | null;
  cellEditor?: string;
  cellEditorParams?: Record<string, any>;
};

const items = ref<OverrideItem[]>([]);
const availableFields = ref<{ label: string; value: string }[]>([]);
const loadingFields = ref(false);
const addFieldValue = ref<string | null>(null);

const cellEditorOptions = [
  { label: '(无)', value: '' },
  { label: '文本 agTextCellEditor', value: 'agTextCellEditor' },
  { label: '大文本 agLargeTextCellEditor', value: 'agLargeTextCellEditor' },
  { label: '数字 agNumberCellEditor', value: 'agNumberCellEditor' },
  { label: '日期 agDateCellEditor', value: 'agDateCellEditor' },
  { label: '下拉 agSelectCellEditor', value: 'agSelectCellEditor' },
  { label: '富文本 agRichSelectCellEditor', value: 'agRichSelectCellEditor' },
];

// 已配置的字段集合
const configuredFields = computed(() => new Set(items.value.map(i => i.field)));

// 可添加的字段（排除已配置的）
const addableFields = computed(() =>
  availableFields.value.filter(f => !configuredFields.value.has(f.value))
);

// 初始化
watch(() => props.show, async (val) => {
  if (!val) return;
  // 解析已有规则
  try {
    const arr = props.rulesJson ? JSON.parse(props.rulesJson) : [];
    items.value = (Array.isArray(arr) ? arr : []).map((r: any) => ({
      field: r.field || r.fieldName || '',
      fieldName: r.fieldName || '',
      visible: r.visible ?? true,
      editable: r.editable ?? undefined,
      searchable: r.searchable ?? undefined,
      required: r.required ?? undefined,
      width: r.width ?? null,
      cellEditor: r.cellEditor || '',
      cellEditorParams: r.cellEditorParams || undefined,
    }));
  } catch {
    items.value = [];
  }
  addFieldValue.value = null;
  // 加载关联表的列
  await loadAvailableFields();
});

async function loadAvailableFields() {
  loadingFields.value = true;
  try {
    const tables = await fetchTablesByPageCode(props.pageCode);
    if (!tables.length) {
      availableFields.value = [];
      return;
    }
    // 找到与 componentKey 关联的表（通过 refTableCode 匹配）
    // 简单策略：加载所有关联表的列
    const allFields: { label: string; value: string }[] = [];
    for (const table of tables) {
      if (!table.id) continue;
      const cols = await fetchColumnsByTableId(table.id);
      for (const col of cols) {
        if (col.fieldName) {
          allFields.push({
            label: `${col.fieldName} (${col.headerText || col.columnName})`,
            value: col.fieldName
          });
        }
      }
    }
    availableFields.value = allFields;
  } catch {
    availableFields.value = [];
  } finally {
    loadingFields.value = false;
  }
}

function addField() {
  if (!addFieldValue.value) return;
  const field = addFieldValue.value;
  const meta = availableFields.value.find(f => f.value === field);
  items.value.push({
    field,
    fieldName: meta?.label?.match(/\((.+)\)/)?.[1] || '',
    visible: true,
    editable: undefined,
    searchable: undefined,
    required: undefined,
    width: null,
    cellEditor: '',
  });
  addFieldValue.value = null;
}

function addCustomField() {
  items.value.push({
    field: '',
    visible: true,
    editable: undefined,
    width: null,
    cellEditor: '',
  });
}

function removeItem(index: number) {
  items.value.splice(index, 1);
}

function moveItem(index: number, dir: -1 | 1) {
  const target = index + dir;
  if (target < 0 || target >= items.value.length) return;
  [items.value[index], items.value[target]] = [items.value[target], items.value[index]];
}

function handleSave() {
  const result = items.value
    .filter(i => i.field)
    .map(i => {
      const obj: any = { field: i.field };
      if (i.visible === false) obj.visible = false;
      if (i.editable != null) obj.editable = i.editable;
      if (i.searchable != null) obj.searchable = i.searchable;
      if (i.required != null) obj.required = i.required;
      if (i.width != null) obj.width = i.width;
      if (i.cellEditor) obj.cellEditor = i.cellEditor;
      if (i.cellEditorParams && Object.keys(i.cellEditorParams).length > 0) {
        obj.cellEditorParams = i.cellEditorParams;
      }
      return obj;
    });
  emit('save', JSON.stringify(result));
  emit('update:show', false);
  message.success('列覆盖配置已更新');
}
</script>

<template>
  <NModal
    :show="show"
    @update:show="(v) => emit('update:show', v)"
    preset="card"
    :title="`列覆盖配置 - ${componentKey}`"
    style="width: 800px; max-height: 90vh"
    :mask-closable="false"
    :segmented="{ content: true, footer: true }"
  >
    <!-- 添加字段 -->
    <div class="add-bar">
      <NSelect
        v-model:value="addFieldValue"
        :options="addableFields"
        :loading="loadingFields"
        filterable
        clearable
        placeholder="选择字段添加覆盖..."
        style="flex: 1"
        size="small"
      />
      <NButton size="small" type="primary" :disabled="!addFieldValue" @click="addField">添加</NButton>
      <NButton size="small" dashed @click="addCustomField">自定义字段</NButton>
    </div>

    <!-- 列表 -->
    <div class="override-list" style="max-height: 65vh; overflow-y: auto">
      <NEmpty v-if="items.length === 0" description="暂无列覆盖配置" />

      <!-- 表头 -->
      <div v-if="items.length > 0" class="override-header">
        <span class="col-field">字段</span>
        <span class="col-check">显示</span>
        <span class="col-check">可编辑</span>
        <span class="col-check">可搜索</span>
        <span class="col-check">必填</span>
        <span class="col-width">宽度</span>
        <span class="col-editor">编辑器</span>
        <span class="col-ops">操作</span>
      </div>

      <div v-for="(item, index) in items" :key="index" class="override-row">
        <div class="col-field">
          <NInput v-if="!availableFields.find(f => f.value === item.field)" v-model:value="item.field" size="small" placeholder="fieldName" />
          <NTag v-else size="small">{{ item.field }}</NTag>
        </div>
        <div class="col-check">
          <NSwitch v-model:value="item.visible" size="small" />
        </div>
        <div class="col-check">
          <NSwitch v-model:value="item.editable" size="small" />
        </div>
        <div class="col-check">
          <NSwitch v-model:value="item.searchable" size="small" />
        </div>
        <div class="col-check">
          <NSwitch v-model:value="item.required" size="small" />
        </div>
        <div class="col-width">
          <NInputNumber v-model:value="item.width" size="small" :min="30" :max="800" placeholder="auto" clearable style="width: 80px" />
        </div>
        <div class="col-editor">
          <NSelect v-model:value="item.cellEditor" :options="cellEditorOptions" size="small" style="width: 140px" clearable />
        </div>
        <div class="col-ops">
          <NButton text size="small" :disabled="index === 0" @click="moveItem(index, -1)">↑</NButton>
          <NButton text size="small" :disabled="index === items.length - 1" @click="moveItem(index, 1)">↓</NButton>
          <NPopconfirm @positive-click="removeItem(index)">
            <template #trigger>
              <NButton text size="small" type="error">删</NButton>
            </template>
            确定移除？
          </NPopconfirm>
        </div>
      </div>
    </div>

    <template #footer>
      <NSpace justify="end" size="small">
        <NButton size="small" @click="emit('update:show', false)">取消</NButton>
        <NButton size="small" type="primary" @click="handleSave">保存</NButton>
      </NSpace>
    </template>
  </NModal>
</template>

<style scoped>
.add-bar {
  display: flex;
  gap: 8px;
  margin-bottom: 12px;
  align-items: center;
}

.override-list {
  display: flex;
  flex-direction: column;
  gap: 0;
}

.override-header {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 8px;
  background: #f5f5f5;
  border-radius: 4px;
  font-size: 12px;
  color: #666;
  font-weight: 500;
  margin-bottom: 4px;
}

.override-row {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 8px;
  border-bottom: 1px solid #f0f0f0;
  transition: background 0.15s;
}

.override-row:hover {
  background: #fafafa;
}

.col-field {
  flex: 0 0 140px;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
}

.col-check {
  flex: 0 0 55px;
  text-align: center;
}

.col-width {
  flex: 0 0 85px;
}

.col-editor {
  flex: 0 0 150px;
}

.col-ops {
  flex: 0 0 70px;
  display: flex;
  gap: 2px;
  align-items: center;
}
</style>
