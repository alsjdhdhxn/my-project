<template>
  <div class="detail-row-renderer" @mouseenter="onMouseEnter" @mouseleave="onMouseLeave">
    <DetailPanelV3
      :tabs="tabs"
      :activeMasterId="masterId"
      :activeMasterRowKey="masterRowKey"
      :detailCache="detailCache"
      :detailColumnsByTab="detailColumnsByTab"
      :detailRowClassByTab="detailRowClassByTab"
      :detailGridOptionsByTab="detailGridOptionsByTab"
      :cellClassRules="cellClassRules"
      :applyGridConfig="applyGridConfig"
      :onDetailCellValueChanged="onDetailCellValueChanged"
      :onDetailCellClicked="onDetailCellClicked"
      :onCellEditingStarted="onCellEditingStarted"
      :onCellEditingStopped="onCellEditingStopped"
      :loadDetailData="loadDetailData"
      :registerDetailGridApi="registerDetailGridApi"
      :unregisterDetailGridApi="unregisterDetailGridApi"
      :getDetailContextMenuItems="getDetailContextMenuItems"
      :refreshDetailRowHeight="refreshDetailRowHeight"
      :defaultViewMode="defaultViewMode"
      :viewMode="detailViewMode"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, unref } from 'vue';
import DetailPanelV3 from '@/v3/components/detail/DetailPanelV3.vue';

const props = defineProps<{ params: any }>();

const panelContext = computed(() => props.params?.context?.detailPanelContext || {});

const masterId = computed<number | null>(() => {
  const raw = props.params?.data?.id;
  if (raw == null) return null;
  const value = Number(raw);
  return Number.isNaN(value) ? null : value;
});
const masterRowKey = computed<string | null>(() => {
  const raw = props.params?.data?._rowKey;
  return raw ? String(raw) : null;
});

const tabs = computed(() => unref(panelContext.value.tabs) || []);
const detailCache = computed(() => panelContext.value.detailCache || new Map());
const detailColumnsByTab = computed(() => unref(panelContext.value.detailColumnsByTab) || {});
const detailRowClassByTab = computed(() => unref(panelContext.value.detailRowClassByTab) || {});
const detailGridOptionsByTab = computed(() => unref(panelContext.value.detailGridOptionsByTab) || {});
const cellClassRules = computed(() => panelContext.value.cellClassRules);
const noop = () => {};
const noopLoad = async () => {};
const noopMenu = () => () => [];

const applyGridConfig = computed(() => panelContext.value.applyGridConfig);
const onDetailCellValueChanged = computed(() => panelContext.value.onDetailCellValueChanged || noop);
const onDetailCellClicked = computed(() => panelContext.value.onDetailCellClicked || noop);
const onCellEditingStarted = computed(() => panelContext.value.onCellEditingStarted || noop);
const onCellEditingStopped = computed(() => panelContext.value.onCellEditingStopped || noop);
const loadDetailData = computed(() => panelContext.value.loadDetailData || noopLoad);
const registerDetailGridApi = computed(() => panelContext.value.registerDetailGridApi || noop);
const unregisterDetailGridApi = computed(() => panelContext.value.unregisterDetailGridApi || noop);
const getDetailContextMenuItems = computed(() => panelContext.value.getDetailContextMenuItems || noopMenu);
const refreshDetailRowHeight = computed(() => panelContext.value.refreshDetailRowHeight || noop);
const defaultViewMode = computed(() => panelContext.value.defaultViewMode || 'stack');
const detailViewMode = computed(() => unref(panelContext.value.detailViewMode));

// 鼠标进入子表区域时，禁用主表滚动
function onMouseEnter() {
  const masterGrid = document.querySelector('.master-grid');
  if (masterGrid) {
    const viewport = masterGrid.querySelector('.ag-body-viewport') as HTMLElement;
    if (viewport) {
      viewport.style.overflowY = 'hidden';
    }
  }
}

// 鼠标离开子表区域时，恢复主表滚动
function onMouseLeave() {
  const masterGrid = document.querySelector('.master-grid');
  if (masterGrid) {
    const viewport = masterGrid.querySelector('.ag-body-viewport') as HTMLElement;
    if (viewport) {
      viewport.style.overflowY = '';
    }
  }
}
</script>

<style scoped>
.detail-row-renderer {
  height: 100%;
  overflow: auto;
  padding: 8px 12px 12px 12px;
  background: #f8fafc;
  box-sizing: border-box;
}
</style>
