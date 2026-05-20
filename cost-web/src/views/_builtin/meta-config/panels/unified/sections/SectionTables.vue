<script setup lang="ts">
import { computed, ref } from 'vue';
import { NAutoComplete, NButton, NCollapse, NCollapseItem, NDescriptions, NDescriptionsItem, NInput, NModal, NSpace, useMessage } from 'naive-ui';
import { AgGridVue } from 'ag-grid-vue3';
import type { ColDef } from 'ag-grid-community';
import { fetchColumnsByTableId, fetchDbObjects, fetchViewColumns, saveColumnMeta, saveTableMeta as saveTableMetaApi } from '@/service/api/meta-config';
import LookupConfigEditor from './LookupConfigEditor.vue';

const props = defineProps<{
  pageCode: string;
  tables: any[];
  components: any[];
}>();

const emit = defineEmits<{
  (e: 'refresh'): void;
}>();

const message = useMessage();

// 每张表的列数据（按需加载）
const columnsByTable = ref<Record<number, any[]>>({});
const loadingTable = ref<Record<number, boolean>>({});
const dirtyColumns = ref<Record<number, Set<any>>>({});
const dbObjectOptions = ref<string[]>([]);

// 搜索数据库表/视图
async function searchDbObjects(keyword: string) {
  if (!keyword || keyword.length < 2) {
    dbObjectOptions.value = [];
    return;
  }
  try {
    const results = await fetchDbObjects(keyword);
    dbObjectOptions.value = results.map((r: any) => r.OBJECT_NAME || r.objectName || '');
  } catch {
    dbObjectOptions.value = [];
  }
}

