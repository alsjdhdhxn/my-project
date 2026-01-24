import { ref } from 'vue';
import type { Ref } from 'vue';
import {
  executeCustomExport,
  fetchCustomExportConfigs,
  type CustomExportConfig,
  type CustomExportMode,
  type CustomExportSort,
  type QueryCondition
} from '@/service/api/export-config';

type NotifyFn = (message: string) => void;

type SortModelItem = { colId?: string; sort?: 'asc' | 'desc' };

const LABEL_EXPORT_OK = '导出已开始';
const LABEL_EXPORT_FAIL = '导出失败';

function toTextCondition(field: string, type: string, value: any): QueryCondition | null {
  if (value == null || value === '') return null;
  switch (type) {
    case 'contains':
    case 'startsWith':
    case 'endsWith':
      return { field, operator: 'like', value };
    case 'equals':
      return { field, operator: 'eq', value };
    case 'notEqual':
      return { field, operator: 'ne', value };
    default:
      return null;
  }
}

function toNumberCondition(field: string, type: string, value: any, value2?: any): QueryCondition | null {
  if (value == null || value === '') return null;
  switch (type) {
    case 'equals':
      return { field, operator: 'eq', value };
    case 'notEqual':
      return { field, operator: 'ne', value };
    case 'lessThan':
      return { field, operator: 'lt', value };
    case 'lessThanOrEqual':
      return { field, operator: 'le', value };
    case 'greaterThan':
      return { field, operator: 'gt', value };
    case 'greaterThanOrEqual':
      return { field, operator: 'ge', value };
    case 'inRange':
      if (value2 == null || value2 === '') return null;
      return { field, operator: 'between', value, value2 };
    default:
      return null;
  }
}

function toDateCondition(field: string, type: string, value: any, value2?: any): QueryCondition | null {
  if (value == null || value === '') return null;
  switch (type) {
    case 'equals':
      return { field, operator: 'eq', value };
    case 'notEqual':
      return { field, operator: 'ne', value };
    case 'lessThan':
      return { field, operator: 'lt', value };
    case 'greaterThan':
      return { field, operator: 'gt', value };
    case 'inRange':
      if (value2 == null || value2 === '') return null;
      return { field, operator: 'between', value, value2 };
    default:
      return null;
  }
}

function buildConditionsFromFilterModel(filterModel: Record<string, any> | null | undefined): QueryCondition[] {
  if (!filterModel) return [];
  const conditions: QueryCondition[] = [];
  for (const [field, filter] of Object.entries(filterModel)) {
    if (!filter) continue;
    if (filter.operator && filter.condition1) {
      const first = buildConditionsFromFilterModel({ [field]: filter.condition1 });
      const second = buildConditionsFromFilterModel({ [field]: filter.condition2 });
      conditions.push(...first);
      if (filter.operator === 'AND') {
        conditions.push(...second);
      }
      continue;
    }
    if (filter.filterType === 'set' && Array.isArray(filter.values)) {
      if (filter.values.length > 0) {
        conditions.push({ field, operator: 'in', value: filter.values });
      }
      continue;
    }
    const type = filter.type;
    if (filter.filterType === 'text') {
      const cond = toTextCondition(field, type, filter.filter);
      if (cond) conditions.push(cond);
      continue;
    }
    if (filter.filterType === 'number') {
      const cond = toNumberCondition(field, type, filter.filter, filter.filterTo);
      if (cond) conditions.push(cond);
      continue;
    }
    if (filter.filterType === 'date') {
      const cond = toDateCondition(field, type, filter.dateFrom, filter.dateTo);
      if (cond) conditions.push(cond);
    }
  }
  return conditions;
}

function buildSorts(sortModel: SortModelItem[] | null | undefined): CustomExportSort[] {
  if (!sortModel || sortModel.length === 0) return [];
  return sortModel
    .filter(item => item?.colId && item?.sort)
    .map(item => ({ field: item.colId as string, order: item.sort as CustomExportSort['order'] }));
}

export function useCustomExport(params: {
  pageCode: string;
  masterGridApi: { value: any | null };
  notifyInfo: NotifyFn;
  notifyError: NotifyFn;
  notifySuccess: NotifyFn;
}) {
  const { pageCode, masterGridApi, notifyInfo, notifyError, notifySuccess } = params;
  const customExportConfigs = ref<CustomExportConfig[]>([]);
  const loaded = ref(false);

  async function loadConfigs() {
    if (loaded.value) return;
    loaded.value = true;
    const { data, error } = await fetchCustomExportConfigs(pageCode);
    if (error) {
      notifyError(error.message || LABEL_EXPORT_FAIL);
      return;
    }
    customExportConfigs.value = data || [];
  }

  async function runExport(exportCode: string, mode: CustomExportMode) {
    const api = masterGridApi.value;
    const filterModel = mode === 'current' ? api?.getFilterModel?.() : null;
    const sortModel = mode === 'current' ? api?.getSortModel?.() : null;
    const conditions = mode === 'current' ? buildConditionsFromFilterModel(filterModel) : [];
    const sorts = mode === 'current' ? buildSorts(sortModel) : [];

    notifyInfo(LABEL_EXPORT_OK);
    try {
      await executeCustomExport(exportCode, {
        mode,
        conditions: conditions.length > 0 ? conditions : undefined,
        sorts: sorts.length > 0 ? sorts : undefined
      });
      notifySuccess(LABEL_EXPORT_OK);
    } catch (error: any) {
      notifyError(error?.message || LABEL_EXPORT_FAIL);
    }
  }

  loadConfigs();

  return {
    customExportConfigs,
    executeCustomExport: runExport
  };
}
