import type { ShallowRef } from 'vue';
import type { GridApi } from 'ag-grid-community';
import { type RowData, ensureRowKey } from '@/v3/logic/calc-engine';

export function useMasterRowAccess(params: {
  masterGridApi: ShallowRef<GridApi | null>;
}) {
  const { masterGridApi } = params;

  function getMasterRowByRowKey(rowKey: string): RowData | null {
    if (!rowKey) return null;
    const api = masterGridApi.value as any;
    const node = api?.getRowNode?.(String(rowKey));
    if (node?.data) return node.data as RowData;
    return null;
  }

  function getMasterRowById(id: number): RowData | null {
    if (id == null) return null;
    const api = masterGridApi.value as any;
    let found: RowData | null = null;
    api?.forEachNode?.((node: any) => {
      if (node?.data?.id === id) {
        found = node.data;
      }
    });
    return found;
  }

  function resolveMasterRowKey(masterId: number): string | null {
    const row = getMasterRowById(masterId);
    if (!row) return null;
    ensureRowKey(row);
    return row._rowKey || null;
  }

  return {
    getMasterRowByRowKey,
    getMasterRowById,
    resolveMasterRowKey
  };
}
