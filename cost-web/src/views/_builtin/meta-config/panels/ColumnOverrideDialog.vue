<script setup lang="ts">
import { ref, computed, watch, reactive } from 'vue';
import {
  NModal, NButton, NSpace, NSwitch, NInputNumber, NInput, NSelect,
  NEmpty, NPopconfirm, NTag, NIcon, NCollapse, NCollapseItem, NAutoComplete, useMessage
} from 'naive-ui';
import { fetchLookupConfig } from '@/service/api';
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
  columnId?: number | null;
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
  precision?: number | null;
  roundMode?: string;
  lookupMappingPairs?: LookupMappingPair[];
};

type LookupOption = {
  label: string;
  value: string;
  dataSource?: string;
};

type AvailableFieldOption = {
  label: string;
  value: string;
  columnId: number;
};

type LookupFieldOption = {
  label: string;
  value: string;
};

type LookupMappingPair = {
  local: string;
  remote: string;
};

const items = ref<OverrideItem[]>([]);
const availableFields = ref<AvailableFieldOption[]>([]);
const fieldLabelMap = ref<Map<string, string>>(new Map());
const numericFields = ref<Set<string>>(new Set());
const availableFieldMapById = ref<Map<number, AvailableFieldOption>>(new Map());
const availableFieldMapByField = ref<Map<string, AvailableFieldOption>>(new Map());
const lookupOptionsRaw = ref<LookupOption[]>([]);
const loadingFields = ref(false);
const addFieldValue = ref<string | null>(null);
const lookupFieldOptionsCache = new Map<string, LookupFieldOption[]>();

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
const configuredFields = computed(() => new Set(
  items.value.map(i => {
    const matched = findAvailableFieldForItem(i);
    if (matched) return `id:${matched.columnId}`;
    return typeof i.columnId === 'number' ? `id:${i.columnId}` : `field:${i.field}`;
  })
));

// 可添加的字段（排除已配置的）
const addableFields = computed(() =>
  availableFields.value.filter(f => !configuredFields.value.has(`id:${f.columnId}`))
);

// 初始化
watch(() => props.show, async (val) => {
  if (!val) return;
  // 解析已有规则
  try {
    const arr = props.rulesJson ? JSON.parse(props.rulesJson) : [];
    items.value = (Array.isArray(arr) ? arr : []).map((r: any) => {
      const cellEditorParams = normalizeCellEditorParams(r.cellEditorParams);
      return {
        columnId: parseColumnId(r.columnId),
        field: r.field || r.fieldName || '',
        fieldName: r.fieldName || '',
        visible: r.visible ?? true,
        editable: r.editable ?? undefined,
        searchable: r.searchable ?? undefined,
        required: r.required ?? undefined,
        width: r.width != null ? String(r.width) : null,
        cellEditor: r.cellEditor || '',
        cellEditorParams,
        aggFunc: r.aggFunc || undefined,
        precision: r.precision ?? null,
        roundMode: r.roundMode || 'round',
        lookupMappingPairs: toLookupMappingPairs(cellEditorParams?.mapping)
      };
    });
  } catch {
    items.value = [];
  }
  addFieldValue.value = null;
  // 默认全部折叠
  expandedRows.clear();
  // 加载关联表的列和 lookup 配置
  await Promise.all([loadAvailableFields(), loadLookupOptions()]);
  normalizeLookupCodesInItems();
  await preloadLookupFieldOptions();
});

