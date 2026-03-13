import { ref } from 'vue';
import type { DynamicQueryCondition } from '@/service/api';
import { createMasterServerSideDataSource } from '@/v3/composables/meta-v3/master-server-side-data-source';

type QueryCondition = DynamicQueryCondition;

export function useMasterQueryState(params: {
  pageCode: string;
  getTableCode: () => string | undefined;
  getMasterPkColumn: () => string;
  notifyError: (message: string) => void;
}) {
  const { pageCode, getTableCode, getMasterPkColumn, notifyError } = params;
  const advancedConditions = ref<QueryCondition[]>([]);

  function setAdvancedConditions(conditions: QueryCondition[]) {
    advancedConditions.value = Array.isArray(conditions)
      ? conditions.filter(condition => Boolean(condition?.field) && Boolean(condition?.operator))
      : [];
  }

  function clearAdvancedConditions() {
    advancedConditions.value = [];
  }

  const createServerSideDataSource = createMasterServerSideDataSource({
    pageCode,
    getTableCode,
    getMasterPkColumn,
    getAdvancedConditions: () => advancedConditions.value,
    notifyError
  });

  return {
    advancedConditions,
    setAdvancedConditions,
    clearAdvancedConditions,
    createServerSideDataSource
  };
}