const columnDefs: ColDef[] = [
  { field: 'columnName', headerName: '字段名', width: 130, editable: false, rowDrag: true },
  { field: 'headerText', headerName: '标题', width: 120, editable: true },
  { field: 'dataType', headerName: '类型', width: 90, editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: ['text', 'number', 'date', 'select', 'checkbox'] } },
  { field: 'targetColumn', headerName: 'TARGET', width: 130, editable: true },
  { field: 'isVirtual', headerName: '虚拟', width: 55, editable: false,
    valueFormatter: (p: any) => p.value ? '是' : '否' },
  { field: 'visible', headerName: '显示', width: 55, editable: true,
    cellEditor: 'agCheckboxCellEditor', cellRenderer: 'agCheckboxCellRenderer',
    valueGetter: (p: any) => p.data?.visible === 1,
    valueSetter: (p: any) => { p.data.visible = p.newValue ? 1 : 0; return true; } },
  { field: 'editable', headerName: '编辑', width: 55, editable: true,
    cellEditor: 'agCheckboxCellEditor', cellRenderer: 'agCheckboxCellRenderer',
    valueGetter: (p: any) => p.data?.editable === 1,
    valueSetter: (p: any) => { p.data.editable = p.newValue ? 1 : 0; return true; } },
  { field: 'searchable', headerName: '查询', width: 55, editable: true,
    cellEditor: 'agCheckboxCellEditor', cellRenderer: 'agCheckboxCellRenderer',
    valueGetter: (p: any) => p.data?.searchable === 1,
    valueSetter: (p: any) => { p.data.searchable = p.newValue ? 1 : 0; return true; } },
  { field: 'required', headerName: '必填', width: 55, editable: true,
    cellEditor: 'agCheckboxCellEditor', cellRenderer: 'agCheckboxCellRenderer',
    valueGetter: (p: any) => p.data?.required === 1,
    valueSetter: (p: any) => { p.data.required = p.newValue ? 1 : 0; return true; } },
  { field: '_aggFunc', headerName: '求和', width: 55, editable: true,
    cellEditor: 'agCheckboxCellEditor', cellRenderer: 'agCheckboxCellRenderer',
    valueGetter: (p: any) => getRulesConfigProp(p.data, 'aggFunc') === 'sum',
    valueSetter: (p: any) => { setRulesConfigProp(p.data, 'aggFunc', p.newValue ? 'sum' : ''); return true; } },
  { field: '_precision', headerName: '精度', width: 55, editable: true,
    valueGetter: (p: any) => { const v = getRulesConfigProp(p.data, 'precision'); return v != null ? v : ''; },
    valueSetter: (p: any) => { const val = p.newValue === '' || p.newValue == null ? null : Number(p.newValue); setRulesConfigProp(p.data, 'precision', Number.isFinite(val) ? val : null); return true; } },
  { field: '_roundMode', headerName: '取整', width: 70, editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: ['', 'round', 'ceil', 'floor'] },
    valueGetter: (p: any) => getRulesConfigProp(p.data, 'roundMode') || '',
    valueSetter: (p: any) => { setRulesConfigProp(p.data, 'roundMode', p.newValue || null); return true; } },
  { field: 'sortable', headerName: '可排序', width: 55, editable: true,
    cellEditor: 'agCheckboxCellEditor', cellRenderer: 'agCheckboxCellRenderer',
    valueGetter: (p: any) => p.data?.sortable === 1,
    valueSetter: (p: any) => { p.data.sortable = p.newValue ? 1 : 0; return true; } },
  { field: 'width', headerName: '宽度', width: 55, editable: true, cellDataType: 'number' },
  { field: 'cellEditor', headerName: '编辑器', width: 120, editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: ['(无)', '文本', '大文本', '数字', '日期', '下拉', '富文本下拉', '弹窗选择'] },
    valueGetter: (p: any) => {
      const map: Record<string, string> = { '': '(无)', 'agTextCellEditor': '文本', 'agLargeTextCellEditor': '大文本', 'agNumberCellEditor': '数字', 'datePicker': '日期', 'agSelectCellEditor': '下拉', 'agRichSelectCellEditor': '富文本下拉', 'lookup': '弹窗选择' };
      return map[p.data?.cellEditor || ''] || p.data?.cellEditor || '(无)';
    },
    valueSetter: (p: any) => {
      const map: Record<string, string> = { '(无)': '', '文本': 'agTextCellEditor', '大文本': 'agLargeTextCellEditor', '数字': 'agNumberCellEditor', '日期': 'datePicker', '下拉': 'agSelectCellEditor', '富文本下拉': 'agRichSelectCellEditor', '弹窗选择': 'lookup' };
      p.data.cellEditor = map[p.newValue] ?? '';
      return true;
    }
  },
  { field: '_editorValues', headerName: '选项值', width: 160,
    editable: (params: any) => params.data?.cellEditor !== 'lookup',
    cellRenderer: (params: any) => {
      const el = document.createElement('span');
      if (params.data?.cellEditor === 'lookup') {
        // Lookup 类型显示为可点击按钮
        const code = getRulesConfigProp(params.data, 'cellEditorParams')?.lookupCode || '';
        el.textContent = code ? `Lookup: ${code}` : '配置Lookup';
        el.style.color = code ? '#2080f0' : '#999';
        el.style.cursor = 'pointer';
        el.addEventListener('click', () => openLookupEditor(params.data));
      } else {
        // 下拉类型显示逗号分隔的值
        const p = getRulesConfigProp(params.data, 'cellEditorParams');
        el.textContent = p?.values && Array.isArray(p.values) ? p.values.join(',') : '';
      }
      return el;
    },
    valueGetter: (p: any) => {
      if (p.data?.cellEditor === 'lookup') return '';
      const params = getRulesConfigProp(p.data, 'cellEditorParams');
      if (!params || !params.values) return '';
      return Array.isArray(params.values) ? params.values.join(',') : '';
    },
    valueSetter: (p: any) => {
      if (p.data?.cellEditor === 'lookup') return false;
      const val = (p.newValue || '').trim();
      if (!val) {
        setRulesConfigProp(p.data, 'cellEditorParams', null);
      } else {
        const values = val.split(',').map((s: string) => s.trim()).filter(Boolean);
        setRulesConfigProp(p.data, 'cellEditorParams', { values });
      }
      return true;
    }
  },
  { field: 'defaultValue', headerName: '默认值', width: 130, editable: true,
    cellEditor: 'agRichSelectCellEditor',
    cellEditorParams: {
      values: ['', '当前时间', '当前日期', '当前用户ID', '当前人员名称', '当前部门名称', '当前部门ID'],
      allowTyping: true,
      filterList: true
    },
    valueGetter: (p: any) => {
      const raw = p.data?.defaultValue;
      if (!raw) return '';
      try {
        const config = typeof raw === 'string' ? JSON.parse(raw) : raw;
        if (config.type === 'builtin') {
          const map: Record<string, string> = { currentTime: '当前时间', currentDate: '当前日期', currentUserId: '当前用户ID', currentUserName: '当前人员名称', currentDeptName: '当前部门名称', currentDeptId: '当前部门ID' };
          return map[config.value] || String(config.value);
        }
        return String(config.value || '');
      } catch { return String(raw); }
    },
    valueSetter: (p: any) => {
      const val = (p.newValue || '').trim();
      if (!val) { p.data.defaultValue = null; return true; }
      // 检查是否是固有对象
      const builtinMap: Record<string, string> = { '当前时间': 'currentTime', '当前日期': 'currentDate', '当前用户ID': 'currentUserId', '当前人员名称': 'currentUserName', '当前部门名称': 'currentDeptName', '当前部门ID': 'currentDeptId' };
      if (builtinMap[val]) {
        p.data.defaultValue = JSON.stringify({ type: 'builtin', value: builtinMap[val] });
      } else {
        p.data.defaultValue = JSON.stringify({ type: 'static', value: val });
      }
      return true;
    }
  },
  { field: 'displayOrder', headerName: '序号', width: 55, editable: false }
];