function parseColumnId(value: unknown): number | null {
  const parsed = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function findAvailableFieldForItem(item: OverrideItem): AvailableFieldOption | undefined {
  if (typeof item.columnId === 'number') {
    const matchedById = availableFieldMapById.value.get(item.columnId);
    if (matchedById) return matchedById;
  }
  return item.field ? availableFieldMapByField.value.get(item.field) : undefined;
}

function syncItemWithAvailableField(item: OverrideItem) {
  const matched = findAvailableFieldForItem(item);
  if (!matched) return;
  item.columnId = matched.columnId;
  item.field = matched.value;
  item.fieldName = matched.value;
}

function syncItemsWithAvailableFields() {
  items.value.forEach(syncItemWithAvailableField);
}

function getFieldDisplayText(item: OverrideItem) {
  const matched = findAvailableFieldForItem(item);
  if (matched) {
    return fieldLabelMap.value.get(matched.value) || matched.value;
  }
  return item.field;
}

function isBoundToAvailableField(item: OverrideItem) {
  return Boolean(findAvailableFieldForItem(item));
}

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
      availableFieldMapById.value = new Map();
      availableFieldMapByField.value = new Map();
      return;
    }

    const cols = await fetchColumnsByTableId(targetTable.id);
    availableFields.value = cols
      .filter((col: any) => col.fieldName)
      .map((col: any) => ({
        label: `${col.fieldName} (${col.headerText || col.columnName})`,
        value: col.fieldName,
        columnId: Number(col.id)
      }));
    availableFieldMapById.value = new Map(
      availableFields.value
        .filter(field => Number.isFinite(field.columnId))
        .map(field => [field.columnId, field])
    );
    availableFieldMapByField.value = new Map(
      availableFields.value.map(field => [field.value, field])
    );
    // 建立 fieldName → 中文名 映射
    fieldLabelMap.value = new Map(
      cols.filter((col: any) => col.fieldName).map((col: any) => [col.fieldName, col.headerText || col.columnName || col.fieldName])
    );
    syncItemsWithAvailableFields();
    // 记录数字类型字段（兼容大小写和多种类型名）
    const numericTypes = new Set(['number', 'integer', 'decimal', 'float', 'double', 'numeric', 'int', 'bigint']);
    numericFields.value = new Set(
      cols.filter((col: any) => col.fieldName && col.dataType && numericTypes.has(col.dataType.toLowerCase()))
        .map((col: any) => col.fieldName)
    );
    // 已配置 aggFunc 的字段也标记为数字（兼容元数据缺失 dataType 的情况）
    for (const item of items.value) {
      if (item.aggFunc) numericFields.value.add(item.field);
    }
  } catch {
    availableFields.value = [];
    availableFieldMapById.value = new Map();
    availableFieldMapByField.value = new Map();
  } finally {
    loadingFields.value = false;
  }
}

async function loadLookupOptions() {
  try {
    const list = await fetchAllLookupConfigs();
    lookupOptionsRaw.value = list.map((item: any) => ({
      label: item.lookupName || item.lookupCode,
      value: item.lookupCode,
      dataSource: item.dataSource || ''
    }));
  } catch {
    lookupOptionsRaw.value = [];
  }
}

async function preloadLookupFieldOptions() {
  const lookupCodes = Array.from(new Set(
    items.value
      .filter(item => isLookupEditor(item.cellEditor))
      .map(item => normalizeLookupCode(item.cellEditorParams?.lookupCode))
      .filter((lookupCode): lookupCode is string => Boolean(lookupCode))
  ));
  await Promise.all(lookupCodes.map(lookupCode => ensureLookupFieldOptions(lookupCode)));
}

function normalizeLookupCode(raw: unknown): string {
  const value = typeof raw === 'string' ? raw.trim() : '';
  if (!value) return '';

  const keyword = value.toLowerCase();
  const matchedByCode = lookupOptionsRaw.value.find(option => option.value.toLowerCase() === keyword);
  if (matchedByCode) return matchedByCode.value;

  const matchedByLabel = lookupOptionsRaw.value.filter(option => option.label.toLowerCase() === keyword);
  if (matchedByLabel.length === 1) {
    return matchedByLabel[0].value;
  }

  return value;
}

function normalizeLookupCodesInItems() {
  for (const item of items.value) {
    if (!isLookupEditor(item.cellEditor) || !item.cellEditorParams?.lookupCode) continue;
    const normalizedLookupCode = normalizeLookupCode(item.cellEditorParams.lookupCode);
    if (normalizedLookupCode && normalizedLookupCode !== item.cellEditorParams.lookupCode) {
      item.cellEditorParams = {
        ...item.cellEditorParams,
        lookupCode: normalizedLookupCode
      };
    }
  }
}

function filterLookupOption(pattern: string, option: any): boolean {
  const keyword = pattern.trim().toLowerCase();
  if (!keyword) return true;
  const label = typeof option?.label === 'string' ? option.label : '';
  const value = typeof option?.value === 'string' ? option.value : '';
  return label.toLowerCase().includes(keyword) || value.toLowerCase().includes(keyword);
}

function filterTextOptions<T extends { label?: string; value?: string }>(pattern: string, options: T[]): T[] {
  const keyword = pattern.trim().toLowerCase();
  if (!keyword) return options;
  return options.filter(option => {
    const label = typeof option.label === 'string' ? option.label : '';
    const value = typeof option.value === 'string' ? option.value : '';
    return label.toLowerCase().includes(keyword) || value.toLowerCase().includes(keyword);
  });
}

function getAvailableFieldAutoOptions(input: string) {
  return filterTextOptions(input, availableFields.value);
}

function getLookupFieldAutoOptions(item: OverrideItem, input: string) {
  const lookupCode = normalizeLookupCode(item.cellEditorParams?.lookupCode);
  if (!lookupCode) return [];
  const options = lookupFieldOptionsCache.get(lookupCode) || [];
  return filterTextOptions(input, options);
}

