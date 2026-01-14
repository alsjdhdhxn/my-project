<template>
  <div class="master-detail-page-v2">
    <div v-if="isReady" class="grid-container">
      <AgGridVue
        class="ag-theme-quartz"
        style="width: 100%; height: 100%"
        :rowData="masterRows"
        :columnDefs="masterColumnDefs"
        :defaultColDef="defaultColDef"
        :getRowId="getMasterRowId"
        :getRowClass="getRowClass"
        :rowSelection="rowSelection"
        :autoSizeStrategy="autoSizeStrategy"
        :getContextMenuItems="getMasterContextMenuItems"
        :masterDetail="true"
        :keepDetailRows="true"
        :detailRowAutoHeight="true"
        :detailCellRendererParams="summaryDetailParams"
        :undoRedoCellEditing="true"
        :undoRedoCellEditingLimit="20"
        :rowHeight="28"
        :headerHeight="28"
        @grid-ready="onMasterGridReady"
        @cell-editing-started="onCellEditingStarted"
        @cell-editing-stopped="onCellEditingStopped"
        @cell-value-changed="onMasterCellValueChanged"
        @cell-clicked="onMasterCellClicked"
      />
    </div>
    <div v-else class="loading">
      <NSpin size="large" />
    </div>

    <!-- Lookup 弹窗 -->
    <LookupDialog
      v-if="currentLookupRule"
      ref="lookupDialogRef"
      :lookupCode="currentLookupRule.lookupCode"
      :mapping="currentLookupRule.mapping"
      @select="onLookupSelect"
      @cancel="onLookupCancel"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, shallowRef, onMounted, onUnmounted } from 'vue';
import { useMessage, NSpin } from 'naive-ui';
import { AgGridVue } from 'ag-grid-vue3';
import type { GridApi, ColDef, GridReadyEvent, CellValueChangedEvent } from 'ag-grid-community';
import { fetchPageComponents, searchDynamicData, saveDynamicData } from '@/service/api';
import { loadTableMeta, extractCalcRules, extractLookupRules, type LookupRule } from '@/composables/useMetaColumns';
import { type ParsedPageConfig, type RowData, type CalcRule, type AggRule, parsePageComponents, compileCalcRules, compileAggRules, calcRowFields, calcAggregates, generateTempId, initRowData, parseValidationRules, validateRows, formatValidationErrors, type ValidationRule } from '@/logic/calc-engine';
import LookupDialog from '@/components/meta-v4/LookupDialog.vue';

const props = defineProps<{ pageCode: string }>();
const message = useMessage();

// State
const isReady = ref(false);
const masterGridApi = shallowRef<GridApi | null>(null);
const masterRows = ref<RowData[]>([]);
const masterColumnDefs = shallowRef<ColDef[]>([]);
const pageConfig = shallowRef<ParsedPageConfig | null>(null);
const detailColumnsByTab = shallowRef<Record<string, ColDef[]>>({});
const detailCalcRulesByTab = shallowRef<Record<string, ReturnType<typeof compileCalcRules>>>({});
const detailFkColumnByTab = shallowRef<Record<string, string>>({});
const compiledAggRules = shallowRef<ReturnType<typeof compileAggRules>>([]);
const compiledMasterCalcRules = shallowRef<ReturnType<typeof compileCalcRules>>([]);
const detailCache = new Map<number, Record<string, RowData[]>>();
const broadcastFields = shallowRef<string[]>([]);
let isUserEditing = false; // 标记是否是用户编辑

// 验证规则
const masterValidationRules = shallowRef<ValidationRule[]>([]);
const detailValidationRulesByTab = shallowRef<Record<string, ValidationRule[]>>({});
const masterColumnMeta = shallowRef<any[]>([]);
const detailColumnMetaByTab = shallowRef<Record<string, any[]>>({});

// Lookup 规则
const masterLookupRules = shallowRef<LookupRule[]>([]);
const detailLookupRulesByTab = shallowRef<Record<string, LookupRule[]>>({});

// Lookup 弹窗状态
const lookupDialogRef = ref<InstanceType<typeof LookupDialog> | null>(null);
const currentLookupRule = ref<LookupRule | null>(null);
const currentLookupRowId = ref<number | null>(null);
const currentLookupIsMaster = ref<boolean>(true);
const currentLookupTabKey = ref<string>('');

type PageRule = {
  id?: number;
  pageCode?: string;
  componentKey?: string;
  ruleType?: string;
  rules?: string;
  sortOrder?: number;
};

type PageComponentWithRules = Api.Metadata.PageComponent & {
  rules?: PageRule[];
  children?: PageComponentWithRules[];
};

type ColumnOverrideRule = {
  field?: string;
  fieldName?: string;
  width?: number;
  visible?: boolean;
  editable?: boolean;
  searchable?: boolean;
  required?: boolean;
};

type LookupRuleConfig = {
  field?: string;
  fieldName?: string;
  lookupCode: string;
  mapping: Record<string, string>;
};

function collectPageRules(components: PageComponentWithRules[]): PageRule[] {
  const rules: PageRule[] = [];
  const visit = (component: PageComponentWithRules) => {
    if (Array.isArray(component.rules)) {
      for (const rule of component.rules) {
        const componentKey = rule.componentKey || component.componentKey;
        rules.push({ ...rule, componentKey });
      }
    }
    if (Array.isArray(component.children)) {
      component.children.forEach(visit);
    }
  };
  components.forEach(visit);
  return rules;
}