const defaultColDef: ColDef = { sortable: false, resizable: true, suppressHeaderMenuButton: true };

// 行样式：虚拟列黄色背景，失效列红色背景
function getRowStyle(params: any) {
  if (!params.data) return undefined;
  if (params.data.isVirtual === 1) {
    return { background: '#fffbe6' }; // 黄色 - 虚拟列
  }
  if (params.data.deleted === 1) {
    return { background: '#fff1f0' }; // 红色 - 失效/已删除
  }
  return undefined;
}

// RULES_CONFIG JSON 读写工具
function getRulesConfigProp(row: any, key: string): any {
  if (!row?.rulesConfig) return null;
  try {
    const config = typeof row.rulesConfig === 'string' ? JSON.parse(row.rulesConfig) : row.rulesConfig;
    return config?.[key] ?? null;
  } catch { return null; }
}

function setRulesConfigProp(row: any, key: string, value: any) {
  let config: any = {};
  if (row.rulesConfig) {
    try { config = typeof row.rulesConfig === 'string' ? JSON.parse(row.rulesConfig) : row.rulesConfig; } catch { config = {}; }
  }
  if (value === null || value === '' || value === undefined) {
    delete config[key];
  } else {
    config[key] = value;
  }
  row.rulesConfig = Object.keys(config).length > 0 ? JSON.stringify(config) : null;
}

// 找出主表和从表
const masterTable = computed(() => props.tables.find(t => !t.parentTableCode));
const detailTables = computed(() => props.tables.filter(t => t.parentTableCode));

async function loadColumns(tableId: number) {
  if (columnsByTable.value[tableId]) return;
  loadingTable.value[tableId] = true;
  try {
    const cols = await fetchColumnsByTableId(tableId);
    columnsByTable.value[tableId] = cols || [];
  } catch {
    message.error('加载列失败');
  } finally {
    loadingTable.value[tableId] = false;
  }
}

function handleCollapseChange(names: string | string[] | number | number[]) {
  const expanded = Array.isArray(names) ? names : [names];
  for (const name of expanded) {
    const tableId = Number(name);
    if (tableId > 0) loadColumns(tableId);
  }
}

