<template>
  <div class="master-detail-page">
    <!-- 主从表分隔区域 -->
    <template v-if="store.isReady">
      <!-- 三层嵌套模式：主表 → 汇总行 → 明细 Grid -->
      <div v-if="isNestedMode" class="master-section full" @contextmenu.prevent="onGridContainerContextMenu($event, true)">
        <AgGridVue
          class="ag-theme-quartz"
          style="width: 100%; height: 100%"
          :rowData="store.visibleMasterRows"
          :columnDefs="masterColumnDefs"
          :defaultColDef="defaultColDef"
          :getRowId="getRowId"
          :getRowClass="masterGetRowClass"
          :rowSelection="masterRowSelection"
          :suppressContextMenu="true"
          :preventDefaultOnContextMenu="true"
          :sideBar="sideBar"
          :cellSelection="cellSelectionEnabled"
          :rowHeight="28"
          :headerHeight="28"
          :masterDetail="true"
          :keepDetailRows="true"
          :detailRowAutoHeight="true"
          :detailCellRendererParams="masterDetailParams"
          @grid-ready="onMasterGridReady"
          @selection-changed="onMasterSelectionChanged"
          @row-group-opened="onMasterRowExpanded"
          @cell-value-changed="onMasterCellValueChanged"
          @cell-clicked="onMasterCellClicked"
          @cell-context-menu="onMasterContextMenu"
          @cell-editing-started="masterAdapter.onCellEditingStarted"
          @cell-editing-stopped="masterAdapter.onCellEditingStopped"
        />
      </div>

      <!-- 分屏模式：有从表上下分隔 -->
      <NSplit
        v-else-if="hasDetail"
        direction="vertical"
        :default-size="0.5"
        :min="0.2"
        :max="0.8"
        class="split-container"
      >
        <!-- 主表 -->
        <template #1>
          <div class="master-section" @contextmenu.prevent="onGridContainerContextMenu($event, true)">
            <AgGridVue
              class="ag-theme-quartz"
              style="width: 100%; height: 100%"
              :rowData="store.visibleMasterRows"
              :columnDefs="masterColumnDefs"
              :defaultColDef="defaultColDef"
              :getRowId="getRowId"
              :getRowClass="masterGetRowClass"
              :rowSelection="masterRowSelection"
              :suppressContextMenu="true"
              :preventDefaultOnContextMenu="true"
              :sideBar="sideBar"
              :cellSelection="cellSelectionEnabled"
              :autoGroupColumnDef="autoGroupColumnDef"
              :groupDefaultExpanded="enableRowGrouping ? 1 : undefined"
              :headerHeight="24"
              @grid-ready="onMasterGridReady"
              @selection-changed="onMasterSelectionChanged"
              @cell-value-changed="onMasterCellValueChanged"
              @cell-clicked="onMasterCellClicked"
              @cell-context-menu="onMasterContextMenu"
              @cell-editing-started="masterAdapter.onCellEditingStarted"
              @cell-editing-stopped="masterAdapter.onCellEditingStopped"
            />
          </div>
        </template>

        <!-- 从表 Tabs -->
        <template #2>
          <div class="detail-section" @contextmenu.prevent="onGridContainerContextMenu($event, false)">
            <MetaTabs
              :tabs="tabs"
              :visibleKeys="visibleTabKeys"
              :store="store"
              :detailColumnDefs="detailColumnDefs"
              :defaultColDef="defaultColDef"
              :getRowClass="detailGetRowClass"
              @cell-value-changed="onDetailCellValueChanged"
              @cell-clicked="onDetailCellClicked"
              @context-menu="onDetailContextMenu"
            />
          </div>
        </template>
      </NSplit>

      <!-- 无从表：主表铺满 -->
      <div v-else class="master-section full" @contextmenu.prevent="onGridContainerContextMenu($event, true)">
        <AgGridVue
          class="ag-theme-quartz"
          style="width: 100%; height: 100%"
          :rowData="store.visibleMasterRows"
          :columnDefs="masterColumnDefs"
          :defaultColDef="defaultColDef"
          :getRowId="getRowId"
          :getRowClass="masterGetRowClass"
          :rowSelection="masterRowSelection"
          :suppressContextMenu="true"
          :preventDefaultOnContextMenu="true"
          :sideBar="sideBar"
          :cellSelection="cellSelectionEnabled"
          :autoGroupColumnDef="autoGroupColumnDef"
          :groupDefaultExpanded="enableRowGrouping ? 1 : undefined"
          :headerHeight="24"
          @grid-ready="onMasterGridReady"
          @cell-value-changed="onMasterCellValueChanged"
          @cell-clicked="onMasterCellClicked"
          @cell-context-menu="onMasterContextMenu"
          @cell-editing-started="masterAdapter.onCellEditingStarted"
          @cell-editing-stopped="masterAdapter.onCellEditingStopped"
        />
      </div>
    </template>

    <!-- 加载中 -->
    <div v-else class="loading-container">
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

    <!-- 右键菜单 -->
    <NDropdown
      placement="bottom-start"
      trigger="manual"
      :x="contextMenuX"
      :y="contextMenuY"
      :options="contextMenuOptions"
      :show="contextMenuVisible"
      @select="onContextMenuSelect"
      @clickoutside="onContextMenuClickOutside"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, shallowRef, computed, onMounted, onUnmounted, watch, h } from 'vue';
