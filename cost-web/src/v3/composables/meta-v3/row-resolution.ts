import { type RowData } from '@/v3/logic/calc-engine';
import { isPersistedRow } from '@/v3/composables/meta-v3/row-persistence';

export function resolveCurrentMasterRow(
  row: RowData,
  params: {
    getMasterRowByRowKey: (rowKey: string) => RowData | null;
    getMasterRowById: (id: number) => RowData | null;
  }
) {
  const { getMasterRowByRowKey, getMasterRowById } = params;
  const rowKey = row?._rowKey ? String(row._rowKey) : null;
  if (rowKey) {
    const currentRow = getMasterRowByRowKey(rowKey);
    if (currentRow) return currentRow;
  }
  if (isPersistedRow(row)) {
    const currentRow = getMasterRowById(Number(row.id));
    if (currentRow) return currentRow;
  }
  return row;
}

export function resolveCurrentDetailRow(rows: RowData[], row: RowData) {
  const rowKey = row?._rowKey ? String(row._rowKey) : null;
  if (rowKey) {
    const currentRow = rows.find(r => r._rowKey === rowKey);
    if (currentRow) return currentRow;
  }
  if (row.id != null) {
    const currentRow = rows.find(r => r.id === row.id);
    if (currentRow) return currentRow;
  }
  return row;
}
