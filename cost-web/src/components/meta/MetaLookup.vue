<template>
  <NModal v-model:show="visible" preset="card" :title="title" style="width: 700px">
    <!-- 搜索栏 -->
    <div class="lookup-search">
      <NInput
        v-model:value="searchText"
        placeholder="输入关键词搜索..."
        clearable
        size="small"
        @update:value="onSearch"
      >
        <template #prefix>
          <span class="i-carbon-search" />
        </template>
      </NInput>
    </div>

    <!-- 表格 -->
    <div class="lookup-grid">
      <AgGridVue
        style="height: 300px; width: 100%"
        :theme="theme"
        :columnDefs="columnDefs"
        :rowData="rowData"
        :defaultColDef="defaultColDef"
        :rowSelection="rowSelection"
        @grid-ready="onGridReady"
        @row-double-clicked="onRowDoubleClick"
      />
    </div>

    <template #footer>
      <NSpace justify="end">
        <NButton size="small" @click="visible = false">取消</NButton>
        <NButton type="primary" size="small" @click="handleConfirm">确定</NButton>
      </NSpace>
    </template>
  </NModal>
</template>

<script setup lang="ts">
import { ref, computed, watch, nextTick } from 'vue';
import { NModal, NInput, NButton, NSpace } from 'naive-ui';
import { AgGridVue } from 'ag-grid-vue3';
import { themeQuartz } from 'ag-grid-community';
import type { GridApi, ColDef } from 'ag-grid-community';
import { fetchTableMetadata, fetchDynamicData } from '@/service/api';

const theme = themeQuartz;

interface LookupConfig {
  tableCode: string;
  displayField: string;
  mapping: Record<string, string>;
  title?: string;
}

const props = defineProps<{
  config: LookupConfig;
}>();

const emit = defineEmits<{
  select: [data: Record<string, any>];
}>();

const visible = ref(false);
const searchText = ref('');
const gridApi = ref<GridApi>();
const rowData = ref<any[]>([]);
const metadata = ref<Api.Metadata.TableMetadata | null>(null);
const loading = ref(false);

const title = computed(() => props.config.title || '选择');

const columnDefs = computed<ColDef[]>(() => {
  if (!metadata.value?.columns) return [];
  return metadata.value.columns
    .filter(col => col.fieldName !== 'id')
    .sort((a, b) => a.displayOrder - b.displayOrder)
    .map(col => ({
      field: col.fieldName,
      headerName: col.headerText,
      width: col.width || 120
    }));
});

const defaultColDef: ColDef = { resizable: true, sortable: true };

const rowSelection = { mode: 'singleRow', checkboxes: false, enableClickSelection: true } as const;

// 打开弹窗
function open() {
  searchText.value = '';
  rowData.value = [];
  visible.value = true;
}

// 监听弹窗显示，Grid 准备好后加载数据
watch(visible, async (val) => {
  if (val && props.config.tableCode) {
    await nextTick();
    await loadMetadata();
    await loadData();
  }
});

// 加载元数据
async function loadMetadata() {
  if (!props.config.tableCode) return;
  const { data } = await fetchTableMetadata(props.config.tableCode);
  if (data) metadata.value = data;
}

// 加载数据
async function loadData() {
  if (!props.config.tableCode) return;
  loading.value = true;
  const { data } = await fetchDynamicData(props.config.tableCode, {});
  if (data) rowData.value = data.list || [];
  loading.value = false;
}

function onGridReady(params: { api: GridApi }) {
  gridApi.value = params.api;
}

function onSearch(value: string) {
  gridApi.value?.setGridOption('quickFilterText', value);
}

function onRowDoubleClick(event: any) {
  handleSelect(event.data);
}

function handleConfirm() {
  const selected = gridApi.value?.getSelectedRows();
  if (selected?.length) {
    handleSelect(selected[0]);
  }
}

function handleSelect(row: any) {
  // 根据 mapping 配置回填数据
  const result: Record<string, any> = {};
  const mapping = props.config.mapping || {};
  for (const [targetField, sourceField] of Object.entries(mapping)) {
    result[targetField] = row[sourceField];
  }
  emit('select', result);
  visible.value = false;
}

// 暴露 open 方法
defineExpose({ open });
</script>

<style scoped>
.lookup-search {
  margin-bottom: 8px;
}
.lookup-grid {
  border: 1px solid #e8e8e8;
  border-radius: 4px;
}
</style>