function groupRulesByComponent(rules: PageRule[]): Map<string, PageRule[]> {
  const map = new Map<string, PageRule[]>();
  for (const rule of rules) {
    if (!rule.componentKey) continue;
    const list = map.get(rule.componentKey) || [];
    list.push(rule);
    map.set(rule.componentKey, list);
  }
  for (const list of map.values()) {
    list.sort((a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0));
  }
  return map;
}

function getComponentRules(
  rulesByComponent: Map<string, PageRule[]>,
  componentKeys: string[]
): PageRule[] {
  for (const key of componentKeys) {
    const rules = rulesByComponent.get(key);
    if (rules && rules.length > 0) return rules;
  }
  return [];
}

function getRuleByType(rules: PageRule[], ruleType: string): PageRule | undefined {
  return rules.find(rule => rule.ruleType === ruleType);
}

function parseRuleArray<T>(rule: PageRule | undefined, label: string): T[] {
  if (!rule?.rules) return [];
  try {
    const raw = typeof rule.rules === 'string' ? JSON.parse(rule.rules) : rule.rules;
    if (!Array.isArray(raw)) {
      console.warn(`[PageRule] ${label} is not an array`);
      return [];
    }
    return raw as T[];
  } catch (error) {
    console.warn(`[PageRule] Failed to parse ${label}`, error);
    return [];
  }
}

function parseValidationRuleConfig(componentKey: string, rules: PageRule[]): ValidationRule[] {
  const rule = getRuleByType(rules, 'VALIDATION');
  const items = parseRuleArray<Record<string, any>>(rule, `${componentKey}.VALIDATION`);
  return items
    .map(item => ({
      field: item.field ?? item.fieldName,
      required: item.required,
      notZero: item.notZero,
      min: item.min,
      max: item.max,
      pattern: item.pattern,
      message: item.message
    }))
    .filter(item => Boolean(item.field));
}

function parseLookupRuleConfig(componentKey: string, rules: PageRule[]): LookupRule[] {
  const rule = getRuleByType(rules, 'LOOKUP');
  const items = parseRuleArray<LookupRuleConfig>(rule, `${componentKey}.LOOKUP`);
  return items
    .filter(item => Boolean(item.field || item.fieldName))
    .map(item => ({
      fieldName: item.field ?? item.fieldName ?? '',
      lookupCode: item.lookupCode,
      mapping: item.mapping
    }));
}

function parseCalcRuleConfig(componentKey: string, rules: PageRule[]): CalcRule[] {
  const rule = getRuleByType(rules, 'CALC');
  return parseRuleArray<CalcRule>(rule, `${componentKey}.CALC`);
}

function parseAggregateRuleConfig(componentKey: string, rules: PageRule[]): AggRule[] {
  const rule = getRuleByType(rules, 'AGGREGATE');
  return parseRuleArray<AggRule>(rule, `${componentKey}.AGGREGATE`);
}

function parseColumnOverrideConfig(componentKey: string, rules: PageRule[]): ColumnOverrideRule[] {
  const rule = getRuleByType(rules, 'COLUMN_OVERRIDE');
  return parseRuleArray<ColumnOverrideRule>(rule, `${componentKey}.COLUMN_OVERRIDE`);
}

function applyColumnOverrides(columns: ColDef[], overrides: ColumnOverrideRule[]): ColDef[] {
  if (!overrides || overrides.length === 0) return columns;
  const overrideMap = new Map<string, ColumnOverrideRule>();
  for (const override of overrides) {
    const key = override.field || override.fieldName;
    if (!key) continue;
    overrideMap.set(key, override);
  }
  return columns.map(col => {
    const field = col.field as string | undefined;
    if (!field) return col;
    const override = overrideMap.get(field);
    if (!override) return col;
    const updated: ColDef = { ...col };
    if (override.width != null) updated.width = override.width;
    if (override.visible != null) updated.hide = override.visible === false;
    if (override.editable != null) updated.editable = override.editable;
    if (override.searchable === false) updated.filter = false;
    if (override.searchable === true && updated.filter === false) updated.filter = true;
    return updated;
  });
}

function attachGroupCellRenderer(columns: ColDef[]): ColDef[] {
  const index = columns.findIndex(col => !col.hide);
  if (index < 0) return columns;
  return columns.map((col, idx) => {
    if (idx !== index) return col;
    return { ...col, cellRenderer: 'agGroupCellRenderer' };
  });
}

// Grid Config
const cellClassRules = {
  'cell-user-changed': (params: any) => {
    const row = params.data;
    const field = params.colDef?.field;
    return row?._dirtyFields?.[field]?.type === 'user';
  },
  'cell-calc-changed': (params: any) => {
    const row = params.data;
    const field = params.colDef?.field;
    return row?._dirtyFields?.[field]?.type === 'calc';
  },
  'cell-new': (params: any) => params.data?._isNew === true,
  'cell-deleted': (params: any) => params.data?._isDeleted === true
};

const defaultColDef: ColDef = { sortable: true, filter: true, resizable: true, editable: true, wrapText: true, autoHeight: true, cellClassRules };
const autoSizeStrategy = { type: 'fitCellContents' as const };
const rowSelection = { mode: 'singleRow' as const, enableClickSelection: true, hideDisabledCheckboxes: true, checkboxes: false };
const getMasterRowId = (params: any) => String(params.data?.id);

function getRowClass(params: any): string | undefined {
  if (params.data?._isDeleted) return 'row-deleted';
  if (params.data?._isNew) return 'row-new';
  return undefined;
}

