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

    applyFn.call(api?.applyColumnState ? api : colApi, {
      state: payload.columns.map((col, index) => ({
        colId: col.field,
        width: col.width,
        hide: col.hidden,
        pinned: col.pinned ?? null,
        order: col.order ?? index
      })),
      applyOrder: true
    });
  }

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
    notifySuccess('列配置已保存');
  }

  return {
    applyGridConfig,
    saveGridConfig
  };
}
