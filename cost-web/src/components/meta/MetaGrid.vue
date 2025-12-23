<template>
  <div class="meta-grid" @contextmenu.prevent="onContextMenu">
    <!-- 标题栏 -->
    <div class="meta-grid-header">
      <div class="meta-grid-header-left">
        <NInput
          v-model:value="quickFilterText"
          placeholder="全文搜索..."
          clearable
          size="small"
          class="quick-filter-input"
          @update:value="onQuickFilterChange"
        >
          <template #prefix>
            <span class="i-carbon-search text-14px" />
          </template>
        </NInput>
        <NButton v-if="isMasterGrid" size="small" @click="showAdvancedSearch = true">
          高级查询
        </NButton>
      </div>
      <div class="meta-grid-header-right">
        <span v-if="isMasterGrid" class="selection-info">选中 {{ selectedCount }} 项</span>
        <span v-else class="current-master">当前: {{ currentMasterLabel }}</span>
        <span class="total-info">共 {{ totalCount }} 条</span>
      </div>
    </div>

    <!-- 表格标题 -->
    <div class="meta-grid-title">{{ gridTitle }}</div>

    <!-- AG Grid -->
    <div :style="{ height: gridHeight + 'px', width: '100%' }">
      <AgGridVue
        ref="gridRef"
        style="height: 100%; width: 100%"
        :theme="theme"
        :columnDefs="columnDefs"
        :rowData="rowData"
        :defaultColDef="defaultColDef"
        :rowSelection="rowSelection"
        @grid-ready="onGridReady"
        @selection-changed="onSelectionChanged"
        @cell-clicked="onCellClicked"
        @cell-value-changed="onCellValueChanged"
      />
    </div>

    <!-- 右键菜单 -->
    <NDropdown
      :show="showContextMenu"
      :x="contextMenuX"
      :y="contextMenuY"
      :options="contextMenuOptions"
      placement="bottom-start"
      @clickoutside="showContextMenu = false"
      @select="onContextMenuSelect"
    />

    <!-- 高级查询弹窗 -->
    <NModal v-model:show="showAdvancedSearch" preset="card" title="高级查询" style="width: 600px">
      <NForm :model="advancedForm" label-placement="left" :label-width="80">
        <NGrid :cols="2" :x-gap="12" :y-gap="8">
          <NFormItemGi v-for="col in allSearchableColumns" :key="col.fieldName" :label="col.headerText">
            <NInput
              v-if="col.dataType === 'text'"
              v-model:value="advancedForm[col.fieldName]"
              :placeholder="'请输入' + col.headerText"
              clearable
              size="small"
            />
            <NInputNumber
              v-else-if="col.dataType === 'number'"
              v-model:value="advancedForm[col.fieldName]"
              :placeholder="'请输入' + col.headerText"
              clearable
              size="small"
              class="w-full"
            />
            <NDatePicker
              v-else-if="col.dataType === 'date'"
              v-model:value="advancedForm[col.fieldName]"
              type="date"
              clearable
              size="small"
              class="w-full"
            />
          </NFormItemGi>
        </NGrid>
      </NForm>
      <template #footer>
        <NSpace justify="end">
          <NButton size="small" @click="handleResetAdvanced">重置</NButton>
          <NButton type="primary" size="small" @click="handleAdvancedSearch">查询</NButton>
        </NSpace>
      </template>
    </NModal>

    <!-- Lookup 弹窗 -->
    <MetaLookup ref="lookupRef" :config="currentLookupConfig" @select="onLookupSelect" />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, reactive, h } from 'vue';
import { AgGridVue } from 'ag-grid-vue3';
import { ModuleRegistry, AllCommunityModule, themeQuartz } from 'ag-grid-community';
import type { GridApi, ColDef, CellClickedEvent, CellValueChangedEvent } from 'ag-grid-community';
import { NInput, NButton, NModal, NForm, NFormItemGi, NGrid, NInputNumber, NDatePicker, NSpace, NDropdown, useMessage, useDialog } from 'naive-ui';
import { fetchDynamicData } from '@/service/api';
import MetaLookup from './MetaLookup.vue';

if (!(window as any).__AG_GRID_REGISTERED__) {
  ModuleRegistry.registerModules([AllCommunityModule]);
  (window as any).__AG_GRID_REGISTERED__ = true;
}

const theme = themeQuartz;
const message = useMessage();
const dialog = useDialog();

const props = defineProps<{
  config: Api.Metadata.PageComponent;
  pageContext: any;
}>();

