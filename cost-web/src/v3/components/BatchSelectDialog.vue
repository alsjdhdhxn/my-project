<template>
  <NModal v-model:show="visible" :mask-closable="true" :close-on-esc="true">
    <div ref="dialogRef" class="batch-select-dialog" :style="dialogStyle">
      <!-- 标题栏（可拖拽） -->
      <div class="dialog-header" @mousedown="startDrag">
        <span class="dialog-title">{{ dialogTitle }}</span>
        <NButton quaternary circle size="small" @click="handleCancel">
          <template #icon><SvgIcon icon="mdi:close" /></template>
        </NButton>
      </div>

      <!-- 内容区 -->
      <div class="dialog-body">
        <div class="dialog-search">
          <NInput v-model:value="searchText" placeholder="输入关键字搜索" clearable @keyup.enter="handleSearch">
            <template #prefix><SvgIcon icon="mdi:magnify" class="text-icon" /></template>
          </NInput>
        </div>
        <div class="dialog-grid" :style="{ height: gridHeight + 'px' }">
          <AgGridVue
            class="ag-theme-quartz"
            style="width: 100%; height: 100%"
            :rowData="rowData"
            :columnDefs="columnDefs"
            :defaultColDef="defaultColDef"
            :rowSelection="rowSelection"
            :getRowId="getRowId"
            @grid-ready="onGridReady"
            @row-double-clicked="onRowDoubleClicked"
          />
        </div>
        <div class="dialog-info">
          <span>已选择 {{ selectedCount }} 条数据</span>
        </div>
      </div>

      <!-- 底部按钮 -->
      <div class="dialog-footer">
        <NSpace justify="end">
          <NButton @click="handleCancel">取消</NButton>
          <NButton type="primary" :disabled="selectedCount === 0" @click="handleConfirm">
            确定添加 ({{ selectedCount }})
          </NButton>
        </NSpace>
      </div>

      <!-- 右下角拖拽调整大小手柄 -->
      <div class="resize-handle" @mousedown.stop="startResize"></div>
    </div>
  </NModal>
</template>

<script setup lang="ts">
import { ref, computed, watch, onUnmounted } from 'vue';
import { NModal, NInput, NButton, NSpace } from 'naive-ui';
import { AgGridVue } from 'ag-grid-vue3';
import type { GridApi, ColDef, GridReadyEvent, RowDoubleClickedEvent } from 'ag-grid-community';
import { fetchLookupConfig } from '@/service/api';
import { request } from '@/service/request';
import SvgIcon from '@/components/custom/svg-icon.vue';

export type BatchSelectConfig = {
  /** Lookup 配置编码 */
  lookupCode: string;
  /** 弹窗标题 */
  title?: string;
  /** 字段映射：{ 目标字段: 源字段 }，不配置则直接使用原字段 */
  mapping?: Record<string, string>;
  /** 筛选列名（SQL列名） */
  filterColumn?: string;
  /** 筛选值来源字段（从主表行取值） */
  filterField?: string;
  /** 主键字段 */
  valueField?: string;
  /** 目标从表 tabKey */
  targetTab?: string;
};

const emit = defineEmits<{
  (e: 'select', data: Record<string, any>[]): void;
  (e: 'cancel'): void;
}>();

const visible = ref(false);
const config = ref<Api.Metadata.LookupConfig | null>(null);
const rowData = ref<Record<string, any>[]>([]);
const searchText = ref('');
const selectedCount = ref(0);
const currentConfig = ref<BatchSelectConfig | null>(null);
let gridApi: GridApi | null = null;

// 弹窗尺寸和位置
const dialogWidth = ref(1050);
const dialogHeight = ref(600);
const dialogX = ref(0);
const dialogY = ref(0);
const dialogRef = ref<HTMLElement | null>(null);

// 拖拽状态
const isDragging = ref(false);
const isResizing = ref(false);
const dragStartX = ref(0);
const dragStartY = ref(0);
const startWidth = ref(0);
const startHeight = ref(0);

function normalizeColumnName(name?: string | null): string {
  return String(name || '').trim().toUpperCase();
}

