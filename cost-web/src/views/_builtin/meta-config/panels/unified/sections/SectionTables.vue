<script setup lang="ts">
import { computed, ref } from 'vue';
import { NAutoComplete, NButton, NCollapse, NCollapseItem, NDescriptions, NDescriptionsItem, NInput, NSpace, useMessage } from 'naive-ui';
import { AgGridVue } from 'ag-grid-vue3';
import type { ColDef } from 'ag-grid-community';
import { fetchColumnsByTableId, fetchDbObjects, saveColumnMeta, saveTableMeta as saveTableMetaApi } from '@/service/api/meta-config';

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
  { field: 'sortable', headerName: '可排序', width: 55, editable: true,
    cellEditor: 'agCheckboxCellEditor', cellRenderer: 'agCheckboxCellRenderer',
    valueGetter: (p: any) => p.data?.sortable === 1,
    valueSetter: (p: any) => { p.data.sortable = p.newValue ? 1 : 0; return true; } },
  { field: 'width', headerName: '宽度', width: 60, editable: true, cellDataType: 'number' },
  { field: 'cellEditor', headerName: '编辑器', width: 120, editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: ['', 'agNumberCellEditor', 'datePicker', 'agSelectCellEditor', 'agCheckboxCellEditor'] } },
  { field: 'displayOrder', headerName: '序号', width: 55, editable: false }
];

const defaultColDef: ColDef = { sortable: false, resizable: true, suppressHeaderMenuButton: true };

// 行样式：虚拟列黄色背景，失效列红色背景
function getRowStyle(params: any) {
  if (!params.data) return undefined;
  if (params.data.isVirtual === 1) {
    return { background: '#fffbe6' }; // 黄色 - 虚拟列
  }
  // 失效列：columnName 存在但在视图中找不到（targetColumn 为空且非虚拟）
  if (params.data.deleted === 1) {
    return { background: '#fff1f0' }; // 红色 - 失效/已删除
  }
  return undefined;
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
  // 拖拽结束后更新所有行的 displayOrder
  const api = event.api;
  if (!api) return;
  const rows: any[] = [];
  api.forEachNode((node: any) => {
    if (node.data) rows.push(node.data);
  });
  // 重新编号
  rows.forEach((row, idx) => {
    row.displayOrder = idx + 1;
  });
  // 标记所有行为脏
  if (!dirtyColumns.value[tableId]) dirtyColumns.value[tableId] = new Set();
  rows.forEach(row => dirtyColumns.value[tableId].add(row));
  // 刷新显示
  api.refreshCells({ force: true });
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
            <NButton size="small" type="primary" @click="saveColumns(masterTable.id)">保存列</NButton>
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
            <NButton size="small" type="primary" @click="saveColumns(detail.id)">保存列</NButton>
          </div>
        </div>
        <div v-else-if="loadingTable[detail.id]" class="loading-hint">加载中...</div>
      </NCollapseItem>
    </NCollapse>
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