const gridApi = ref<GridApi>();
const rowData = ref<any[]>([]);
const quickFilterText = ref('');
const showAdvancedSearch = ref(false);
const advancedForm = reactive<Record<string, any>>({});
const totalCount = ref(0);

// 右键菜单状态
const showContextMenu = ref(false);
const contextMenuX = ref(0);
const contextMenuY = ref(0);

// Lookup 相关
const lookupRef = ref<InstanceType<typeof MetaLookup>>();
const currentLookupConfig = ref({ tableCode: '', displayField: '', mapping: {} });
const currentLookupRowIndex = ref<number>(-1);

// 变更追踪器
const changeTracker = computed(() => props.pageContext.changeTracker);

const contextMenuOptions = computed(() => [
  { label: '新增', key: 'create', icon: renderIcon('i-carbon-add') },
  { label: '删除', key: 'delete', icon: renderIcon('i-carbon-trash-can'), disabled: selectedCount.value === 0 },
  { type: 'divider', key: 'd1' },
  { label: '刷新', key: 'refresh', icon: renderIcon('i-carbon-refresh') }
]);

function renderIcon(iconClass: string) {
  return () => h('span', { class: iconClass });
}

const gridConfig = computed(() => {
  try {
    return JSON.parse(props.config.componentConfig || '{}');
  } catch {
    return {};
  }
});

const gridHeight = computed(() => gridConfig.value.height || 300);
const gridTitle = computed(() => gridConfig.value.title || metadata.value?.tableName || '');
const tableCode = computed(() => props.config.refTableCode || '');

const metadata = computed(() => props.pageContext.metadata[tableCode.value]);
const isDetailGrid = computed(() => !!metadata.value?.parentTableCode);
const isMasterGrid = computed(() => {
  if (!tableCode.value) return false;
  for (const key in props.pageContext.metadata) {
    if (props.pageContext.metadata[key]?.parentTableCode === tableCode.value) return true;
  }
  return false;
});
const parentFkColumn = computed(() => metadata.value?.parentFkColumn);

const rowSelection = computed(() => {
  if (isMasterGrid.value) {
    return { mode: 'singleRow', checkboxes: false, enableClickSelection: true } as const;
  }
  return { mode: 'multiRow', checkboxes: true, enableClickSelection: true } as const;
});

const selectedCount = computed(() => props.pageContext.selectedRows[props.config.componentKey]?.length || 0);

const currentMasterLabel = computed(() => {
  const masterGridKey = gridConfig.value.masterGrid || findMasterGridKey();
  const selected = props.pageContext.selectedRows[masterGridKey];
  if (selected?.length) {
    return selected[0].orderNo || selected[0].code || selected[0].id || '-';
  }
  return '-';
});

function parseRulesConfig(col: Api.Metadata.ColumnMetadata) {
  try {
    return JSON.parse(col.rulesConfig || '{}');
  } catch {
    return {};
  }
}

const columnDefs = computed<ColDef[]>(() => {
  if (!metadata.value?.columns) return [];
  return metadata.value.columns
    .filter(col => col.fieldName !== 'id' && col.fieldName !== 'orderId')
    .sort((a, b) => a.displayOrder - b.displayOrder)
    .map(col => {
      const rules = parseRulesConfig(col);
      const colDef: ColDef = {
        field: col.fieldName,
        headerName: col.headerText,
        width: col.width || 120,
        sortable: true,
        filter: col.searchable,
        editable: col.editable && !rules.lookup
      };
      if (rules.lookup) {
        colDef.cellClass = 'lookup-cell';
        colDef.cellStyle = { cursor: 'pointer', color: '#1890ff' };
      }
      return colDef;
    });
});

function getLookupConfig(fieldName: string) {
  const col = metadata.value?.columns?.find((c: Api.Metadata.ColumnMetadata) => c.fieldName === fieldName);
  if (!col) return null;
  const rules = parseRulesConfig(col);
  return rules.lookup || null;
}

const allSearchableColumns = computed(() => {
  const cols: Api.Metadata.ColumnMetadata[] = [];
  for (const key in props.pageContext.metadata) {
    const meta = props.pageContext.metadata[key];
    if (meta?.columns) {
      meta.columns.filter((c: Api.Metadata.ColumnMetadata) => c.searchable).forEach((c: Api.Metadata.ColumnMetadata) => {
        cols.push({ ...c, headerText: `${meta.tableName}-${c.headerText}` });
      });
    }
  }
  return cols;
});

const defaultColDef: ColDef = { resizable: true, sortable: true };

