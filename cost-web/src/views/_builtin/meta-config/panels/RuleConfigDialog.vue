<script setup lang="ts">
import { ref, computed, watch, nextTick } from 'vue';
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

// ==================== 类型 ====================
type FormulaMatchType = 'equals' | 'regex';
type FormulaItem = { key: string; expression: string; matchType: FormulaMatchType };
type CalcItem = {
  field: string; expression: string; condition?: string; order?: number;
  isMultiFormula: boolean; formulaField?: string; formulas: FormulaItem[];
};
type AggItem = {
  sourceField?: string; targetField: string; algorithm?: string;
  filter?: string; expression?: string; sourceTab?: string; isExpression: boolean;
};
type ValidationItem = { field: string; rule: string; message: string; value?: any };
type FieldInfo = { fieldName: string; headerText: string; columnName: string };
type TableFieldGroup = { tableCode: string; label: string; isMaster: boolean; isCurrent: boolean; fields: FieldInfo[] };

// ==================== 状态 ====================
const calcItems = ref<CalcItem[]>([]);
const aggItems = ref<AggItem[]>([]);
const validationItems = ref<ValidationItem[]>([]);
const availableFields = ref<{ label: string; value: string }[]>([]);
const fieldGroups = ref<TableFieldGroup[]>([]);
const saving = ref(false);
const sidebarFilter = ref('');

// ==================== 字段插入联动 ====================
// 记录当前聚焦的输入框信息，点击侧边栏字段时追加到该输入框
type ActiveInput = { getValue: () => string; setValue: (v: string) => void; el: HTMLInputElement | null };
const activeInput = ref<ActiveInput | null>(null);

function trackFocus(getValue: () => string, setValue: (v: string) => void, event: FocusEvent) {
  activeInput.value = { getValue, setValue, el: event.target as HTMLInputElement };
}

function insertField(fieldName: string) {
  const ai = activeInput.value;
  if (!ai) { message.info('请先点击一个输入框'); return; }
  const el = ai.el;
  const current = ai.getValue();
  if (el) {
    // 在光标位置插入
    const start = el.selectionStart ?? current.length;
    const end = el.selectionEnd ?? current.length;
    const newVal = current.slice(0, start) + fieldName + current.slice(end);
    ai.setValue(newVal);
    // 恢复焦点和光标位置
    nextTick(() => { el.focus(); el.setSelectionRange(start + fieldName.length, start + fieldName.length); });
  } else {
    ai.setValue(current + fieldName);
  }
}

const titleMap: Record<string, string> = { CALC: '行级计算规则', AGGREGATE: '聚合规则', VALIDATION: '校验规则' };
const dialogTitle = computed(() => `${titleMap[props.ruleType]} - ${props.componentKey}`);
const algorithmOptions = [
  { label: 'SUM (求和)', value: 'SUM' }, { label: 'AVG (平均)', value: 'AVG' },
  { label: 'COUNT (计数)', value: 'COUNT' }, { label: 'MAX (最大)', value: 'MAX' },
  { label: 'MIN (最小)', value: 'MIN' },
];
const formulaMatchTypeOptions = [
  { label: '等值', value: 'equals' },
  { label: '正则', value: 'regex' }
];
const validationRuleOptions = [
  { label: '必填', value: 'required' }, { label: '最小值', value: 'min' },
  { label: '最大值', value: 'max' }, { label: '最小长度', value: 'minLength' },
  { label: '最大长度', value: 'maxLength' }, { label: '正则匹配', value: 'pattern' },
  { label: '自定义', value: 'custom' },
];

// 侧边栏：根据规则类型过滤显示的字段组
const visibleFieldGroups = computed(() => {
  let groups: TableFieldGroup[];
  if (props.ruleType === 'CALC') {
    // 行计算：只显示当前组件自己的表字段（不管是主表还是从表）
    groups = fieldGroups.value.filter(g => g.isCurrent);
  } else {
    // AGGREGATE / VALIDATION：显示全部
    groups = fieldGroups.value;
  }
  const kw = sidebarFilter.value.trim().toLowerCase();
  if (!kw) return groups;
  return groups.map(g => ({
    ...g,
    fields: g.fields.filter(f =>
      f.fieldName.toLowerCase().includes(kw) || f.headerText.toLowerCase().includes(kw)
    ),
  })).filter(g => g.fields.length > 0);
});