import { NButton, NDropdown, useMessage, NSplit, NSpin } from 'naive-ui';
import type { DropdownOption } from 'naive-ui';
import { AgGridVue } from 'ag-grid-vue3';
import type { GridApi, ColDef, GridReadyEvent, CellValueChangedEvent, CellContextMenuEvent } from 'ag-grid-community';
import { useMasterDetailStore } from '@/store/modules/master-detail';
import { useGridAdapter, getCellClassRules, cellStyleCSS } from '@/composables/useGridAdapter';
import {
  parsePageComponents,
  buildSaveParams,
  parseValidationRules,
  validateRows,
  formatValidationErrors,
  generateTempId,
  type ParsedPageConfig,
  type ValidationRule
} from '@/logic/calc-engine';
import { fetchPageComponents, saveDynamicData, searchDynamicData, executeAction } from '@/service/api';
import { loadTableMeta, filterColumnsByVariant, type RowStyleRule, type LookupRule, extractLookupRules } from '@/composables/useMetaColumns';
import MetaTabs from './MetaTabs.vue';
import LookupDialog from './LookupDialog.vue';

// AG Grid 模块已在 main.ts 全局注册

// ==================== Props ====================

const props = defineProps<{
  pageCode: string;
}>();

const message = useMessage();

// ==================== Store ====================

const store = useMasterDetailStore(props.pageCode);

// ==================== State ====================

const masterGridApi = shallowRef<GridApi | null>(null);
const visibleTabKeys = ref(new Set<string>());

// 验证规则
const masterValidationRules = shallowRef<ValidationRule[]>([]);
const detailValidationRules = shallowRef<ValidationRule[]>([]);

// 原始列元数据（用于验证时获取 headerText）
const masterColumnMeta = shallowRef<any[]>([]);
const detailColumnMeta = shallowRef<any[]>([]);

// 从表外键字段名（从元数据读取）
const detailFkColumn = ref<string>('');

// 行样式类函数
const masterGetRowClass = shallowRef<((params: any) => string | undefined) | undefined>(undefined);
const detailGetRowClass = shallowRef<((params: any) => string | undefined) | undefined>(undefined);

// Lookup 规则
const masterLookupRules = shallowRef<LookupRule[]>([]);
const detailLookupRules = shallowRef<LookupRule[]>([]);

// Lookup 弹窗状态
const lookupDialogRef = ref<InstanceType<typeof LookupDialog> | null>(null);
const currentLookupRule = ref<LookupRule | null>(null);
const currentLookupRowId = ref<number | null>(null);
const currentLookupIsMaster = ref<boolean>(false);

// 右键菜单状态
const contextMenuVisible = ref(false);
const contextMenuX = ref(0);
const contextMenuY = ref(0);
const contextMenuTarget = ref<{ isMaster: boolean; rowData: any; tabKey?: string } | null>(null);
const contextMenuConfig = ref<any>(null);

// ==================== Computed ====================

const tabs = computed(() => store.config?.tabs || []);

/** 是否有从表 */
const hasDetail = computed(() => !!store.config?.detailTableCode);

/** 是否启用三层嵌套模式 */
const isNestedMode = computed(() => !!store.config?.nestedConfig?.enabled);

/** 是否启用单元格选择 */
const cellSelectionEnabled = computed(() => store.config?.enterpriseConfig?.enableRangeSelection ?? false);

/** 是否启用行分组 */
const enableRowGrouping = computed(() => {
  const groupBy = store.config?.enterpriseConfig?.groupBy;
  return groupBy && groupBy.length > 0;
});

/** 自动分组列配置 */
const autoGroupColumnDef = computed(() => {
  if (!enableRowGrouping.value) return undefined;
  return {
    headerName: store.config?.enterpriseConfig?.groupColumnName || '分组',
    minWidth: 200
  };
});

/** 三层嵌套：主表展开后显示汇总行的配置 */
const masterDetailParams = computed(() => {
  if (!isNestedMode.value) return undefined;
  
  const nestedConfig = store.config?.nestedConfig;
  const summaryColumns = nestedConfig?.summaryColumns || [];
  
  return {
    refreshStrategy: 'nothing',
    detailGridOptions: {
      columnDefs: [
        // 第一列启用展开功能
        { 
          field: nestedConfig?.groupLabelField || 'groupLabel', 
          headerName: '分组',
          cellRenderer: 'agGroupCellRenderer',
          minWidth: 150
        },
        // 汇总列
        ...summaryColumns.map(col => ({
          field: col.field,
          headerName: col.headerName,
          width: col.width || 120,
          type: 'numericColumn'
        }))
      ],
      defaultColDef: {
        sortable: false,
        filter: false,
        resizable: true
      },
      rowHeight: 28,
      headerHeight: 28,
      suppressContextMenu: true,
      preventDefaultOnContextMenu: true,
      masterDetail: true,
      keepDetailRows: true,
      detailRowAutoHeight: true,
      // 为汇总行设置唯一 ID，保持展开状态
      getRowId: (rowParams: any) => `${rowParams.data?._masterId}_${rowParams.data?._groupKey}`,
      detailCellRendererParams: getSummaryDetailParams()
    },
    getDetailRowData: async (params: any) => {
      const masterId = params.data?.id;
      const masterRow = store.masterRows.find(r => r.id === masterId);
      
      // 如果没有数据，尝试加载
      if (!masterRow?._details?.rows?.length) {
        await loadDetailForRow(masterId);
        // 重新获取更新后的数据
        const updatedRow = store.masterRows.find(r => r.id === masterId);
        if (!updatedRow?._details?.rows?.length) {
          params.successCallback([]);
          return;
        }
        const summaryData = calcSummaryRowsForMaster(updatedRow);
        params.successCallback(summaryData);
        return;
      }
      
      const summaryData = calcSummaryRowsForMaster(masterRow);
      params.successCallback(summaryData);
    }
  };
});

