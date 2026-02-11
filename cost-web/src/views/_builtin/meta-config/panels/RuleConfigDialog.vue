<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import {
  NModal, NButton, NSpace, NSelect, NInput, NInputNumber,
  NEmpty, NPopconfirm, NTag, NSwitch, useMessage
} from 'naive-ui';
import { fetchColumnsByTableId, fetchTablesByPageCode, fetchAllPageComponents, savePageRule } from '@/service/api/meta-config';

const props = defineProps<{
  show: boolean;
  rulesJson: string;
  ruleType: 'CALC' | 'AGGREGATE' | 'VALIDATION';
  pageCode: string;
  componentKey: string;
  ruleRow?: any;
}>();

const emit = defineEmits<{
  (e: 'update:show', value: boolean): void;
  (e: 'save', json: string): void;
}>();

const message = useMessage();

type FormulaItem = { key: string; expression: string; triggerFields: string[] };
type CalcItem = {
  field: string; expression: string; triggerFields: string[];
  condition?: string; order?: number;
  isMultiFormula: boolean; formulaField?: string; formulas: FormulaItem[];
};
type AggItem = {
  sourceField?: string; targetField: string; algorithm?: string;
  filter?: string; expression?: string; sourceTab?: string; isExpression: boolean;
};
type ValidationItem = { field: string; rule: string; message: string; value?: any };

const calcItems = ref<CalcItem[]>([]);
const aggItems = ref<AggItem[]>([]);
const validationItems = ref<ValidationItem[]>([]);
const availableFields = ref<{ label: string; value: string }[]>([]);
const saving = ref(false);

const titleMap: Record<string, string> = { CALC: '行级计算规则', AGGREGATE: '聚合规则', VALIDATION: '校验规则' };
const dialogTitle = computed(() => `${titleMap[props.ruleType]} - ${props.componentKey}`);

const algorithmOptions = [
  { label: 'SUM (求和)', value: 'SUM' },
  { label: 'AVG (平均)', value: 'AVG' },
  { label: 'COUNT (计数)', value: 'COUNT' },
  { label: 'MAX (最大)', value: 'MAX' },
  { label: 'MIN (最小)', value: 'MIN' },
];
const validationRuleOptions = [
  { label: '必填', value: 'required' },
  { label: '最小值', value: 'min' },
  { label: '最大值', value: 'max' },
  { label: '最小长度', value: 'minLength' },
  { label: '最大长度', value: 'maxLength' },
  { label: '正则匹配', value: 'pattern' },
  { label: '自定义', value: 'custom' },
];

watch(() => props.show, async (val) => {
  if (!val) return;
  parseRulesJson();
  await loadAvailableFields();
});

function parseRulesJson() {
  try {
    const arr = props.rulesJson ? JSON.parse(props.rulesJson) : [];
    const list = Array.isArray(arr) ? arr : [];
    if (props.ruleType === 'CALC') {
      calcItems.value = list.map((r: any) => {
        const isMulti = Boolean(r.formulaField && r.formulas);
        const formulas: FormulaItem[] = [];
        if (isMulti && r.formulas) {
          for (const [key, f] of Object.entries(r.formulas as Record<string, any>)) {
            formulas.push({ key, expression: f.expression || '', triggerFields: f.triggerFields || [] });
          }
        }
        return {
          field: r.field || '', expression: isMulti ? '' : (r.expression || ''),
          triggerFields: isMulti ? [] : (r.triggerFields || []),
          condition: r.condition || '', order: r.order,
          isMultiFormula: isMulti, formulaField: r.formulaField || '', formulas,
        };
      });
    } else if (props.ruleType === 'AGGREGATE') {
      aggItems.value = list.map((r: any) => ({
        sourceField: r.sourceField || '', targetField: r.targetField || '',
        algorithm: r.algorithm || 'SUM', filter: r.filter || '',
        expression: r.expression || '', sourceTab: r.sourceTab || '',
        isExpression: Boolean(r.expression && !r.algorithm),
      }));
    } else {
      validationItems.value = list.map((r: any) => ({
        field: r.field || '', rule: r.rule || 'required',
        message: r.message || '', value: r.value,
      }));
    }
  } catch {
    calcItems.value = []; aggItems.value = []; validationItems.value = [];
  }
}

