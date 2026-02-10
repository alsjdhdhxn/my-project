<script setup lang="ts">
import { ref, computed, watch, reactive } from 'vue';
import {
  NModal, NButton, NSpace, NSwitch, NInputNumber, NInput, NSelect,
  NEmpty, NPopconfirm, NTag, NIcon, NCollapse, NCollapseItem, NAutoComplete, useMessage
} from 'naive-ui';
import { fetchColumnsByTableId, fetchTablesByPageCode, savePageRule, fetchAllLookupConfigs } from '@/service/api/meta-config';

const props = defineProps<{
  show: boolean;
  rulesJson: string;
  pageCode: string;
  componentKey: string;
  ruleRow?: any;
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
  width?: string | null;
  cellEditor?: string;
  cellEditorParams?: Record<string, any>;
  aggFunc?: string;
};

const items = ref<OverrideItem[]>([]);
const availableFields = ref<{ label: string; value: string }[]>([]);
const numericFields = ref<Set<string>>(new Set());
const lookupOptionsRaw = ref<Array<{ label: string; value: string }>>([]);
const loadingFields = ref(false);
const addFieldValue = ref<string | null>(null);

const cellEditorOptions = [
  { label: '(无)', value: '' },
  { label: '文本', value: 'agTextCellEditor' },
  { label: '大文本', value: 'agLargeTextCellEditor' },
  { label: '数字', value: 'agNumberCellEditor' },
  { label: '日期', value: 'agDateCellEditor' },
  { label: '下拉', value: 'agSelectCellEditor' },
  { label: '富文本下拉', value: 'agRichSelectCellEditor' },
  { label: '弹窗选择', value: 'lookup' },
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
      width: r.width != null ? String(r.width) : null,
      cellEditor: r.cellEditor || '',
      cellEditorParams: normalizeCellEditorParams(r.cellEditorParams),
      aggFunc: r.aggFunc || undefined,
    }));
  } catch {
    items.value = [];
  }
  addFieldValue.value = null;
  // 默认全部折叠
  expandedRows.clear();
  // 加载关联表的列和 lookup 配置
  await Promise.all([loadAvailableFields(), loadLookupOptions()]);
});

async function loadAvailableFields() {
  loadingFields.value = true;
  try {
    const tables = await fetchTablesByPageCode(props.pageCode);
    if (!tables.length) {
      availableFields.value = [];
      return;
    }
    // 找到当前 componentKey 对应的表（通过组件列表匹配 refTableCode）
    const { fetchAllPageComponents } = await import('@/service/api/meta-config');
    const allComps = await fetchAllPageComponents();
    const currentComp = allComps?.find(
      (c: any) => c.pageCode === props.pageCode && c.componentKey === props.componentKey
    );
    const currentRefTableCode = currentComp?.refTableCode;

    // 只加载当前组件关联表的列
    const targetTable = currentRefTableCode
      ? tables.find((t: any) => t.tableCode === currentRefTableCode)
      : tables[0];

    if (!targetTable?.id) {
      availableFields.value = [];
      return;
    }

    const cols = await fetchColumnsByTableId(targetTable.id);
    availableFields.value = cols
      .filter((col: any) => col.fieldName)
      .map((col: any) => ({
        label: `${col.fieldName} (${col.headerText || col.columnName})`,
        value: col.fieldName
      }));
    // 记录数字类型字段
    numericFields.value = new Set(
      cols.filter((col: any) => col.fieldName && col.dataType === 'number')
        .map((col: any) => col.fieldName)
    );
  } catch {
    availableFields.value = [];
  } finally {
    loadingFields.value = false;
  }
}

async function loadLookupOptions() {
  try {
    const list = await fetchAllLookupConfigs();
    lookupOptionsRaw.value = list.map((item: any) => ({
      label: item.lookupName || item.lookupCode,
      value: item.lookupCode
    }));
  } catch {
    lookupOptionsRaw.value = [];
  }
}

