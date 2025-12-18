<template>
  <div :style="{ height: gridHeight + 'px', width: '100%' }">
    <AgGridVue
      style="height: 100%; width: 100%;"
      :theme="theme"
      :columnDefs="columnDefs"
      :rowData="rowData"
      :defaultColDef="defaultColDef"
      :rowSelection="rowSelection"
      @grid-ready="onGridReady"
      @selection-changed="onSelectionChanged"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { AgGridVue } from 'ag-grid-vue3';
import { ModuleRegistry, AllCommunityModule, themeQuartz } from 'ag-grid-community';
import type { GridApi, ColDef } from 'ag-grid-community';
import { fetchDynamicData } from '@/service/api';

// 注册 AG Grid 模块（只注册一次）
if (!(window as any).__AG_GRID_REGISTERED__) {
  ModuleRegistry.registerModules([AllCommunityModule]);
  (window as any).__AG_GRID_REGISTERED__ = true;
}

const theme = themeQuartz;

const props = defineProps<{
  config: Api.Metadata.PageComponent;
  pageContext: any;
}>();

const gridApi = ref<GridApi>();
const rowData = ref<any[]>([]);

// 解析组件配置
const gridConfig = computed(() => {
  try {
    return JSON.parse(props.config.componentConfig || '{}');
  } catch {
    return {};
  }
});

const gridHeight = computed(() => gridConfig.value.height || 400);

// 从 pageContext 获取元数据
const metadata = computed(() => {
  return props.pageContext.metadata[props.config.refTableCode || ''];
});

// 是否是从表（有父表配置）
const isDetailGrid = computed(() => !!metadata.value?.parentTableCode);

// 父表外键字段
const parentFkColumn = computed(() => metadata.value?.parentFkColumn);

// 是否是主表（被其他表关联）
const isMasterGrid = computed(() => {
  // 检查 pageContext.metadata 中是否有表的 parentTableCode 指向当前表
  const currentTableCode = props.config.refTableCode;
  if (!currentTableCode) return false;
  for (const key in props.pageContext.metadata) {
    const meta = props.pageContext.metadata[key];
    if (meta?.parentTableCode === currentTableCode) {
      return true;
    }
  }
  return false;
});

// 主表单选，从表/独立表多选
const rowSelection = computed(() => ({
  mode: isMasterGrid.value ? 'singleRow' : 'multiRow'
} as const));

// 根据元数据生成列定义
const columnDefs = computed<ColDef[]>(() => {
  if (!metadata.value?.columns) return [];
  return metadata.value.columns
    .filter(col => col.fieldName !== 'id' && col.fieldName !== 'orderId')
    .sort((a, b) => a.displayOrder - b.displayOrder)
    .map(col => ({
      field: col.fieldName,
      headerName: col.headerText,
      width: col.width || 150,
      sortable: true,
      filter: col.searchable,
      editable: col.editable
    }));
});

const defaultColDef: ColDef = {
  resizable: true,
  sortable: true
};

function onGridReady(params: { api: GridApi }) {
  gridApi.value = params.api;
  props.pageContext.refresh[props.config.componentKey] = loadData;
}

function onSelectionChanged() {
  const selected = gridApi.value?.getSelectedRows() || [];
  props.pageContext.selectedRows[props.config.componentKey] = selected;
}

async function loadData() {
  if (!props.config.refTableCode) return;
  
  const params: Record<string, any> = {};
  
  // 从表需要根据主表选中行过滤
  if (isDetailGrid.value && parentFkColumn.value) {
    const masterGridKey = gridConfig.value.masterGrid || findMasterGridKey();
    const selectedMaster = props.pageContext.selectedRows[masterGridKey];
    if (!selectedMaster?.length) {
      rowData.value = [];
      return;
    }
    // 使用主表的 id 作为外键过滤条件
    params[parentFkColumn.value] = selectedMaster[0].id;
  }
  
  const { data, error } = await fetchDynamicData(props.config.refTableCode, params);
  if (!error && data) {
    rowData.value = data.list || [];
    
    // 主表加载完成后，自动选中第一行
    if (!isDetailGrid.value && rowData.value.length > 0) {
      setTimeout(() => {
        const firstNode = gridApi.value?.getDisplayedRowAtIndex(0);
        firstNode?.setSelected(true);
      }, 0);
    }
  }
}

// 查找主表 Grid 的 key
function findMasterGridKey(): string {
  // 从 pageContext 中找到 master: true 的 grid
  for (const key in props.pageContext.refresh) {
    if (key.includes('master') || key.includes('Master')) {
      return key;
    }
  }
  return 'masterGrid';
}

// 监听元数据加载完成，主表自动加载数据
watch(
  () => metadata.value,
  (meta) => {
    if (meta && !meta.parentTableCode && gridApi.value) {
      // 主表：元数据加载完成后立即加载数据
      loadData();
    }
  },
  { immediate: true }
);

// 从表：监听主表选中行变化，自动刷新
watch(
  () => {
    if (!isDetailGrid.value) return null;
    const masterGridKey = gridConfig.value.masterGrid || findMasterGridKey();
    return props.pageContext.selectedRows[masterGridKey];
  },
  (newVal) => {
    if (isDetailGrid.value && newVal !== null) {
      loadData();
    }
  },
  { deep: true }
);
</script>
