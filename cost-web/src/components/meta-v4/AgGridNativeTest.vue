<template>
  <div class="aggrid-native-test">
    <div v-if="isReady" class="grid-container">
      <AgGridVue
        class="ag-theme-quartz"
        style="width: 100%; height: 100%"
        :rowData="masterRows"
        :columnDefs="masterColumnDefs"
        :defaultColDef="defaultColDef"
        :getRowId="getMasterRowId"
        :rowSelection="rowSelection"
        :masterDetail="true"
        :keepDetailRows="true"
        :detailRowAutoHeight="true"
        :detailCellRendererParams="summaryDetailParams"
        :undoRedoCellEditing="true"
        :undoRedoCellEditingLimit="20"
        :rowHeight="32"
        :headerHeight="32"
        @grid-ready="onGridReady"
        @cell-value-changed="onMasterCellValueChanged"
      />
    </div>
    <div v-else class="loading">
      <NSpin size="large" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, shallowRef, onMounted } from 'vue';
import { useMessage, NSpin } from 'naive-ui';
import { AgGridVue } from 'ag-grid-vue3';
import type { GridApi, ColDef, GridReadyEvent, CellValueChangedEvent } from 'ag-grid-community';
import { searchDynamicData } from '@/service/api';
import { loadTableMeta } from '@/composables/useMetaColumns';

const props = defineProps<{
  pageCode: string;
}>();

const message = useMessage();

// ==================== State ====================
const isReady = ref(false);
const masterGridApi = shallowRef<GridApi | null>(null);
const masterRows = ref<any[]>([]);
const masterColumnDefs = shallowRef<ColDef[]>([]);

// 从表列定义
const materialColumns = shallowRef<ColDef[]>([]);
const packageColumns = shallowRef<ColDef[]>([]);

// 从表数据缓存（主表切换时不丢失）
const detailCache = new Map<number, { material: any[]; package: any[] }>();

// ==================== Grid Config ====================
const defaultColDef: ColDef = {
  sortable: true,
  filter: true,
  resizable: true,
  editable: true,
};

const rowSelection = { mode: 'singleRow' as const, enableClickSelection: true };

const getMasterRowId = (params: any) => String(params.data?.id);

// ==================== 第二层：汇总行配置 ====================
const summaryDetailParams = {
  refreshStrategy: 'nothing',
  detailGridOptions: {
    columnDefs: [
      { 
        field: 'groupLabel', 
        headerName: '分类',
        cellRenderer: 'agGroupCellRenderer',
        minWidth: 150
      },
      { field: 'totalAmount', headerName: '合计金额', width: 120, type: 'numericColumn' },
      { field: 'rowCount', headerName: '行数', width: 80, type: 'numericColumn' }
    ],
    defaultColDef: { sortable: false, filter: false, resizable: true },
    rowHeight: 32,
    headerHeight: 32,
    masterDetail: true,
    keepDetailRows: true,
    detailRowAutoHeight: true,
    getRowId: (params: any) => `${params.data?._masterId}_${params.data?._groupKey}`,
    suppressContextMenu: true,
    // 第三层：明细 Grid 配置
    detailCellRendererParams: getDetailGridParams()
  },
  getDetailRowData: async (params: any) => {
    const masterId = params.data?.id;
    
    // 检查缓存
    let cached = detailCache.get(masterId);
    if (!cached) {
      await loadDetailData(masterId);
      cached = detailCache.get(masterId);
    }
    
    if (!cached) {
      params.successCallback([]);
      return;
    }
    
    // 构建汇总行数据
    const summaryRows = [
      {
        _groupKey: 'material',
        _masterId: masterId,
        groupLabel: '原辅料',
        totalAmount: cached.material.reduce((sum, r) => sum + (r.costBatch || 0), 0),
        rowCount: cached.material.length,
        _detailRows: cached.material
      },
      {
        _groupKey: 'package',
        _masterId: masterId,
        groupLabel: '包材',
        totalAmount: cached.package.reduce((sum, r) => sum + (r.costBatch || 0), 0),
        rowCount: cached.package.length,
        _detailRows: cached.package
      }
    ];
    
    params.successCallback(summaryRows);
  }
};

// ==================== 第三层：明细 Grid 配置 ====================
function getDetailGridParams() {
  return (params: any) => {
    const groupKey = params.data?._groupKey;
    const masterId = params.data?._masterId;
    
    // 根据分组类型返回不同列定义
    const columns = groupKey === 'material' 
      ? materialColumns.value 
      : packageColumns.value;
    
    return {
      refreshStrategy: 'nothing',
      detailGridOptions: {
        columnDefs: columns,
        defaultColDef: {
          sortable: true,
          filter: true,
          resizable: true,
          editable: true
        },
        rowHeight: 28,
        headerHeight: 28,
        getRowId: (rowParams: any) => String(rowParams.data?.id),
        // 从表编辑事件
        onCellValueChanged: (event: any) => onDetailCellValueChanged(event, masterId, groupKey)
      },
      getDetailRowData: (detailParams: any) => {
        const rows = detailParams.data?._detailRows || [];
        detailParams.successCallback(rows);
      }
    };
  };
}