function getTableLabel(table: any) {
  const comp = props.components.find((c: any) => c.refTableCode === table.tableCode);
  const type = comp?.componentType === 'DETAIL_GRID' ? '从表' : '主表';
  return `${type}: ${table.tableCode} (${table.tableName || ''})`;
}

function getTableSummary(table: any) {
  const cols = columnsByTable.value[table.id];
  return cols ? `${cols.length} 列` : '';
}

function markDirty(tableId: number, event: any) {
  if (!dirtyColumns.value[tableId]) {
    dirtyColumns.value[tableId] = new Set();
  }
  if (event.data) {
    dirtyColumns.value[tableId].add(event.data);
  }
}

async function saveColumns(tableId: number) {
  const dirty = dirtyColumns.value[tableId];
  if (!dirty || dirty.size === 0) {
    message.info('没有需要保存的修改');
    return;
  }
  try {
    const rows = Array.from(dirty);
    await Promise.all(rows.map((row: any) => saveColumnMeta(row)));
    message.success(`已保存 ${rows.length} 列`);
    dirtyColumns.value[tableId] = new Set();
  } catch (e: any) {
    message.error(e?.message || '保存失败');
  }
}

async function saveTableMeta(table: any) {
  try {
    await saveTableMetaApi(table);
    message.success('表信息已保存');
  } catch (e: any) {
    message.error(e?.message || '保存失败');
  }
}

function onRowDragEnd(tableId: number, event: any) {
  const api = event.api;
  if (!api) return;
  const rows: any[] = [];
  api.forEachNode((node: any) => { if (node.data) rows.push(node.data); });
  rows.forEach((row, idx) => { row.displayOrder = idx + 1; });
  if (!dirtyColumns.value[tableId]) dirtyColumns.value[tableId] = new Set();
  rows.forEach(row => dirtyColumns.value[tableId].add(row));
  api.refreshCells({ force: true });
}

async function reimportColumns(table: any) {
  if (!table.queryView) {
    message.warning('请先配置视图名');
    return;
  }
  try {
    const viewCols = await fetchViewColumns(table.queryView);
    if (!viewCols || viewCols.length === 0) {
      message.error('视图未找到或无列');
      return;
    }
    // 获取目标表列用于对比虚拟/真实
    const targetCols = table.targetTable ? await fetchViewColumns(table.targetTable) : [];
    const targetSet = new Set((targetCols || []).map((c: any) => (c.COLUMN_NAME || '').toUpperCase()));

    const existingCols = columnsByTable.value[table.id] || [];
    const existingMap = new Map(existingCols.map((c: any) => [c.columnName?.toUpperCase(), c]));

    // 找出新列（视图中有但列元数据中没有的）
    const AUDIT = new Set(['DELETED', 'CREATE_TIME', 'UPDATE_TIME', 'CREATE_BY', 'UPDATE_BY']);
    let addedCount = 0;
    for (const vc of viewCols) {
      const colName = (vc.COLUMN_NAME || '').toUpperCase();
      if (AUDIT.has(colName)) continue;
      if (existingMap.has(colName)) continue;
      // 新列
      const isReal = targetSet.has(colName);
      const newCol: any = {
        _isNew: true,
        tableMetadataId: table.id,
        columnName: vc.COLUMN_NAME,
        targetColumn: isReal ? vc.COLUMN_NAME : '',
        headerText: vc.COLUMN_COMMENT || vc.COLUMN_NAME,
        dataType: mapDataType(vc.DATA_TYPE),
        displayOrder: existingCols.length + addedCount + 1,
        isVirtual: isReal ? 0 : 1,
        visible: 1,
        editable: isReal ? 1 : 0,
        searchable: 0,
        sortable: 1,
        filterable: 0
      };
      existingCols.push(newCol);
      addedCount++;
    }

    columnsByTable.value[table.id] = [...existingCols];
    if (addedCount > 0) {
      message.success(`发现 ${addedCount} 个新列，请确认后保存`);
      // 标记新列为脏
      if (!dirtyColumns.value[table.id]) dirtyColumns.value[table.id] = new Set();
      existingCols.filter((c: any) => c._isNew).forEach((c: any) => dirtyColumns.value[table.id].add(c));
    } else {
      message.info('没有新列需要导入');
    }
  } catch (e: any) {
    message.error(e?.message || '导入失败');
  }
}

