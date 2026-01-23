<template>
  <div class="detail-row-renderer">
    <DetailPanelV3
      :tabs="tabs"
      :activeMasterId="masterId"
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
      :defaultViewMode="defaultViewMode"
      :viewMode="detailViewMode"
      :onViewModeChange="setDetailViewMode"
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
const defaultViewMode = computed(() => panelContext.value.defaultViewMode || 'stack');
const detailViewMode = computed(() => unref(panelContext.value.detailViewMode));
const setDetailViewMode = computed(() => panelContext.value.setDetailViewMode || noop);
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