function getLookupAutoOptions(input: string): Array<{ label: string; value: string }> {
  if (!input) return lookupOptionsRaw.value;
  const keyword = input.toLowerCase();
  return lookupOptionsRaw.value.filter(
    o => o.label.toLowerCase().includes(keyword) || o.value.toLowerCase().includes(keyword)
  );
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
    aggFunc: undefined,
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
    aggFunc: undefined,
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

function normalizeCellEditorParams(params: any): Record<string, any> | undefined {
  if (!params) return undefined;
  const result = { ...params };
  // 兼容旧数据：values 是数组时转为逗号字符串
  if (Array.isArray(result.values)) {
    result.values = result.values.join(',');
  }
  if (!result.mode && !result.lookupCode) {
    result.mode = result.refTable ? 'ref' : 'static';
  }
  return result;
}

function isSelectEditor(editor?: string) {
  return editor === 'agSelectCellEditor' || editor === 'agRichSelectCellEditor';
}

function isLookupEditor(editor?: string) {
  return editor === 'lookup';
}

function onEditorChange(item: OverrideItem, value: string, index?: number) {
  if (isSelectEditor(value) && !item.cellEditorParams) {
    item.cellEditorParams = { mode: 'static', values: '' };
  }
  if (isLookupEditor(value) && !item.cellEditorParams) {
    item.cellEditorParams = { lookupCode: '', mapping: {} };
  }
  // 选择有参数的编辑器时自动展开
  if ((isSelectEditor(value) || isLookupEditor(value)) && index != null) {
    expandedRows.add(index);
  }
  // 选择无参数编辑器时折叠
  if (!isSelectEditor(value) && !isLookupEditor(value) && index != null) {
    expandedRows.delete(index);
  }
}

function toggleExpand(index: number) {
  if (expandedRows.has(index)) {
    expandedRows.delete(index);
  } else {
    expandedRows.add(index);
  }
}

function hasParams(item: OverrideItem): boolean {
  return isSelectEditor(item.cellEditor) || isLookupEditor(item.cellEditor);
}

function setParamMode(item: OverrideItem, mode: string) {
  if (!item.cellEditorParams) item.cellEditorParams = {};
  item.cellEditorParams = { mode };
}

function setParam(item: OverrideItem, key: string, value: any) {
  if (!item.cellEditorParams) item.cellEditorParams = { mode: 'static' };
  if (key === 'noFillback') {
    // boolean 特殊处理
    if (value) {
      item.cellEditorParams = { ...item.cellEditorParams, [key]: true };
    } else {
      const { noFillback: _, ...rest } = item.cellEditorParams;
      item.cellEditorParams = rest;
    }
    return;
  }
  // 空字符串时删除该 key
  if (value === '' || value == null) {
    const { [key]: _, ...rest } = item.cellEditorParams;
    item.cellEditorParams = rest;
    return;
  }
  item.cellEditorParams = { ...item.cellEditorParams, [key]: value };
}

function getStaticValuesStr(item: OverrideItem): string {
  const v = item.cellEditorParams?.values;
  if (Array.isArray(v)) return v.join(',');
  if (typeof v === 'string') return v;
  return '';
}

function setStaticValuesStr(item: OverrideItem, value: string) {
  if (!item.cellEditorParams) item.cellEditorParams = { mode: 'static' };
  item.cellEditorParams = { ...item.cellEditorParams, values: value };
}

// Lookup mapping 管理
function getLookupMapping(item: OverrideItem): Array<{ local: string; remote: string }> {
  const mapping = item.cellEditorParams?.mapping;
  if (!mapping || typeof mapping !== 'object') return [];
  return Object.entries(mapping).map(([local, remote]) => ({ local, remote: remote as string }));
}

function setLookupMapping(item: OverrideItem, pairs: Array<{ local: string; remote: string }>) {
  if (!item.cellEditorParams) item.cellEditorParams = { lookupCode: '', mapping: {} };
  const mapping: Record<string, string> = {};
  for (const p of pairs) {
    if (p.local && p.remote) mapping[p.local] = p.remote;
  }
  item.cellEditorParams = { ...item.cellEditorParams, mapping };
}

function addLookupMappingPair(item: OverrideItem) {
  const pairs = getLookupMapping(item);
  pairs.push({ local: '', remote: '' });
  setLookupMapping(item, pairs);
}

function removeLookupMappingPair(item: OverrideItem, index: number) {
  const pairs = getLookupMapping(item);
  pairs.splice(index, 1);
  setLookupMapping(item, pairs);
}

function updateLookupMappingPair(item: OverrideItem, index: number, key: 'local' | 'remote', value: string) {
  const pairs = getLookupMapping(item);
  if (pairs[index]) {
    pairs[index][key] = value;
    setLookupMapping(item, pairs);
  }
}

const saving = ref(false);

// 跟踪每行的折叠状态（lookup/select 参数区）
const expandedRows = reactive(new Set<number>());

async function handleSave() {
  const result = items.value
    .filter(i => i.field)
    .map(i => {
      const obj: any = { field: i.field };
      if (i.visible === false) obj.visible = false;
      if (i.editable != null) obj.editable = i.editable;
      if (i.searchable != null) obj.searchable = i.searchable;
      if (i.required != null) obj.required = i.required;
      if (i.width != null && i.width !== '') obj.width = Number(i.width);
      if (i.cellEditor) obj.cellEditor = i.cellEditor;
      if (i.aggFunc) obj.aggFunc = i.aggFunc;
      if (i.cellEditorParams && Object.keys(i.cellEditorParams).length > 0) {
        const params = { ...i.cellEditorParams };
        // 清理 lookup mapping 中的空项
        if (params.mapping && typeof params.mapping === 'object') {
          const cleaned: Record<string, string> = {};
          for (const [k, v] of Object.entries(params.mapping)) {
            if (k && v) cleaned[k] = v as string;
          }
          if (Object.keys(cleaned).length > 0) {
            params.mapping = cleaned;
          } else {
            delete params.mapping;
          }
        }
        // 清理空字符串值
        for (const [k, v] of Object.entries(params)) {
          if (v === '' || v == null) delete params[k];
        }
        if (Object.keys(params).length > 0) {
          obj.cellEditorParams = params;
        }
      }
      return obj;
    });
  const json = JSON.stringify(result);

  // 直接保存到数据库
  if (props.ruleRow) {
    saving.value = true;
    try {
      await savePageRule({ ...props.ruleRow, rules: json });
      message.success('列覆盖配置已保存');
      emit('save', json);
      emit('update:show', false);
    } catch {
      message.error('保存失败');
    } finally {
      saving.value = false;
    }
  } else {
    emit('save', json);
    emit('update:show', false);
    message.success('列覆盖配置已更新');
  }
}
</script>

<template>
  <NModal
    :show="show"
    @update:show="(v) => emit('update:show', v)"
    preset="card"
    :title="`列覆盖配置 - ${componentKey}`"
    style="width: 960px; max-height: 90vh"
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
    <div class="override-list" style="max-height: 65vh; overflow-y: auto; overflow-x: hidden">
      <NEmpty v-if="items.length === 0" description="暂无列覆盖配置" />

      <!-- 表头 -->
      <div v-if="items.length > 0" class="override-header">
        <span class="col-field">字段</span>
        <span class="col-check">显示</span>
        <span class="col-check">编辑</span>
        <span class="col-check">搜索</span>
        <span class="col-check">必填</span>
        <span class="col-check">求和</span>
        <span class="col-width">宽度</span>
        <span class="col-editor">编辑器</span>
        <span class="col-ops">操作</span>
      </div>

      <div v-for="(item, index) in items" :key="index" class="override-row-wrap">
        <div class="override-row">
        <div class="col-field">
          <NInput v-if="!availableFields.find(f => f.value === item.field)" v-model:value="item.field" size="small" placeholder="fieldName" />
          <NTag v-else size="small" :bordered="false">{{ item.field }}</NTag>
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
        <div class="col-check">
          <NSwitch
            v-if="numericFields.has(item.field)"
            :value="item.aggFunc === 'sum'"
            @update:value="(v: boolean) => item.aggFunc = v ? 'sum' : undefined"
            size="small"
          />
          <span v-else style="color:#ccc;font-size:11px">—</span>
        </div>
        <div class="col-width">
          <NInput v-model:value="item.width" size="small" placeholder="auto" clearable style="width: 60px" />
        </div>
        <div class="col-editor">
          <NSelect v-model:value="item.cellEditor" :options="cellEditorOptions" size="small" clearable
            @update:value="onEditorChange(item, $event, index)" />
        </div>
        <div class="col-ops">
          <NButton v-if="hasParams(item)" text size="small" @click="toggleExpand(index)" :style="{ color: expandedRows.has(index) ? '#18a058' : '#999' }">
            {{ expandedRows.has(index) ? '▾' : '▸' }}
          </NButton>
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
        <!-- 下拉参数配置区（可折叠） -->
        <div v-if="isSelectEditor(item.cellEditor) && expandedRows.has(index)" class="editor-params">
          <div class="params-row">
            <span class="params-label">模式</span>
            <NSelect
              :value="item.cellEditorParams?.mode || 'static'"
              @update:value="setParamMode(item, $event)"
              :options="[{ label: '纯值', value: 'static' }, { label: '关联查询', value: 'ref' }]"
              size="small" style="width: 120px"
            />
            <template v-if="(item.cellEditorParams?.mode || 'static') === 'static'">
              <span class="params-label">值(逗号分隔)</span>
              <NInput
                :value="getStaticValuesStr(item)"
                @update:value="setStaticValuesStr(item, $event)"
                size="small" placeholder="值1,值2,值3" style="flex: 1"
              />
            </template>
            <template v-else>
              <span class="params-label">当前关联字段</span>
              <NSelect
                :value="item.cellEditorParams?.localField || null"
                @update:value="setParam(item, 'localField', $event)"
                :options="availableFields"
                size="small" filterable clearable placeholder="选择字段" style="width: 140px"
              />
              <span class="params-label">关联表</span>
              <NInput
                :value="item.cellEditorParams?.refTable || ''"
                @update:value="setParam(item, 'refTable', $event)"
                size="small" placeholder="T_COST_USER" style="width: 150px"
              />
              <span class="params-label">关联字段(唯一)</span>
              <NInput
                :value="item.cellEditorParams?.refField || ''"
                @update:value="setParam(item, 'refField', $event)"
                size="small" placeholder="ID" style="width: 100px"
              />
            </template>
          </div>
          <div v-if="(item.cellEditorParams?.mode) === 'ref'" class="params-row">
            <span class="params-label">显示字段</span>
            <NInput
              :value="item.cellEditorParams?.labelField || ''"
              @update:value="setParam(item, 'labelField', $event)"
              size="small" placeholder="USER_NAME" style="width: 140px"
            />
            <span class="params-label">回填字段</span>
            <NInput
              :value="item.cellEditorParams?.valueField || ''"
              @update:value="setParam(item, 'valueField', $event)"
              size="small" placeholder="ID (写入当前字段的值)" style="width: 160px"
            />
          </div>
          <div v-if="(item.cellEditorParams?.mode) === 'ref'" class="params-row">
            <span class="params-label">过滤条件</span>
            <NInput
              :value="item.cellEditorParams?.filter || ''"
              @update:value="setParam(item, 'filter', $event)"
              size="small" placeholder="DELETED = 0 (可选)" style="flex: 1"
            />
          </div>
        </div>
        <!-- 弹窗选择参数配置区（可折叠） -->
        <div v-if="isLookupEditor(item.cellEditor) && expandedRows.has(index)" class="editor-params">
          <div class="params-row">
            <span class="params-label">lookupCode</span>
            <NAutoComplete
              :value="item.cellEditorParams?.lookupCode || ''"
              @update:value="setParam(item, 'lookupCode', $event || '')"
              :options="getLookupAutoOptions(item.cellEditorParams?.lookupCode || '')"
              :get-show="() => true"
              size="small" clearable placeholder="搜索Lookup" style="width: 200px"
            />
            <span class="params-label">禁止回填</span>
            <NSwitch
              :value="!!item.cellEditorParams?.noFillback"
              @update:value="setParam(item, 'noFillback', $event)"
              size="small"
            />
          </div>
          <div class="params-row">
            <span class="params-label">筛选字段(行)</span>
            <NSelect
              :value="item.cellEditorParams?.filterField || null"
              @update:value="setParam(item, 'filterField', $event || '')"
              :options="availableFields"
              size="small" filterable clearable placeholder="可选" style="width: 140px"
            />
            <span class="params-label">筛选列(SQL)</span>
            <NInput
              :value="item.cellEditorParams?.filterColumn || ''"
              @update:value="setParam(item, 'filterColumn', $event)"
              size="small" placeholder="如 GOODSID" style="width: 130px"
            />
            <span class="params-label">值来源</span>
            <NSelect
              :value="item.cellEditorParams?.filterValueFrom || null"
              @update:value="setParam(item, 'filterValueFrom', $event || '')"
              :options="[{ label: '行数据', value: 'row' }, { label: '单元格', value: 'cell' }]"
              size="small" clearable style="width: 100px"
            />
          </div>
          <div class="params-row" style="align-items: flex-start">
            <span class="params-label" style="margin-top: 4px">字段映射</span>
            <div style="flex: 1; display: flex; flex-direction: column; gap: 4px">
              <div v-for="(pair, pi) in getLookupMapping(item)" :key="pi" style="display: flex; gap: 4px; align-items: center">
                <NSelect
                  :value="pair.local || null"
                  @update:value="updateLookupMappingPair(item, pi, 'local', $event || '')"
                  :options="availableFields"
                  size="small" filterable placeholder="本表字段" style="width: 150px"
                />
                <span style="color: #999">→</span>
                <NInput
                  :value="pair.remote"
                  @update:value="updateLookupMappingPair(item, pi, 'remote', $event)"
                  size="small" placeholder="弹窗字段" style="width: 150px"
                />
                <NButton text size="small" type="error" @click="removeLookupMappingPair(item, pi)">删</NButton>
              </div>
              <NButton size="tiny" dashed @click="addLookupMappingPair(item)" style="width: fit-content">+ 添加映射</NButton>
            </div>
          </div>
        </div>
      </div>
    </div>

    <template #footer>
      <NSpace justify="end" size="small">
        <NButton size="small" @click="emit('update:show', false)">取消</NButton>
        <NButton size="small" type="primary" :loading="saving" @click="handleSave">保存</NButton>
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
  gap: 6px;
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
  gap: 6px;
  padding: 6px 8px;
  transition: background 0.15s;
}

.col-field {
  flex: 1 1 120px;
  min-width: 80px;
  overflow: hidden;
  text-overflow: ellipsis;
}

.col-check {
  flex: 0 0 46px;
  text-align: center;
}

.col-width {
  flex: 0 0 60px;
}

.col-editor {
  flex: 0 0 120px;
}

.col-ops {
  flex: 0 0 90px;
  display: flex;
  gap: 2px;
  align-items: center;
}

.override-row-wrap {
  border-bottom: 1px solid #f0f0f0;
}

.override-row-wrap:hover {
  background: #fafafa;
}

.editor-params {
  padding: 6px 8px 8px 16px;
  display: flex;
  flex-direction: column;
  gap: 4px;
  background: #fafcff;
  border-left: 2px solid #d6e4ff;
  margin: 0 8px 4px 8px;
  border-radius: 0 4px 4px 0;
}

.params-row {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-wrap: wrap;
}

.params-label {
  font-size: 12px;
  color: #666;
  white-space: nowrap;
}
</style>