watch(() => props.show, async (val) => {
  if (!val) return;
  sidebarFilter.value = '';
  parseRulesJson();
  await loadAvailableFields();
});

// ==================== 解析 ====================
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
            formulas.push({ key, expression: f.expression || '', matchType: f.matchType === 'regex' ? 'regex' : 'equals' });
          }
        }
        return { field: r.field || '', expression: isMulti ? '' : (r.expression || ''),
          condition: r.condition || '', order: r.order,
          isMultiFormula: isMulti, formulaField: r.formulaField || '', formulas };
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
        field: r.field || '', rule: r.rule || 'required', message: r.message || '', value: r.value,
      }));
    }
  } catch { calcItems.value = []; aggItems.value = []; validationItems.value = []; }
}

// ==================== 字段加载（多表） ====================
async function loadAvailableFields() {
  fieldGroups.value = [];
  availableFields.value = [];
  try {
    const tables = await fetchTablesByPageCode(props.pageCode);
    if (!tables.length) return;
    const allComps = await fetchAllPageComponents();
    const currentComp = allComps?.find((c: any) => c.pageCode === props.pageCode && c.componentKey === props.componentKey);
    const masterComp = allComps?.find((c: any) => c.pageCode === props.pageCode && c.componentType === 'GRID');
    const currentRef = currentComp?.refTableCode;
    const masterRef = masterComp?.refTableCode;

    // 加载当前组件表字段
    const currentTable = currentRef ? tables.find((t: any) => t.tableCode === currentRef) : null;
    if (currentTable?.id) {
      const cols = await fetchColumnsByTableId(currentTable.id);
      const fields = cols.filter((c: any) => c.fieldName).map((c: any) => ({
        fieldName: c.fieldName, headerText: c.headerText || '', columnName: c.columnName || '',
      }));
      const isMaster = currentRef === masterRef;
      fieldGroups.value.push({ tableCode: currentRef || '', label: isMaster ? `主表 (${currentRef})` : `当前表 (${currentRef})`, isMaster, isCurrent: true, fields });
      availableFields.value = fields.map(f => ({ label: `${f.fieldName} (${f.headerText || f.columnName})`, value: f.fieldName }));
    }

    // 如果当前不是主表，额外加载主表
    if (masterRef && masterRef !== currentRef) {
      const masterTable = tables.find((t: any) => t.tableCode === masterRef);
      if (masterTable?.id) {
        const cols = await fetchColumnsByTableId(masterTable.id);
        const fields = cols.filter((c: any) => c.fieldName).map((c: any) => ({
          fieldName: c.fieldName, headerText: c.headerText || '', columnName: c.columnName || '',
        }));
        fieldGroups.value.unshift({ tableCode: masterRef, label: `主表 (${masterRef})`, isMaster: true, isCurrent: false, fields });
      }
    }

    // VALIDATION / AGGREGATE：加载同页面其他从表
    if (props.ruleType === 'VALIDATION' || props.ruleType === 'AGGREGATE') {
      const others = (allComps || []).filter((c: any) =>
        c.pageCode === props.pageCode && c.componentType === 'DETAIL_GRID'
        && c.refTableCode && c.refTableCode !== currentRef && c.refTableCode !== masterRef
      );
      for (const comp of others) {
        const table = tables.find((t: any) => t.tableCode === comp.refTableCode);
        if (!table?.id) continue;
        const cols = await fetchColumnsByTableId(table.id);
        const fields = cols.filter((c: any) => c.fieldName).map((c: any) => ({
          fieldName: c.fieldName, headerText: c.headerText || '', columnName: c.columnName || '',
        }));
        fieldGroups.value.push({ tableCode: comp.refTableCode, label: `${comp.componentKey} (${comp.refTableCode})`, isMaster: false, isCurrent: false, fields });
      }
    }
  } catch { /* ignore */ }
}

// ==================== 操作 ====================
function addItem() {
  if (props.ruleType === 'CALC') {
    calcItems.value.push({ field: '', expression: '', condition: '', order: calcItems.value.length, isMultiFormula: false, formulaField: '', formulas: [] });
  } else if (props.ruleType === 'AGGREGATE') {
    aggItems.value.push({ sourceField: '', targetField: '', algorithm: 'SUM', filter: '', expression: '', sourceTab: '', isExpression: false });
  } else {
    validationItems.value.push({ field: '', rule: 'required', message: '', value: undefined });
  }
}

