<script setup lang="ts">
import { ref, watch } from 'vue';
import {
  NButton,
  NEmpty,
  NInput,
  NInputNumber,
  NModal,
  NPopconfirm,
  NSelect,
  NSpace,
  NSwitch,
  NTag,
  useMessage
} from 'naive-ui';
import { fetchColumnsByTableId, fetchTablesByPageCode, savePageRule } from '@/service/api/meta-config';

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

type Condition = {
  field: string;
  operator: string;
  value?: any;
};

type EditableRule = {
  logic: 'AND' | 'OR';
  conditions: Condition[];
  sqlCheck?: string;
  enableSql: boolean;
  editableFields: string[];
};

const items = ref<EditableRule[]>([]);
const availableFields = ref<{ label: string; value: string }[]>([]);
const saving = ref(false);

const operatorOptions = [
  { label: '= 等于', value: 'eq' },
  { label: '≠ 不等于', value: 'ne' },
  { label: '非空', value: 'notNull' },
  { label: '为空', value: 'isNull' },
  { label: '包含', value: 'in' },
  { label: '不包含', value: 'notIn' }
];

const needsValue = (op: string) => !['notNull', 'isNull'].includes(op);

watch(
  () => props.show,
  async val => {
    if (!val) return;
    try {
      const raw = props.rulesJson ? JSON.parse(props.rulesJson) : [];
      const arr = Array.isArray(raw) ? raw : [raw];
      items.value = arr.map(normalizeRule);
    } catch {
      items.value = [];
    }
    await loadAvailableFields();
  }
);

/** 兼容旧格式（单条件）和新格式（多条件） */
function normalizeRule(r: any): EditableRule {
  // 旧格式: { condition: { field, operator, value }, editableFields: [...] }
  if (r.condition && !r.conditions) {
    return {
      logic: 'AND',
      conditions: [
        { field: r.condition.field || '', operator: r.condition.operator || 'eq', value: r.condition.value }
      ],
      sqlCheck: r.sqlCheck || '',
      enableSql: Boolean(r.sqlCheck),
      editableFields: r.editableFields || []
    };
  }
  // 新格式
  return {
    logic: r.logic || 'AND',
    conditions: (r.conditions || []).map((c: any) => ({
      field: c.field || '',
      operator: c.operator || 'eq',
      value: c.value
    })),
    sqlCheck: r.sqlCheck || '',
    enableSql: Boolean(r.sqlCheck),
    editableFields: r.editableFields || []
  };
}

async function loadAvailableFields() {
  try {
    const tables = await fetchTablesByPageCode(props.pageCode);
    if (!tables.length) {
      availableFields.value = [];
      return;
    }
    const { fetchAllPageComponents } = await import('@/service/api/meta-config');
    const allComps = await fetchAllPageComponents();
    const currentComp = allComps?.find(
      (c: any) => c.pageCode === props.pageCode && c.componentKey === props.componentKey
    );
    const targetTable = currentComp?.refTableCode
      ? tables.find((t: any) => t.tableCode === currentComp.refTableCode)
      : tables[0];
    if (!targetTable?.id) {
      availableFields.value = [];
      return;
    }
    const cols = await fetchColumnsByTableId(targetTable.id);
    availableFields.value = cols
      .filter((col: any) => col.columnName)
      .map((col: any) => ({
        label: `${col.columnName} (${col.headerText || col.columnName})`,
        value: col.columnName
      }));
  } catch {
    availableFields.value = [];
  }
}

function addRule() {
  items.value.push({
    logic: 'AND',
    conditions: [{ field: '', operator: 'eq', value: undefined }],
    sqlCheck: '',
    enableSql: false,
    editableFields: []
  });
}

function removeRule(idx: number) {
  items.value.splice(idx, 1);
}

function addCondition(rule: EditableRule) {
  rule.conditions.push({ field: '', operator: 'eq', value: undefined });
}

function removeCondition(rule: EditableRule, idx: number) {
  rule.conditions.splice(idx, 1);
}

function buildJson(): string {
  return JSON.stringify(
    items.value.map(rule => {
      const r: any = {
        logic: rule.logic,
        conditions: rule.conditions.map(c => {
          const cond: any = { field: c.field, operator: c.operator };
          if (needsValue(c.operator) && c.value !== undefined && c.value !== '') cond.value = c.value;
          return cond;
        }),
        editableFields: rule.editableFields
      };
      if (rule.enableSql && rule.sqlCheck?.trim()) {
        r.sqlCheck = rule.sqlCheck.trim();
      }
      return r;
    })
  );
}