/** 为指定主表行计算汇总数据（避免依赖全局 store.summaryRows） */
function calcSummaryRowsForMaster(masterRow: any) {
  const nestedConfig = store.config?.nestedConfig;
  if (!nestedConfig?.enabled) return [];

  const tabs = store.config?.tabs || [];
  const groupField = store.config?.groupField;
  const summaryAggregates = nestedConfig.summaryAggregates || [];
  const groupLabelField = nestedConfig.groupLabelField || 'groupLabel';
  
  const allRows = (masterRow._details?.rows || []).filter((r: any) => !r._isDeleted);

  return tabs.map(tab => {
    // 按分组过滤行
    let rows: any[];
    if (tab.mode === 'group') {
      if (tab.groupValues && tab.groupValues.length > 0 && groupField) {
        rows = allRows.filter((r: any) => tab.groupValues!.includes(r[groupField]));
      } else if (!tab.groupValue || tab.groupValue === '*' || !groupField) {
        rows = allRows;
      } else {
        rows = allRows.filter((r: any) => r[groupField] === tab.groupValue);
      }
    } else {
      rows = [];
    }

    // 计算聚合值
    const aggValues: Record<string, number> = {};
    for (const agg of summaryAggregates) {
      const values = rows.map((r: any) => Number(r[agg.sourceField]) || 0);
      switch (agg.algorithm) {
        case 'SUM':
          aggValues[agg.targetField] = values.reduce((a, b) => a + b, 0);
          break;
        case 'AVG':
          aggValues[agg.targetField] = values.length > 0 ? values.reduce((a, b) => a + b, 0) / values.length : 0;
          break;
        case 'COUNT':
          aggValues[agg.targetField] = rows.length;
          break;
        case 'MAX':
          aggValues[agg.targetField] = values.length > 0 ? Math.max(...values) : 0;
          break;
        case 'MIN':
          aggValues[agg.targetField] = values.length > 0 ? Math.min(...values) : 0;
          break;
      }
    }

    return {
      _groupKey: tab.key,
      _groupValue: tab.groupValue || tab.groupValues?.[0] || tab.key,
      [groupLabelField]: tab.title,
      _detailRows: rows,
      _variantKey: tab.variantKey,
      _masterId: masterRow.id,  // 绑定主表ID，用于刷新
      ...aggValues
    };
  });
}

/** 三层嵌套：汇总行展开后显示明细 Grid 的配置 */
function getSummaryDetailParams() {
  return (params: any) => {
    // 根据汇总行的 _variantKey 动态返回列定义
    const variantKey = params.data?._variantKey;
    const columns = variantKey
      ? filterColumnsByVariant(detailColumnDefs.value, variantKey, detailColumnMeta.value)
      : detailColumnDefs.value;
    
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
        suppressContextMenu: true,
        preventDefaultOnContextMenu: true,
        getRowId: (rowParams: any) => String(rowParams.data?.id),
        // 编辑事件：触发 store 更新和计算链
        onCellValueChanged: (event: any) => {
          const field = event.colDef?.field;
          const rowId = event.data?.id;
          if (field && rowId != null) {
            store.updateField(rowId, field, event.newValue, 'user', false);
          }
        },
        // 右键菜单事件
        onCellContextMenu: (event: any) => {
          event.event?.preventDefault();
          const e = event.event as MouseEvent;
          if (!e) return;
          
          contextMenuX.value = e.clientX;
          contextMenuY.value = e.clientY;
          contextMenuTarget.value = { 
            isMaster: false, 
            rowData: event.data,
            tabKey: groupKey // 使用当前分组的 key
          };
          contextMenuVisible.value = true;
        }
      },
      getDetailRowData: (detailParams: any) => {
        // 汇总行的 _detailRows 包含该分组的明细数据
        const detailRows = detailParams.data?._detailRows || [];
        detailParams.successCallback(detailRows);
      }
    };
  };
}

const masterColumnDefs = computed<ColDef[]>(() => {
  const cols = store.masterColumns.map((col, index) => {
    const colDef: ColDef = {
      ...col,
      cellClassRules: {
        ...col.cellClassRules,
        ...getCellClassRules()
      }
    };
    
    // 嵌套模式：第一列添加展开按钮
    if (isNestedMode.value && index === 0) {
      colDef.cellRenderer = 'agGroupCellRenderer';
    }
    
    return colDef;
  });
  
  return cols;
});

const detailColumnDefs = computed<ColDef[]>(() => {
  return store.detailColumns.map(col => ({
    ...col,
    cellClassRules: {
      ...col.cellClassRules,  // 保留元数据中的样式规则
      ...getCellClassRules()  // 添加变更状态样式
    }
  }));
});

const defaultColDef: ColDef = {
  sortable: true,
  filter: true,
  resizable: true,
  wrapHeaderText: true,
  autoHeaderHeight: true
};

const masterRowSelection = { mode: 'singleRow', checkboxes: false, enableClickSelection: true } as const;

// Side Bar 配置
const sideBar = {
  toolPanels: [
    {
      id: 'columns',
      labelDefault: 'Columns',
      labelKey: 'columns',
      iconKey: 'columns',
      toolPanel: 'agColumnsToolPanel',
      minWidth: 200,
      width: 250,
      toolPanelParams: {
        suppressRowGroups: true,      // 隐藏 Row Groups 区域
        suppressValues: true,          // 隐藏 Values 区域
        suppressPivots: true,          // 隐藏 Pivots 区域
        suppressPivotMode: true,       // 隐藏 Pivot Mode 开关
        suppressColumnFilter: false,   // 保留列过滤搜索框
        suppressColumnSelectAll: false, // 保留全选/取消全选
        suppressColumnExpandAll: false  // 保留展开/折叠全部
      }
    },
    {
      id: 'filters',
      labelDefault: 'Filters',
      labelKey: 'filters',
      iconKey: 'filter',
      toolPanel: 'agFiltersToolPanel',
      minWidth: 180,
      width: 250
    }
  ],
  position: 'right' as const,
  defaultToolPanel: 'columns'
};