function getLookupDataSource(item: OverrideItem): string {
  const lookupCode = normalizeLookupCode(item.cellEditorParams?.lookupCode);
  if (!lookupCode) return '';
  const matched = lookupOptionsRaw.value.find(option => option.value === lookupCode);
  return matched?.dataSource || '';
}

async function copyLookupDataSource(item: OverrideItem, event: MouseEvent) {
  const text = getLookupDataSource(item);
  if (!text) return;

  const input = event.currentTarget as HTMLInputElement | null;
  input?.focus();
  input?.select();

  try {
    await navigator.clipboard.writeText(text);
    message.success('视图名已复制');
  } catch {
    try {
      document.execCommand('copy');
      message.success('视图名已复制');
    } catch {
      message.error('复制失败，请手动复制');
    }
  }
}

function toLookupMappingPairs(mapping: any): LookupMappingPair[] {
  if (!mapping || typeof mapping !== 'object') return [];
  return Object.entries(mapping).map(([local, remote]) => ({ local, remote: String(remote ?? '') }));
}

function toLookupMappingObject(pairs: LookupMappingPair[]): Record<string, string> {
  const mapping: Record<string, string> = {};
  for (const pair of pairs) {
    if (pair.local && pair.remote) {
      mapping[pair.local] = pair.remote;
    }
  }
  return mapping;
}

function buildLookupFieldOptions(config: any): LookupFieldOption[] {
  const result: LookupFieldOption[] = [];
  const seen = new Set<string>();
  const addField = (field?: string, label?: string) => {
    const value = typeof field === 'string' ? field.trim() : '';
    if (!value) return;
    const key = value.toLowerCase();
    if (seen.has(key)) return;
    seen.add(key);
    result.push({
      value,
      label: label ? `${value} (${label})` : value
    });
  };

  for (const column of config?.displayColumns || []) {
    addField(column?.field, column?.header);
  }
  addField(config?.valueField, '值字段');
  addField(config?.labelField, '显示字段');

  return result;
}

async function ensureLookupFieldOptions(lookupCode: string): Promise<LookupFieldOption[]> {
  if (!lookupCode) return [];
  const cached = lookupFieldOptionsCache.get(lookupCode);
  if (cached) return cached;

  try {
    const { data } = await fetchLookupConfig(lookupCode);
    const options = buildLookupFieldOptions(data);
    lookupFieldOptionsCache.set(lookupCode, options);
    return options;
  } catch {
    return [];
  }
}

function buildAutoLookupMappingPairs(item: OverrideItem, lookupFields: LookupFieldOption[]): LookupMappingPair[] {
  if (lookupFields.length === 0) return [];

  const remoteFieldMap = new Map(
    lookupFields.map(option => [option.value.toLowerCase(), option.value])
  );
  const pairs: LookupMappingPair[] = [];
  const seenLocals = new Set<string>();

  const addPair = (localField?: string) => {
    const local = typeof localField === 'string' ? localField.trim() : '';
    if (!local) return;
    const localKey = local.toLowerCase();
    const remote = remoteFieldMap.get(localKey);
    if (!remote || seenLocals.has(localKey)) return;
    seenLocals.add(localKey);
    pairs.push({ local, remote });
  };

  addPair(item.field);
  availableFields.value.forEach(field => addPair(field.value));

  return pairs;
}

function mergeLookupMappingPairs(autoPairs: LookupMappingPair[], existingPairs: LookupMappingPair[]): LookupMappingPair[] {
  if (existingPairs.length === 0) return autoPairs.map(pair => ({ ...pair }));

  const result = autoPairs.map(pair => ({ ...pair }));
  const indexByLocal = new Map<string, number>();
  result.forEach((pair, index) => {
    if (pair.local) indexByLocal.set(pair.local.toLowerCase(), index);
  });

  for (const pair of existingPairs) {
    const normalizedPair = {
      local: pair.local || '',
      remote: pair.remote || ''
    };
    const localKey = normalizedPair.local.trim().toLowerCase();

    if (localKey && indexByLocal.has(localKey)) {
      result[indexByLocal.get(localKey)!] = normalizedPair;
      continue;
    }

    if (normalizedPair.local || normalizedPair.remote) {
      result.push(normalizedPair);
    }
  }

  return result;
}