async function handleSave() {
  for (const rule of items.value) {
    if (rule.conditions.length === 0 && !rule.enableSql) {
      message.warning('每条规则至少需要一个条件或启用SQL判断');
      return;
    }
    for (const c of rule.conditions) {
      if (!c.field) {
        message.warning('请选择条件字段');
        return;
      }
    }
    if (!rule.editableFields.length) {
      message.warning('请选择可编辑字段');
      return;
    }
  }
  const json = buildJson();
  if (props.ruleRow) {
    saving.value = true;
    try {
      await savePageRule({ ...props.ruleRow, rules: json });
      message.success('单元格可编辑规则已保存');
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
  }
}
</script>

<template>
  <NModal
    :show="show"
    preset="card"
    :title="`单元格可编辑规则 - ${componentKey}`"
    style="width: 760px; max-height: 85vh"
    :mask-closable="true"
    :segmented="{ content: true, footer: true }"
    @update:show="(v: boolean) => emit('update:show', v)"
  >
    <div style="max-height: 65vh; overflow-y: auto">
      <div v-if="items.length === 0" style="padding: 20px 0; text-align: center">
        <NEmpty description="暂无规则，点击下方添加" />
      </div>

      <div v-for="(rule, rIdx) in items" :key="rIdx" class="rule-card">
        <div class="rule-header">
          <NTag size="small" type="info">#{{ rIdx + 1 }}</NTag>
          <span style="flex: 1"></span>
          <NPopconfirm @positive-click="removeRule(rIdx)">
            <template #trigger>
              <NButton size="tiny" quaternary type="error">删除</NButton>
            </template>
            确定删除此规则？
          </NPopconfirm>
        </div>

        <!-- 条件组合 -->
        <div class="section-label">
          条件组合
          <NSelect
            v-model:value="rule.logic"
            size="tiny"
            :options="[
              { label: 'AND (全部满足)', value: 'AND' },
              { label: 'OR (任一满足)', value: 'OR' }
            ]"
            style="width: 160px; display: inline-flex; margin-left: 8px"
          />
        </div>

        <!-- 条件列表 -->
        <div v-for="(cond, cIdx) in rule.conditions" :key="cIdx" class="condition-row">
          <NSelect
            v-model:value="cond.field"
            :options="availableFields"
            size="small"
            filterable
            placeholder="字段"
            style="width: 170px"
          />
          <NSelect v-model:value="cond.operator" :options="operatorOptions" size="small" style="width: 110px" />
          <NInput
            v-if="needsValue(cond.operator)"
            v-model:value="cond.value"
            size="small"
            placeholder="值"
            style="width: 130px"
          />
          <NButton
            size="tiny"
            quaternary
            type="error"
            :disabled="rule.conditions.length <= 1 && !rule.enableSql"
            @click="removeCondition(rule, cIdx)"
          >
            ✕
          </NButton>
        </div>
        <NButton size="tiny" dashed style="margin: 4px 0 8px" @click="addCondition(rule)">+ 添加条件</NButton>

        <!-- SQL 判断 -->
        <div class="section-label" style="margin-top: 6px">
          <NSwitch v-model:value="rule.enableSql" size="small" />
          <span style="margin-left: 6px">启用 SQL 判断</span>
        </div>
        <div v-if="rule.enableSql" style="margin-bottom: 8px">
          <NInput
            v-model:value="rule.sqlCheck"
            type="textarea"
            size="small"
            placeholder="SELECT CASE WHEN ... THEN 1 ELSE 0 END FROM ... WHERE id = :id"
            :autosize="{ minRows: 2, maxRows: 4 }"
          />
          <div class="hint">返回 1 = 可编辑，0 = 不可编辑。:id 自动替换为当前行主键</div>
        </div>

        <!-- 可编辑字段 -->
        <div class="section-label">可编辑字段</div>
        <NSelect
          v-model:value="rule.editableFields"
          :options="availableFields"
          size="small"
          filterable
          multiple
          placeholder="选择允许编辑的字段"
          style="width: 100%"
        />
      </div>
    </div>

    <template #footer>
      <NSpace justify="space-between" size="small">
        <NButton size="small" @click="addRule">+ 新增规则</NButton>
        <NSpace size="small">
          <NButton size="small" @click="emit('update:show', false)">取消</NButton>
          <NButton size="small" type="primary" :loading="saving" @click="handleSave">保存</NButton>
        </NSpace>
      </NSpace>
    </template>
  </NModal>
</template>

<style scoped>
.rule-card {
  border: 1px solid #e8e8e8;
  border-radius: 6px;
  padding: 10px 12px;
  margin-bottom: 10px;
  background: #fafafa;
}
.rule-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}
.section-label {
  font-size: 12px;
  color: #666;
  margin-bottom: 4px;
  display: flex;
  align-items: center;
}
.condition-row {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 4px;
}
.hint {
  font-size: 11px;
  color: #999;
  margin-top: 2px;
}
</style>
