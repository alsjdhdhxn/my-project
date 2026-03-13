import type { Ref } from 'vue';
import type { RowData } from '@/v3/logic/calc-engine';
import type { RuntimeFeatures } from './types';

type RunMasterCalc = (node: any, row: RowData, valueOverrides?: Record<string, any>) => string[] | void;

type RunDetailCalc = (
  node: any,
  api: any,
  row: RowData,
  masterId: number,
  tabKey: string,
  masterRowKey?: string,
  changedFields?: string | string[],
  valueOverrides?: Record<string, any>
) => string[] | void;

type RecalcAggregates = (masterId: number, masterRowKey?: string) => void;

type AddMasterRow = () => RowData | null | undefined;
type DeleteMasterRow = (row: RowData) => void;
type CopyMasterRow = (row: RowData) => Promise<RowData | null | undefined> | RowData | null | undefined;
type AddDetailRow = (masterId: number, tabKey: string, masterRowKey?: string) => RowData | null | undefined;
type DeleteDetailRow = (masterId: number, tabKey: string, row: RowData, masterRowKey?: string) => boolean;
type CopyDetailRow = (masterId: number, tabKey: string, sourceRow: RowData, masterRowKey?: string) => RowData | null | undefined;

export function useRuntimeMutations(params: {
  resolvedFeatures: Ref<Required<RuntimeFeatures>>;
  detailGridApisByTab: Ref<Record<string, any>>;
  addMasterRowRaw: AddMasterRow;
  deleteMasterRowRaw: DeleteMasterRow;
  copyMasterRowRaw: CopyMasterRow;
  addDetailRowRaw: AddDetailRow;
  deleteDetailRowRaw: DeleteDetailRow;
  copyDetailRowRaw: CopyDetailRow;
  runMasterCalc: RunMasterCalc;
  runDetailCalc: RunDetailCalc;
  recalcAggregates: RecalcAggregates;
}) {
  const {
    resolvedFeatures,
    detailGridApisByTab,
    addMasterRowRaw,
    deleteMasterRowRaw,
    copyMasterRowRaw,
    addDetailRowRaw,
    deleteDetailRowRaw,
    copyDetailRowRaw,
    runMasterCalc,
    runDetailCalc,
    recalcAggregates
  } = params;

  function finalizeDetailMutation(masterId: number, tabKey: string, row: RowData | null | undefined, masterRowKey?: string) {
    if (!row) return row;
    if (resolvedFeatures.value.detailTabs) {
      const api = detailGridApisByTab.value?.[tabKey];
      runDetailCalc(null, api, row, masterId, tabKey, masterRowKey);
    }
    recalcAggregates(masterId, masterRowKey);
    return row;
  }

  function addMasterRow() {
    const row = addMasterRowRaw();
    if (row) {
      runMasterCalc(null, row);
    }
    return row;
  }

  function deleteMasterRow(row: RowData) {
    deleteMasterRowRaw(row);
  }

  async function copyMasterRow(sourceRow: RowData) {
    const row = await copyMasterRowRaw(sourceRow);
    if (row) {
      runMasterCalc(null, row);
    }
    return row;
  }

  function addDetailRow(masterId: number, tabKey: string, masterRowKey?: string) {
    const row = addDetailRowRaw(masterId, tabKey, masterRowKey);
    return finalizeDetailMutation(masterId, tabKey, row, masterRowKey);
  }

  function deleteDetailRow(masterId: number, tabKey: string, row: RowData, masterRowKey?: string) {
    const deleted = deleteDetailRowRaw(masterId, tabKey, row, masterRowKey);
    if (deleted) {
      recalcAggregates(masterId, masterRowKey);
    }
    return deleted;
  }

  function copyDetailRow(masterId: number, tabKey: string, sourceRow: RowData, masterRowKey?: string) {
    const row = copyDetailRowRaw(masterId, tabKey, sourceRow, masterRowKey);
    return finalizeDetailMutation(masterId, tabKey, row, masterRowKey);
  }

  return {
    addMasterRow,
    deleteMasterRow,
    copyMasterRow,
    addDetailRow,
    deleteDetailRow,
    copyDetailRow
  };
}
