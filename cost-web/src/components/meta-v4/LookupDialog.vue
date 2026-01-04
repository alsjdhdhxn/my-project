<template>
  <NModal
    v-model:show="visible"
    preset="card"
    :title="config?.lookupName || '选择'"
    :style="{ width: '700px' }"
    :mask-closable="false"
  >
    <!-- 搜索区 -->
    <div class="lookup-search" v-if="config?.searchColumns?.length">
      <NInput
        v-model:value="searchText"
        placeholder="输入关键字搜索"
        clearable
        @keyup.enter="handleSearch"
      >
        <template #prefix>
          <SvgIcon icon="mdi:magnify" class="text-icon" />
        </template>
      </NInput>
    </div>

    <!-- 数据表格 -->
    <div class="lookup-grid">
      <AgGridVue
        class="ag-theme-alpine"
        style="width: 100%; height: 300px"
        :rowData="rowData"
        :columnDefs="columnDefs"
        :defaultColDef="defaultColDef"
        rowSelection="single"
        @grid-ready="onGridReady"
        @row-double-clicked="onRowDoubleClicked"
        @selection-changed="onSelectionChanged"
      />
    </div>

    <!-- 底部按钮 -->
    <template #footer>
      <NSpace justify="end">
        <NButton @click="handleCancel">取消</NButton>
        <NButton type="primary" :disabled="!selectedRow" @click="handleConfirm">确定</NButton>
      </NSpace>
    </template>
  </NModal>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { NModal, NInput, NButton, NSpace } from 'naive-ui';
import { AgGridVue } from 'ag-grid-vue3';
import type { GridApi, ColDef, GridReadyEvent, RowDoubleClickedEvent, SelectionChangedEvent } from 'ag-grid-community';
import { fetchLookupConfig } from '@/service/api';
import { request } from '@/service/request';
import SvgIcon from '@/components/custom/svg-icon.vue';

// ==================== Props & Emits ====================

const props = defineProps<{
  lookupCode: string;
  mapping: Record<string, string>;  // 回填映射：目标字段 -> 源字段
}>();

const emit = defineEmits<{
  (e: 'select', data: Record<string, any>): void;
  (e: 'cancel'): void;
}>();

// ==================== State ====================

const visible = ref(false);
const config = ref<Api.Metadata.LookupConfig | null>(null);
const rowData = ref<Record<string, any>[]>([]);
const searchText = ref('');
const selectedRow = ref<Record<string, any> | null>(null);
let gridApi: GridApi | null = null;

// ==================== Computed ====================

const columnDefs = computed<ColDef[]>(() => {
  if (!config.value?.displayColumns) return [];
  return config.value.displayColumns.map(col => ({
    field: col.field,
    headerName: col.header,
    width: col.width || 120,
    sortable: true,
    resizable: true
  }));
});

const defaultColDef: ColDef = {
  sortable: true,
  resizable: true
};

// ==================== Methods ====================

async function open() {
  visible.value = true;
  selectedRow.value = null;
  searchText.value = '';
  
  // 加载配置
  if (!config.value) {
    const { data } = await fetchLookupConfig(props.lookupCode);
    if (data) {
      config.value = data;
    }
  }
  
  // 加载数据
  await loadData();
}

async function loadData() {
  if (!config.value?.dataSource) return;
  
  // 使用动态数据接口查询
  // dataSource 可以是表名（如 T_COST_MATERIAL）或 tableCode（如 CostMaterial）
  const tableCode = config.value.dataSource.startsWith('T_COST_') 
    ? toTableCode(config.value.dataSource)
    : config.value.dataSource;
  
  const { data } = await request<{ list: Record<string, any>[] }>({
    url: `/api/data/${tableCode}`,
    params: { page: 1, pageSize: 500 }
  });
  
  rowData.value = data?.list || [];
}

function toTableCode(tableName: string): string {
  // T_COST_MATERIAL -> CostMaterial
  return tableName
    .replace(/^T_COST_/, '')
    .toLowerCase()
    .replace(/_([a-z])/g, (_, c) => c.toUpperCase())
    .replace(/^([a-z])/, (_, c) => c.toUpperCase());
}

function handleSearch() {
  if (!gridApi || !searchText.value) {
    gridApi?.setGridOption('quickFilterText', '');
    return;
  }
  gridApi.setGridOption('quickFilterText', searchText.value);
}

function handleCancel() {
  visible.value = false;
  emit('cancel');
}

function handleConfirm() {
  if (!selectedRow.value) return;
  
  // 根据 mapping 构建回填数据
  const fillData: Record<string, any> = {};
  for (const [targetField, sourceField] of Object.entries(props.mapping)) {
    fillData[targetField] = selectedRow.value[sourceField];
  }
  
  visible.value = false;
  emit('select', fillData);
}

// ==================== Event Handlers ====================

function onGridReady(params: GridReadyEvent) {
  gridApi = params.api;
}

function onRowDoubleClicked(_event: RowDoubleClickedEvent) {
  if (selectedRow.value) {
    handleConfirm();
  }
}

function onSelectionChanged(event: SelectionChangedEvent) {
  const rows = event.api.getSelectedRows();
  selectedRow.value = rows.length > 0 ? rows[0] : null;
}

// ==================== Watch ====================

watch(searchText, () => {
  handleSearch();
});

// ==================== Expose ====================

defineExpose({ open });
</script>

<style scoped>
.lookup-search {
  margin-bottom: 12px;
}

.lookup-grid {
  border: 1px solid #e8e8e8;
  border-radius: 4px;
  overflow: hidden;
}
</style>
