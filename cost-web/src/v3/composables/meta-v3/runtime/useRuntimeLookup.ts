import type { Ref } from 'vue';
import { useLookupDialog } from '@/v3/composables/meta-v3/useLookupDialog';
import { buildCellEditableCallback } from '@/v3/composables/meta-v3/usePageRules';
import type { RuntimeFeatures } from './types';

type RuntimeLookupMeta = {
  masterCellEditableRules?: Ref<any[]>;
  masterRowEditableRules?: Ref<any[]>;
  masterLookupRules: Ref<any[]>;
  detailLookupRulesByTab: Ref<Record<string, any[]>>;
};

type RuntimeLookupOptions = {
  resolvedFeatures: Ref<Required<RuntimeFeatures>>;
  meta: RuntimeLookupMeta;
  applyMasterPatch: (rowId: number | null, rowKey: string | null, patch: Record<string, any>) => any;
  applyDetailPatch: (tabKey: string, rowId: number | null, rowKey: string | null, patch: Record<string, any>) => any;
  markFieldChange: (row: any, field: string, oldValue: any, newValue: any, type: 'user' | 'calc') => void;
  runMasterCalc: (node: any, row: any, valueOverrides?: Record<string, any>) => string[] | void;
  runDetailCalc: (
    node: any,
    api: any,
    row: any,
    masterId: number,
    tabKey: string,
    masterRowKey?: string,
    changedFields?: string | string[],
    valueOverrides?: Record<string, any>
  ) => string[] | void;
  recalcAggregates: (masterId: number, masterRowKey?: string) => void;
  broadcastToDetail?: (masterId: number, row: any, changedFields?: string | string[]) => Promise<void>;
};

function createMasterRowEditableChecker(meta: RuntimeLookupMeta) {
  return (row: any) => {
    const cellRules = meta.masterCellEditableRules?.value || [];
    const rowRules = meta.masterRowEditableRules?.value || [];
    if (cellRules.length === 0 && rowRules.length === 0) return true;
    const callback = buildCellEditableCallback(cellRules, rowRules);
    return callback ? callback({ data: row, colDef: {} }) : true;
  };
}

export function useRuntimeLookup(options: RuntimeLookupOptions) {
  const { resolvedFeatures, meta, ...lookupOptions } = options;
  const isRowEditable = createMasterRowEditableChecker(meta);
  const {
    onMasterCellClicked,
    onDetailCellClicked,
    onLookupSelect,
    onLookupCancel,
    ...lookupState
  } = useLookupDialog({
    ...lookupOptions,
    masterLookupRules: meta.masterLookupRules,
    detailLookupRulesByTab: meta.detailLookupRulesByTab,
    isRowEditable
  });

  return {
    ...lookupState,
    onMasterCellClicked: (event: any) => {
      if (!resolvedFeatures.value.lookup) return;
      onMasterCellClicked(event);
    },
    onDetailCellClicked: (event: any, masterId: number, tabKey: string) => {
      if (!resolvedFeatures.value.lookup) return;
      onDetailCellClicked(event, masterId, tabKey);
    },
    onLookupSelect: (fillData: Record<string, any>) => {
      if (!resolvedFeatures.value.lookup) return;
      onLookupSelect(fillData);
    },
    onLookupCancel: () => {
      if (!resolvedFeatures.value.lookup) return;
      onLookupCancel();
    }
  };
}