const masterGridOptions = computed(() => ({
  getContextMenuItems: (params: any) => getContextMenuItems(params, true)
}));

const detailGridOptions = computed(() => ({
  getContextMenuItems: (params: any) => getContextMenuItems(params, false)
}));

function getContextMenuItems(params: any, isMaster: boolean) {
  const hasSelection = !!params.node;
  
  const items: any[] = [];
  
  // 新增行（始终显示）
  items.push({
    name: '新增行',
    action: () => {
      if (isMaster) {
        const newRow = store.addMasterRow();
        setTimeout(() => {
          masterGridApi.value?.forEachNode(node => {
            if (node.data?.id === newRow.id) node.setSelected(true);
          });
        }, 50);
      } else {
        // 从表需要知道是哪个 tab
        const tabKey = getCurrentTabKey();
        if (tabKey) {
          store.addDetailRow(tabKey, {});
        }
      }
    },
    icon: '<span class="ag-icon ag-icon-plus"></span>'
  });
  
  // 复制行和删除行（只在有选中行时显示）
  if (hasSelection) {
    items.push({
      name: '复制行',
      action: () => {
        const sourceData = { ...params.node.data };
        delete sourceData.id;
        delete sourceData._isNew;
        delete sourceData._isDeleted;
        delete sourceData._changeType;
        delete sourceData._originalValues;
        
        if (isMaster) {
          // 复制主表时，连带复制从表数据
          const sourceDetails = sourceData._details;
          delete sourceData._details;
          
          const newRow = store.addMasterRow(sourceData);
          
          // 复制从表数据
          if (sourceDetails?.rows?.length > 0) {
            const fkField = detailFkColumn.value;
            for (const detailRow of sourceDetails.rows) {
              if (detailRow._isDeleted) continue;
              
              const detailCopy = { ...detailRow };
              delete detailCopy.id;
              delete detailCopy._isNew;
              delete detailCopy._isDeleted;
              delete detailCopy._changeType;
              delete detailCopy._originalValues;
              
              if (fkField) {
                detailCopy[fkField] = newRow.id;
              }
              
              const newDetailId = generateTempId();
              newRow._details!.rows.push({
                ...detailCopy,
                id: newDetailId,
                _isNew: true,
                _changeType: {},
                _originalValues: {}
              });
            }
          }
          
          setTimeout(() => {
            masterGridApi.value?.forEachNode(node => {
              if (node.data?.id === newRow.id) node.setSelected(true);
            });
          }, 50);
        } else {
          const tabKey = getCurrentTabKey();
          if (tabKey) {
            delete sourceData._details;
            store.addDetailRow(tabKey, sourceData);
          }
        }
      },
      icon: '<span class="ag-icon ag-icon-copy"></span>'
    });
    
    items.push('separator');
    
    items.push({
      name: '删除行',
      action: () => {
        store.deleteRow(params.node.data.id, isMaster);
      },
      icon: '<span class="ag-icon ag-icon-delete"></span>',
      cssClasses: ['ag-menu-option-danger']
    });
  }
  
  return items;
}

function getCurrentTabKey(): string | undefined {
  // 从当前选中的 tab 获取 key
  // 这里简化处理，实际应该从 MetaTabs 传递过来
  return tabs.value[0]?.key;
}
  // 如果有元数据配置，使用元数据
  if (contextMenuConfig.value?.items) {
    const hasSelection = !!contextMenuTarget.value?.rowData;
    return contextMenuConfig.value.items
      .filter((item: any) => {
        // 过滤掉需要选中行但当前未选中的菜单项
        if (item.disabled === '!selectedRow' && !hasSelection) {
          return false;
        }
        return true;
      })
      .map((item: any) => {
        if (item.type === 'divider') {
          return { type: 'divider', key: item.key || `divider-${Math.random()}` };
        }
        return {
          label: item.label,
          key: item.key,
          icon: item.icon ? renderIcon(item.icon) : undefined,
          disabled: item.disabled === '!selectedRow' ? !hasSelection : false,
          props: item.key === 'delete' ? { style: { color: '#d03050' } } : undefined
        };
      });
  }
  
  // 降级：使用硬编码菜单
  const hasSelection = !!contextMenuTarget.value?.rowData;
  const options: DropdownOption[] = [
    { label: '新增行', key: 'add', icon: renderIcon('mdi:plus') }
  ];
  
  if (hasSelection) {
    options.push(
      { label: '复制行', key: 'copy', icon: renderIcon('mdi:content-copy') },
      { type: 'divider', key: 'd1' },
      { label: '删除行', key: 'delete', icon: renderIcon('mdi:delete'), props: { style: { color: '#d03050' } } }
    );
  }
  
  return options;
});

function renderIcon(iconName: string) {
  // 简单的图标映射，实际应该使用 iconify
  const iconMap: Record<string, string> = {
    'mdi:plus': '➕',
    'mdi:pencil': '✏️',
    'mdi:content-copy': '📋',
    'mdi:delete': '🗑️',
    'mdi:lock-reset': '🔒',
    'mdi:refresh': '🔄'
  };
  return () => h('span', { style: { marginRight: '8px' } }, iconMap[iconName] || '');
}

function onMasterContextMenu(event: CellContextMenuEvent) {
  const e = event.event as MouseEvent;
  if (!e) return;
  
  contextMenuX.value = e.clientX;
  contextMenuY.value = e.clientY;
  contextMenuTarget.value = { isMaster: true, rowData: event.data };
  contextMenuVisible.value = true;
}

