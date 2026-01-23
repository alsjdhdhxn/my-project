<template>
  <div class="detail-panel-inner" :class="{ 'tab-mode': currentViewMode === 'tab' }">
    <div class="detail-toolbar" v-if="hasTabs && currentViewMode === 'tab'">
      <div class="detail-tabs">
        <template v-if="currentViewMode === 'tab'">
          <button
            v-for="tab in tabs"
            :key="tab.key"
            class="tab-btn"
            :class="{ active: tab.key === activeTab }"
            @click="activeTab = tab.key"
          >
            {{ tab.title }}
          </button>
        </template>
        <div class="detail-toggle">
          <button class="toggle-btn" :class="{ active: currentViewMode === 'tab' }" @click="setViewMode('tab')">Tab</button>
          <button class="toggle-btn" :class="{ active: currentViewMode === 'stack' }" @click="setViewMode('stack')">Stack</button>
        </div>
      </div>
    </div>

    <div class="detail-body">
      <div v-if="!activeMasterId" class="detail-empty">请选择主表记录</div>
      <div v-else-if="!hasTabs" class="detail-empty">暂无明细配置</div>
      <div v-else class="detail-content">
        <DetailGridV3
          v-if="currentViewMode === 'tab' && activeTabConfig"
          :key="activeTabConfig.key"
          :tab="activeTabConfig"
          :rows="resolveRows(activeTabConfig.key)"
          :columns="detailColumnsByTab[activeTabConfig.key] || []"
          :rowClassGetter="detailRowClassByTab?.[activeTabConfig.key]"
          :gridOptions="detailGridOptionsByTab?.[activeTabConfig.key]"
          :cellClassRules="cellClassRules"
          :contextMenuItems="getDetailContextMenuItemsFor(activeTabConfig.key)"
          :registerDetailGridApi="handleRegister"
          :unregisterDetailGridApi="handleUnregister"
          :applyGridConfig="applyGridConfig"
          :onCellValueChanged="(event) => onDetailCellValueChanged(event, activeMasterId!, activeTabConfig.key)"
          :onCellClicked="(event) => onDetailCellClicked(event, activeMasterId!, activeTabConfig.key)"
          :onCellEditingStarted="onCellEditingStarted"
          :onCellEditingStopped="onCellEditingStopped"
        />

        <div v-else class="detail-stack">
          <DetailGridV3
            v-for="(tab, index) in tabs"
            :key="tab.key"
            :tab="tab"
            :rows="resolveRows(tab.key)"
            :columns="detailColumnsByTab[tab.key] || []"
            :rowClassGetter="detailRowClassByTab?.[tab.key]"
            :gridOptions="detailGridOptionsByTab?.[tab.key]"
            :cellClassRules="cellClassRules"
            :contextMenuItems="getDetailContextMenuItemsFor(tab.key)"
            :showTitle="true"
            :registerDetailGridApi="handleRegister"
            :unregisterDetailGridApi="handleUnregister"
            :applyGridConfig="applyGridConfig"
            :onCellValueChanged="(event) => onDetailCellValueChanged(event, activeMasterId!, tab.key)"
            :onCellClicked="(event) => onDetailCellClicked(event, activeMasterId!, tab.key)"
            :onCellEditingStarted="onCellEditingStarted"
            :onCellEditingStopped="onCellEditingStopped"
          >
            <template v-if="index === 0" #title-extra>
              <div class="detail-toggle">
                <button class="toggle-btn" :class="{ active: currentViewMode === 'tab' }" @click="setViewMode('tab')">
                  Tab
                </button>
                <button class="toggle-btn" :class="{ active: currentViewMode === 'stack' }" @click="setViewMode('stack')">
                  Stack
                </button>
              </div>
            </template>
          </DetailGridV3>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue';
import type { ColDef } from 'ag-grid-community';
import type { TabConfig, RowData } from '@/v3/logic/calc-engine';
import DetailGridV3 from '@/v3/components/detail/DetailGridV3.vue';
import type { ResolvedGridOptions } from '@/v3/composables/meta-v3/grid-options';

const props = defineProps<{
  tabs: TabConfig[];
  activeMasterId: number | null;
  detailCache: Map<number, Record<string, RowData[]>>;
  detailColumnsByTab: Record<string, ColDef[]>;
  detailRowClassByTab?: Record<string, ((params: any) => string | undefined) | undefined>;
  detailGridOptionsByTab?: Record<string, ResolvedGridOptions>;
  cellClassRules: ColDef['cellClassRules'];
  defaultViewMode?: 'tab' | 'stack';
  viewMode?: 'tab' | 'stack';
  onViewModeChange?: (mode: 'tab' | 'stack') => void;
  applyGridConfig?: (gridKey: string, api: any, columnApi: any) => void;
  onDetailCellValueChanged: (event: any, masterId: number, tabKey: string) => void;
  onDetailCellClicked: (event: any, masterId: number, tabKey: string) => void;
  onCellEditingStarted: () => void;
  onCellEditingStopped: () => void;
  loadDetailData: (masterId: number) => Promise<void>;
  registerDetailGridApi: (tabKey: string, api: any) => void;
  unregisterDetailGridApi?: (tabKey: string, api: any) => void;
  getDetailContextMenuItems: (masterId: number, tabKey: string) => (params: any) => any[];
}>();