function mapDataType(oracleType: string): string {
  const upper = (oracleType || '').toUpperCase();
  if (upper.includes('NUMBER') || upper.includes('FLOAT')) return 'number';
  if (upper.includes('DATE') || upper.includes('TIMESTAMP')) return 'date';
  return 'text';
}

// ==================== Lookup 配置弹窗 ====================
const showLookupEditor = ref(false);
const lookupEditingRow = ref<any>(null);
const lookupConfig = ref<any>({});
const lookupAvailableFields = ref<string[]>([]);

function openLookupEditor(row: any) {
  lookupEditingRow.value = row;
  lookupConfig.value = getRulesConfigProp(row, 'cellEditorParams') || {};
  // 收集当前表所有字段名作为 mapping 可选项
  const tableId = findTableIdForRow(row);
  if (tableId) {
    lookupAvailableFields.value = (columnsByTable.value[tableId] || []).map((c: any) => c.columnName);
  }
  showLookupEditor.value = true;
}

function onLookupSave(config: any) {
  if (!lookupEditingRow.value) return;
  setRulesConfigProp(lookupEditingRow.value, 'cellEditorParams', config);
  // 标记脏
  const tableId = findTableIdForRow(lookupEditingRow.value);
  if (tableId) {
    if (!dirtyColumns.value[tableId]) dirtyColumns.value[tableId] = new Set();
    dirtyColumns.value[tableId].add(lookupEditingRow.value);
  }
  showLookupEditor.value = false;
}

function findTableIdForRow(row: any): number | null {
  for (const [tableId, cols] of Object.entries(columnsByTable.value)) {
    if ((cols as any[]).includes(row)) return Number(tableId);
  }
  return null;
}
</script>