function onGridReady(params: { api: GridApi }) {
  gridApi.value = params.api;
  props.pageContext.refresh[props.config.componentKey] = loadData;
}

function onSelectionChanged() {
  const selected = gridApi.value?.getSelectedRows() || [];
  props.pageContext.selectedRows[props.config.componentKey] = selected;

  // 主表选中时，初始化变更追踪
  if (isMasterGrid.value && selected.length === 1 && changeTracker.value) {
    const row = selected[0];
    // 检查是否切换了主表行
    if (props.pageContext.currentMasterId !== row.id) {
      // 如果有未保存的修改，提示用户
      if (changeTracker.value.isDirty.value) {
        dialog.warning({
          title: '提示',
          content: '有未保存的修改，是否放弃？',
          positiveText: '放弃',
          negativeText: '取消',
          onPositiveClick: () => {
            changeTracker.value.reset();
            initMasterTracking(row);
          },
          onNegativeClick: () => {
            // 恢复选中之前的行
            const prevId = props.pageContext.currentMasterId;
            if (prevId) {
              const prevRow = rowData.value.find(r => r.id === prevId);
              if (prevRow) {
                setTimeout(() => {
                  gridApi.value?.forEachNode(node => {
                    if (node.data?.id === prevId) node.setSelected(true);
                  });
                }, 0);
              }
            }
          }
        });
      } else {
        initMasterTracking(row);
      }
    }
  }
}

function initMasterTracking(row: any) {
  props.pageContext.currentMasterId = row.id;
  changeTracker.value?.initMaster(tableCode.value, row);
}

function onQuickFilterChange(value: string) {
  gridApi.value?.setGridOption('quickFilterText', value);
}

// 单元格值变更 - 追踪变更
function onCellValueChanged(event: CellValueChangedEvent) {
  if (!changeTracker.value || !event.colDef.field) return;

  const field = event.colDef.field;
  const oldValue = event.oldValue;
  const newValue = event.newValue;
  const rowId = event.data?.id;

  if (isMasterGrid.value) {
    changeTracker.value.trackMasterChange(field, oldValue, newValue);
  } else if (rowId) {
    changeTracker.value.trackDetailChange(tableCode.value, rowId, field, oldValue, newValue);
  }

  // 同步到 rowData
  const idx = rowData.value.findIndex(r => r.id === rowId);
  if (idx >= 0) {
    rowData.value[idx][field] = newValue;
  }
}

function onCellClicked(event: CellClickedEvent) {
  const fieldName = event.colDef.field;
  if (!fieldName) return;

  const lookupConfig = getLookupConfig(fieldName);
  if (lookupConfig) {
    currentLookupConfig.value = lookupConfig;
    currentLookupRowIndex.value = event.rowIndex ?? -1;
    lookupRef.value?.open();
  }
}

function onLookupSelect(data: Record<string, any>) {
  if (currentLookupRowIndex.value < 0) return;

  const rowNode = gridApi.value?.getDisplayedRowAtIndex(currentLookupRowIndex.value);
  if (rowNode) {
    const oldData = { ...rowNode.data };
    const updatedData = { ...rowNode.data, ...data };
    rowNode.setData(updatedData);

    // 追踪变更
    if (changeTracker.value) {
      for (const [field, newValue] of Object.entries(data)) {
        const oldValue = oldData[field];
        if (oldValue !== newValue) {
          if (isMasterGrid.value) {
            changeTracker.value.trackMasterChange(field, oldValue, newValue);
          } else if (oldData.id) {
            changeTracker.value.trackDetailChange(tableCode.value, oldData.id, field, oldValue, newValue);
          }
        }
      }
    }

    const idx = rowData.value.findIndex(r => r.id === updatedData.id);
    if (idx >= 0) rowData.value[idx] = updatedData;
  }
}

function onContextMenu(e: MouseEvent) {
  e.preventDefault();
  showContextMenu.value = true;
  contextMenuX.value = e.clientX;
  contextMenuY.value = e.clientY;
}

function onContextMenuSelect(key: string) {
  showContextMenu.value = false;
  switch (key) {
    case 'create':
      handleCreate();
      break;
    case 'delete':
      handleDelete();
      break;
    case 'refresh':
      loadData();
      break;
  }
}

