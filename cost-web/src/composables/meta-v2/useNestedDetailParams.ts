import { computed, watch, type Ref } from 'vue';
import type { ColDef } from 'ag-grid-community';
import type { ParsedPageConfig, RowData } from '@/logic/calc-engine';
import {
  buildSummaryColumnDefs,
  buildSummaryRows,
  getSummaryRowId,
  resolveSummaryConfig
} from '@/composables/meta-v2/summary-config';
import { buildGridRuntimeOptions, autoSizeColumnsOnReady, type ResolvedGridOptions } from '@/composables/meta-v2/grid-options';

export function useNestedDetailParams(params: {
  pageConfig: Ref<ParsedPageConfig | null>;
  detailColumnsByTab: Ref<Record<string, ColDef[]>>;
  detailCache: Map<number, Record<string, RowData[]>>;
  loadDetailData: (masterId: number) => Promise<void>;
  cellClassRules: ColDef['cellClassRules'];
  getRowClass: (params: any) => string | undefined;
  detailRowClassByTab?: Ref<Record<string, ((params: any) => string | undefined) | undefined>>;
  detailGridOptionsByTab?: Ref<Record<string, ResolvedGridOptions>>;
  applyGridConfig?: (gridKey: string, api: any, columnApi: any) => void;
  getDetailContextMenuItems: (masterId: number, tabKey: string) => (params: any) => any[];
  onCellEditingStarted: () => void;
  onCellEditingStopped: () => void;
  onDetailCellValueChanged: (event: any, masterId: number, tabKey: string) => void;
  onDetailCellClicked: (event: any, masterId: number, tabKey: string) => void;
}) {
  const {
    pageConfig,
    detailColumnsByTab,
    detailCache,
    loadDetailData,
    cellClassRules,
    getRowClass,
    detailRowClassByTab,
    detailGridOptionsByTab,
    applyGridConfig,
    getDetailContextMenuItems,
    onCellEditingStarted,
    onCellEditingStopped,
    onDetailCellValueChanged,
    onDetailCellClicked
  } = params;

  const summaryConfig = computed(() => resolveSummaryConfig(pageConfig.value));

  const summaryDetailParams = {
    refreshStrategy: 'nothing' as const,
    detailGridOptions: {
      columnDefs: buildSummaryColumnDefs(summaryConfig.value),
      defaultColDef: { sortable: false, filter: false, resizable: true, wrapHeaderText: true, autoHeaderHeight: true },
      rowHeight: 28,
      masterDetail: true,
      keepDetailRows: true,
      detailRowAutoHeight: true,
      getRowId: (rowParams: any) => {
        const masterId = rowParams.data?._masterId;
        const tabKey = rowParams.data?._tabKey;
        if (masterId == null || !tabKey) return String(rowParams.data?.id ?? '');
        return getSummaryRowId(masterId, tabKey);
      },
      detailCellRendererParams: null as any
    },
    getDetailRowData: async (params: any) => {
      const masterId = params.data?.id;
      if (masterId == null) {
        params.successCallback([]);
        return;
      }
      let cached = detailCache.get(masterId);
      if (!cached) {
        await loadDetailData(masterId);
        cached = detailCache.get(masterId);
      }
      if (!cached) {
        params.successCallback([]);
        return;
      }
      const summaryRows = buildSummaryRows({
        masterId,
        pageConfig: pageConfig.value,
        detailCache,
        summaryConfig: summaryConfig.value
      });
      params.successCallback(summaryRows);
    }
  };

  function updateSummaryColumnDefs() {
    summaryDetailParams.detailGridOptions.columnDefs = buildSummaryColumnDefs(summaryConfig.value);
  }

  function updateSecondLevelDetailParams() {
    summaryDetailParams.detailGridOptions.detailCellRendererParams = (params: any) => {
      const tabKey = params.data?._tabKey;
      const masterId = params.data?._masterId;
      const columns = detailColumnsByTab.value[tabKey] || [];
      const metaRowClass = detailRowClassByTab?.value?.[tabKey];
      const gridOptions = detailGridOptionsByTab?.value?.[tabKey];
      const mergedRowClass = (rowParams: any) => {
        const classes: string[] = [];
        const baseClass = getRowClass(rowParams);
        if (baseClass) classes.push(baseClass);
        const metaClass = metaRowClass?.(rowParams);
        if (metaClass) classes.push(metaClass);
        return classes.length > 0 ? classes.join(' ') : undefined;
      };
      const runtimeOptions = buildGridRuntimeOptions(gridOptions);

      return {
        refreshStrategy: 'nothing' as const,
        detailGridOptions: {
          columnDefs: columns,
          defaultColDef: { sortable: true, filter: true, resizable: true, editable: true, wrapHeaderText: true, autoHeaderHeight: true, cellClassRules },
          rowHeight: 28,
          getRowId: (rowParams: any) => String(rowParams.data?.id),
          getRowClass: mergedRowClass,
          getContextMenuItems: getDetailContextMenuItems(masterId, tabKey),
          onCellEditingStarted,
          onCellEditingStopped,
          onCellValueChanged: (event: any) => onDetailCellValueChanged(event, masterId, tabKey),
          onCellClicked: (event: any) => onDetailCellClicked(event, masterId, tabKey),
          onGridReady: (event: any) => {
            if (gridOptions?.autoSizeColumns) {
              autoSizeColumnsOnReady(event.api, columns, gridOptions);
            }
          },
          ...runtimeOptions
        },
        getDetailRowData: (detailParams: any) => detailParams.successCallback(detailParams.data?._detailRows || [])
      };
    };
  }

  watch([detailColumnsByTab, pageConfig], () => {
    updateSummaryColumnDefs();
    updateSecondLevelDetailParams();
  }, { deep: true, immediate: true });

  return {
    summaryDetailParams
  };
}
