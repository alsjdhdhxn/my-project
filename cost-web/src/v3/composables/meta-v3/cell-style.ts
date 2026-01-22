import type { ColDef } from 'ag-grid-community';

export function isFlagTrue(value: unknown) {
  return value === true || value === 1 || value === '1' || value === 'true';
}

export const DIRTY_CELL_CLASS_RULES: NonNullable<ColDef['cellClassRules']> = {
  'cell-user-changed': (params: any) => {
    const row = params.data;
    const field = params.colDef?.field;
    return row?._dirtyFields?.[field]?.type === 'user';
  },
  'cell-calc-changed': (params: any) => {
    const row = params.data;
    const field = params.colDef?.field;
    return row?._dirtyFields?.[field]?.type === 'calc';
  },
  'cell-new': (params: any) => {
    const row = params.data;
    const field = params.colDef?.field;
    if (!isFlagTrue(row?._isNew) || isFlagTrue(row?._isDeleted)) return false;
    if (!field) return true;
    return !row?._dirtyFields?.[field];
  },
  'cell-deleted': (params: any) => isFlagTrue(params.data?._isDeleted)
};

export function mergeCellClassRules(
  columns: ColDef[],
  extraRules: ColDef['cellClassRules'] = DIRTY_CELL_CLASS_RULES
): ColDef[] {
  if (!extraRules) return columns;
  return columns.map(col => {
    const merged = { ...(col.cellClassRules || {}), ...(extraRules as Record<string, any>) };
    if (Object.keys(merged).length === 0) return col;
    return { ...col, cellClassRules: merged };
  });
}