function onGridContainerContextMenu(event: MouseEvent, isMaster: boolean) {
  // 如果点击的是单元格，会先触发对应的 ContextMenu 事件，这里不处理
  const target = event.target as HTMLElement;
  const isCell = target.closest('.ag-cell');
  
  if (isCell) {
    // 单元格右键由 onMasterContextMenu 或 onDetailContextMenu 处理
    return;
  }
  
  // 空白区域右键，显示菜单（无选中行）
  contextMenuX.value = event.clientX;
  contextMenuY.value = event.clientY;
  
  if (isMaster) {
    contextMenuTarget.value = { isMaster: true, rowData: null };
  } else {
    // 从表空白区域，需要确定是哪个 tab
    // 通过 DOM 查找最近的 tab-grid-wrapper
    const tabWrapper = target.closest('.tab-grid-wrapper');
    if (tabWrapper) {
      // 从 tab header 获取 tabKey（需要从 visibleTabs 匹配）
      const tabHeader = tabWrapper.querySelector('.tab-header');
      const tabTitle = tabHeader?.textContent?.trim();
      const tab = tabs.value.find(t => t.title === tabTitle);
      contextMenuTarget.value = { isMaster: false, rowData: null, tabKey: tab?.key };
    } else {
      contextMenuTarget.value = { isMaster: false, rowData: null };
    }
  }
  
  contextMenuVisible.value = true;
}

function onContextMenuSelect(key: string) {
  contextMenuVisible.value = false;
  const target = contextMenuTarget.value;
  if (!target) return;

  // 查找菜单项配置
  const menuItem = contextMenuConfig.value?.items?.find((item: any) => item.key === key);
  
  if (menuItem) {
    handleMenuAction(menuItem, target);
  } else {
    // 降级：硬编码处理
    handleLegacyMenuAction(key, target);
  }
}

async function handleMenuAction(menuItem: any, target: any) {
  const { action, actionParams, confirm, confirmMessage } = menuItem;
  
  // 需要确认的操作
  if (confirm) {
    return new Promise((resolve) => {
      window.$dialog?.warning({
        title: '确认',
        content: confirmMessage || '确认执行此操作吗？',
        positiveText: '确认',
        negativeText: '取消',
        onPositiveClick: () => {
          executeMenuAction(action, actionParams, target);
          resolve(true);
        },
        onNegativeClick: () => {
          resolve(false);
        }
      });
    });
  }
  
  // 不需要确认，直接执行
  executeMenuAction(action, actionParams, target);
}

function executeMenuAction(action: string, actionParams: any, target: any) {
  switch (action) {
    case 'addRow':
      handleAddRow(target);
      break;
    case 'editRow':
      handleEditRow(target);
      break;
    case 'copyRow':
      handleCopyRow(target);
      break;
    case 'deleteRow':
      handleDeleteRow(target);
      break;
    case 'executeAction':
      handleExecuteAction(actionParams, target);
      break;
    case 'refresh':
      loadMasterData();
      break;
    default:
      console.warn('未知的菜单动作:', action);
  }
}

async function handleExecuteAction(actionParams: any, target: any) {
  const { tableCode, group, dataFields, extraData } = actionParams;
  
  // 构建请求数据
  const data: any = { ...extraData };
  dataFields?.forEach((field: string) => {
    data[field] = target.rowData[field];
  });
  
  try {
    const { error } = await executeAction(tableCode, { group, data });
    if (error) {
      message.error(error.msg || '操作失败');
      return;
    }
    message.success('操作成功');
    await loadMasterData();
  } catch (error: any) {
    message.error(error.message || '操作失败');
  }
}

function handleLegacyMenuAction(key: string, target: any) {
  if (key === 'add') {
    if (target.isMaster) {
      const newRow = store.addMasterRow();
      setTimeout(() => {
        masterGridApi.value?.forEachNode(node => {
          if (node.data?.id === newRow.id) node.setSelected(true);
        });
      }, 50);
    } else if (target.tabKey) {
      store.addDetailRow(target.tabKey, {});
    }
  } else if (key === 'copy' && target.rowData) {
    const sourceData = { ...target.rowData };
    delete sourceData.id;
    delete sourceData._isNew;
    delete sourceData._isDeleted;
    delete sourceData._changeType;
    delete sourceData._originalValues;
    
    if (target.isMaster) {
      // 复制主表时，连带复制从表数据
      const sourceDetails = sourceData._details;
      delete sourceData._details;
      
      const newRow = store.addMasterRow(sourceData);
      
      // 复制从表数据
      if (sourceDetails?.rows?.length > 0) {
        const fkField = detailFkColumn.value;
        for (const detailRow of sourceDetails.rows) {
          if (detailRow._isDeleted) continue;
          
          const detailCopy = { ...detailRow };
          delete detailCopy.id;
          delete detailCopy._isNew;
          delete detailCopy._isDeleted;
          delete detailCopy._changeType;
          delete detailCopy._originalValues;
          
          // 设置新的外键关联（临时 ID）
          if (fkField) {
            detailCopy[fkField] = newRow.id;
          }
          
          // 直接添加到新主表的从表中
          const newDetailId = generateTempId();
          newRow._details!.rows.push({
            ...detailCopy,
            id: newDetailId,
            _isNew: true,
            _changeType: {},
            _originalValues: {}
          });
        }
      }
      
      setTimeout(() => {
        masterGridApi.value?.forEachNode(node => {
          if (node.data?.id === newRow.id) node.setSelected(true);
        });
      }, 50);
    } else if (target.tabKey) {
      delete sourceData._details;
      store.addDetailRow(target.tabKey, sourceData);
    }
  } else if (key === 'delete' && target.rowData) {
    store.deleteRow(target.rowData.id, target.isMaster);
  }
}

