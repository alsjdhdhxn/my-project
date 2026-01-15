import { computed, ref, shallowRef } from 'vue';
import type { GridApi } from 'ag-grid-community';
import { useMetaConfig } from '@/composables/meta-v2/useMetaConfig';
import { useMasterDetailData } from '@/composables/meta-v2/useMasterDetailData';
import { useCalcBroadcast } from '@/composables/meta-v2/useCalcBroadcast';
import { useLookupDialog } from '@/composables/meta-v2/useLookupDialog';
import { useSave } from '@/composables/meta-v2/useSave';
import { useUserGridConfig } from '@/composables/meta-v2/useUserGridConfig';
import { useExportExcel } from '@/composables/meta-v2/useExportExcel';
import { applyComponentExtensions } from '@/composables/meta-v2/registry';
import { initComponentExtensions } from '@/composables/meta-v2/extensions';
import { collectPageRules, groupRulesByComponent } from '@/composables/meta-v2/usePageRules';
import { useAuthStore } from '@/store/modules/auth';

type NotifyFn = (message: string) => void;

export function useMetaRuntime(params: {
  pageCode: string;
  notifyInfo: NotifyFn;
  notifyError: NotifyFn;
  notifySuccess: NotifyFn;
}) {
  const { pageCode, notifyInfo, notifyError, notifySuccess } = params;

  const isReady = ref(false);
  const masterGridApi = shallowRef<GridApi | null>(null);
  const detailGridApisByTab = ref<Record<string, any>>({});
  const authStore = useAuthStore();
  const isAdmin = computed(() => authStore.userInfo.roles?.includes('ADMIN'));

  const meta = useMetaConfig(pageCode, notifyError);
  const gridConfig = useUserGridConfig({ pageCode, notifyError, notifySuccess });
  const recalcAggregatesRef = { current: (_masterId: number) => {} };
  const recalcAggregatesProxy = (masterId: number) => recalcAggregatesRef.current(masterId);

  const addRowHooks = {
    onMasterRowAdded: (_row: any) => {},
    onDetailRowAdded: (_masterId: number, _tabKey: string, _row: any) => {}
  };

  const data = useMasterDetailData({
    pageCode,
    pageConfig: meta.pageConfig,
    detailFkColumnByTab: meta.detailFkColumnByTab,
    masterGridApi,
    detailGridApisByTab,
    notifyError,
    recalcAggregates: recalcAggregatesProxy,
    afterAddMasterRow: row => addRowHooks.onMasterRowAdded(row),
    afterAddDetailRow: (masterId, tabKey, row) => addRowHooks.onDetailRowAdded(masterId, tabKey, row)
  });

  const calc = useCalcBroadcast({
    masterGridApi,
    masterRows: data.masterRows,
    detailCache: data.detailCache,
    broadcastFields: meta.broadcastFields,
    detailCalcRulesByTab: meta.detailCalcRulesByTab,
    compiledAggRules: meta.compiledAggRules,
    compiledMasterCalcRules: meta.compiledMasterCalcRules,
    pageConfig: meta.pageConfig,
    loadDetailData: data.loadDetailData,
    detailGridApisByTab
  });

  addRowHooks.onMasterRowAdded = (row) => {
    calc.runMasterCalc(null, row);
  };
  addRowHooks.onDetailRowAdded = (masterId, tabKey, row) => {
    const api = detailGridApisByTab.value?.[tabKey];
    calc.runDetailCalc(null, api, row, masterId, tabKey);
  };

  recalcAggregatesRef.current = calc.recalcAggregates;

  const lookup = useLookupDialog({
    masterRows: data.masterRows,
    detailCache: data.detailCache,
    masterGridApi,
    masterLookupRules: meta.masterLookupRules,
    detailLookupRulesByTab: meta.detailLookupRulesByTab,
    markFieldChange: calc.markFieldChange,
    runMasterCalc: calc.runMasterCalc,
    runDetailCalc: calc.runDetailCalc,
    recalcAggregates: recalcAggregatesProxy,
    detailGridApisByTab
  });

  const { save } = useSave({
    pageCode,
    pageConfig: meta.pageConfig,
    masterRows: data.masterRows,
    detailCache: data.detailCache,
    masterValidationRules: meta.masterValidationRules,
    detailValidationRulesByTab: meta.detailValidationRulesByTab,
    masterColumnMeta: meta.masterColumnMeta,
    detailColumnMetaByTab: meta.detailColumnMetaByTab,
    detailFkColumnByTab: meta.detailFkColumnByTab,
    masterGridApi,
    notifyInfo,
    notifyError,
    notifySuccess
  });

  const exportExcel = useExportExcel({
    pageCode,
    masterGridApi,
    masterGridKey: meta.masterGridKey,
    pageConfig: meta.pageConfig,
    isAdmin,
    notifyInfo,
    notifyError,
    notifySuccess
  });

  const runtimeApi = {
    pageCode,
    masterGridApi,
    detailGridApisByTab,
    masterGridKey: meta.masterGridKey,
    detailTabsKey: meta.detailTabsKey,
    ...meta,
    ...data,
    ...calc,
    ...lookup,
    ...exportExcel,
    save,
    applyGridConfig: gridConfig.applyGridConfig,
    saveGridConfig: gridConfig.saveGridConfig
  };

  function applyRuntimeExtensions() {
    if (!meta.pageConfig.value) return;
    const components = meta.pageComponents.value || [];
    const rulesByComponent = groupRulesByComponent(collectPageRules(components));
    initComponentExtensions();
    meta.componentStateByKey.value = {};
    applyComponentExtensions({
      pageCode,
      pageConfig: meta.pageConfig.value,
      pageComponents: components,
      rulesByComponent,
      componentStateByKey: meta.componentStateByKey.value,
      runtime: runtimeApi
    });
  }

  async function init() {
    const ok = await meta.loadMetadata();
    if (ok) {
      applyRuntimeExtensions();
      isReady.value = true;
      await data.loadMasterData();
    }
  }

  return {
    isReady,
    init,
    ...runtimeApi
  };
}
