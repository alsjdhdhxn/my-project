import { type Ref, type ShallowRef, ref } from 'vue';
import type { GridApi } from 'ag-grid-community';
import { saveDynamicData } from '@/service/api';
import { forEachNestedDetailGridApi } from '@/v3/composables/meta-v3/detail-grid-apis';
import {
  type ParsedPageConfig,
  type RowData,
  type ValidationRule,
  ensureRowKey,
  formatValidationErrors,
  validateRows
} from '@/v3/logic/calc-engine';

type NotifyFn = (message: string) => void;

type DetailValidationRules = Record<string, ValidationRule[]>;

type ColumnMetaByTab = Record<string, any[]>;

type DetailCache = Map<string, Record<string, RowData[]>>;

export function useSave(params: {
  pageCode: string;
  pageConfig: Ref<ParsedPageConfig | null>;
  detailCache: DetailCache;
  getMasterRowById: (masterId: number) => RowData | null;
  getMasterRowByRowKey: (rowKey: string) => RowData | null;
  resolveMasterRowKey: (masterId: number) => string | null;
  masterValidationRules: Ref<ValidationRule[]>;
  detailValidationRulesByTab: Ref<DetailValidationRules>;
  masterColumnMeta: Ref<any[]>;
  detailColumnMetaByTab: Ref<ColumnMetaByTab>;
  masterPkColumn: Ref<string>;
  detailPkColumnByTab: Ref<Record<string, string>>;
  detailFkColumnByTab: Ref<Record<string, string>>;
  loadDetailData?: (masterId: number, masterRowKey?: string) => Promise<void>;
  masterGridApi: ShallowRef<GridApi | null>;
  detailGridApisByTab?: Ref<Record<string, any>>;
  activeMasterRowKey?: Ref<string | null>;
  notifyInfo: NotifyFn;
  notifyError: NotifyFn;
  notifySuccess: NotifyFn;
}) {
  const {
    pageCode,
    pageConfig,
    detailCache,
    getMasterRowById,
    getMasterRowByRowKey,
    resolveMasterRowKey,
    masterValidationRules,
    detailValidationRulesByTab,
    masterColumnMeta,
    detailColumnMetaByTab,
    masterPkColumn,
    detailPkColumnByTab,
    detailFkColumnByTab,
    loadDetailData,
    masterGridApi,
    detailGridApisByTab,
    activeMasterRowKey,
    notifyInfo,
    notifyError,
    notifySuccess
  } = params;

  // 保存状态锁，防止重复提交
  const isSaving = ref(false);

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
    const api = masterGridApi.value as any;
    const masterPkField = masterPkColumn.value;

    // 更新主表行 ID（SSRM: Grid 内部行）
    api?.forEachNode?.((node: any) => {
      const row = node?.data;
      if (!row) return;
      const mapped = idMapping.get(Number(row.id));
      if (mapped) {
        row.id = mapped;
        if (masterPkField) {
          row[masterPkField] = mapped;
        }
      }
    });

    if (detailCache.size === 0) return;

    // 更新从表外键与自身 ID（不重建缓存键）
    for (const [, tabData] of detailCache.entries()) {
      for (const [tabKey, rows] of Object.entries(tabData)) {
        const fkColumn = detailFkColumnByTab.value[tabKey] || 'masterId';
        const detailPkField = detailPkColumnByTab.value[tabKey];
        for (const row of rows) {
          const mappedRowId = idMapping.get(Number(row.id));
          if (mappedRowId) {
            row.id = mappedRowId;
            if (detailPkField) {
              row[detailPkField] = mappedRowId;
            }
          }
          const mappedFk = idMapping.get(Number(row[fkColumn]));
          if (mappedFk) row[fkColumn] = mappedFk;
        }
      }
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

    const excludeFields = new Set<string>(['masterId', 'id', ...extraExcludeFields.filter(Boolean)]);
    const data: Record<string, any> = { _tableCode: tableCode };

    if (isNew) {
      // 新增：传所有字段
      for (const [key, value] of Object.entries(row)) {
        if (!key.startsWith('_') && !excludeFields.has(key)) data[key] = value;
      }
    } else if (status === 'modified') {
      // 修改：只传脏字段
      for (const field of Object.keys(dirtyFields)) {
        if (!excludeFields.has(field)) {
          data[field] = row[field];
        }
      }
    } else {
      // 删除或未变更：data 保持为空
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
      id: row.id,
      status,
      data,
      changes: changes.length > 0 ? changes : undefined
    };
  }

  async function save() {
    // 防止重复提交
    if (isSaving.value) {
      notifyInfo('正在保存中，请稍候...');
      return;
    }

    isSaving.value = true;

    try {
      const dirtyMaster: RowData[] = [];
      const dirtyDetailByTab: Record<string, RowData[]> = {};

      const api = masterGridApi.value as any;
      api?.forEachNode?.((node: any) => {
        const row = node.data;
        if (row && (row._isNew || row._isDeleted || row._dirtyFields)) {
          dirtyMaster.push(row);
        }
      });

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

      if (dirtyMaster.length === 0 && !Object.values(dirtyDetailByTab).some(arr => arr.length > 0)) {
        notifyInfo('没有需要保存的数据');
        return;
      }

      const masterToValidate = dirtyMaster.filter(r => !r._isDeleted);
      if (masterToValidate.length > 0) {
        const masterResult = validateRows(masterToValidate, masterValidationRules.value, masterColumnMeta.value);
        if (!masterResult.valid) {
          notifyError(`主表验证失败:\n${formatValidationErrors(masterResult.errors)}`);
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
          notifyError(`${tabTitle} 验证失败:\n${formatValidationErrors(result.errors)}`);
          return;
        }
      }

      const masterIdsToSave = new Set<number>();
      for (const row of dirtyMaster) {
        if (row.id != null) masterIdsToSave.add(row.id);
      }

      for (const [masterRowKey, tabData] of detailCache.entries()) {
        const masterRow = getMasterRowByRowKey(masterRowKey);
        const masterId = masterRow?.id;
        if (masterId == null) continue;
        for (const rows of Object.values(tabData)) {
          if (rows.some(r => r._isNew || r._isDeleted || r._dirtyFields)) {
            masterIdsToSave.add(masterId);
            break;
          }
        }
      }

      const savedMasterIds: number[] = [];
      const detailReloadTargets = new Map<number, string>();
      for (const masterId of masterIdsToSave) {
        const masterRow = getMasterRowById(masterId);
        if (!masterRow) continue;

        const detailsMap: Record<string, any[]> = {};
        const masterRowKey = resolveMasterRowKey(masterId);
        const cached = masterRowKey ? detailCache.get(masterRowKey) : undefined;
        let hasDirtyDetails = false;
        if (cached) {
          for (const tab of pageConfig.value?.tabs || []) {
            const tableCode = tab.tableCode || pageConfig.value?.detailTableCode;
            if (!tableCode) continue;
            const rows = cached[tab.key] || [];
            const dirtyRows = rows.filter(r => r._isNew || r._isDeleted || r._dirtyFields);
            if (dirtyRows.length > 0) {
              hasDirtyDetails = true;
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
          const errorMessage =
            (error as any)?.response?.data?.msg || (error as any)?.msg || error.message || '保存失败';
          saveStats.errors.push(`主表 ${masterId}: ${errorMessage}`);
        } else {
          const mapping = normalizeIdMapping((data as any)?.idMapping);
          const backendMasterId = Number((data as any)?.masterId);
          const resolvedMasterId =
            !Number.isNaN(backendMasterId) && backendMasterId > 0
              ? backendMasterId
              : Number(mapping.get(masterId) ?? masterId);

          if (!mapping.has(masterId) && resolvedMasterId > 0 && resolvedMasterId !== masterId) {
            mapping.set(masterId, resolvedMasterId);
          }
          if (mapping.size > 0) {
            applyIdMapping(mapping);
          }

          // 用后端返回的最新数据更新本地行
          const returnedMasterRow = (data as any)?.masterRow;
          if (returnedMasterRow && !masterRow._isDeleted) {
            for (const [key, value] of Object.entries(returnedMasterRow)) {
              if (!key.startsWith('_')) {
                masterRow[key] = value;
              }
            }
          }

          if (!masterRow._isDeleted && resolvedMasterId > 0) {
            masterRow.id = resolvedMasterId;
            const masterPkField = masterPkColumn.value;
            if (masterPkField && masterRow[masterPkField] == null) {
              masterRow[masterPkField] = resolvedMasterId;
            }
          }

          saveStats.successCount++;
          savedMasterIds.push(resolvedMasterId);
          if (hasDirtyDetails && !masterRow._isDeleted) {
            detailReloadTargets.set(resolvedMasterId, ensureRowKey(masterRow));
          }
        }
      }

      // 清除变更标记，收集需要更新/删除的行
      const rowsToUpdate: RowData[] = [];
      const rowsToRemove: RowData[] = [];
      const touchedDetailKeys = new Set<string>();

      for (const masterId of savedMasterIds) {
        const masterRow = getMasterRowById(masterId);
        if (masterRow) {
          if (masterRow._isDeleted) {
            // 无论是否已在表格中，都需要加入 rowsToRemove 以触发 Grid 删除
            rowsToRemove.push(masterRow);
          } else {
            clearRowFlags(masterRow);
            rowsToUpdate.push(masterRow);
          }
        }

        const masterRowKey = masterRow ? ensureRowKey(masterRow) : resolveMasterRowKey(masterId);
        const cached = masterRowKey ? detailCache.get(masterRowKey) : undefined;
        if (cached && masterRowKey) {
          for (const [tabKey, rows] of Object.entries(cached)) {
            const remaining: RowData[] = [];
            for (const r of rows) {
              if (r._isDeleted) {
                continue;
              }
              clearRowFlags(r);
              remaining.push(r);
            }
            cached[tabKey] = remaining;
          }
          touchedDetailKeys.add(masterRowKey);
        }
      }

      // 更新主表 Grid
      const gridApi = masterGridApi.value as any;
      if (rowsToUpdate.length > 0) {
        gridApi?.applyServerSideTransaction?.({ route: [], update: rowsToUpdate });
      }
      if (rowsToRemove.length > 0) {
        gridApi?.applyServerSideTransaction?.({ route: [], remove: rowsToRemove });
      }

      for (const [masterId, masterRowKey] of detailReloadTargets.entries()) {
        await loadDetailData?.(masterId, masterRowKey);
        touchedDetailKeys.add(masterRowKey);
      }

      // 更新明细 Grid（分割/嵌套视图）
      for (const masterRowKey of touchedDetailKeys) {
        const cached = detailCache.get(masterRowKey);
        if (!cached) continue;

        forEachNestedDetailGridApi({
          masterGridApi,
          masterRowKey,
          tabKeys: Object.keys(cached),
          callback: (api, tabKey) => {
            api.setGridOption?.('rowData', cached[tabKey]);
            api.refreshCells?.({ force: true });
          }
        });

        if (detailGridApisByTab?.value && activeMasterRowKey?.value === masterRowKey) {
          for (const [tabKey, rows] of Object.entries(cached)) {
            const detailApi = detailGridApisByTab.value[tabKey];
            detailApi?.setGridOption?.('rowData', rows);
            detailApi?.refreshCells?.({ force: true });
          }
        }
      }

      masterGridApi.value?.refreshCells({ force: true });

      if (saveStats.errors.length > 0) {
        notifyError(
          `成功 ${saveStats.successCount} 条，失败 ${saveStats.errors.length} 条\n${saveStats.errors.join('\n')}`
        );
      } else {
        notifySuccess('保存成功');
      }
    } finally {
      isSaving.value = false;
    }
  }

  return { save, isSaving };
}