const dialogTitle = computed(() => currentConfig.value?.title || config.value?.lookupName || '选择数据');

const columnDefs = computed<ColDef[]>(() => {
  if (!config.value?.displayColumns) return [];
  return config.value.displayColumns.map(col => ({
    field: normalizeColumnName(col.field),
    headerName: col.header,
    ...(col.width ? { width: col.width } : { flex: 1, minWidth: 120 }),
    sortable: true,
    resizable: true
  }));
});

const defaultColDef: ColDef = {
  sortable: true,
  resizable: true,
  suppressHeaderMenuButton: true
};

// 多选配置
const rowSelection = {
  mode: 'multiRow' as const,
  enableClickSelection: true,
  checkboxes: true,
  headerCheckbox: true,
  selectAll: 'all' as const
};

const dialogStyle = computed(() => ({
  width: `${dialogWidth.value}px`,
  height: `${dialogHeight.value}px`,
  transform: `translate(${dialogX.value}px, ${dialogY.value}px)`
}));

const gridHeight = computed(() => dialogHeight.value - 200);

function getRowId(params: any) {
  const valueField = normalizeColumnName(currentConfig.value?.valueField || config.value?.valueField || 'ID');
  return String(params.data?.[valueField] ?? params.data?.ID ?? Math.random());
}

// 拖拽移动
function startDrag(e: MouseEvent) {
  if ((e.target as HTMLElement).closest('button')) return;
  e.preventDefault();
  isDragging.value = true;
  dragStartX.value = e.clientX - dialogX.value;
  dragStartY.value = e.clientY - dialogY.value;
  document.addEventListener('mousemove', onDrag);
  document.addEventListener('mouseup', stopDrag);
}

function onDrag(e: MouseEvent) {
  if (!isDragging.value) return;
  dialogX.value = e.clientX - dragStartX.value;
  dialogY.value = e.clientY - dragStartY.value;
}

function stopDrag() {
  isDragging.value = false;
  document.removeEventListener('mousemove', onDrag);
  document.removeEventListener('mouseup', stopDrag);
}

// 拖拽调整大小
function startResize(e: MouseEvent) {
  e.preventDefault();
  isResizing.value = true;
  dragStartX.value = e.clientX;
  dragStartY.value = e.clientY;
  startWidth.value = dialogWidth.value;
  startHeight.value = dialogHeight.value;
  document.addEventListener('mousemove', onResize);
  document.addEventListener('mouseup', stopResize);
}

function onResize(e: MouseEvent) {
  if (!isResizing.value) return;
  dialogWidth.value = Math.max(600, Math.min(startWidth.value + e.clientX - dragStartX.value, window.innerWidth - 100));
  dialogHeight.value = Math.max(400, Math.min(startHeight.value + e.clientY - dragStartY.value, window.innerHeight - 100));
}

function stopResize() {
  isResizing.value = false;
  document.removeEventListener('mousemove', onResize);
  document.removeEventListener('mouseup', stopResize);
  gridApi?.sizeColumnsToFit();
}

/**
 * 打开弹窗
 * @param batchConfig 批量选择配置
 * @param filterValue 筛选值（可选，会覆盖从 masterRow 取的值）
 */
async function open(batchConfig: BatchSelectConfig, filterValue?: any) {
  currentConfig.value = batchConfig;
  visible.value = true;
  selectedCount.value = 0;
  searchText.value = '';
  dialogX.value = 0;
  dialogY.value = 0;
  
  // 加载 lookup 配置
  const { data } = await fetchLookupConfig(batchConfig.lookupCode);
  if (data) config.value = data;
  
  await loadData(filterValue);
}

async function loadData(filterValue?: any) {
  if (!config.value?.lookupCode) return;
  
  const params: Record<string, any> = { page: 1, pageSize: 1000 };
  
  const filterColumn = currentConfig.value?.filterColumn;
  if (filterColumn && filterValue != null) {
    params.filterColumn = filterColumn;
    params.filterValue = filterValue;
  }
  
  const { data } = await request<{ list: Record<string, any>[] }>({
    url: `/api/lookup/${config.value.lookupCode}/data`,
    params
  });
  rowData.value = data?.list || [];
}