async function loadAvailableFields() {
  try {
    const tables = await fetchTablesByPageCode(props.pageCode);
    if (!tables.length) { availableFields.value = []; return; }
    const allComps = await fetchAllPageComponents();
    const comp = allComps?.find((c: any) => c.pageCode === props.pageCode && c.componentKey === props.componentKey);
    const targetTable = comp?.refTableCode
      ? tables.find((t: any) => t.tableCode === comp.refTableCode)
      : tables[0];
    if (!targetTable?.id) { availableFields.value = []; return; }
    const cols = await fetchColumnsByTableId(targetTable.id);
    availableFields.value = cols
      .filter((col: any) => col.fieldName)
      .map((col: any) => ({ label: `${col.fieldName} (${col.headerText || col.columnName})`, value: col.fieldName }));
  } catch { availableFields.value = []; }
}

function addItem() {
  if (props.ruleType === 'CALC') {
    calcItems.value.push({
      field: '', expression: '', triggerFields: [], condition: '',
      order: calcItems.value.length, isMultiFormula: false, formulaField: '', formulas: [],
    });
  } else if (props.ruleType === 'AGGREGATE') {
    aggItems.value.push({
      sourceField: '', targetField: '', algorithm: 'SUM',
      filter: '', expression: '', sourceTab: '', isExpression: false,
    });
  } else {
    validationItems.value.push({ field: '', rule: 'required', message: '', value: undefined });
  }
}

function buildJson(): string {
  if (props.ruleType === 'CALC') {
    return JSON.stringify(calcItems.value.map(item => {
      if (item.isMultiFormula) {
        const formulas: Record<string, any> = {};
        for (const f of item.formulas) {
          if (!f.key) continue;
          formulas[f.key] = { expression: f.expression, triggerFields: f.triggerFields };
        }
        const r: any = { field: item.field, formulaField: item.formulaField, formulas };
        if (item.condition) r.condition = item.condition;
        if (item.order != null) r.order = item.order;
        return r;
      }
      const r: any = { field: item.field, expression: item.expression, triggerFields: item.triggerFields };
      if (item.condition) r.condition = item.condition;
      if (item.order != null) r.order = item.order;
      return r;
    }));
  }
  if (props.ruleType === 'AGGREGATE') {
    return JSON.stringify(aggItems.value.map(item => {
      if (item.isExpression) return { targetField: item.targetField, expression: item.expression };
      const r: any = { sourceField: item.sourceField, targetField: item.targetField, algorithm: item.algorithm };
      if (item.filter) r.filter = item.filter;
      if (item.sourceTab) r.sourceTab = item.sourceTab;
      return r;
    }));
  }
  return JSON.stringify(validationItems.value.map(item => {
    const r: any = { field: item.field, rule: item.rule, message: item.message };
    if (item.value !== undefined && item.value !== '') r.value = item.value;
    return r;
  }));
}

function validate(): boolean {
  if (props.ruleType === 'CALC') {
    for (const item of calcItems.value) {
      if (!item.field) { message.warning('目标字段不能为空'); return false; }
      if (!item.isMultiFormula && !item.expression) { message.warning(`${item.field}: 表达式不能为空`); return false; }
      if (item.isMultiFormula) {
        if (!item.formulaField) { message.warning(`${item.field}: 分支字段不能为空`); return false; }
        if (item.formulas.length === 0) { message.warning(`${item.field}: 至少需要一个分支`); return false; }
        for (const f of item.formulas) {
          if (!f.key) { message.warning(`${item.field}: 分支值不能为空`); return false; }
          if (!f.expression) { message.warning(`${item.field}.${f.key}: 表达式不能为空`); return false; }
        }
      }
    }
  } else if (props.ruleType === 'AGGREGATE') {
    for (const item of aggItems.value) {
      if (!item.targetField) { message.warning('目标字段不能为空'); return false; }
      if (!item.isExpression && !item.sourceField) { message.warning(`${item.targetField}: 源字段不能为空`); return false; }
      if (item.isExpression && !item.expression) { message.warning(`${item.targetField}: 表达式不能为空`); return false; }
    }
  } else {
    for (const item of validationItems.value) {
      if (!item.field) { message.warning('字段不能为空'); return false; }
    }
  }
  return true;
}

async function handleSave() {
  if (!validate()) return;
  const json = buildJson();
  if (props.ruleRow) {
    saving.value = true;
    try {
      await savePageRule({ ...props.ruleRow, rules: json });
      message.success('规则已保存');
      emit('save', json);
      emit('update:show', false);
    } catch { message.error('保存失败'); }
    finally { saving.value = false; }
  } else {
    emit('save', json);
    emit('update:show', false);
  }
}
</script>