function onContextMenuClickOutside() {
  contextMenuVisible.value = false;
}

// ==================== Adapter ====================

const masterAdapter = useGridAdapter({
  gridApi: masterGridApi,
  rowsGetter: () => store.visibleMasterRows,
  onFieldUpdate: (rowId, field, value) => {
    store.updateField(rowId, field, value, 'user', true);
  }
});

// ==================== Grid Helpers ====================

function getRowId(params: any) {
  return String(params.data?.id);
}

// ==================== Event Handlers ====================

function onMasterGridReady(params: GridReadyEvent) {
  masterGridApi.value = params.api;
  // 只对没有配置固定宽度的列进行自动调整
  const colsToAutoSize = store.masterColumns
    .filter(col => !col.width)
    .map(col => col.field as string);
  
  if (colsToAutoSize.length > 0) {
    params.api.autoSizeColumns(colsToAutoSize);
  }
}

async function onMasterSelectionChanged() {
  const api = masterGridApi.value;
  if (!api) return;

  const selectedRows = api.getSelectedRows();
  if (selectedRows.length !== 1) return;

  const masterId = selectedRows[0].id;
  const needLoad = store.selectMaster(masterId);

  if (needLoad) {
    await loadDetailData(masterId);
  }
}

/** 三层嵌套模式：主表行展开时的事件处理（数据加载已在 getDetailRowData 中处理） */
async function onMasterRowExpanded(event: any) {
  // 数据加载逻辑已移至 masterDetailParams.getDetailRowData
  // 此处仅用于其他扩展逻辑（如日志、统计等）
}

function onMasterCellValueChanged(event: CellValueChangedEvent) {
  masterAdapter.onCellValueChanged(event);
}

function onMasterCellClicked(event: any) {
  const field = event.colDef?.field;
  const rowData = event.data;
  if (!field || !rowData) return;
  
  // 检查是否有 lookup 配置
  const rule = masterLookupRules.value.find(r => r.fieldName === field);
  if (!rule) return;
  
  // 保存当前上下文，打开弹窗
  currentLookupRule.value = rule;
  currentLookupRowId.value = rowData.id;
  currentLookupIsMaster.value = true;
  lookupDialogRef.value?.open();
}

function onDetailCellValueChanged(event: { tabKey: string; rowId: number; field: string; value: any }) {
  store.updateField(event.rowId, event.field, event.value, 'user', false);
}

function onDetailCellClicked(event: { tabKey: string; rowId: number; field: string; data: any }) {
  // 检查是否有 lookup 配置
  const rule = detailLookupRules.value.find(r => r.fieldName === event.field);
  if (!rule) return;
  
  // 保存当前上下文，打开弹窗
  currentLookupRule.value = rule;
  currentLookupRowId.value = event.rowId;
  currentLookupIsMaster.value = false;
  lookupDialogRef.value?.open();
}

function onLookupSelect(fillData: Record<string, any>) {
  if (!currentLookupRowId.value) return;
  
  const rowId = currentLookupRowId.value;
  const isMaster = currentLookupIsMaster.value;
  store.updateFields(rowId, fillData, isMaster);
  
  // 清理状态
  currentLookupRule.value = null;
  currentLookupRowId.value = null;
  currentLookupIsMaster.value = false;
}

function onLookupCancel() {
  currentLookupRule.value = null;
  currentLookupRowId.value = null;
  currentLookupIsMaster.value = false;
}

function onDetailContextMenu(payload: { tabKey: string; rowData: any; x: number; y: number }) {
  contextMenuX.value = payload.x;
  contextMenuY.value = payload.y;
  contextMenuTarget.value = { isMaster: false, rowData: payload.rowData, tabKey: payload.tabKey };
  contextMenuVisible.value = true;
}

// ==================== Data Loading ====================

async function loadMetadata() {
  // 1. 加载页面组件配置
  const pageRes = await fetchPageComponents(props.pageCode);

  if (pageRes.error || !pageRes.data) {
    message.error('加载页面配置失败');
    return;
  }

  const pageConfig = parsePageComponents(pageRes.data);
  if (!pageConfig) {
    message.error('解析页面配置失败');
    return;
  }

  // 加载右键菜单配置
  const contextMenuComponent = pageRes.data.find((comp: any) => comp.componentType === 'CONTEXT_MENU');
  if (contextMenuComponent?.componentConfig) {
    try {
      contextMenuConfig.value = typeof contextMenuComponent.componentConfig === 'string'
        ? JSON.parse(contextMenuComponent.componentConfig)
        : contextMenuComponent.componentConfig;
    } catch (e) {
      console.warn('解析右键菜单配置失败:', e);
    }
  }

  // 2. 加载主表元数据（传入 pageCode 合并权限）
  const masterMeta = await loadTableMeta(pageConfig.masterTableCode, props.pageCode);
  if (!masterMeta) {
    message.error('加载主表元数据失败');
    return;
  }

  // 保存原始列元数据（用于验证）
  masterColumnMeta.value = masterMeta.rawColumns || [];
  masterValidationRules.value = parseValidationRules(masterColumnMeta.value);
  
  // 保存行样式类函数
  masterGetRowClass.value = masterMeta.getRowClass;
  
  // 提取主表 lookup 规则
  masterLookupRules.value = masterMeta.lookupRules || [];

  // 3. 加载从表元数据（如果有，传入 pageCode 合并权限）
  let detailCols: ColDef[] = [];
  if (pageConfig.detailTableCode) {
    const detailMeta = await loadTableMeta(pageConfig.detailTableCode, props.pageCode);
    if (!detailMeta) {
      message.error('加载从表元数据失败');
      return;
    }

    detailColumnMeta.value = detailMeta.rawColumns || [];
    detailValidationRules.value = parseValidationRules(detailColumnMeta.value);
    detailCols = detailMeta.columns;
    
    // 保存从表行样式类函数
    detailGetRowClass.value = detailMeta.getRowClass;
    
    // 提取 lookup 规则
    detailLookupRules.value = detailMeta.lookupRules || [];

    // 保存从表外键字段名（从列元数据中查找 fieldName）
    const fkCol = detailMeta.metadata?.parentFkColumn;
    if (fkCol) {
      // 在列元数据中找到 columnName 匹配的列，取其 fieldName
      const fkColumnMeta = detailMeta.rawColumns?.find(
        (col: any) => col.columnName?.toUpperCase() === fkCol.toUpperCase()
      );
      detailFkColumn.value = fkColumnMeta?.fieldName || fkCol.toLowerCase();
    }

    // 初始化可见 Tab
    pageConfig.tabs.forEach(tab => visibleTabKeys.value.add(tab.key));
    
    // 合并从表列元数据中的计算规则（RULES_CONFIG 中定义的）
    if (detailMeta.calcRules && detailMeta.calcRules.length > 0) {
      pageConfig.calcRules = [...pageConfig.calcRules, ...detailMeta.calcRules];
    }
  }

  // 4. 初始化 Store
  store.init(
    pageConfig,
    masterMeta.columns,
    detailCols
  );
}