function getMasterContextMenuItems(params: any) {
  const items: any[] = [
    { name: '新增', action: () => addMasterRow() },
  ];
  if (params.node) {
    items.push({ name: '复制', action: () => copyMasterRow(params.node.data) });
    items.push({ name: '删除', action: () => deleteMasterRow(params.node.data) });
  }
  items.push('separator', { name: '保存', action: () => save() }, 'separator', 'copy', 'paste');
  return items;
}

function getDetailContextMenuItems(masterId: number, tabKey: string) {
  return (params: any) => {
    const items: any[] = [
      { name: '新增', action: () => addDetailRow(masterId, tabKey) },
    ];
    if (params.node) {
      items.push({ name: '复制', action: () => copyDetailRow(masterId, tabKey, params.node.data) });
      items.push({ name: '删除', action: () => deleteDetailRow(masterId, tabKey, params.node.data) });
    }
    items.push('separator', 'copy', 'paste');
    return items;
  };
}

// 第二层：汇总行配置
const summaryDetailParams = {
  refreshStrategy: 'nothing' as const,
  detailGridOptions: {
    columnDefs: [
      { field: 'groupLabel', headerName: '分类', cellRenderer: 'agGroupCellRenderer', minWidth: 150 },
      { field: 'totalAmount', headerName: '合计金额', width: 120, type: 'numericColumn' },
      { field: 'rowCount', headerName: '行数', width: 80, type: 'numericColumn' }
    ],
    defaultColDef: { sortable: false, filter: false, resizable: true },
    rowHeight: 28, headerHeight: 28, masterDetail: true, keepDetailRows: true, detailRowAutoHeight: true,
    getRowId: (params: any) => `${params.data?._masterId}_${params.data?._tabKey}`,
    detailCellRendererParams: { refreshStrategy: 'nothing' as const, getDetailRowData: (params: any) => params.successCallback(params.data?._detailRows || []) }
  },
  getDetailRowData: async (params: any) => {
    const masterId = params.data?.id;
    let cached = detailCache.get(masterId);
    if (!cached) { await loadDetailData(masterId); cached = detailCache.get(masterId); }
    if (!cached) { params.successCallback([]); return; }
    const tabs = pageConfig.value?.tabs || [];
    const summaryRows = tabs.map(tab => {
      const rows = cached![tab.key] || [];
      return { _tabKey: tab.key, _masterId: masterId, groupLabel: tab.title, totalAmount: rows.filter(r => !r._isDeleted).reduce((sum, r) => sum + (Number(r.costBatch) || 0), 0), rowCount: rows.filter(r => !r._isDeleted).length, _detailRows: rows };
    });
    params.successCallback(summaryRows);
  }
};

function updateSecondLevelDetailParams() {
  summaryDetailParams.detailGridOptions.detailCellRendererParams = (params: any) => {
    const tabKey = params.data?._tabKey;
    const masterId = params.data?._masterId;
    const columns = detailColumnsByTab.value[tabKey] || [];
    return {
      refreshStrategy: 'nothing' as const,
      detailGridOptions: {
        columnDefs: columns,
        defaultColDef: { sortable: true, filter: true, resizable: true, editable: true, cellClassRules },
        rowHeight: 28, headerHeight: 28,
        getRowId: (rowParams: any) => String(rowParams.data?.id),
        getRowClass, getContextMenuItems: getDetailContextMenuItems(masterId, tabKey),
        onCellEditingStarted: onCellEditingStarted,
        onCellEditingStopped: onCellEditingStopped,
        onCellValueChanged: (event: any) => onDetailCellValueChanged(event, masterId, tabKey),
        onCellClicked: (event: any) => onDetailCellClicked(event, masterId, tabKey)
      },
      getDetailRowData: (detailParams: any) => detailParams.successCallback(detailParams.data?._detailRows || [])
    };
  };
}

function onMasterGridReady(params: GridReadyEvent) { masterGridApi.value = params.api; params.api.sizeColumnsToFit(); }

function onCellEditingStarted() { isUserEditing = true; }
function onCellEditingStopped() { isUserEditing = false; }

async function onMasterCellValueChanged(event: CellValueChangedEvent) {
  const field = event.colDef?.field;
  const masterId = event.data?.id;
  const row = event.data;
  if (!field || !masterId) return;
  
  const changeType = isUserEditing ? 'user' : 'calc';
  console.log('[主表变更]', field, event.oldValue, '->', event.newValue, changeType);
  markFieldChange(row, field, event.oldValue, event.newValue, changeType);
  masterGridApi.value?.refreshCells({ rowNodes: [event.node], columns: [field], force: true });
  
  if (isUserEditing) {
    runMasterCalc(event.node, row);
    if (broadcastFields.value.includes(field)) await broadcastToDetail(masterId, row);
  }
}

function onDetailCellValueChanged(event: any, masterId: number, tabKey: string) {
  const field = event.colDef?.field;
  const row = event.data;
  if (!field || !masterId) return;
  
  const changeType = isUserEditing ? 'user' : 'calc';
  console.log('[从表变更]', tabKey, field, event.oldValue, '->', event.newValue, changeType);
  markFieldChange(row, field, event.oldValue, event.newValue, changeType);
  event.api?.refreshCells({ rowNodes: [event.node], columns: [field], force: true });
  
  if (isUserEditing) {
    runDetailCalc(event.node, event.api, row, masterId, tabKey);
    recalcAggregates(masterId);
  }
}