<template>
  <div class="section-tables">
    <NCollapse @update:expanded-names="handleCollapseChange">
      <!-- 主表 -->
      <NCollapseItem v-if="masterTable" :title="getTableLabel(masterTable)" :name="masterTable.id">
        <template #header-extra>
          <span class="col-count">{{ getTableSummary(masterTable) }}</span>
        </template>
        <NDescriptions size="small" :column="3" bordered class="table-meta">
          <NDescriptionsItem label="视图">
            <NAutoComplete
              v-model:value="masterTable.queryView"
              :options="dbObjectOptions"
              placeholder="搜索视图..."
              size="small"
              style="width: 220px"
              @update:value="searchDbObjects"
            />
          </NDescriptionsItem>
          <NDescriptionsItem label="目标表">
            <NAutoComplete
              v-model:value="masterTable.targetTable"
              :options="dbObjectOptions"
              placeholder="搜索表..."
              size="small"
              style="width: 220px"
              @update:value="searchDbObjects"
            />
          </NDescriptionsItem>
          <NDescriptionsItem label="PK">
            <NInput v-model:value="masterTable.pkColumn" size="small" style="width: 120px" />
          </NDescriptionsItem>
        </NDescriptions>
        <div class="table-actions">
          <NButton size="tiny" @click="saveTableMeta(masterTable)">保存表信息</NButton>
        </div>
        <div v-if="columnsByTable[masterTable.id]" class="columns-grid">
          <AgGridVue
            class="ag-theme-quartz"
            style="width: 100%"
            :style="{ height: Math.max(350, Math.min(600, (columnsByTable[masterTable.id]?.length || 5) * 35 + 50)) + 'px' }"
            :row-data="columnsByTable[masterTable.id]"
            :column-defs="columnDefs"
            :default-col-def="defaultColDef"
            :get-row-style="getRowStyle"
            :row-drag-managed="true"
            :animate-rows="true"
            @cell-value-changed="(e: any) => markDirty(masterTable.id, e)"
            @row-drag-end="(e: any) => onRowDragEnd(masterTable.id, e)"
          />
          <div class="grid-actions">
            <NSpace size="small">
              <NButton size="small" @click="reimportColumns(masterTable)">从视图重新导入</NButton>
              <NButton size="small" type="primary" @click="saveColumns(masterTable.id)">保存列</NButton>
            </NSpace>
          </div>
        </div>
        <div v-else-if="loadingTable[masterTable.id]" class="loading-hint">加载中...</div>
      </NCollapseItem>

      <!-- 从表 -->
      <NCollapseItem v-for="detail in detailTables" :key="detail.id" :title="getTableLabel(detail)" :name="detail.id">
        <template #header-extra>
          <span class="col-count">FK: {{ detail.parentFkColumn }} | {{ getTableSummary(detail) }}</span>
        </template>
        <NDescriptions size="small" :column="3" bordered class="table-meta">
          <NDescriptionsItem label="视图">
            <NAutoComplete
              v-model:value="detail.queryView"
              :options="dbObjectOptions"
              placeholder="搜索视图..."
              size="small"
              style="width: 220px"
              @update:value="searchDbObjects"
            />
          </NDescriptionsItem>
          <NDescriptionsItem label="目标表">
            <NAutoComplete
              v-model:value="detail.targetTable"
              :options="dbObjectOptions"
              placeholder="搜索表..."
              size="small"
              style="width: 220px"
              @update:value="searchDbObjects"
            />
          </NDescriptionsItem>
          <NDescriptionsItem label="PK">
            <NInput v-model:value="detail.pkColumn" size="small" style="width: 120px" />
          </NDescriptionsItem>
        </NDescriptions>
        <div class="table-actions">
          <NButton size="tiny" @click="saveTableMeta(detail)">保存表信息</NButton>
        </div>
        <div v-if="columnsByTable[detail.id]" class="columns-grid">
          <AgGridVue
            class="ag-theme-quartz"
            style="width: 100%"
            :style="{ height: Math.max(250, Math.min(500, (columnsByTable[detail.id]?.length || 5) * 35 + 50)) + 'px' }"
            :row-data="columnsByTable[detail.id]"
            :column-defs="columnDefs"
            :default-col-def="defaultColDef"
            :get-row-style="getRowStyle"
            :row-drag-managed="true"
            :animate-rows="true"
            @cell-value-changed="(e: any) => markDirty(detail.id, e)"
            @row-drag-end="(e: any) => onRowDragEnd(detail.id, e)"
          />
          <div class="grid-actions">
            <NSpace size="small">
              <NButton size="small" @click="reimportColumns(detail)">从视图重新导入</NButton>
              <NButton size="small" type="primary" @click="saveColumns(detail.id)">保存列</NButton>
            </NSpace>
          </div>
        </div>
        <div v-else-if="loadingTable[detail.id]" class="loading-hint">加载中...</div>
      </NCollapseItem>
    </NCollapse>

    <!-- Lookup 配置弹窗 -->
    <NModal v-model:show="showLookupEditor" preset="card" title="弹窗选择配置" :style="{ width: '650px' }">
      <LookupConfigEditor
        :config="lookupConfig"
        :available-fields="lookupAvailableFields"
        @save="onLookupSave"
        @close="showLookupEditor = false"
      />
    </NModal>
  </div>
</template>

<style scoped>
.section-tables {
  padding: 8px 0;
}
.table-meta {
  margin-bottom: 8px;
}
.table-actions {
  margin-top: 4px;
  margin-bottom: 8px;
}
.columns-grid {
  margin-top: 8px;
}
.col-count {
  font-size: 12px;
  color: #999;
}
.loading-hint {
  padding: 12px;
  color: #999;
  font-size: 13px;
}
.grid-actions {
  margin-top: 8px;
  text-align: right;
}
</style>
