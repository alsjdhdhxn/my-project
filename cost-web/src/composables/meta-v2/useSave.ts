import type { Ref, ShallowRef } from 'vue';
import type { GridApi } from 'ag-grid-community';
import { saveDynamicData } from '@/service/api';
import { runSaveHooks } from '@/composables/meta-v2/registry';
import {
  validateRows,
  formatValidationErrors,
  type ParsedPageConfig,
  type ValidationRule,
  type RowData
} from '@/logic/calc-engine';

type NotifyFn = (message: string) => void;

type DetailValidationRules = Record<string, ValidationRule[]>;

type ColumnMetaByTab = Record<string, any[]>;

type DetailCache = Map<number, Record<string, RowData[]>>;

export function useSave(params: {
  pageCode: string;
  pageConfig: Ref<ParsedPageConfig | null>;
  masterRows: Ref<RowData[]>;
  detailCache: DetailCache;
  masterValidationRules: Ref<ValidationRule[]>;
  detailValidationRulesByTab: Ref<DetailValidationRules>;
  masterColumnMeta: Ref<any[]>;
  detailColumnMetaByTab: Ref<ColumnMetaByTab>;
  masterGridApi: ShallowRef<GridApi | null>;
  notifyInfo: NotifyFn;
  notifyError: NotifyFn;
  notifySuccess: NotifyFn;
}) {
  const {
    pageCode,
    pageConfig,
    masterRows,
    detailCache,
    masterValidationRules,
    detailValidationRulesByTab,
    masterColumnMeta,
    detailColumnMetaByTab,
    masterGridApi,
    notifyInfo,
    notifyError,
    notifySuccess
  } = params;

  function buildRecordItem(row: RowData, tableCode: string) {
    const isNew = row._isNew === true;
    const isDeleted = row._isDeleted === true;
    const dirtyFields = row._dirtyFields || {};

    let status: 'added' | 'modified' | 'deleted' | 'unchanged';
    if (isDeleted) status = 'deleted';
    else if (isNew) status = 'added';
    else if (Object.keys(dirtyFields).length > 0) status = 'modified';
    else status = 'unchanged';

    const excludeFields = ['masterId'];
    const data: Record<string, any> = { _tableCode: tableCode };
    for (const [key, value] of Object.entries(row)) {
      if (!key.startsWith('_') && !excludeFields.includes(key)) data[key] = value;
    }

    const changes = Object.entries(dirtyFields)
      .filter(([field]) => !excludeFields.includes(field))
      .map(([field, info]) => ({
        field,
        oldValue: info.originalValue,
        newValue: row[field],
        changeType: info.type
      }));

    return {
      id: isNew ? null : row.id,
      status,
      data,
      changes: changes.length > 0 ? changes : undefined
    };
  }

  async function save() {
    const dirtyMaster: RowData[] = [];
    const dirtyDetailByTab: Record<string, RowData[]> = {};

    for (const row of masterRows.value) {
      if (row._isNew || row._isDeleted || row._dirtyFields) dirtyMaster.push(row);
    }

    for (const [, tabData] of detailCache.entries()) {
      for (const [tabKey, rows] of Object.entries(tabData)) {
        for (const row of rows) {
          if (row._isNew || row._isDeleted || row._dirtyFields) {
            if (!dirtyDetailByTab[tabKey]) dirtyDetailByTab[tabKey] = [];
            dirtyDetailByTab[tabKey].push(row);
          }
        }
      }
    }

    const saveStats = { successCount: 0, errors: [] as string[] };
    const hookContext = {
      pageCode,
      pageConfig: pageConfig.value,
      masterRows: masterRows.value,
      detailCache,
      dirtyMaster,
      dirtyDetailByTab,
      masterValidationRules: masterValidationRules.value,
      detailValidationRulesByTab: detailValidationRulesByTab.value,
      masterColumnMeta: masterColumnMeta.value,
      detailColumnMetaByTab: detailColumnMetaByTab.value,
      saveStats,
      addError: (message: string) => saveStats.errors.push(message)
    };

    if (!runSaveHooks('beforeValidate', hookContext)) return;

    if (dirtyMaster.length === 0 && !Object.values(dirtyDetailByTab).some(arr => arr.length > 0)) {
      notifyInfo('没有需要保存的数据');
      return;
    }

    const masterToValidate = dirtyMaster.filter(r => !r._isDeleted);
    if (masterToValidate.length > 0) {
      const masterResult = validateRows(masterToValidate, masterValidationRules.value, masterColumnMeta.value);
      if (!masterResult.valid) {
        notifyError('主表验证失败:\n' + formatValidationErrors(masterResult.errors));
        return;
      }
    }

    for (const [tabKey, rows] of Object.entries(dirtyDetailByTab)) {
      const rowsToValidate = rows.filter(r => !r._isDeleted);
      if (rowsToValidate.length === 0) continue;
      const rules = detailValidationRulesByTab.value[tabKey] || [];
      const meta = detailColumnMetaByTab.value[tabKey] || [];
      const result = validateRows(rowsToValidate, rules, meta);
      if (!result.valid) {
        const tabTitle = pageConfig.value?.tabs?.find(t => t.key === tabKey)?.title || tabKey;
        notifyError(`${tabTitle} 验证失败:\n` + formatValidationErrors(result.errors));
        return;
      }
    }

    if (!runSaveHooks('afterValidate', hookContext)) return;

    if (!runSaveHooks('beforeSave', hookContext)) return;

    const masterIdsToSave = new Set<number>();
    for (const row of dirtyMaster) {
      masterIdsToSave.add(row.id);
    }

    for (const [masterId, tabData] of detailCache.entries()) {
      for (const rows of Object.values(tabData)) {
        if (rows.some(r => r._isNew || r._isDeleted || r._dirtyFields)) {
          masterIdsToSave.add(masterId);
          break;
        }
      }
    }

    const savedMasterIds: number[] = [];
    for (const masterId of masterIdsToSave) {
      const masterRow = masterRows.value.find(r => r.id === masterId);
      if (!masterRow) continue;

      const detailsMap: Record<string, any[]> = {};
      const cached = detailCache.get(masterId);
      if (cached) {
        for (const tab of pageConfig.value?.tabs || []) {
          const rows = cached[tab.key] || [];
          const dirtyRows = rows.filter(r => r._isNew || r._isDeleted || r._dirtyFields);
          if (dirtyRows.length > 0) {
            detailsMap[tab.tableCode] = dirtyRows.map(r => buildRecordItem(r, tab.tableCode));
          }
        }
      }

      const paramsToSave = {
        pageCode,
        master: buildRecordItem(masterRow, pageConfig.value?.masterTableCode || ''),
        details: Object.keys(detailsMap).length > 0 ? detailsMap : undefined
      };

      const { error } = await saveDynamicData(paramsToSave);
      if (error) {
        saveStats.errors.push(`主表 ${masterId}: ${error.msg || '保存失败'}`);
      } else {
        saveStats.successCount++;
        savedMasterIds.push(masterId);
      }
    }

    for (const masterId of savedMasterIds) {
      const masterRow = masterRows.value.find(r => r.id === masterId);
      if (masterRow) {
        if (masterRow._isDeleted) {
          const idx = masterRows.value.findIndex(r => r.id === masterId);
          if (idx >= 0) masterRows.value.splice(idx, 1);
        } else {
          delete masterRow._dirtyFields;
          masterRow._isNew = false;
        }
      }

      const cached = detailCache.get(masterId);
      if (cached) {
        for (const [tabKey, rows] of Object.entries(cached)) {
          cached[tabKey] = rows.filter(r => {
            if (r._isDeleted) return false;
            delete r._dirtyFields;
            r._isNew = false;
            return true;
          });
        }
        const secondLevelInfo = masterGridApi.value?.getDetailGridInfo(`detail_${masterId}`);
        if (secondLevelInfo?.api) {
          secondLevelInfo.api.forEachDetailGridInfo((detailInfo: any) => {
            detailInfo.api?.refreshCells({ force: true });
          });
        }
      }
    }

    masterGridApi.value?.refreshCells({ force: true });

    if (!runSaveHooks('afterSave', hookContext)) return;

    if (saveStats.errors.length > 0) {
      notifyError(`成功 ${saveStats.successCount} 条，失败 ${saveStats.errors.length} 条\n${saveStats.errors.join('\n')}`);
    } else {
      notifySuccess('保存成功');
    }
  }

  return { save };
}