const builtins = new Set(['abs','ceil','floor','round','sqrt','pow','log','exp','min','max','sum','mean','mod','sign','pi','e','true','false','null','undefined','if','else','return','NaN','Infinity']);
function extractIdentifiers(expression: string): string[] {
  const regex = /\b([a-zA-Z_]\w*)\b/g;
  const fields = new Set<string>();
  let m: RegExpExecArray | null;
  while ((m = regex.exec(expression)) !== null) { if (!builtins.has(m[1])) fields.add(m[1]); }
  return Array.from(fields);
}

function buildJson(): string {
  if (props.ruleType === 'CALC') {
    return JSON.stringify(calcItems.value.map(item => {
      if (item.isMultiFormula) {
        const formulas: Record<string, any> = {};
        for (const f of item.formulas) {
          if (f.key) {
            formulas[f.key] = {
              expression: f.expression,
              triggerFields: extractIdentifiers(f.expression),
              matchType: f.matchType || 'equals'
            };
          }
        }
        const r: any = { field: item.field, formulaField: item.formulaField, formulas };
        if (item.condition) r.condition = item.condition;
        if (item.order != null) r.order = item.order;
        return r;
      }
      const r: any = { field: item.field, expression: item.expression, triggerFields: extractIdentifiers(item.expression) };
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
          if (f.matchType === 'regex') {
            try {
              // 仅校验语法合法性
              // eslint-disable-next-line no-new
              new RegExp(f.key);
            } catch {
              message.warning(`${item.field}.${f.key || '(空)'}: 正则表达式无效`);
              return false;
            }
          }
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
    for (const item of validationItems.value) { if (!item.field) { message.warning('字段不能为空'); return false; } }
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
      emit('save', json); emit('update:show', false);
    } catch { message.error('保存失败'); }
    finally { saving.value = false; }
  } else { emit('save', json); emit('update:show', false); }
}
</script>

<template>
  <NModal
    :show="show"
    @update:show="(v: boolean) => emit('update:show', v)"
    preset="card"
    :title="dialogTitle"
    style="width: 1060px; max-height: 85vh"
    :mask-closable="true"
    :segmented="{ content: true, footer: true }"
  >
    <div class="dialog-body">
      <!-- 左侧：规则编辑区 -->
      <div class="rules-area">

        <!-- CALC -->
        <template v-if="ruleType === 'CALC'">
          <NEmpty v-if="calcItems.length === 0" description="暂无计算规则" />
          <div v-for="(item, idx) in calcItems" :key="idx" class="rule-card">
            <div class="rule-header">
              <NTag size="small" :type="item.isMultiFormula ? 'warning' : 'info'">{{ item.isMultiFormula ? '多公式' : '单公式' }}</NTag>
              <span class="rule-index">#{{ idx + 1 }}</span>
              <div style="flex:1" />
              <NSwitch v-model:value="item.isMultiFormula" size="small"><template #checked>多公式</template><template #unchecked>单公式</template></NSwitch>
              <NPopconfirm @positive-click="calcItems.splice(idx, 1)"><template #trigger><NButton size="tiny" quaternary type="error">删除</NButton></template>确定删除？</NPopconfirm>
            </div>
            <div class="rule-row">
              <div class="rule-field"><span class="field-label">目标字段</span><NSelect v-model:value="item.field" :options="availableFields" size="small" filterable tag placeholder="输入或选择" style="width:200px" /></div>
              <div class="rule-field"><span class="field-label">排序</span><NInputNumber v-model:value="item.order" size="small" style="width:80px" /></div>
              <div class="rule-field" style="flex:1"><span class="field-label">条件 (可选)</span><NInput v-model:value="item.condition" size="small" placeholder="如: useFlag !== '包材'" @focus="(e: FocusEvent) => trackFocus(() => item.condition || '', (v) => item.condition = v, e)" /></div>
            </div>
            <template v-if="!item.isMultiFormula">
              <div class="rule-row"><div class="rule-field" style="flex:1"><span class="field-label">表达式</span><NInput v-model:value="item.expression" size="small" placeholder="如: batchQty * price" @focus="(e: FocusEvent) => trackFocus(() => item.expression, (v) => item.expression = v, e)" /></div></div>
            </template>
            <template v-else>
              <div class="rule-row"><div class="rule-field"><span class="field-label">分支字段</span><NSelect v-model:value="item.formulaField" :options="availableFields" size="small" filterable tag placeholder="选择分支依据" style="width:220px" /></div></div>
              <div v-for="(f, fi) in item.formulas" :key="fi" class="formula-card">
                <div class="rule-row">
                  <div class="rule-field">
                    <span class="field-label">匹配方式</span>
                    <NSelect v-model:value="f.matchType" :options="formulaMatchTypeOptions" size="small" style="width:100px" />
                  </div>
                  <div class="rule-field">
                    <span class="field-label">{{ f.matchType === 'regex' ? '正则模式' : '分支值' }}</span>
                    <NInput
                      v-model:value="f.key"
                      size="small"
                      :placeholder="f.matchType === 'regex' ? '如: 桶|说明书|小盒' : '如: A'"
                      style="width:180px"
                    />
                  </div>
                  <div class="rule-field" style="flex:1"><span class="field-label">表达式</span><NInput v-model:value="f.expression" size="small" placeholder="如: apexPl / pPerpack" @focus="(e: FocusEvent) => trackFocus(() => f.expression, (v) => f.expression = v, e)" /></div>
                  <NPopconfirm @positive-click="item.formulas.splice(fi, 1)"><template #trigger><NButton size="tiny" quaternary type="error" style="align-self:flex-end">删除</NButton></template>删除此分支？</NPopconfirm>
                </div>
              </div>
              <NButton size="tiny" dashed @click="item.formulas.push({ key: '', expression: '', matchType: 'equals' })" style="margin-top:4px">+ 添加分支</NButton>
            </template>
          </div>
        </template>

        <!-- AGGREGATE -->
        <template v-if="ruleType === 'AGGREGATE'">
          <NEmpty v-if="aggItems.length === 0" description="暂无聚合规则" />
          <div v-for="(item, idx) in aggItems" :key="idx" class="rule-card">
            <div class="rule-header">
              <NTag size="small" :type="item.isExpression ? 'warning' : 'success'">{{ item.isExpression ? '表达式' : '聚合函数' }}</NTag>
              <span class="rule-index">#{{ idx + 1 }}</span>
              <div style="flex:1" />
              <NSwitch v-model:value="item.isExpression" size="small"><template #checked>表达式</template><template #unchecked>聚合函数</template></NSwitch>
              <NPopconfirm @positive-click="aggItems.splice(idx, 1)"><template #trigger><NButton size="tiny" quaternary type="error">删除</NButton></template>确定删除？</NPopconfirm>
            </div>
            <div class="rule-row"><div class="rule-field"><span class="field-label">目标字段 (主表)</span><NSelect v-model:value="item.targetField" :options="availableFields" size="small" filterable tag placeholder="输入或选择" style="width:200px" /></div></div>
            <template v-if="!item.isExpression">
              <div class="rule-row">
                <div class="rule-field"><span class="field-label">聚合函数</span><NSelect v-model:value="item.algorithm" :options="algorithmOptions" size="small" style="width:160px" /></div>
                <div class="rule-field"><span class="field-label">源字段 (从表)</span><NSelect v-model:value="item.sourceField" :options="availableFields" size="small" filterable tag placeholder="输入或选择" style="width:200px" /></div>
              </div>
              <div class="rule-row">
                <div class="rule-field"><span class="field-label">来源Tab (可选)</span><NInput v-model:value="item.sourceTab" size="small" placeholder="如: CostMaterial" style="width:180px" /></div>
                <div class="rule-field" style="flex:1"><span class="field-label">过滤条件 (可选)</span><NInput v-model:value="item.filter" size="small" placeholder="如: useFlag === '原料'" @focus="(e: FocusEvent) => trackFocus(() => item.filter || '', (v) => item.filter = v, e)" /></div>
              </div>
            </template>
            <template v-else>
              <div class="rule-row"><div class="rule-field" style="flex:1"><span class="field-label">表达式</span><NInput v-model:value="item.expression" size="small" placeholder="如: totalYl + totalFl" @focus="(e: FocusEvent) => trackFocus(() => item.expression || '', (v) => item.expression = v, e)" /></div></div>
            </template>
          </div>
        </template>

        <!-- VALIDATION -->
        <template v-if="ruleType === 'VALIDATION'">
          <NEmpty v-if="validationItems.length === 0" description="暂无校验规则" />
          <div v-for="(item, idx) in validationItems" :key="idx" class="rule-card">
            <div class="rule-header">
              <NTag size="small" type="info">校验</NTag>
              <span class="rule-index">#{{ idx + 1 }}</span>
              <div style="flex:1" />
              <NPopconfirm @positive-click="validationItems.splice(idx, 1)"><template #trigger><NButton size="tiny" quaternary type="error">删除</NButton></template>确定删除？</NPopconfirm>
            </div>
            <div class="rule-row">
              <div class="rule-field"><span class="field-label">字段</span><NSelect v-model:value="item.field" :options="availableFields" size="small" filterable tag placeholder="输入或选择" style="width:200px" /></div>
              <div class="rule-field"><span class="field-label">规则</span><NSelect v-model:value="item.rule" :options="validationRuleOptions" size="small" style="width:140px" /></div>
              <div v-if="item.rule !== 'required'" class="rule-field"><span class="field-label">值</span><NInput v-model:value="item.value" size="small" placeholder="规则值" style="width:140px" /></div>
            </div>
            <div class="rule-row"><div class="rule-field" style="flex:1"><span class="field-label">错误提示</span><NInput v-model:value="item.message" size="small" placeholder="校验失败时的提示信息" /></div></div>
          </div>
        </template>
      </div>

      <!-- 右侧：字段参考侧边栏 -->
      <div class="field-sidebar">
        <div class="sidebar-header">字段参考</div>
        <NInput v-model:value="sidebarFilter" size="tiny" placeholder="搜索字段..." clearable style="margin-bottom:6px" />
        <div class="sidebar-scroll">
          <div v-for="group in visibleFieldGroups" :key="group.tableCode" class="field-group">
            <div class="group-title">
              <NTag size="tiny" :type="group.isMaster ? 'success' : 'info'">{{ group.isMaster ? '主' : '从' }}</NTag>
              <span>{{ group.label }}</span>
            </div>
            <div v-for="f in group.fields" :key="f.fieldName" class="field-item" :title="f.columnName" @mousedown.prevent="insertField(f.fieldName)">
              <span class="field-name">{{ f.fieldName }}</span>
              <span class="field-desc">{{ f.headerText }}</span>
            </div>
          </div>
          <NEmpty v-if="visibleFieldGroups.length === 0" description="无字段" size="small" />
        </div>
      </div>
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
.dialog-body { display: flex; gap: 12px; max-height: 65vh; }
.rules-area { flex: 1; overflow-y: auto; padding-right: 4px; min-width: 0; }
.field-sidebar { width: 220px; flex-shrink: 0; display: flex; flex-direction: column; border-left: 1px solid #e8e8e8; padding-left: 12px; }
.sidebar-header { font-size: 13px; font-weight: 500; color: #333; margin-bottom: 6px; }
.sidebar-scroll { flex: 1; overflow-y: auto; }
.field-group { margin-bottom: 10px; }
.group-title { display: flex; align-items: center; gap: 4px; font-size: 12px; color: #666; margin-bottom: 4px; font-weight: 500; }
.field-item { display: flex; align-items: center; gap: 6px; padding: 2px 4px; font-size: 12px; border-radius: 3px; cursor: pointer; user-select: none; }
.field-item:hover { background: #f0f0f0; }
.field-name { color: #2080f0; font-family: monospace; white-space: nowrap; }
.field-desc { color: #999; font-size: 11px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.rule-card { border: 1px solid #e8e8e8; border-radius: 6px; padding: 10px 12px; margin-bottom: 10px; background: #fafafa; }
.rule-header { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; }
.rule-index { font-size: 12px; color: #999; }
.rule-row { display: flex; align-items: flex-end; gap: 12px; margin-bottom: 6px; flex-wrap: wrap; }
.rule-field { display: flex; flex-direction: column; gap: 2px; }
.field-label { font-size: 12px; color: #666; }
.formula-card { border: 1px dashed #d9d9d9; border-radius: 4px; padding: 8px; margin: 6px 0; background: #fff; }
</style>
