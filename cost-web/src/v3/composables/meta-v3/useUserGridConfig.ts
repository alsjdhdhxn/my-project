import { fetchUserGridConfig, saveUserGridConfig } from '@/service/api';

type NotifyFn = (message: string) => void;

type ColumnPreference = {
  columnId?: number;
  columnName: string;
  width?: number;
  order?: number;
  hidden?: boolean;
  pinned?: 'left' | 'right' | null;
};

type GridConfigPayload = {
  columns?: ColumnPreference[];
};

/** Grid API 引用，用于批量保存 */
type GridApiRef = {
  gridKey: string;
  api: any;
  columnApi?: any;
};

function parseColumnId(value: unknown): number | undefined {
  const parsed = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function getRuntimeColumnName(source: any): string {
  return String(source?.field ?? source?.colId ?? '').trim();
}

function getMetaColumnId(source: any): number | undefined {
  return parseColumnId(source?.columnId ?? source?.metaColumnId ?? source?.context?.metaColumnId);
}

function getPreferenceKey(source: { columnId?: number; columnName?: string }): string | null {
  if (typeof source.columnId === 'number') {
    return `id:${source.columnId}`;
  }
  const columnName = String(source.columnName ?? '').trim();
  return columnName ? `column:${columnName}` : null;
}

function buildPreferenceLookup(columns: ColumnPreference[]) {
  const result = new Map<string, ColumnPreference>();
  columns.forEach(column => {
    const identityKey = getPreferenceKey(column);
    if (identityKey) {
      result.set(identityKey, column);
    }
  });
  return result;
}

function getColumnDefIdentity(def: any): string | null {
  const columnId = getMetaColumnId(def);
  if (typeof columnId === 'number') {
    return `id:${columnId}`;
  }
  const columnName = getRuntimeColumnName(def);
  return columnName ? `column:${columnName}` : null;
}

function buildColumnDefLookup(columnDefs: any[]) {
  const result = new Map<string, any>();
  columnDefs.forEach(def => {
    const identityKey = getColumnDefIdentity(def);
    if (identityKey) {
      result.set(identityKey, def);
    }
  });
  return result;
}

function isBackendHidden(def: any) {
  return def?.hide === true || def?.lockVisible === true || def?.suppressColumnsToolPanel === true;
}

function normalizeColumns(source: any[], columnDefs: any[] = []): ColumnPreference[] {
  const result: ColumnPreference[] = [];
  const columnDefByField = new Map(
    columnDefs.map(def => [getRuntimeColumnName(def), def] as const).filter(([columnName]) => Boolean(columnName))
  );
  source.forEach((col: any, index: number) => {
    const columnName = getRuntimeColumnName(col);
    if (!columnName) return;
    const matchedDef = columnDefByField.get(columnName);
    result.push({
      columnId: getMetaColumnId(col) ?? getMetaColumnId(matchedDef),
      columnName,
      width: typeof col.width === 'number' ? col.width : undefined,
      order: typeof col.order === 'number' ? col.order : index,
      hidden: typeof col.hidden === 'boolean' ? col.hidden : typeof col.hide === 'boolean' ? col.hide : undefined,
      pinned: col.pinned === 'left' || col.pinned === 'right' ? col.pinned : null
    });
  });
  return result;
}

function parseConfigPayload(data: any): GridConfigPayload | null {
  if (!data) return null;
  if (typeof data === 'string') {
    try {
      return parseConfigPayload(JSON.parse(data));
    } catch {
      return null;
    }
  }
  if (Array.isArray(data)) {
    return { columns: normalizeColumns(data) };
  }
  if (typeof data === 'object') {
    if (Array.isArray((data as any).columnState)) {
      return { columns: normalizeColumns((data as any).columnState) };
    }
    if (Array.isArray((data as any).columns)) {
      return { columns: normalizeColumns((data as any).columns) };
    }
    return data as GridConfigPayload;
  }
  return null;
}

function resolveGridKey(key: string | null | undefined) {
  return key && key.trim().length > 0 ? key : 'masterGrid';
}

export function useUserGridConfig(params: { pageCode: string; notifyError: NotifyFn; notifySuccess: NotifyFn }) {
  const { pageCode, notifyError, notifySuccess } = params;
  const cache = new Map<string, GridConfigPayload | null>();

  // 存储所有已注册的 grid API 引用
  const gridApiRefs = new Map<string, GridApiRef>();

  async function loadGridConfig(gridKey?: string | null) {
    const resolvedKey = resolveGridKey(gridKey);
    if (cache.has(resolvedKey)) return cache.get(resolvedKey);

    const { data, error } = await fetchUserGridConfig(pageCode, resolvedKey);
    if (error) {
      notifyError('加载列配置失败');
      cache.set(resolvedKey, null);
      return null;
    }

    const payload = parseConfigPayload(data);
    cache.set(resolvedKey, payload);
    return payload;
  }

  async function applyGridConfig(
    gridKey: string | null | undefined,
    api: any,
    columnApi?: any,
    sourceColumnDefs?: any[]
  ) {
    const payload = await loadGridConfig(gridKey);
    const colApi = columnApi ?? api?.columnApi ?? api?.getColumnApi?.();
    const applyFn = api?.applyColumnState ?? colApi?.applyColumnState;
    if (!applyFn) return;

    const currentDefs = (api?.getColumnDefs?.() ?? []) as Array<any>;
    const baseDefs =
      Array.isArray(sourceColumnDefs) && sourceColumnDefs.length > 0 ? sourceColumnDefs : currentDefs;
    const preferenceColumns = payload?.columns ?? [];
    const prefMap = buildPreferenceLookup(preferenceColumns);
    const lockedHiddenColumns = new Set<string>();
    const normalizedDefs = baseDefs.map(def => {
      const field = getRuntimeColumnName(def);
      if (!field) return def;
      const pref = prefMap.get(getColumnDefIdentity(def) || '') ?? prefMap.get(`column:${field}`);
      const hiddenByUser = pref?.hidden === true;
      const hiddenByBase = def?.hide === true;
      const backendLocked = def?.lockVisible === true || def?.suppressColumnsToolPanel === true;
      const shouldLock = backendLocked || (hiddenByBase && !hiddenByUser);
      if (shouldLock) {
        lockedHiddenColumns.add(field);
        return {
          ...def,
          lockVisible: true,
          suppressColumnsToolPanel: true
        };
      }

      return {
        ...def,
        lockVisible: undefined,
        suppressColumnsToolPanel: undefined
      };
    });

    (api as any).__lockedHiddenColumns = Array.from(lockedHiddenColumns);
    if (sourceColumnDefs || normalizedDefs !== currentDefs) {
      api?.setGridOption?.('columnDefs', normalizedDefs);
    }

    const activeDefs = normalizedDefs;
    const currentDefsByIdentity = buildColumnDefLookup(activeDefs);

    applyFn.call(api?.applyColumnState ? api : colApi, {
      state: activeDefs
        .map(def => {
          const runtimeField = getRuntimeColumnName(def);
          if (!runtimeField) return null;
          return {
            colId: runtimeField,
            hide: isBackendHidden(def)
          };
        })
        .filter((col): col is NonNullable<typeof col> => Boolean(col)),
      applyOrder: false
    });

    if (preferenceColumns.length === 0) {
      const resolvedKey = resolveGridKey(gridKey);
      gridApiRefs.set(resolvedKey, { gridKey: resolvedKey, api, columnApi });
      return;
    }

    applyFn.call(api?.applyColumnState ? api : colApi, {
      state: preferenceColumns
        .map((col, index) => {
          const def =
            currentDefsByIdentity.get(getPreferenceKey(col) || '') ??
            currentDefsByIdentity.get(`column:${col.columnName}`);
          const runtimeField = getRuntimeColumnName(def);
          if (!runtimeField) return null;
          const hiddenByUser = col.hidden === true;
          const hiddenByBase = isBackendHidden(def);
          return {
            colId: runtimeField,
            width: col.width,
            hide: hiddenByUser || hiddenByBase ? true : false,
            pinned: col.pinned ?? null,
            order: col.order ?? index
          };
        })
        .filter((col): col is NonNullable<typeof col> => Boolean(col)),
      applyOrder: true
    });

    // 注册 grid API 引用
    const resolvedKey = resolveGridKey(gridKey);
    gridApiRefs.set(resolvedKey, { gridKey: resolvedKey, api, columnApi });
  }

  /** 保存单个 grid 的列配置 */
  async function saveGridConfig(gridKey: string | null | undefined, api: any, columnApi?: any) {
    const resolvedKey = resolveGridKey(gridKey);
    const colApi = columnApi ?? api?.columnApi ?? api?.getColumnApi?.();
    const state = api?.getColumnState?.() ?? colApi?.getColumnState?.();
    if (!state || !Array.isArray(state)) {
      notifyError('无法获取列配置');
      return;
    }

    const currentDefs = (api?.getColumnDefs?.() ?? []) as Array<any>;
    const payload: GridConfigPayload = { columns: normalizeColumns(state, currentDefs) };
    const { error } = await saveUserGridConfig(pageCode, resolvedKey, payload.columns);
    if (error) {
      notifyError('保存列配置失败');
      return;
    }

    cache.set(resolvedKey, payload);

    // 更新 grid API 引用
    gridApiRefs.set(resolvedKey, { gridKey: resolvedKey, api, columnApi });

    // 保存所有已注册的 grid 配置
    await saveAllGridConfigs(resolvedKey);
  }

  /** 保存所有已注册的 grid 配置（排除触发源，因为已经保存过了） */
  async function saveAllGridConfigs(excludeKey?: string) {
    const promises: Promise<void>[] = [];

    for (const [key, ref] of gridApiRefs.entries()) {
      if (key === excludeKey) continue; // 跳过已保存的

      const colApi = ref.columnApi ?? ref.api?.columnApi ?? ref.api?.getColumnApi?.();
      const state = ref.api?.getColumnState?.() ?? colApi?.getColumnState?.();
      if (!state || !Array.isArray(state)) continue;

      const currentDefs = (ref.api?.getColumnDefs?.() ?? []) as Array<any>;
      const payload: GridConfigPayload = { columns: normalizeColumns(state, currentDefs) };
      promises.push(
        saveUserGridConfig(pageCode, key, payload.columns).then(({ error }) => {
          if (!error) {
            cache.set(key, payload);
          }
        })
      );
    }

    if (promises.length > 0) {
      await Promise.all(promises);
    }

    notifySuccess('列配置已保存');
  }

  /** 注册 grid API 引用（用于批量保存） */
  function registerGridApi(gridKey: string | null | undefined, api: any, columnApi?: any) {
    const resolvedKey = resolveGridKey(gridKey);
    gridApiRefs.set(resolvedKey, { gridKey: resolvedKey, api, columnApi });
  }

  return {
    applyGridConfig,
    saveGridConfig,
    registerGridApi
  };
}