// ==================== 事件处理 ====================
function onGridReady(params: GridReadyEvent) {
  masterGridApi.value = params.api;
  params.api.sizeColumnsToFit();
}

function onMasterCellValueChanged(event: CellValueChangedEvent) {
  const field = event.colDef?.field;
  const masterId = event.data?.id;
  
  console.log('[主表编辑]', field, event.oldValue, '->', event.newValue);
  
  // 标记脏数据
  event.data._isDirty = true;
  
  // 检查是否是广播字段
  const broadcastFields = ['apexPl', 'yield', 'pPerpack', 'sPerback', 'xPerback'];
  if (broadcastFields.includes(field!)) {
    broadcastToDetail(masterId, event.data); // async 函数，不需要 await
  }
}

function onDetailCellValueChanged(event: any, masterId: number, groupKey: string) {
  const field = event.colDef?.field;
  const row = event.data;
  
  console.log('[从表编辑]', groupKey, field, event.oldValue, '->', event.newValue);
  
  // 标记脏数据
  row._isDirty = true;
  
  // 行级计算：costBatch = batchQty * price
  if (field === 'batchQty' || field === 'price') {
    const newCostBatch = (row.batchQty || 0) * (row.price || 0);
    event.node.setDataValue('costBatch', newCostBatch);
  }
  
  // 聚合到主表
  recalcAggregates(masterId);
}

// ==================== 广播到从表 ====================
async function broadcastToDetail(masterId: number, masterRow: any) {
  // 如果 cache 没数据，先加载
  let cached = detailCache.get(masterId);
  if (!cached) {
    await loadDetailData(masterId);
    cached = detailCache.get(masterId);
  }
  if (!cached) return;
  
  const apexPl = masterRow.apexPl || 0;
  const pPerpack = masterRow.pPerpack || 1;
  const sPerback = masterRow.sPerback || 1;
  const xPerback = masterRow.xPerback || 1;
  
  // 重算原辅料的 batchQty（公式 C: perHl * apexPl * (1 + exaddMater / 100) / 1000000）
  for (const row of cached.material) {
    const perHl = row.perHl || 0;
    const rowExadd = row.exaddMater || 0;
    row.batchQty = perHl * apexPl * (1 + rowExadd / 100) / 1000000;
    row.costBatch = row.batchQty * (row.price || 0);
    row._isDirty = true;
  }
  
  // 重算包材的 batchQty（根据 formulaType 选择公式）
  for (const row of cached.package) {
    const formulaType = row.formulaType || 'A';
    let batchQty = 0;
    
    switch (formulaType) {
      case 'A': // 桶/说明书/小盒/标签/瓶/纸
        batchQty = apexPl / pPerpack;
        break;
      case 'E': // 大纸箱
        batchQty = Math.ceil(apexPl / (pPerpack * sPerback));
        break;
      case 'F': // 托盘
        batchQty = Math.ceil(apexPl / (pPerpack * sPerback * xPerback));
        break;
      case 'D': // 硬片/铝箔（和原辅料一样）
        const perHl = row.perHl || 0;
        const rowExadd = row.exaddMater || 0;
        batchQty = perHl * apexPl * (1 + rowExadd / 100) / 1000000;
        break;
      default:
        batchQty = apexPl / pPerpack;
    }
    
    row.batchQty = batchQty;
    row.costBatch = row.batchQty * (row.price || 0);
    row._isDirty = true;
  }
  
  // 刷新第三层 Grid（如果展开了）
  refreshThirdLevelGrid(masterId, 'material');
  refreshThirdLevelGrid(masterId, 'package');
  
  // 重算聚合
  recalcAggregates(masterId);
  
  // 刷新汇总行
  refreshSummaryRow(masterId);
  
  console.log('[广播完成]', { apexPl, pPerpack, sPerback, xPerback });
}

// ==================== 刷新第三层 Grid ====================
function refreshThirdLevelGrid(masterId: number, groupKey: string) {
  const api = masterGridApi.value;
  if (!api) return;
  
  // 获取第二层 Grid（汇总行 Grid）
  const secondLevelInfo = api.getDetailGridInfo(`detail_${masterId}`);
  if (!secondLevelInfo?.api) {
    console.log('[刷新第三层] 第二层 Grid 未展开');
    return;
  }
  
  // 遍历第二层的所有 detail Grid
  secondLevelInfo.api.forEachDetailGridInfo((detailInfo: any) => {
    // 检查是否是目标 groupKey
    if (detailInfo.id?.includes(groupKey)) {
      const cached = detailCache.get(masterId);
      if (!cached) return;
      
      const rows = groupKey === 'material' ? cached.material : cached.package;
      
      // 用 setDataValue 逐个更新，保留变更追踪
      detailInfo.api.forEachNode((node: any) => {
        const cachedRow = rows.find((r: any) => r.id === node.data?.id);
        if (cachedRow) {
          // 只更新计算字段
          if (node.data.batchQty !== cachedRow.batchQty) {
            node.setDataValue('batchQty', cachedRow.batchQty);
          }
          if (node.data.costBatch !== cachedRow.costBatch) {
            node.setDataValue('costBatch', cachedRow.costBatch);
          }
        }
      });
      
      console.log('[刷新第三层] 更新数据:', rows.length, '行');
    }
  });
}

