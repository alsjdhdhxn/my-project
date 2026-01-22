import type { Ref, ShallowRef } from 'vue';
import type { GridApi } from 'ag-grid-community';
import { saveDynamicData } from '@/service/api';
import {
  validateRows,
  formatValidationErrors,
  type ParsedPageConfig,
  type ValidationRule,
  type RowData
} from '@/v3/logic/calc-engine';

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
  detailFkColumnByTab: Ref<Record<string, string>>;
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
    detailFkColumnByTab,
    masterGridApi,
    notifyInfo,
    notifyError,
    notifySuccess
  } = params;

  function normalizeIdMapping(raw?: Record<string, number> | null) {
    const mapping = new Map<number, number>();
    if (!raw) return mapping;
    for (const [key, value] of Object.entries(raw)) {
      const fromId = Number(key);
      const toId = Number(value);
      if (!Number.isNaN(fromId) && !Number.isNaN(toId)) {
        mapping.set(fromId, toId);
      }
    }
    return mapping;
  }

  function isFlagTrue(value: unknown) {
    return value === true || value === 1 || value === '1' || value === 'true';
  }

  function applyIdMapping(idMapping: Map<number, number>) {
    if (idMapping.size === 0) return;
    const masterIdMap = new Map<number, number>();

    for (const master of masterRows.value) {
      const mapped = idMapping.get(Number(master.id));
      if (mapped) {
        masterIdMap.set(Number(master.id), mapped);
        master.id = mapped;
      }
    }

    if (detailCache.size === 0) return;

    const updatedCache = new Map<number, Record<string, RowData[]>>();
    for (const [masterId, tabData] of detailCache.entries()) {
      const newMasterId = masterIdMap.get(masterId) ?? masterId;
      const nextTabData: Record<string, RowData[]> = {};
      for (const [tabKey, rows] of Object.entries(tabData)) {
        const fkColumn = detailFkColumnByTab.value[tabKey] || 'masterId';
        nextTabData[tabKey] = rows.map(row => {
          const mappedRowId = idMapping.get(Number(row.id));
          if (mappedRowId) row.id = mappedRowId;
          if (masterIdMap.has(masterId)) row[fkColumn] = newMasterId;
          return row;
        });
      }
      updatedCache.set(newMasterId, nextTabData);
    }

    detailCache.clear();
    for (const [masterId, tabData] of updatedCache.entries()) {
      detailCache.set(masterId, tabData);
    }
  }

  function clearRowFlags(row: RowData) {
    delete row._dirtyFields;
    row._isNew = false;
    row._isDeleted = false;
  }

  function buildRecordItem(row: RowData, tableCode: string, extraExcludeFields: string[] = []) {
    const isNew = isFlagTrue(row._isNew);
    const isDeleted = isFlagTrue(row._isDeleted);
    const dirtyFields = (row._dirtyFields || {}) as Record<string, { originalValue: any; type: 'user' | 'calc' }>;

    let status: 'added' | 'modified' | 'deleted' | 'unchanged';
    if (isDeleted) status = 'deleted';
    else if (isNew) status = 'added';
    else if (Object.keys(dirtyFields).length > 0) status = 'modified';
    else status = 'unchanged';

    const excludeFields = new Set<string>(['masterId', ...extraExcludeFields.filter(Boolean)]);
    const data: Record<string, any> = { _tableCode: tableCode };
    for (const [key, value] of Object.entries(row)) {
      if (!key.startsWith('_') && !excludeFields.has(key)) data[key] = value;
    }

    const changes = Object.entries(dirtyFields)
      .filter(([field]) => !excludeFields.has(field))
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

    const masterIdsToSave = new Set<number>();
    for (const row of dirtyMaster) {
      if (row.id != null) masterIdsToSave.add(row.id);
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
    let hasIdMapping = false;
    for (const masterId of masterIdsToSave) {
      const masterRow = masterRows.value.find(r => r.id === masterId);
      if (!masterRow) continue;

      const detailsMap: Record<string, any[]> = {};
      const cached = detailCache.get(masterId);
      if (cached) {
        for (const tab of pageConfig.value?.tabs || []) {
          const tableCode = tab.tableCode || pageConfig.value?.detailTableCode;
          if (!tableCode) continue;
          const rows = cached[tab.key] || [];
          const dirtyRows = rows.filter(r => r._isNew || r._isDeleted || r._dirtyFields);
          if (dirtyRows.length > 0) {
            const fkField = detailFkColumnByTab.value[tab.key] || 'masterId';
            detailsMap[tableCode] = dirtyRows.map(r => buildRecordItem(r, tableCode, [fkField]));
          }
        }
      }

      const paramsToSave = {
        pageCode,
        master: buildRecordItem(masterRow, pageConfig.value?.masterTableCode || ''),
        details: Object.keys(detailsMap).length > 0 ? detailsMap : undefined
      };

      const { error, data } = await saveDynamicData(paramsToSave);
      if (error) {
        const errorMessage = (error as any)?.response?.data?.msg || (error as any)?.msg || error.message || '保存失败';
        saveStats.errors.push(`主表 ${masterId}: ${errorMessage}`);
      } else {
        const mapping = normalizeIdMapping((data as any)?.idMapping);
        if (mapping.size > 0) {
          applyIdMapping(mapping);
          hasIdMapping = true;
        }
        const resolvedMasterId = Number((data as any)?.masterId ?? mapping.get(masterId) ?? masterId);
        saveStats.successCount++;
        savedMasterIds.push(resolvedMasterId);
      }
    }

    // 先清除脏标记，再刷新 Grid
    for (const masterId of savedMasterIds) {
      const masterRow = masterRows.value.find(r => r.id === masterId);
      if (masterRow) {
        if (masterRow._isDeleted) {
          const idx = masterRows.value.findIndex(r => r.id === masterId);
          if (idx >= 0) masterRows.value.splice(idx, 1);
        } else {
          clearRowFlags(masterRow);
        }
      }

      const cached = detailCache.get(masterId);
      if (cached) {
        for (const [tabKey, rows] of Object.entries(cached)) {
          cached[tabKey] = rows.filter(r => {
            if (r._isDeleted) return false;
            clearRowFlags(r);
            return true;
          });
        }
      }
    }

    // ID 映射后需要重新设置数据（此时脏标记已清除）
    if (hasIdMapping) {
      const api = masterGridApi.value as any;
      if (api?.setGridOption) {
        api.setGridOption('rowData', masterRows.value);
      } else if (api?.setRowData) {
        api.setRowData(masterRows.value);
      }
    }

    // 刷新从表 Grid
    for (const masterId of savedMasterIds) {
      const cached = detailCache.get(masterId);
      if (cached) {
        const secondLevelInfo = masterGridApi.value?.getDetailGridInfo(`detail_${masterId}`);
        if (secondLevelInfo?.api) {
          secondLevelInfo.api.forEachDetailGridInfo((detailInfo: any) => {
            detailInfo.api?.refreshCells({ force: true });
          });
        }
      }
    }

    masterGridApi.value?.refreshCells({ force: true });

    if (saveStats.errors.length > 0) {
      notifyError(`成功 ${saveStats.successCount} 条，失败 ${saveStats.errors.length} 条\n${saveStats.errors.join('\n')}`);
    } else {
      notifySuccess('保存成功');
    }
  }

  return { save };
}

