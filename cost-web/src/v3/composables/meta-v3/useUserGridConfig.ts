import { fetchUserGridConfig, saveUserGridConfig } from '@/service/api';

type NotifyFn = (message: string) => void;

type ColumnPreference = {
  field: string;
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

function normalizeColumns(source: any[]): ColumnPreference[] {
  const result: ColumnPreference[] = [];
  source.forEach((col: any, index: number) => {
    const field = col?.field ?? col?.colId;
    if (!field) return;
    result.push({
      field,
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

export function useUserGridConfig(params: {
  pageCode: string;
  notifyError: NotifyFn;
  notifySuccess: NotifyFn;
}) {
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

  async function applyGridConfig(gridKey: string | null | undefined, api: any, columnApi?: any) {
    const payload = await loadGridConfig(gridKey);
    if (!payload?.columns || payload.columns.length === 0) return;

    const colApi = columnApi ?? api?.columnApi ?? api?.getColumnApi?.();
    const applyFn = api?.applyColumnState ?? colApi?.applyColumnState;
    if (!applyFn) return;

    const prefMap = new Map(payload.columns.map(col => [col.field, col]));
    const currentDefs = (api?.getColumnDefs?.() ?? []) as Array<any>;
    const lockedHiddenColumns = new Set<string>();
    let needPatchDefs = false;
    const patchedDefs = currentDefs.map(def => {
      const field = String(def?.field ?? def?.colId ?? '').trim();
      if (!field) return def;
      const hiddenByUser = prefMap.get(field)?.hidden === true;
      const hiddenByBase = def?.hide === true;
      const backendLocked = def?.lockVisible === true || def?.suppressColumnsToolPanel === true;
      const shouldLock = backendLocked || (hiddenByBase && !hiddenByUser);
      if (!shouldLock) return def;
      lockedHiddenColumns.add(field);
      if (def?.lockVisible === true && def?.suppressColumnsToolPanel === true) {
        return def;
      }
      needPatchDefs = true;
      return {
        ...def,
        lockVisible: true,
        suppressColumnsToolPanel: true
      };
    });

    if (lockedHiddenColumns.size > 0) {
      (api as any).__lockedHiddenColumns = Array.from(lockedHiddenColumns);
    }
    if (needPatchDefs) {
      api?.setGridOption?.('columnDefs', patchedDefs);
    }

    applyFn.call(api?.applyColumnState ? api : colApi, {
      state: payload.columns.map((col, index) => ({
        colId: col.field,
        width: col.width,
        // 用户个性化只允许收紧：
        // hidden=true 时隐藏；hidden=false/undefined 不允许反向放开后端权限结果。
        hide: col.hidden === true ? true : undefined,
        pinned: col.pinned ?? null,
        order: col.order ?? index
      })),
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

    const payload: GridConfigPayload = { columns: normalizeColumns(state) };
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
      
      const payload: GridConfigPayload = { columns: normalizeColumns(state) };
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