async function loadMasterData() {
  const tableCode = store.config?.masterTableCode;
  if (!tableCode) return;

  // 使用 searchDynamicData 传入 pageCode 以应用数据权限
  const { data, error } = await searchDynamicData(tableCode, {
    pageCode: props.pageCode
  });
  if (error) {
    message.error('加载主表数据失败');
    return;
  }

  store.loadMaster(data?.list || []);

  // 自动选中第一行
  if (store.masterRows.length > 0) {
    setTimeout(() => {
      masterGridApi.value?.forEachNode((node, index) => {
        if (index === 0) node.setSelected(true);
      });
    }, 100);
  }
}

async function loadDetailData(masterId: number) {
  const tableCode = store.config?.detailTableCode;
  const fkColumn = detailFkColumn.value;

  if (!tableCode || !fkColumn) return;

  // 使用 searchDynamicData 传入 pageCode 以应用数据权限
  const { data, error } = await searchDynamicData(tableCode, {
    pageCode: props.pageCode,
    conditions: [{ field: fkColumn, operator: 'eq', value: masterId }]
  });
  if (error) {
    message.error('加载从表数据失败');
    return;
  }

  store.loadDetail(data?.list || []);
}

/** 为指定主表行加载从表数据（用于展开时数据为空的情况） */
async function loadDetailForRow(masterId: number) {
  const tableCode = store.config?.detailTableCode;
  const fkColumn = detailFkColumn.value;

  if (!tableCode || !fkColumn) return;

  const { data, error } = await searchDynamicData(tableCode, {
    pageCode: props.pageCode,
    conditions: [{ field: fkColumn, operator: 'eq', value: masterId }]
  });
  if (error) {
    message.error('加载从表数据失败');
    return;
  }

  // 直接挂载到指定主表行
  store.loadDetailForMaster(masterId, data?.list || []);
}

// ==================== Toolbar Actions ====================

async function handleRefresh() {
  store.reset();
  await loadMasterData();
}

async function handleSave() {
  if (!store.isDirty) {
    message.info('没有需要保存的数据');
    return;
  }

  // 验证主表数据
  const masterResult = validateRows(
    store.masterRows,
    masterValidationRules.value,
    masterColumnMeta.value
  );
  if (!masterResult.valid) {
    message.error('主表数据验证失败:\n' + formatValidationErrors(masterResult.errors));
    return;
  }

  // 验证从表数据（所有主表的从表）
  for (const master of store.masterRows) {
    if (master._isDeleted || !master._details?.rows) continue;

    const detailResult = validateRows(
      master._details.rows,
      detailValidationRules.value,
      detailColumnMeta.value
    );
    if (!detailResult.valid) {
      message.error(`从表数据验证失败 (主表ID: ${master.id}):\n` + formatValidationErrors(detailResult.errors));
      return;
    }
  }

  const params = buildSaveParams(
    props.pageCode,
    store.masterRows as any,
    store.config?.masterTableCode || '',
    store.config?.detailTableCode || '',
    detailFkColumn.value
  );

  if (params.length === 0) {
    message.warning('没有有效的保存数据');
    return;
  }

  try {
    for (const param of params) {
      const { error } = await saveDynamicData(param);
      if (error) {
        message.error('保存失败: ' + (error.msg || '未知错误'));
        return;
      }
    }

    message.success('保存成功');
    store.clearChanges();
    await handleRefresh();
  } catch (e: any) {
    message.error('保存失败: ' + (e.message || '网络错误'));
  }
}

// ==================== Keyboard Shortcuts ====================

function onKeyDown(e: KeyboardEvent) {
  if (e.ctrlKey && e.key === 's') {
    e.preventDefault();
    handleSave();
  }
}

// ==================== Watch ====================

// 监听 updateVersion 变化，刷新主表 Grid 单元格样式
watch(
  () => store.updateVersion,
  () => {
    masterGridApi.value?.refreshCells({ force: true });
    
    // 三层嵌套模式：刷新所有展开的 detail grid
    if (isNestedMode.value) {
      refreshAllDetailGrids();
    }
  }
);