async function onLookupCodeChange(item: OverrideItem, value: string) {
  const previousLookupCode = normalizeLookupCode(item.cellEditorParams?.lookupCode);
  const lookupCode = normalizeLookupCode(value);
  setParam(item, 'lookupCode', lookupCode);

  if (!lookupCode) {
    setLookupMapping(item, []);
    return;
  }

  const lookupFields = await ensureLookupFieldOptions(lookupCode);
  if (normalizeLookupCode(item.cellEditorParams?.lookupCode) !== lookupCode) return;

  const autoPairs = buildAutoLookupMappingPairs(item, lookupFields);
  if (previousLookupCode !== lookupCode) {
    setLookupMapping(item, autoPairs);
    return;
  }

  const currentPairs = getLookupMapping(item);
  if (autoPairs.length === 0 && currentPairs.length === 0) return;
  const nextPairs = mergeLookupMappingPairs(autoPairs, currentPairs);
  setLookupMapping(item, nextPairs);
}

function addField() {
  if (!addFieldValue.value) return;
  const field = addFieldValue.value;
  const meta = availableFields.value.find(f => f.value === field);
  items.value.push({
    columnId: meta?.columnId ?? null,
    field,
    fieldName: field,
    visible: true,
    editable: undefined,
    searchable: undefined,
    required: undefined,
    width: null,
    cellEditor: '',
    aggFunc: undefined,
    precision: null,
    roundMode: 'round',
  });
  addFieldValue.value = null;
}