function markFieldChange(row: RowData, field: string, oldValue: any, newValue: any, type: 'user' | 'calc') {
  if (!row._dirtyFields) row._dirtyFields = {};
  if (!row._dirtyFields[field]) { row._dirtyFields[field] = { originalValue: oldValue, type }; }
  else {
    if (newValue === row._dirtyFields[field].originalValue) { delete row._dirtyFields[field]; if (Object.keys(row._dirtyFields).length === 0) delete row._dirtyFields; return; }
    if (type === 'user') row._dirtyFields[field].type = 'user';
  }
  console.log('[markFieldChange]', field, type, row._dirtyFields);
}

function runDetailCalc(node: any, api: any, row: RowData, masterId: number, tabKey: string) {
  const masterRow = masterRows.value.find(r => r.id === masterId);
  if (!masterRow) return;
  const calcRules = detailCalcRulesByTab.value[tabKey] || [];
  if (calcRules.length === 0) return;
  const context: Record<string, any> = {};
  for (const field of broadcastFields.value) context[field] = masterRow[field];
  const results = calcRowFields(row, context, calcRules);
  const changedFields: string[] = [];
  for (const [field, value] of Object.entries(results)) {
    if (row[field] !== value) {
      const oldValue = row[field];
      row[field] = value;
      markFieldChange(row, field, oldValue, value, 'calc');
      changedFields.push(field);
    }
  }
  if (changedFields.length > 0) api?.refreshCells({ rowNodes: [node], columns: changedFields, force: true });
}

function runMasterCalc(node: any, row: RowData) {
  if (compiledMasterCalcRules.value.length === 0) return;
  const results = calcRowFields(row, {}, compiledMasterCalcRules.value);
  const changedFields: string[] = [];
  for (const [field, value] of Object.entries(results)) {
    if (row[field] !== value) {
      const oldValue = row[field];
      row[field] = value;
      markFieldChange(row, field, oldValue, value, 'calc');
      changedFields.push(field);
    }
  }
  if (changedFields.length > 0) masterGridApi.value?.refreshCells({ rowNodes: [node], columns: changedFields, force: true });
}

async function broadcastToDetail(masterId: number, masterRow: RowData) {
  let cached = detailCache.get(masterId);
  if (!cached) { await loadDetailData(masterId); cached = detailCache.get(masterId); }
  if (!cached) return;
  const context: Record<string, any> = {};
  for (const field of broadcastFields.value) context[field] = masterRow[field];
  for (const [tabKey, rows] of Object.entries(cached)) {
    const calcRules = detailCalcRulesByTab.value[tabKey] || [];
    if (calcRules.length === 0) continue;
    for (const row of rows) {
      if (row._isDeleted) continue;
      const results = calcRowFields(row, context, calcRules);
      for (const [field, value] of Object.entries(results)) {
        if (row[field] !== value) { const oldValue = row[field]; row[field] = value; markFieldChange(row, field, oldValue, value, 'calc'); }
      }
    }
  }
  refreshAllDetailGrids(masterId);
  recalcAggregates(masterId);
  console.log('[广播完成]', masterId);
}

function refreshAllDetailGrids(masterId: number) {
  const api = masterGridApi.value;
  if (!api) return;
  const secondLevelInfo = api.getDetailGridInfo(`detail_${masterId}`);
  if (!secondLevelInfo?.api) { console.log('[刷新第三层] 第二层未展开'); return; }
  const cached = detailCache.get(masterId);
  if (!cached) return;
  const tabs = pageConfig.value?.tabs || [];
  secondLevelInfo.api.forEachDetailGridInfo((detailInfo: any) => {
    if (!detailInfo?.api) return;
    let tabKey: string | undefined;
    for (const tab of tabs) { if (detailInfo.id?.includes(tab.key)) { tabKey = tab.key; break; } }
    if (!tabKey || !cached[tabKey]) return;
    console.log('[刷新第三层]', tabKey, cached[tabKey].length, '行');
    // 直接刷新整个 Grid，数据已在 cache 中更新
    detailInfo.api.refreshCells({ force: true });
  });
}

function recalcAggregates(masterId: number) {
  const cached = detailCache.get(masterId);
  if (!cached) return;
  const masterNode = masterGridApi.value?.getRowNode(String(masterId));
  if (!masterNode) return;
  const masterRow = masterNode.data;
  const allRows: RowData[] = [];
  for (const rows of Object.values(cached)) allRows.push(...rows.filter(r => !r._isDeleted));
  const results = calcAggregates(allRows, compiledAggRules.value, masterRow as Record<string, any>, 2, pageConfig.value?.postProcess);
  const changedFields: string[] = [];
  for (const [field, value] of Object.entries(results)) {
    if (masterRow[field] !== value) {
      const oldValue = masterRow[field];
      masterRow[field] = value;
      markFieldChange(masterRow, field, oldValue, value, 'calc');
      changedFields.push(field);
    }
  }
  // 级联计算
  if (compiledMasterCalcRules.value.length > 0) {
    const calcResults = calcRowFields(masterRow, {}, compiledMasterCalcRules.value);
    for (const [field, value] of Object.entries(calcResults)) {
      if (masterRow[field] !== value) {
        const oldValue = masterRow[field];
        masterRow[field] = value;
        markFieldChange(masterRow, field, oldValue, value, 'calc');
        changedFields.push(field);
      }
    }
  }
  if (changedFields.length > 0) masterGridApi.value?.refreshCells({ rowNodes: [masterNode], columns: changedFields, force: true });
  refreshSummaryRow(masterId);
  console.log('[聚合计算]', results);
}