function handleSearch() {
  gridApi?.setGridOption('quickFilterText', searchText.value || '');
}

function handleCancel() {
  visible.value = false;
  emit('cancel');
}

function handleConfirm() {
  const selectedRows = gridApi?.getSelectedRows() || [];
  if (selectedRows.length === 0) return;
  
  const mapping = currentConfig.value?.mapping;
  
  // 根据 mapping 转换数据，生成新行数据
  const newRows = selectedRows.map(row => {
    const newRow: Record<string, any> = {};
    if (mapping && Object.keys(mapping).length > 0) {
      // 有 mapping：按映射转换字段
      for (const [targetField, sourceField] of Object.entries(mapping)) {
        newRow[targetField] = row[normalizeColumnName(sourceField)];
      }
    } else {
      // 无 mapping：直接复制所有字段（排除 id，让系统生成新 id）
      for (const [key, value] of Object.entries(row)) {
        if (key !== 'ID') {
          newRow[key] = value;
        }
      }
    }
    return newRow;
  });
  
  visible.value = false;
  emit('select', newRows);
}

function onGridReady(params: GridReadyEvent) {
  gridApi = params.api;
  setTimeout(() => {
    gridApi?.autoSizeAllColumns();
  }, 100);
  
  // 监听选择变化
  params.api.addEventListener('selectionChanged', () => {
    selectedCount.value = params.api.getSelectedRows().length;
  });
}

function onRowDoubleClicked(event: RowDoubleClickedEvent) {
  // 双击单行直接确认
  if (event.data) {
    gridApi?.deselectAll();
    gridApi?.getRowNode(getRowId({ data: event.data }))?.setSelected(true);
    handleConfirm();
  }
}

/** 获取当前配置（供外部使用） */
function getConfig() {
  return currentConfig.value;
}

watch(searchText, handleSearch);

onUnmounted(() => {
  document.removeEventListener('mousemove', onDrag);
  document.removeEventListener('mouseup', stopDrag);
  document.removeEventListener('mousemove', onResize);
  document.removeEventListener('mouseup', stopResize);
});

defineExpose({ open, getConfig });
</script>

<style scoped>
.batch-select-dialog {
  background: #fff;
  border-radius: 8px;
  box-shadow: 0 6px 16px 0 rgba(0,0,0,0.08), 0 3px 6px -4px rgba(0,0,0,0.12), 0 9px 28px 8px rgba(0,0,0,0.05);
  display: flex;
  flex-direction: column;
  position: relative;
  min-width: 600px;
  min-height: 400px;
}

.dialog-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 16px;
  border-bottom: 1px solid #f0f0f0;
  cursor: move;
  user-select: none;
}

.dialog-title {
  font-size: 16px;
  font-weight: 500;
  color: #333;
}

.dialog-body {
  flex: 1;
  padding: 16px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.dialog-search {
  margin-bottom: 12px;
  flex-shrink: 0;
}

.dialog-grid {
  flex: 1;
  border: 1px solid #e8e8e8;
  border-radius: 4px;
  overflow: hidden;
}

.dialog-info {
  margin-top: 8px;
  font-size: 13px;
  color: #666;
}

.dialog-footer {
  padding: 12px 16px;
  border-top: 1px solid #f0f0f0;
}

.resize-handle {
  position: absolute;
  right: 0;
  bottom: 0;
  width: 16px;
  height: 16px;
  cursor: se-resize;
  background: linear-gradient(135deg, transparent 50%, #d9d9d9 50%, #d9d9d9 60%, transparent 60%, transparent 70%, #d9d9d9 70%, #d9d9d9 80%, transparent 80%);
  border-radius: 0 0 8px 0;
}

.resize-handle:hover {
  background: linear-gradient(135deg, transparent 50%, #1890ff 50%, #1890ff 60%, transparent 60%, transparent 70%, #1890ff 70%, #1890ff 80%, transparent 80%);
}
</style>