/** 刷新所有展开的 detail grid（三层嵌套模式） */
function refreshAllDetailGrids() {
  const api = masterGridApi.value;
  if (!api) return;
  
  // 遍历所有主表行，刷新已展开的 detail
  api.forEachNode(node => {
    if (node.expanded && node.data) {
      const masterId = node.data.id;
      // 从 store 获取最新的主表行数据（而不是用 node.data）
      const masterRow = store.masterRows.find(r => r.id === masterId);
      if (!masterRow) return;
      
      const detailGridInfo = api.getDetailGridInfo(`detail_${masterId}`);
      if (detailGridInfo?.api) {
        const summaryApi = detailGridInfo.api;
        // 重新计算汇总数据
        const newSummaryData = calcSummaryRowsForMaster(masterRow);
        
        // 用 setDataValue 逐字段更新，保持展开状态
        newSummaryData.forEach((newRow: any) => {
          const rowId = `${newRow._masterId}_${newRow._groupKey}`;
          const rowNode = summaryApi.getRowNode(rowId);
          if (rowNode) {
            // 更新汇总字段（跳过内部字段）
            Object.keys(newRow).forEach(field => {
              if (!field.startsWith('_') && rowNode.data[field] !== newRow[field]) {
                rowNode.setDataValue(field, newRow[field]);
              }
            });
            // 同步 _detailRows 供第三层使用（直接赋值，不触发渲染）
            rowNode.data._detailRows = newRow._detailRows;
            
            // 如果第三层也展开了，刷新第三层数据
            if (rowNode.expanded) {
              const thirdLevelId = `detail_${rowId}`;
              const thirdGridInfo = summaryApi.getDetailGridInfo(thirdLevelId);
              console.log('[三层刷新] 查找第三层 grid:', thirdLevelId, '结果:', !!thirdGridInfo);
              if (thirdGridInfo?.api) {
                // 第三层数据和 store 是同一个引用，数据已经更新
                // 只需要强制刷新单元格显示
                const thirdApi = thirdGridInfo.api;
                thirdApi.refreshCells({ force: true });
              }
            }
          }
        });
      }
    }
  });
}

// ==================== Lifecycle ====================

onMounted(async () => {
  document.addEventListener('keydown', onKeyDown);
  window.addEventListener('beforeunload', onBeforeUnload);

  // 注入单元格样式
  if (!document.getElementById('cell-change-styles')) {
    const style = document.createElement('style');
    style.id = 'cell-change-styles';
    style.textContent = cellStyleCSS;
    document.head.appendChild(style);
  }

  await loadMetadata();
  await loadMasterData();
});

onUnmounted(() => {
  document.removeEventListener('keydown', onKeyDown);
  window.removeEventListener('beforeunload', onBeforeUnload);
});

function onBeforeUnload(e: BeforeUnloadEvent) {
  if (store.isDirty) {
    e.preventDefault();
    e.returnValue = '';
  }
}
</script>

<style scoped>
.master-detail-page {
  height: 100%;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.split-container {
  flex: 1;
  min-height: 0;
}

.master-section,
.detail-section {
  height: 100%;
  background: #fff;
  border-radius: 4px;
  overflow: hidden;
}

.master-section.full {
  flex: 1;
  min-height: 0;
}

/* 表头自动换行 */
.master-section :deep(.ag-header-cell-label),
.detail-section :deep(.ag-header-cell-label) {
  white-space: normal !important;
  word-wrap: break-word;
  line-height: 1.2;
  display: flex;
  align-items: center;
  justify-content: center;
  text-align: center;
  font-size: 11px;
}

.master-section :deep(.ag-header-cell),
.detail-section :deep(.ag-header-cell) {
  padding-top: 2px;
  padding-bottom: 2px;
}

.master-section :deep(.ag-header-cell-text),
.detail-section :deep(.ag-header-cell-text) {
  white-space: normal !important;
  word-wrap: break-word;
  overflow: visible !important;
  font-size: 11px;
}

.loading-container {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
}

/* ========== AG Grid Quartz 主题美化 ========== */

/* 去掉外边框 */
.master-section :deep(.ag-root-wrapper) {
  border: none;
}

/* 表头样式 */
.master-section :deep(.ag-header) {
  background-color: #f9fafb;
  border-radius: 8px;
  border: 1px solid #eff0f1;
}

/* 行样式：去掉底边框，添加圆角 */
.master-section :deep(.ag-row) {
  border-bottom: none;
}

.master-section :deep(.ag-row:not(.ag-row-level-1)) {
  border-radius: 8px;
  overflow: hidden;
}

/* 单元格垂直居中 */
.master-section :deep(.ag-cell) {
  display: flex;
  align-items: center;
}

/* 首尾单元格圆角 */
.master-section :deep(.ag-cell:first-child) {
  border-top-left-radius: 8px;
  border-bottom-left-radius: 8px;
}

.master-section :deep(.ag-cell:last-child) {
  border-top-right-radius: 8px;
  border-bottom-right-radius: 8px;
}

/* 数字列右对齐 */
.master-section :deep(.ag-right-aligned-cell) {
  justify-content: flex-end;
}

/* Master-Detail 紧凑布局 */
.master-section :deep(.ag-center-cols-viewport) {
  min-height: unset !important;
}

.master-section :deep(.ag-details-row) {
  padding: 8px 16px;
}

.master-section :deep(.ag-full-width-container .ag-row),
.master-section :deep(.ag-full-width-container .ag-details-row) {
  background-color: transparent;
}

/* 行 hover 过渡效果 */
.master-section :deep(.ag-row:not(.ag-row-level-1))::before {
  content: "";
  display: block;
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  pointer-events: none;
  transition: background-color 0.2s ease-in-out;
}
</style>