function refreshSummaryRow(masterId: number) {
  const api = masterGridApi.value;
  if (!api) return;
  const secondLevelInfo = api.getDetailGridInfo(`detail_${masterId}`);
  if (!secondLevelInfo?.api) return;
  const cached = detailCache.get(masterId);
  if (!cached) return;
  for (const tab of pageConfig.value?.tabs || []) {
    const rows = cached[tab.key] || [];
    const summaryNode = secondLevelInfo.api.getRowNode(`${masterId}_${tab.key}`);
    if (summaryNode) {
      summaryNode.setDataValue('totalAmount', rows.filter(r => !r._isDeleted).reduce((sum, r) => sum + (Number(r.costBatch) || 0), 0));
      summaryNode.setDataValue('rowCount', rows.filter(r => !r._isDeleted).length);
    }
  }
}

function addMasterRow() {
  const newRow = initRowData({ id: generateTempId() }, true);
  masterRows.value.push(newRow);
  setTimeout(() => masterGridApi.value?.ensureIndexVisible(masterRows.value.length - 1), 100);
}

function deleteMasterRow(row: RowData) {
  if (!row) return;
  if (row._isNew) { const idx = masterRows.value.findIndex(r => r.id === row.id); if (idx >= 0) masterRows.value.splice(idx, 1); }
  else { row._isDeleted = true; masterGridApi.value?.refreshCells({ rowNodes: [masterGridApi.value.getRowNode(String(row.id))!] }); }
}

function addDetailRow(masterId: number, tabKey: string) {
  const cached = detailCache.get(masterId);
  if (!cached || !cached[tabKey]) return;
  const fkColumn = detailFkColumnByTab.value[tabKey] || 'masterId';
  const newRow = initRowData({ id: generateTempId(), [fkColumn]: masterId }, true);
  cached[tabKey].push(newRow);
  const secondLevelInfo = masterGridApi.value?.getDetailGridInfo(`detail_${masterId}`);
  if (secondLevelInfo?.api) {
    secondLevelInfo.api.forEachDetailGridInfo((detailInfo: any) => {
      if (detailInfo.id?.includes(tabKey)) detailInfo.api.setGridOption('rowData', cached[tabKey]);
    });
  }
  recalcAggregates(masterId);
}

function deleteDetailRow(masterId: number, tabKey: string, row: RowData) {
  if (!row) return;
  const cached = detailCache.get(masterId);
  if (!cached || !cached[tabKey]) return;
  if (row._isNew) { const idx = cached[tabKey].findIndex(r => r.id === row.id); if (idx >= 0) cached[tabKey].splice(idx, 1); }
  else row._isDeleted = true;
  const secondLevelInfo = masterGridApi.value?.getDetailGridInfo(`detail_${masterId}`);
  if (secondLevelInfo?.api) {
    secondLevelInfo.api.forEachDetailGridInfo((detailInfo: any) => { if (detailInfo.id?.includes(tabKey)) detailInfo.api.refreshCells(); });
  }
  recalcAggregates(masterId);
}

// 复制主表行（包含从表）
async function copyMasterRow(sourceRow: RowData) {
  if (!sourceRow) return;
  const sourceMasterId = sourceRow.id;
  const newMasterId = generateTempId();
  const newRow = initRowData({ id: newMasterId }, true);
  // 复制主表数据字段（排除内部字段和 id）
  for (const [key, value] of Object.entries(sourceRow)) {
    if (!key.startsWith('_') && key !== 'id') newRow[key] = value;
  }
  masterRows.value.push(newRow);
  
  // 复制从表数据
  let sourceCached = detailCache.get(sourceMasterId);
  if (!sourceCached) {
    await loadDetailData(sourceMasterId);
    sourceCached = detailCache.get(sourceMasterId);
  }
  if (sourceCached) {
    const newCached: Record<string, RowData[]> = {};
    for (const [tabKey, rows] of Object.entries(sourceCached)) {
      const fkColumn = detailFkColumnByTab.value[tabKey] || 'masterId';
      newCached[tabKey] = rows.filter(r => !r._isDeleted).map(r => {
        const newDetailRow = initRowData({ id: generateTempId(), [fkColumn]: newMasterId }, true);
        for (const [key, value] of Object.entries(r)) {
          if (!key.startsWith('_') && key !== 'id' && key !== fkColumn) newDetailRow[key] = value;
        }
        return newDetailRow;
      });
    }
    detailCache.set(newMasterId, newCached);
  }
  
  setTimeout(() => masterGridApi.value?.ensureIndexVisible(masterRows.value.length - 1), 100);
}

// 复制从表行
function copyDetailRow(masterId: number, tabKey: string, sourceRow: RowData) {
  if (!sourceRow) return;
  const cached = detailCache.get(masterId);
  if (!cached || !cached[tabKey]) return;
  const fkColumn = detailFkColumnByTab.value[tabKey] || 'masterId';
  const newRow = initRowData({ id: generateTempId(), [fkColumn]: masterId }, true);
  // 复制数据字段
  for (const [key, value] of Object.entries(sourceRow)) {
    if (!key.startsWith('_') && key !== 'id' && key !== fkColumn) newRow[key] = value;
  }
  cached[tabKey].push(newRow);
  const secondLevelInfo = masterGridApi.value?.getDetailGridInfo(`detail_${masterId}`);
  if (secondLevelInfo?.api) {
    secondLevelInfo.api.forEachDetailGridInfo((detailInfo: any) => {
      if (detailInfo.id?.includes(tabKey)) detailInfo.api.setGridOption('rowData', cached[tabKey]);
    });
  }
  recalcAggregates(masterId);
}