const localViewMode = ref<'tab' | 'stack'>(props.defaultViewMode ?? 'tab');
const activeTab = ref<string>('');
const gridApis = ref<Record<string, any>>({});

const hasTabs = computed(() => Array.isArray(props.tabs) && props.tabs.length > 0);
const hasExternalViewMode = computed(() => props.viewMode != null);
const currentViewMode = computed<'tab' | 'stack'>({
  get: () => props.viewMode ?? localViewMode.value,
  set: (mode) => {
    if (props.onViewModeChange) {
      props.onViewModeChange(mode);
    } else {
      localViewMode.value = mode;
    }
  }
});

const activeTabConfig = computed(() => {
  if (!hasTabs.value) return null;
  return props.tabs.find(tab => tab.key === activeTab.value) || props.tabs[0];
});

watch(
  () => props.tabs,
  (tabs) => {
    if (!tabs || tabs.length === 0) {
      activeTab.value = '';
      return;
    }
    if (!activeTab.value || !tabs.some(tab => tab.key === activeTab.value)) {
      activeTab.value = tabs[0].key;
    }
  },
  { immediate: true }
);

watch(
  () => props.activeMasterId,
  async (masterId) => {
    if (masterId == null) return;
    if (!props.detailCache.get(masterId)) {
      await props.loadDetailData(masterId);
    }
    updateGridRows(masterId);
  },
  { immediate: true }
);

watch(activeTab, () => {
  if (props.activeMasterId == null) return;
  updateGridRows(props.activeMasterId, activeTab.value);
  nextTick(() => refreshLayout());
});

watch(currentViewMode, async () => {
  await nextTick();
  refreshLayout();
});

function setViewMode(mode: 'tab' | 'stack') {
  currentViewMode.value = mode;
}

function handleRegister(tabKey: string, api: any) {
  gridApis.value[tabKey] = api;
  props.registerDetailGridApi(tabKey, api);
  if (props.activeMasterId != null) {
    const rows = props.detailCache.get(props.activeMasterId)?.[tabKey] || [];
    api?.setGridOption?.('rowData', rows);
  }
}

function handleUnregister(tabKey: string, api: any) {
  if (gridApis.value[tabKey] === api) {
    delete gridApis.value[tabKey];
  }
  props.unregisterDetailGridApi?.(tabKey, api);
}

function resolveRows(tabKey: string): RowData[] {
  if (props.activeMasterId == null) return [];
  return props.detailCache.get(props.activeMasterId)?.[tabKey] || [];
}

function updateGridRows(masterId: number, tabKey?: string) {
  const cached = props.detailCache.get(masterId);
  if (!cached) return;
  if (tabKey) {
    gridApis.value[tabKey]?.setGridOption('rowData', cached[tabKey] || []);
    return;
  }
  Object.entries(cached).forEach(([key, rows]) => {
    gridApis.value[key]?.setGridOption('rowData', rows || []);
  });
}

function getDetailContextMenuItemsFor(tabKey: string) {
  if (props.activeMasterId == null) return () => [];
  return props.getDetailContextMenuItems(props.activeMasterId, tabKey);
}

function refreshLayout() {
  const apis = Object.values(gridApis.value);
  if (apis.length === 0) return;
  apis.forEach(api => {
    api?.doLayout?.();
    api?.sizeColumnsToFit?.();
  });
}
</script>

<style scoped>
.detail-panel-inner {
  display: flex;
  flex-direction: column;
  gap: 8px;
  --detail-title-height: 24px;
}

.detail-panel-inner.tab-mode {
  gap: 4px;
}

.detail-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  height: var(--detail-title-height);
  padding: 0 12px;
  border-bottom: 1px solid #eef2f7;
}

.detail-tabs {
  display: flex;
  gap: 12px;
  flex: 1;
  align-items: center;
  height: 100%;
}

.tab-btn {
  border: none;
  background: transparent;
  height: 100%;
  padding: 0 2px;
  line-height: var(--detail-title-height);
  font-size: 13px;
  color: #64748b;
  border-bottom: 2px solid transparent;
  cursor: pointer;
  transition: all 0.2s ease;
}

.tab-btn.active {
  color: #2563eb;
  border-bottom-color: #2563eb;
  font-weight: 600;
}

.detail-toggle {
  margin-left: auto;
  display: inline-flex;
  gap: 4px;
  height: calc(var(--detail-title-height) - 6px);
  padding: 0 2px;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 999px;
}

.toggle-btn {
  border: none;
  background: transparent;
  height: 100%;
  padding: 0 8px;
  line-height: calc(var(--detail-title-height) - 6px);
  border-radius: 999px;
  font-size: 11px;
  color: #64748b;
  cursor: pointer;
  transition: all 0.2s ease;
}

.toggle-btn.active {
  background: #2563eb;
  color: #ffffff;
  font-weight: 600;
}

.detail-body {
  padding: 0 12px 12px 12px;
}

.detail-content {
}

/* Tab 模式下单个 grid */
.detail-panel-inner.tab-mode :deep(.detail-grid-wrap) {
  height: 300px;
}

/* 堆叠模式：多个子表垂直排列 */
.detail-stack {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.detail-stack :deep(.detail-grid-wrap) {
  height: 200px;
}

.detail-empty {
  height: 100px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #94a3b8;
  font-size: 13px;
}
</style>