<template>
  <NModal
    :show="show"
    @update:show="(v: boolean) => emit('update:show', v)"
    preset="card"
    :title="dialogTitle"
    style="width: 800px; max-height: 85vh"
    :mask-closable="false"
    :segmented="{ content: true, footer: true }"
  >
    <div style="max-height: 65vh; overflow-y: auto; padding: 4px">

      <!-- ==================== CALC ==================== -->
      <template v-if="ruleType === 'CALC'">
        <NEmpty v-if="calcItems.length === 0" description="暂无计算规则" />
        <div v-for="(item, idx) in calcItems" :key="idx" class="rule-card">
          <div class="rule-header">
            <NTag size="small" :type="item.isMultiFormula ? 'warning' : 'info'">
              {{ item.isMultiFormula ? '多公式' : '单公式' }}
            </NTag>
            <span class="rule-index">#{{ idx + 1 }}</span>
            <div style="flex:1" />
            <NSwitch v-model:value="item.isMultiFormula" size="small">
              <template #checked>多公式</template>
              <template #unchecked>单公式</template>
            </NSwitch>
            <NPopconfirm @positive-click="calcItems.splice(idx, 1)">
              <template #trigger><NButton size="tiny" quaternary type="error">删除</NButton></template>
              确定删除此规则？
            </NPopconfirm>
          </div>
          <div class="rule-row">
            <div class="rule-field">
              <span class="field-label">目标字段</span>
              <NSelect v-model:value="item.field" :options="availableFields" size="small" filterable tag placeholder="输入或选择" style="width: 200px" />
            </div>
            <div class="rule-field">
              <span class="field-label">排序</span>
              <NInputNumber v-model:value="item.order" size="small" style="width: 80px" />
            </div>
            <div class="rule-field" style="flex:1">
              <span class="field-label">条件 (可选)</span>
              <NInput v-model:value="item.condition" size="small" placeholder="如: useFlag !== '包材'" />
            </div>
          </div>
          <!-- 单公式 -->
          <template v-if="!item.isMultiFormula">
            <div class="rule-row">
              <div class="rule-field" style="flex:1">
                <span class="field-label">表达式</span>
                <NInput v-model:value="item.expression" size="small" placeholder="如: batchQty * price" />
              </div>
            </div>
            <div class="rule-row">
              <div class="rule-field" style="flex:1">
                <span class="field-label">触发字段</span>
                <NSelect v-model:value="item.triggerFields" :options="availableFields" size="small" filterable multiple tag placeholder="选择或输入" />
              </div>
            </div>
          </template>
          <!-- 多公式 -->
          <template v-else>
            <div class="rule-row">
              <div class="rule-field">
                <span class="field-label">分支字段</span>
                <NSelect v-model:value="item.formulaField" :options="availableFields" size="small" filterable tag placeholder="选择分支依据" style="width: 220px" />
              </div>
            </div>
            <div v-for="(f, fi) in item.formulas" :key="fi" class="formula-card">
              <div class="rule-row">
                <div class="rule-field">
                  <span class="field-label">分支值</span>
                  <NInput v-model:value="f.key" size="small" placeholder="如: A" style="width: 80px" />
                </div>
                <div class="rule-field" style="flex:1">
                  <span class="field-label">表达式</span>
                  <NInput v-model:value="f.expression" size="small" placeholder="如: apexPl / pPerpack" />
                </div>
                <NPopconfirm @positive-click="item.formulas.splice(fi, 1)">
                  <template #trigger><NButton size="tiny" quaternary type="error" style="align-self:flex-end">删除</NButton></template>
                  删除此分支？
                </NPopconfirm>
              </div>
              <div class="rule-row">
                <div class="rule-field" style="flex:1">
                  <span class="field-label">触发字段</span>
                  <NSelect v-model:value="f.triggerFields" :options="availableFields" size="small" filterable multiple tag placeholder="选择或输入" />
                </div>
              </div>
            </div>
            <NButton size="tiny" dashed @click="item.formulas.push({ key: '', expression: '', triggerFields: [] })" style="margin-top:4px">+ 添加分支</NButton>
          </template>
        </div>
      </template>

      <!-- ==================== AGGREGATE ==================== -->
      <template v-if="ruleType === 'AGGREGATE'">
        <NEmpty v-if="aggItems.length === 0" description="暂无聚合规则" />
        <div v-for="(item, idx) in aggItems" :key="idx" class="rule-card">
          <div class="rule-header">
            <NTag size="small" :type="item.isExpression ? 'warning' : 'success'">
              {{ item.isExpression ? '表达式' : '聚合函数' }}
            </NTag>
            <span class="rule-index">#{{ idx + 1 }}</span>
            <div style="flex:1" />
            <NSwitch v-model:value="item.isExpression" size="small">
              <template #checked>表达式</template>
              <template #unchecked>聚合函数</template>
            </NSwitch>
            <NPopconfirm @positive-click="aggItems.splice(idx, 1)">
              <template #trigger><NButton size="tiny" quaternary type="error">删除</NButton></template>
              确定删除？
            </NPopconfirm>
          </div>
          <div class="rule-row">
            <div class="rule-field">
              <span class="field-label">目标字段 (主表)</span>
              <NSelect v-model:value="item.targetField" :options="availableFields" size="small" filterable tag placeholder="输入或选择" style="width: 200px" />
            </div>
          </div>
          <template v-if="!item.isExpression">
            <div class="rule-row">
              <div class="rule-field">
                <span class="field-label">聚合函数</span>
                <NSelect v-model:value="item.algorithm" :options="algorithmOptions" size="small" style="width: 160px" />
              </div>
              <div class="rule-field">
                <span class="field-label">源字段 (从表)</span>
                <NSelect v-model:value="item.sourceField" :options="availableFields" size="small" filterable tag placeholder="输入或选择" style="width: 200px" />
              </div>
            </div>
            <div class="rule-row">
              <div class="rule-field">
                <span class="field-label">来源Tab (可选)</span>
                <NInput v-model:value="item.sourceTab" size="small" placeholder="如: CostMaterial" style="width: 180px" />
              </div>
              <div class="rule-field" style="flex:1">
                <span class="field-label">过滤条件 (可选)</span>
                <NInput v-model:value="item.filter" size="small" placeholder="如: useFlag === '原料'" />
              </div>
            </div>
          </template>
          <template v-else>
            <div class="rule-row">
              <div class="rule-field" style="flex:1">
                <span class="field-label">表达式</span>
                <NInput v-model:value="item.expression" size="small" placeholder="如: totalYl + totalFl" />
              </div>
            </div>
          </template>
        </div>
      </template>

      <!-- ==================== VALIDATION ==================== -->
      <template v-if="ruleType === 'VALIDATION'">
        <NEmpty v-if="validationItems.length === 0" description="暂无校验规则" />
        <div v-for="(item, idx) in validationItems" :key="idx" class="rule-card">
          <div class="rule-header">
            <NTag size="small" type="info">校验</NTag>
            <span class="rule-index">#{{ idx + 1 }}</span>
            <div style="flex:1" />
            <NPopconfirm @positive-click="validationItems.splice(idx, 1)">
              <template #trigger><NButton size="tiny" quaternary type="error">删除</NButton></template>
              确定删除？
            </NPopconfirm>
          </div>
          <div class="rule-row">
            <div class="rule-field">
              <span class="field-label">字段</span>
              <NSelect v-model:value="item.field" :options="availableFields" size="small" filterable tag placeholder="输入或选择" style="width: 200px" />
            </div>
            <div class="rule-field">
              <span class="field-label">规则</span>
              <NSelect v-model:value="item.rule" :options="validationRuleOptions" size="small" style="width: 140px" />
            </div>
            <div v-if="item.rule !== 'required'" class="rule-field">
              <span class="field-label">值</span>
              <NInput v-model:value="item.value" size="small" placeholder="规则值" style="width: 140px" />
            </div>
          </div>
          <div class="rule-row">
            <div class="rule-field" style="flex:1">
              <span class="field-label">错误提示</span>
              <NInput v-model:value="item.message" size="small" placeholder="校验失败时的提示信息" />
            </div>
          </div>
        </div>
      </template>
    </div>

    <template #footer>
      <NSpace justify="space-between" size="small">
        <NButton size="small" @click="addItem">+ 添加规则</NButton>
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
.rule-index { font-size: 12px; color: #999; }
.rule-row {
  display: flex;
  align-items: flex-end;
  gap: 12px;
  margin-bottom: 6px;
  flex-wrap: wrap;
}
.rule-field { display: flex; flex-direction: column; gap: 2px; }
.field-label { font-size: 12px; color: #666; }
.formula-card {
  border: 1px dashed #d9d9d9;
  border-radius: 4px;
  padding: 8px;
  margin: 6px 0;
  background: #fff;
}
</style>