// Lookup 点击处理
function onMasterCellClicked(event: any) {
  const field = event.colDef?.field;
  const rowData = event.data;
  if (!field || !rowData) return;
  const rule = masterLookupRules.value.find(r => r.fieldName === field);
  if (!rule) return;
  currentLookupRule.value = rule;
  currentLookupRowId.value = rowData.id;
  currentLookupIsMaster.value = true;
  currentLookupTabKey.value = '';
  lookupDialogRef.value?.open();
}

function onDetailCellClicked(event: any, masterId: number, tabKey: string) {
  const field = event.colDef?.field;
  const rowData = event.data;
  if (!field || !rowData) return;
  const rule = detailLookupRulesByTab.value[tabKey]?.find(r => r.fieldName === field);
  if (!rule) return;
  currentLookupRule.value = rule;
  currentLookupRowId.value = rowData.id;
  currentLookupIsMaster.value = false;
  currentLookupTabKey.value = tabKey;
  lookupDialogRef.value?.open();
}

function onLookupSelect(fillData: Record<string, any>) {
  if (!currentLookupRowId.value) return;
  const rowId = currentLookupRowId.value;
  
  if (currentLookupIsMaster.value) {
    // 主表回填
    const row = masterRows.value.find(r => r.id === rowId);
    if (row) {
      const node = masterGridApi.value?.getRowNode(String(rowId));
      for (const [field, value] of Object.entries(fillData)) {
        if (row[field] !== value) {
          const oldValue = row[field];
          row[field] = value;
          markFieldChange(row, field, oldValue, value, 'user');
        }
      }
      if (node) {
        masterGridApi.value?.refreshCells({ rowNodes: [node], force: true });
        // 触发主表计算
        runMasterCalc(node, row);
      }
    }
  } else {
    // 从表回填
    const tabKey = currentLookupTabKey.value;
    for (const [masterId, tabData] of detailCache.entries()) {
      const rows = tabData[tabKey];
      if (!rows) continue;
      const row = rows.find(r => r.id === rowId);
      if (row) {
        for (const [field, value] of Object.entries(fillData)) {
          if (row[field] !== value) {
            const oldValue = row[field];
            row[field] = value;
            markFieldChange(row, field, oldValue, value, 'user');
          }
        }
        // 刷新第三层 Grid 并触发计算
        const secondLevelInfo = masterGridApi.value?.getDetailGridInfo(`detail_${masterId}`);
        if (secondLevelInfo?.api) {
          secondLevelInfo.api.forEachDetailGridInfo((detailInfo: any) => {
            if (detailInfo.id?.includes(tabKey)) {
              // 找到对应的 node 触发计算
              detailInfo.api.forEachNode((node: any) => {
                if (node.data?.id === rowId) {
                  runDetailCalc(node, detailInfo.api, row, masterId, tabKey);
                }
              });
              detailInfo.api.refreshCells({ force: true });
            }
          });
        }
        // 重新计算聚合
        recalcAggregates(masterId);
        break;
      }
    }
  }
  
  currentLookupRule.value = null;
  currentLookupRowId.value = null;
}

function onLookupCancel() {
  currentLookupRule.value = null;
  currentLookupRowId.value = null;
}