// ==================== 聚合计算 ====================
function recalcAggregates(masterId: number) {
  const cached = detailCache.get(masterId);
  if (!cached) return;
  
  // 计算原辅料合计
  let totalYl = 0;
  let totalFl = 0;
  for (const row of cached.material) {
    if (row.dtlUseflag === '原料') {
      totalYl += row.costBatch || 0;
    } else {
      totalFl += row.costBatch || 0;
    }
  }
  
  // 计算包材合计
  let totalBc = 0;
  for (const row of cached.package) {
    totalBc += row.costBatch || 0;
  }
  
  // 更新主表
  const masterNode = masterGridApi.value?.getRowNode(String(masterId));
  if (masterNode) {
    masterNode.setDataValue('totalYl', totalYl);
    masterNode.setDataValue('totalFl', totalFl);
    masterNode.setDataValue('totalBc', totalBc);
    masterNode.setDataValue('totalCost', totalYl + totalFl + totalBc);
  }
  
  // 更新汇总行
  refreshSummaryRow(masterId);
  
  console.log('[聚合计算]', { totalYl, totalFl, totalBc });
}

// ==================== 刷新汇总行 ====================
function refreshSummaryRow(masterId: number) {
  const api = masterGridApi.value;
  if (!api) return;
  
  const secondLevelInfo = api.getDetailGridInfo(`detail_${masterId}`);
  if (!secondLevelInfo?.api) return;
  
  const cached = detailCache.get(masterId);
  if (!cached) return;
  
  // 更新原辅料汇总行
  const materialNode = secondLevelInfo.api.getRowNode(`${masterId}_material`);
  if (materialNode) {
    materialNode.setDataValue('totalAmount', cached.material.reduce((sum, r) => sum + (r.costBatch || 0), 0));
    materialNode.setDataValue('rowCount', cached.material.length);
  }
  
  // 更新包材汇总行
  const packageNode = secondLevelInfo.api.getRowNode(`${masterId}_package`);
  if (packageNode) {
    packageNode.setDataValue('totalAmount', cached.package.reduce((sum, r) => sum + (r.costBatch || 0), 0));
    packageNode.setDataValue('rowCount', cached.package.length);
  }
}

// ==================== 数据加载 ====================
async function loadMetadata() {
  // 加载主表元数据
  const masterMeta = await loadTableMeta('CostPinggu', props.pageCode);
  if (masterMeta) {
    // 第一列添加展开按钮
    const cols = masterMeta.columns.map((col, index) => {
      if (index === 0) {
        return { ...col, cellRenderer: 'agGroupCellRenderer' };
      }
      return col;
    });
    masterColumnDefs.value = cols;
  }
  
  // 加载原辅料元数据
  const materialMeta = await loadTableMeta('CostMaterial', props.pageCode);
  if (materialMeta) {
    materialColumns.value = materialMeta.columns;
  }
  
  // 加载包材元数据
  const packageMeta = await loadTableMeta('CostPackage', props.pageCode);
  if (packageMeta) {
    packageColumns.value = packageMeta.columns;
  }
  
  isReady.value = true;
}

async function loadMasterData() {
  const { data, error } = await searchDynamicData('CostPinggu', {
    pageCode: props.pageCode
  });
  
  if (error) {
    message.error('加载主表数据失败');
    return;
  }
  
  masterRows.value = data?.list || [];
}

async function loadDetailData(masterId: number) {
  // 并行加载原辅料和包材（使用 masterId 字段，对应视图中的 MASTER_ID）
  const [materialRes, packageRes] = await Promise.all([
    searchDynamicData('CostMaterial', {
      pageCode: props.pageCode,
      conditions: [{ field: 'masterId', operator: 'eq', value: masterId }]
    }),
    searchDynamicData('CostPackage', {
      pageCode: props.pageCode,
      conditions: [{ field: 'masterId', operator: 'eq', value: masterId }]
    })
  ]);
  
  // 缓存
  detailCache.set(masterId, {
    material: materialRes.data?.list || [],
    package: packageRes.data?.list || []
  });
  
  console.log('[加载从表]', masterId, detailCache.get(masterId));
}

// ==================== 生命周期 ====================
onMounted(async () => {
  await loadMetadata();
  await loadMasterData();
});
</script>

<style scoped>
.aggrid-native-test {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
}

.grid-container {
  flex: 1;
  min-height: 0;
}

.loading {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 100%;
}
</style>
