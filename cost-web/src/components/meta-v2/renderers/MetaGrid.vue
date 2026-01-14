<template>
  <div class="meta-grid" :class="gridClass" :style="containerStyle">
    <AgGridVue
      class="ag-theme-quartz"
      style="width: 100%; height: 100%"
      :rowData="rowData"
      :columnDefs="columnDefs"
      :defaultColDef="defaultColDef"
      :getRowId="getRowId"
      :getRowClass="getRowClass"
      :rowSelection="rowSelection"
      :autoSizeStrategy="autoSizeStrategy"
      :getContextMenuItems="getContextMenuItems"
      :rowHeight="rowHeight"
      :headerHeight="headerHeight"
      v-bind="gridOptions"
      @grid-ready="handleGridReady"
      @cell-value-changed="handleCellValueChanged"
      @cell-clicked="handleCellClicked"
      @cell-editing-started="handleCellEditingStarted"
      @cell-editing-stopped="handleCellEditingStopped"
    />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { AgGridVue } from 'ag-grid-vue3';
import type { ColDef, GridReadyEvent } from 'ag-grid-community';
import type { PageComponentWithRules } from '@/composables/meta-v2/types';

type GridConfig = {
  width?: string | number;
  height?: string | number;
  className?: string;
};

const props = defineProps<{
  component: PageComponentWithRules;
  runtime: any;
}>();

function parseGridConfig(config?: string): GridConfig {
  if (!config) return {};
  try {
    return JSON.parse(config) as GridConfig;
  } catch (error) {
    console.warn('[MetaV2] grid config parse failed', error);
    return {};
  }
}

function resolveComponentState(): Record<string, any> {
  const source = props.runtime?.componentStateByKey;
  const stateByKey = source?.value ?? source;
  if (!stateByKey) return {};
  return stateByKey[props.component.componentKey] || {};
}

const state = computed(() => resolveComponentState());
const gridConfig = computed(() => parseGridConfig(props.component.componentConfig));

function toCssSize(value: string | number | undefined) {
  if (value == null) return undefined;
  return typeof value === 'number' ? `${value}px` : value;
}

const containerStyle = computed(() => ({
  width: toCssSize(gridConfig.value.width) || '100%',
  height: toCssSize(gridConfig.value.height) || '100%'
}));

const gridClass = computed(() => gridConfig.value.className || '');

const rowData = computed(() => state.value.rowData ?? []);
const columnDefs = computed<ColDef[]>(() => state.value.columnDefs ?? []);
const defaultColDef = computed<ColDef>(() => ({
  sortable: true,
  filter: true,
  resizable: true,
  ...(state.value.defaultColDef || {})
}));

const gridOptions = computed(() => state.value.gridOptions ?? {});
const rowSelection = computed(() => state.value.rowSelection);
const autoSizeStrategy = computed(() => state.value.autoSizeStrategy);
const getRowId = computed(() => state.value.getRowId);
const getRowClass = computed(() => state.value.getRowClass);
const getContextMenuItems = computed(() => state.value.getContextMenuItems);
const rowHeight = computed(() => state.value.rowHeight);
const headerHeight = computed(() => state.value.headerHeight);

function handleGridReady(params: GridReadyEvent) {
  state.value.onGridReady?.(params);
}

function handleCellValueChanged(event: any) {
  state.value.onCellValueChanged?.(event);
}

function handleCellClicked(event: any) {
  state.value.onCellClicked?.(event);
}

function handleCellEditingStarted(event: any) {
  state.value.onCellEditingStarted?.(event);
}

function handleCellEditingStopped(event: any) {
  state.value.onCellEditingStopped?.(event);
}
</script>

<style scoped>
.meta-grid {
  width: 100%;
  height: 100%;
}
</style>