async function save() {
  // 收集需要保存的数据（新增、修改、删除的行）
  const dirtyMaster: RowData[] = [];
  const dirtyDetailByTab: Record<string, RowData[]> = {};
  for (const row of masterRows.value) { 
    if (row._isNew || row._isDeleted || row._dirtyFields) dirtyMaster.push(row); 
  }
  for (const [, tabData] of detailCache.entries()) {
    for (const [tabKey, rows] of Object.entries(tabData)) {
      for (const row of rows) { 
        if (row._isNew || row._isDeleted || row._dirtyFields) { 
          if (!dirtyDetailByTab[tabKey]) dirtyDetailByTab[tabKey] = []; 
          dirtyDetailByTab[tabKey].push(row); 
        } 
      }
    }
  }
  
  if (dirtyMaster.length === 0 && !Object.values(dirtyDetailByTab).some(arr => arr.length > 0)) { 
    message.info('没有需要保存的数据'); 
    return; 
  }

  // 只验证有修改的行（排除删除的行）
  const masterToValidate = dirtyMaster.filter(r => !r._isDeleted);
  if (masterToValidate.length > 0) {
    const masterResult = validateRows(masterToValidate, masterValidationRules.value, masterColumnMeta.value);
    if (!masterResult.valid) {
      message.error('主表验证失败:\n' + formatValidationErrors(masterResult.errors));
      return;
    }
  }
  
  // 验证从表（只验证有修改的行）
  for (const [tabKey, rows] of Object.entries(dirtyDetailByTab)) {
    const rowsToValidate = rows.filter(r => !r._isDeleted);
    if (rowsToValidate.length === 0) continue;
    const rules = detailValidationRulesByTab.value[tabKey] || [];
    const meta = detailColumnMetaByTab.value[tabKey] || [];
    const result = validateRows(rowsToValidate, rules, meta);
    if (!result.valid) {
      const tabTitle = pageConfig.value?.tabs?.find(t => t.key === tabKey)?.title || tabKey;
      message.error(`${tabTitle} 验证失败:\n` + formatValidationErrors(result.errors));
      return;
    }
  }

  // 按主表分组保存
  let successCount = 0;
  const errors: string[] = [];
  
  // 收集所有需要保存的主表ID（主表有修改 或 从表有修改）
  const masterIdsToSave = new Set<number>();
  for (const row of dirtyMaster) {
    masterIdsToSave.add(row.id);
  }
  for (const [masterId, tabData] of detailCache.entries()) {
    for (const rows of Object.values(tabData)) {
      if (rows.some(r => r._isNew || r._isDeleted || r._dirtyFields)) {
        masterIdsToSave.add(masterId);
        break;
      }
    }
  }
  
  // 逐条保存
  const savedMasterIds: number[] = [];
  for (const masterId of masterIdsToSave) {
    const masterRow = masterRows.value.find(r => r.id === masterId);
    if (!masterRow) continue;
    
    // 收集从表修改
    const detailsMap: Record<string, any[]> = {};
    const cached = detailCache.get(masterId);
    if (cached) {
      for (const tab of pageConfig.value?.tabs || []) {
        const rows = cached[tab.key] || [];
        const dirtyRows = rows.filter(r => r._isNew || r._isDeleted || r._dirtyFields);
        if (dirtyRows.length > 0) {
          detailsMap[tab.tableCode] = dirtyRows.map(r => buildRecordItem(r, tab.tableCode));
        }
      }
    }
    
    const params = { 
      pageCode: props.pageCode, 
      master: buildRecordItem(masterRow, pageConfig.value?.masterTableCode || ''),
      details: Object.keys(detailsMap).length > 0 ? detailsMap : undefined
    };
    
    const { error } = await saveDynamicData(params);
    if (error) { 
      errors.push(`主表 ${masterId}: ${error.msg || '保存失败'}`);
    } else {
      successCount++;
      savedMasterIds.push(masterId);
    }
  }
  
  // 清理保存成功的行的状态
  for (const masterId of savedMasterIds) {
    // 清理主表
    const masterRow = masterRows.value.find(r => r.id === masterId);
    if (masterRow) {
      if (masterRow._isDeleted) {
        const idx = masterRows.value.findIndex(r => r.id === masterId);
        if (idx >= 0) masterRows.value.splice(idx, 1);
      } else {
        delete masterRow._dirtyFields;
        masterRow._isNew = false;
      }
    }
    // 清理从表
    const cached = detailCache.get(masterId);
    if (cached) {
      for (const [tabKey, rows] of Object.entries(cached)) {
        cached[tabKey] = rows.filter(r => {
          if (r._isDeleted) return false;
          delete r._dirtyFields;
          r._isNew = false;
          return true;
        });
      }
      // 刷新从表 Grid
      const secondLevelInfo = masterGridApi.value?.getDetailGridInfo(`detail_${masterId}`);
      if (secondLevelInfo?.api) {
        secondLevelInfo.api.forEachDetailGridInfo((detailInfo: any) => {
          detailInfo.api?.refreshCells({ force: true });
        });
      }
    }
  }
  
  // 刷新主表 Grid
  masterGridApi.value?.refreshCells({ force: true });
  
  if (errors.length > 0) {
    message.error(`成功 ${successCount} 条，失败 ${errors.length} 条:\n${errors.join('\n')}`);
  } else {
    message.success('保存成功');
  }
}

function buildRecordItem(row: RowData, tableCode: string) {
  const isNew = row._isNew === true, isDeleted = row._isDeleted === true, dirtyFields = row._dirtyFields || {};
  let status: 'added' | 'modified' | 'deleted' | 'unchanged';
  if (isDeleted) status = 'deleted'; else if (isNew) status = 'added'; else if (Object.keys(dirtyFields).length > 0) status = 'modified'; else status = 'unchanged';
  // 排除视图别名字段（masterId 是 DOCID 的视图别名，不是真实列）
  const excludeFields = ['masterId'];
  const data: Record<string, any> = { _tableCode: tableCode };
  for (const [key, value] of Object.entries(row)) { if (!key.startsWith('_') && !excludeFields.includes(key)) data[key] = value; }
  const changes = Object.entries(dirtyFields).filter(([field]) => !excludeFields.includes(field)).map(([field, info]) => ({ field, oldValue: info.originalValue, newValue: row[field], changeType: info.type }));
  return { id: isNew ? null : row.id, status, data, changes: changes.length > 0 ? changes : undefined };
}

