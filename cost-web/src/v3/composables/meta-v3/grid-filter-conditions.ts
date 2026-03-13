import type { DynamicQueryCondition } from '@/service/api';

type QueryCondition = DynamicQueryCondition;

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

export function buildConditionsFromFilterModel(
  filterModel: Record<string, any> | null | undefined
): QueryCondition[] {
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