function handleCreate() {
  // 新增空行
  const newRow: Record<string, any> = { id: null };
  metadata.value?.columns?.forEach((col: Api.Metadata.ColumnMetadata) => {
    newRow[col.fieldName] = null;
  });

  if (isDetailGrid.value && parentFkColumn.value) {
    const masterGridKey = gridConfig.value.masterGrid || findMasterGridKey();
    const selectedMaster = props.pageContext.selectedRows[masterGridKey];
    if (selectedMaster?.length) {
      const fkFieldName = parentFkColumn.value.replace(/_([a-z])/g, (_, c) => c.toUpperCase()).replace(/^./, c => c.toLowerCase());
      newRow[fkFieldName] = selectedMaster[0].id;
    }
  }

  rowData.value.push(newRow);
  changeTracker.value?.addDetailRow(tableCode.value, newRow);

  // 滚动到新行并开始编辑
  setTimeout(() => {
    const lastIndex = rowData.value.length - 1;
    gridApi.value?.ensureIndexVisible(lastIndex);
    const firstEditableCol = columnDefs.value.find(c => c.editable);
    if (firstEditableCol?.field) {
      gridApi.value?.startEditingCell({ rowIndex: lastIndex, colKey: firstEditableCol.field });
    }
  }, 100);
}

function handleDelete() {
  const selected = props.pageContext.selectedRows[props.config.componentKey];
  if (!selected?.length) {
    message.warning('请选择要删除的数据');
    return;
  }

  dialog.warning({
    title: '确认删除',
    content: `确定删除选中的 ${selected.length} 条数据？`,
    positiveText: '确定',
    negativeText: '取消',
    onPositiveClick: () => {
      for (const row of selected) {
        if (row.id) {
          // 已有数据标记删除
          changeTracker.value?.deleteDetailRow(tableCode.value, row.id);
        }
        // 从显示中移除
        const idx = rowData.value.findIndex(r => r.id === row.id);
        if (idx >= 0) rowData.value.splice(idx, 1);
      }
      message.success('已标记删除，保存后生效');
    }
  });
}

function handleAdvancedSearch() {
  showAdvancedSearch.value = false;
  loadData();
}

function handleResetAdvanced() {
  Object.keys(advancedForm).forEach(k => (advancedForm[k] = undefined));
}

async function loadData() {
  if (!tableCode.value) return;

  const params: Record<string, any> = { ...advancedForm };

  if (isDetailGrid.value && parentFkColumn.value) {
    const masterGridKey = gridConfig.value.masterGrid || findMasterGridKey();
    const selectedMaster = props.pageContext.selectedRows[masterGridKey];
    if (!selectedMaster?.length) {
      rowData.value = [];
      totalCount.value = 0;
      return;
    }
    const currentMasterId = selectedMaster[0].id;
    params[parentFkColumn.value] = currentMasterId;

    // 从表：检查是否有当前主表对应的缓存数据
    if (changeTracker.value) {
      const cachedData = changeTracker.value.getDetailData(tableCode.value);
      const fkFieldName = parentFkColumn.value
        .replace(/_([a-z])/g, (_: string, c: string) => c.toUpperCase())
        .replace(/^./, (c: string) => c.toLowerCase());
      if (cachedData.length > 0 && cachedData[0]?.[fkFieldName] === currentMasterId) {
        rowData.value = cachedData;
        totalCount.value = cachedData.length;
        return;
      }
    }
  }

  const { data, error } = await fetchDynamicData(tableCode.value, params);
  if (!error && data) {
    rowData.value = data.list || [];
    totalCount.value = data.total || 0;

    // 初始化从表变更追踪
    if (isDetailGrid.value && changeTracker.value) {
      changeTracker.value.initDetails(tableCode.value, rowData.value);
    }

    // 主表自动选中第一行
    if (!isDetailGrid.value && rowData.value.length > 0) {
      setTimeout(() => gridApi.value?.getDisplayedRowAtIndex(0)?.setSelected(true), 0);
    }
  }
}

function findMasterGridKey(): string {
  for (const key in props.pageContext.refresh) {
    if (key.toLowerCase().includes('master')) return key;
  }
  return 'masterGrid';
}

watch(() => metadata.value, (meta) => {
  if (meta && !meta.parentTableCode && gridApi.value) loadData();
}, { immediate: true });

// 从表不再自动监听主表变化，由 MetaTabs 控制按需加载
</script>

<style scoped>
.meta-grid {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.meta-grid-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 4px 0;
}
.meta-grid-header-left {
  display: flex;
  align-items: center;
  gap: 8px;
}
.quick-filter-input {
  width: 200px;
}
.meta-grid-header-right {
  display: flex;
  align-items: center;
  gap: 12px;
  font-size: 12px;
  color: #666;
}
.meta-grid-title {
  font-size: 14px;
  font-weight: 500;
  padding: 4px 0;
  border-bottom: 1px solid #e8e8e8;
}
</style>