function addCustomField() {
  items.value.push({
    columnId: null,
    field: '',
    visible: true,
    editable: undefined,
    width: null,
    cellEditor: '',
    aggFunc: undefined,
    precision: null,
    roundMode: 'round',
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

// 拖拽排序
const dragIndex = ref<number | null>(null);
const dragOverIndex = ref<number | null>(null);

function onDragStart(index: number, e: DragEvent) {
  dragIndex.value = index;
  if (e.dataTransfer) {
    e.dataTransfer.effectAllowed = 'move';
  }
}

function onDragOver(index: number) {
  dragOverIndex.value = index;
}

function onDragLeave() {
  dragOverIndex.value = null;
}

function onDrop(index: number) {
  const from = dragIndex.value;
  if (from == null || from === index) return;
  const [moved] = items.value.splice(from, 1);
  items.value.splice(index, 0, moved);
  dragOverIndex.value = null;
  dragIndex.value = null;
}

function onDragEnd() {
  dragIndex.value = null;
  dragOverIndex.value = null;
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
  if (!item.lookupMappingPairs) {
    item.lookupMappingPairs = toLookupMappingPairs(item.cellEditorParams?.mapping);
  }
  return item.lookupMappingPairs;
}

function setLookupMapping(item: OverrideItem, pairs: Array<{ local: string; remote: string }>) {
  if (!item.cellEditorParams) item.cellEditorParams = { lookupCode: '', mapping: {} };

  item.lookupMappingPairs = pairs.map(pair => ({
    local: pair.local || '',
    remote: pair.remote || ''
  }));

  const mapping = toLookupMappingObject(item.lookupMappingPairs);
  if (Object.keys(mapping).length > 0) {
    item.cellEditorParams = { ...item.cellEditorParams, mapping };
  } else {
    const { mapping: _, ...rest } = item.cellEditorParams;
    item.cellEditorParams = rest;
  }
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
      const matched = findAvailableFieldForItem(i);
      const resolvedField = matched?.value || i.field;
      const obj: any = { field: resolvedField };
      if (typeof (matched?.columnId ?? i.columnId) === 'number') {
        obj.columnId = matched?.columnId ?? i.columnId;
      }
      if (i.visible === false) obj.visible = false;
      if (i.editable != null) obj.editable = i.editable;
      if (i.searchable != null) obj.searchable = i.searchable;
      if (i.required != null) obj.required = i.required;
      if (i.width != null && i.width !== '') obj.width = Number(i.width);
      if (i.cellEditor) obj.cellEditor = i.cellEditor;
      if (i.aggFunc) obj.aggFunc = i.aggFunc;
      if (i.precision != null) obj.precision = i.precision;
      if (i.roundMode && i.roundMode !== 'round') obj.roundMode = i.roundMode;
      if (i.cellEditorParams && Object.keys(i.cellEditorParams).length > 0) {
        const params = { ...i.cellEditorParams };
        if (params.lookupCode) {
          params.lookupCode = normalizeLookupCode(params.lookupCode);
        }
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
    style="width: 1100px; max-height: 90vh"
    :mask-closable="true"
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
        <span class="col-seq">#</span>
        <span class="col-field">字段</span>
        <span class="col-check">显示</span>
        <span class="col-check">编辑</span>
        <span class="col-check">搜索</span>
        <span class="col-check">必填</span>
        <span class="col-check">求和</span>
        <span class="col-precision">精度</span>
        <span class="col-roundmode">取整</span>
        <span class="col-width">宽度</span>
        <span class="col-editor">编辑器</span>
        <span class="col-ops">操作</span>
      </div>

      <div
        v-for="(item, index) in items"
        :key="index"
        class="override-row-wrap"
        :class="{ 'drag-over': dragOverIndex === index }"
        draggable="true"
        @dragstart="onDragStart(index, $event)"
        @dragover.prevent="onDragOver(index)"
        @dragleave="onDragLeave"
        @drop="onDrop(index)"
        @dragend="onDragEnd"
      >
        <div class="override-row">
        <div class="col-seq">
          <span class="drag-handle" title="拖拽排序">☰</span>
          <span class="seq-num">{{ index + 1 }}</span>
        </div>
        <div class="col-field">
          <NInput v-if="!isBoundToAvailableField(item)" v-model:value="item.field" size="small" placeholder="fieldName" />
          <NTag v-else size="small" :bordered="false">{{ getFieldDisplayText(item) }}</NTag>
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
        <div class="col-precision">
          <NInputNumber
            v-if="numericFields.has(item.field)"
            v-model:value="item.precision"
            size="small"
            :min="0"
            :max="10"
            :show-button="false"
            placeholder="—"
            clearable
            style="width: 50px"
          />
          <span v-else style="color:#ccc;font-size:11px">—</span>
        </div>
        <div class="col-roundmode">
          <NSelect
            v-if="numericFields.has(item.field) && item.precision != null"
            v-model:value="item.roundMode"
            :options="[
              { label: '四舍五入', value: 'round' },
              { label: '向上', value: 'ceil' },
              { label: '向下', value: 'floor' },
            ]"
            size="small"
            style="width: 80px"
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
            <span class="params-label">弹窗</span>
            <NSelect
              :value="item.cellEditorParams?.lookupCode || null"
              @update:value="onLookupCodeChange(item, $event || '')"
              :options="lookupOptionsRaw"
              :filter="filterLookupOption"
              size="small" filterable clearable placeholder="选择弹窗" style="width: 200px"
            />
            <input
              v-if="getLookupDataSource(item)"
              class="lookup-data-source-input"
              :value="`视图：${getLookupDataSource(item)}`"
              readonly
              :title="`${getLookupDataSource(item)}（双击复制）`"
              @dblclick="copyLookupDataSource(item, $event)"
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
            <NAutoComplete
              :value="item.cellEditorParams?.filterField || ''"
              @update:value="setParam(item, 'filterField', $event || '')"
              :options="getAvailableFieldAutoOptions(item.cellEditorParams?.filterField || '')"
              size="small" clearable placeholder="可选" style="width: 140px"
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
                <NAutoComplete
                  :value="pair.local"
                  @update:value="updateLookupMappingPair(item, pi, 'local', $event || '')"
                  :options="getAvailableFieldAutoOptions(pair.local || '')"
                  size="small" clearable placeholder="本表字段" style="width: 150px"
                />
                <span style="color: #999">→</span>
                <NAutoComplete
                  :value="pair.remote"
                  @update:value="updateLookupMappingPair(item, pi, 'remote', $event)"
                  :options="getLookupFieldAutoOptions(item, pair.remote || '')"
                  size="small" clearable placeholder="弹窗字段" style="width: 150px"
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

.lookup-data-source-input {
  width: 260px;
  max-width: 260px;
  height: 28px;
  padding: 0 10px;
  border: 1px solid #d9d9d9;
  border-radius: 6px;
  background: #f8fbff;
  color: #3f54ff;
  font-size: 12px;
  line-height: 28px;
  cursor: copy;
  user-select: all;
}

.lookup-data-source-input:focus {
  outline: none;
  border-color: #6370ff;
  box-shadow: 0 0 0 2px rgb(99 112 255 / 14%);
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

.col-precision {
  flex: 0 0 65px;
}

.col-roundmode {
  flex: 0 0 80px;
}

.col-editor {
  flex: 0 0 120px;
}

.col-ops {
  flex: 0 0 50px;
  display: flex;
  gap: 2px;
  align-items: center;
}

.col-seq {
  flex: 0 0 42px;
  display: flex;
  align-items: center;
  gap: 2px;
}

.drag-handle {
  cursor: grab;
  color: #999;
  font-size: 14px;
  user-select: none;
}

.drag-handle:active {
  cursor: grabbing;
}

.seq-num {
  font-size: 11px;
  color: #999;
  min-width: 16px;
  text-align: center;
}

.override-row-wrap.drag-over {
  border-top: 2px solid #18a058;
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