async function loadMetadata() {
  const pageRes = await fetchPageComponents(props.pageCode);
  if (pageRes.error || !pageRes.data) { message.error('加载页面配置失败'); return; }
  const pageComponents = pageRes.data as PageComponentWithRules[];
  const config = parsePageComponents(pageComponents);
  if (!config) { message.error('解析页面配置失败'); return; }
  pageConfig.value = config;
  broadcastFields.value = config.broadcast || [];
  const rulesByComponent = groupRulesByComponent(collectPageRules(pageComponents));
  const masterRules = getComponentRules(rulesByComponent, ['master', 'masterGrid']);
  const masterMeta = await loadTableMeta(config.masterTableCode, props.pageCode);
  if (!masterMeta) { message.error('加载主表元数据失败'); return; }
  const masterOverrides = parseColumnOverrideConfig('master', masterRules);
  const masterColumns = attachGroupCellRenderer(applyColumnOverrides(masterMeta.columns, masterOverrides));
  masterColumnDefs.value = masterColumns;
  // 提取主表验证规则和 Lookup 规则
  masterColumnMeta.value = masterMeta.rawColumns || [];
  const masterValidation = parseValidationRuleConfig('master', masterRules);
  masterValidationRules.value = masterValidation.length > 0 ? masterValidation : parseValidationRules(masterColumnMeta.value);
  const masterLookup = parseLookupRuleConfig('master', masterRules);
  masterLookupRules.value = masterLookup.length > 0 ? masterLookup : extractLookupRules(masterColumnMeta.value);
  
  const masterCalcRules = parseCalcRuleConfig('master', masterRules);
  if (masterCalcRules.length > 0) {
    compiledMasterCalcRules.value = compileCalcRules(masterCalcRules, `${props.pageCode}_master`);
  } else if (config.masterCalcRules?.length) {
    compiledMasterCalcRules.value = compileCalcRules(config.masterCalcRules, `${props.pageCode}_master`);
  }
  const masterAggRules = parseAggregateRuleConfig('master', masterRules);
  if (masterAggRules.length > 0) {
    compiledAggRules.value = compileAggRules(masterAggRules, `${props.pageCode}_agg`);
  } else if (config.aggregates?.length) {
    compiledAggRules.value = compileAggRules(config.aggregates, `${props.pageCode}_agg`);
  }
  for (const tab of config.tabs || []) {
    const tableCode = tab.tableCode || config.detailTableCode;
    if (!tableCode) continue;
    const detailMeta = await loadTableMeta(tableCode, props.pageCode);
    if (!detailMeta) { console.warn(`[加载从表元数据失败] ${tableCode}`); continue; }
    const tabRules = getComponentRules(rulesByComponent, [tab.key]);
    const tabOverrides = parseColumnOverrideConfig(tab.key, tabRules);
    detailColumnsByTab.value[tab.key] = applyColumnOverrides(detailMeta.columns, tabOverrides);
    const fkColumnName = detailMeta.metadata.parentFkColumn;
    detailFkColumnByTab.value[tab.key] = fkColumnName ? (detailMeta.rawColumns.find(col => col.columnName.toUpperCase() === fkColumnName.toUpperCase())?.fieldName || 'masterId') : 'masterId';
    // 提取从表验证规则和 Lookup 规则
    detailColumnMetaByTab.value[tab.key] = detailMeta.rawColumns || [];
    const detailValidation = parseValidationRuleConfig(tab.key, tabRules);
    detailValidationRulesByTab.value[tab.key] = detailValidation.length > 0 ? detailValidation : parseValidationRules(detailMeta.rawColumns || []);
    const detailLookup = parseLookupRuleConfig(tab.key, tabRules);
    detailLookupRulesByTab.value[tab.key] = detailLookup.length > 0 ? detailLookup : extractLookupRules(detailMeta.rawColumns || []);
    
    const detailCalcRules = parseCalcRuleConfig(tab.key, tabRules);
    const calcRules = detailCalcRules.length > 0 ? detailCalcRules : extractCalcRules(detailMeta.rawColumns);
    if (calcRules.length > 0) { detailCalcRulesByTab.value[tab.key] = compileCalcRules(calcRules, `${props.pageCode}_${tab.key}`); console.log(`[从表计算规则] ${tab.key}:`, calcRules.length, '条'); }
  }
  updateSecondLevelDetailParams();
  isReady.value = true;
}

async function loadMasterData() {
  const tableCode = pageConfig.value?.masterTableCode;
  if (!tableCode) return;
  const { data, error } = await searchDynamicData(tableCode, { pageCode: props.pageCode });
  if (error) { message.error('加载主表数据失败'); return; }
  masterRows.value = (data?.list || []).map((row: any) => initRowData(row));
}

async function loadDetailData(masterId: number) {
  const tabs = pageConfig.value?.tabs || [];
  const grouped: Record<string, RowData[]> = {};
  for (const tab of tabs) {
    const tableCode = tab.tableCode || pageConfig.value?.detailTableCode;
    const fkColumn = detailFkColumnByTab.value[tab.key] || 'masterId';
    if (!tableCode) continue;
    const { data, error } = await searchDynamicData(tableCode, { pageCode: props.pageCode, conditions: [{ field: fkColumn, operator: 'eq', value: masterId }] });
    if (error) { console.error(`[加载从表失败] ${tab.key}`, error); grouped[tab.key] = []; continue; }
    grouped[tab.key] = (data?.list || []).map((row: any) => initRowData(row));
  }
  detailCache.set(masterId, grouped);
  console.log('[加载从表]', masterId, Object.keys(grouped).map(k => `${k}: ${grouped[k].length}行`).join(', '));
}

// 键盘快捷键
function onKeyDown(e: KeyboardEvent) {
  if (e.ctrlKey && e.key === 's') {
    e.preventDefault();
    save();
  }
}

onMounted(async () => {
  document.addEventListener('keydown', onKeyDown);
  await loadMetadata();
  await loadMasterData();
});

onUnmounted(() => {
  document.removeEventListener('keydown', onKeyDown);
});
</script>

<style scoped>
.master-detail-page-v2 { width: 100%; height: 100%; display: flex; flex-direction: column; }
.grid-container { flex: 1; min-height: 0; }
.loading { display: flex; justify-content: center; align-items: center; height: 100%; }
:deep(.cell-user-changed) { background-color: #d4edda !important; }
:deep(.cell-calc-changed) { background-color: #fff3cd !important; }
:deep(.cell-new) { background-color: #cce5ff !important; }
:deep(.cell-deleted) { background-color: #f8d7da !important; text-decoration: line-through; }
:deep(.row-deleted) { opacity: 0.5; }
:deep(.row-new) { font-style: italic; }
/* 表头自动换行 */
:deep(.ag-header-cell-label) { white-space: normal !important; line-height: 1.2; }
:deep(.ag-header-cell) { height: auto !important; }
</style>
