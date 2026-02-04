import type { ContextMenuItemRule, ContextMenuRule } from '@/v3/composables/meta-v3/types';
import type { CustomExportConfig } from '@/service/api/export-config';

const LABEL_ADD = '新增';
const LABEL_COPY = '复制';
const LABEL_DELETE = '删除';
const LABEL_SAVE = '保存';
const LABEL_SAVE_GRID = '保存列配置';
const LABEL_CUSTOM_EXPORT = '自定义导出';

type MenuConfigInput = ContextMenuRule | { value?: ContextMenuRule | null } | null | undefined;

type MenuScope = {
  type: 'master' | 'detail';
  params: any;
  masterId?: number;
  masterRowKey?: string;
  tabKey?: string;
};

export function useGridContextMenu(params: {
  addMasterRow: () => void;
  deleteMasterRow: (row: any) => void;
  copyMasterRow: (row: any) => void;
  addDetailRow: (masterId: number, tabKey: string, masterRowKey?: string) => void;
  deleteDetailRow: (masterId: number, tabKey: string, row: any, masterRowKey?: string) => void;
  copyDetailRow: (masterId: number, tabKey: string, row: any, masterRowKey?: string) => void;
  save: () => void;
  saveGridConfig?: (gridKey: string, api: any, columnApi: any) => void;
  masterGridKey?: string | null;
  masterMenuConfig?: MenuConfigInput;
  detailMenuByTab?: Record<string, ContextMenuRule | null> | { value?: Record<string, ContextMenuRule | null> };
  /** 自定义导出配置列表 */
  customExportConfigs?: CustomExportConfig[] | { value?: CustomExportConfig[] };
  /** 执行自定义导出的回调 */
  executeCustomExport?: (exportCode: string, mode: 'all' | 'current') => void;
  /** 执行后端 action */
  executeAction?: (actionCode: string, options?: { data?: Record<string, any>; selectedRow?: Record<string, any> | null }) => Promise<void>;
  /** 主表行是否可编辑的回调（用于控制删除权限） */
  isRowEditable?: (row: any) => boolean;
  /** 从表行是否可编辑的回调（按tabKey） */
  isDetailRowEditableByTab?: Record<string, ((row: any) => boolean) | undefined> | { value?: Record<string, ((row: any) => boolean) | undefined> };
  /** 提示消息 */
  notifyError?: (message: string) => void;
}) {
  const {
    addMasterRow,
    deleteMasterRow,
    copyMasterRow,
    addDetailRow,
    deleteDetailRow,
    copyDetailRow,
    save,
    saveGridConfig,
    masterGridKey,
    masterMenuConfig,
    detailMenuByTab,
    customExportConfigs,
    executeCustomExport,
    executeAction,
    isRowEditable,
    isDetailRowEditableByTab,
    notifyError
  } = params;

  function resolveMenuConfig(config: MenuConfigInput): ContextMenuRule | null {
    if (!config) return null;
    const raw = (config as any).value ?? config;
    if (!raw || !Array.isArray(raw.items)) return null;
    return raw as ContextMenuRule;
  }

  function resolveMenuByTab(tabKey: string): ContextMenuRule | null {
    const raw = (detailMenuByTab as any)?.value ?? detailMenuByTab;
    if (!raw || typeof raw !== 'object') return null;
    return raw[tabKey] || null;
  }

  function hasSelection(params: any): boolean {
    if (params?.node) return true;
    const selected = params?.api?.getSelectedRows?.() || [];
    return selected.length > 0;
  }

  function resolveRow(params: any): any | null {
    if (params?.node?.data) return params.node.data;
    const selected = params?.api?.getSelectedRows?.() || [];
    return selected[0] || null;
  }

  function normalizeAction(action?: string): string | null {
    if (!action) return null;
    const key = action.trim();
    if (!key) return null;
    const normalized = key.replace(/\s+/g, '');
    switch (normalized) {
      case 'add':
      case 'addRow':
        return 'addRow';
      case 'copy':
      case 'copyRow':
        return 'copyRow';
      case 'delete':
      case 'deleteRow':
        return 'deleteRow';
      case 'save':
        return 'save';
      case 'saveGrid':
      case 'saveGridConfig':
      case 'saveColumnConfig':
        return 'saveGridConfig';
      case 'clipboard.copy':
      case 'clipboard_copy':
        return 'clipboardCopy';
      case 'clipboard.paste':
      case 'clipboard_paste':
        return 'clipboardPaste';
      case 'separator':
        return 'separator';
      default:
        return normalized;
    }
  }

  function resolveAction(action: string, ctx: MenuScope): {
    label?: string;
    handler?: () => void;
    builtIn?: 'copy' | 'paste';
    requiresRow?: boolean;
    requiresSelection?: boolean;
  } | null {
    switch (action) {
      case 'addRow':
        return {
          label: LABEL_ADD,
          handler: () => {
            if (ctx.type === 'master') addMasterRow();
            else if (ctx.masterId != null && ctx.tabKey) addDetailRow(ctx.masterId, ctx.tabKey, ctx.masterRowKey);
          }
        };
      case 'copyRow':
        return {
          label: LABEL_COPY,
          requiresRow: true,
          handler: () => {
            const api = ctx.params?.api;
            const selectedRows = api?.getSelectedRows?.() || [];
            
            if (selectedRows.length > 1) {
              if (ctx.type === 'master') {
                selectedRows.forEach((row: any) => copyMasterRow(row));
              } else if (ctx.masterId != null && ctx.tabKey) {
                selectedRows.forEach((row: any) => copyDetailRow(ctx.masterId!, ctx.tabKey!, row, ctx.masterRowKey));
              }
            } else {
              const row = resolveRow(ctx.params);
              if (!row) return;
              if (ctx.type === 'master') copyMasterRow(row);
              else if (ctx.masterId != null && ctx.tabKey) copyDetailRow(ctx.masterId, ctx.tabKey, row, ctx.masterRowKey);
            }
          }
        };
      case 'deleteRow':
        return {
          label: LABEL_DELETE,
          requiresRow: true,
          handler: () => {
            const api = ctx.params?.api;
            const selectedRows = api?.getSelectedRows?.() || [];
            
            // 解析响应式的 isDetailRowEditableByTab（支持 ref、computed 或普通对象）
            let resolvedDetailEditable: Record<string, ((row: any) => boolean) | undefined> | undefined = undefined;
            if (isDetailRowEditableByTab) {
              if (typeof isDetailRowEditableByTab === 'object' && 'value' in isDetailRowEditableByTab) {
                resolvedDetailEditable = (isDetailRowEditableByTab as any).value;
              } else {
                resolvedDetailEditable = isDetailRowEditableByTab as Record<string, ((row: any) => boolean) | undefined>;
              }
            }
            console.log('[DEBUG] deleteRow - ctx.type:', ctx.type, 'ctx.tabKey:', ctx.tabKey);
            console.log('[DEBUG] deleteRow - resolvedDetailEditable keys:', resolvedDetailEditable ? Object.keys(resolvedDetailEditable) : 'undefined');
            
            // 检查行是否可编辑（不可编辑的行不允许删除）
            const checkEditable = (row: any, tabKey?: string): boolean => {
              if (!row) return false;
              // 新增行始终可以删除
              if (row._isNew) return true;
              // 主表检查
              if (ctx.type === 'master') {
                if (isRowEditable && !isRowEditable(row)) {
                  notifyError?.('该行不允许删除');
                  return false;
                }
              } else {
                // 从表检查
                const detailChecker = tabKey ? resolvedDetailEditable?.[tabKey] : undefined;
                console.log('[DEBUG] checkEditable - tabKey:', tabKey, 'detailChecker:', detailChecker ? 'exists' : 'undefined');
                if (detailChecker) {
                  const isEditable = detailChecker(row);
                  console.log('[DEBUG] checkEditable - row:', row, 'isEditable:', isEditable);
                  if (!isEditable) {
                    notifyError?.('该行不允许删除');
                    return false;
                  }
                }
              }
              return true;
            };
            
            if (selectedRows.length > 1) {
              if (ctx.type === 'master') {
                const editableRows = selectedRows.filter((row: any) => checkEditable(row));
                editableRows.forEach((row: any) => deleteMasterRow(row));
              } else if (ctx.masterId != null && ctx.tabKey) {
                const editableRows = selectedRows.filter((row: any) => checkEditable(row, ctx.tabKey));
                editableRows.forEach((row: any) => deleteDetailRow(ctx.masterId!, ctx.tabKey!, row, ctx.masterRowKey));
              }
            } else {
              const row = resolveRow(ctx.params);
              if (!row) return;
              if (ctx.type === 'master') {
                if (!checkEditable(row)) return;
                deleteMasterRow(row);
              } else if (ctx.masterId != null && ctx.tabKey) {
                if (!checkEditable(row, ctx.tabKey)) return;
                deleteDetailRow(ctx.masterId, ctx.tabKey, row, ctx.masterRowKey);
              }
            }
          }
        };
      case 'save':
        return save ? { label: LABEL_SAVE, handler: () => save() } : null;
      case 'saveGridConfig': {
        if (!saveGridConfig) return null;
        const key = ctx.type === 'master' ? (masterGridKey || 'masterGrid') : (ctx.tabKey || '');
        if (!key) return null;
        return {
          label: LABEL_SAVE_GRID,
          handler: () => saveGridConfig(key, ctx.params?.api, ctx.params?.columnApi)
        };
      }
      case 'clipboardCopy':
        return { builtIn: 'copy' };
      case 'clipboardPaste':
        return { builtIn: 'paste' };
      default:
        return null;
    }
  }

  function resolveChildren(item: ContextMenuItemRule): ContextMenuItemRule[] {
    if (Array.isArray(item.items)) return item.items;
    const raw = (item as any).children ?? (item as any).subMenu;
    return Array.isArray(raw) ? raw : [];
  }

  function isSeparator(item: ContextMenuItemRule): boolean {
    if (item.type === 'separator') return true;
    if (item.action && normalizeAction(item.action) === 'separator') return true;
    return (item as any).separator === true;
  }

  // 内置前端 action 列表
  const BUILTIN_ACTIONS = [
    'addRow', 'copyRow', 'deleteRow', 'save', 'saveGridConfig',
    'clipboardCopy', 'clipboardPaste'
  ];

  function buildMenuItems(items: ContextMenuItemRule[], ctx: MenuScope): any[] {
    const built: any[] = [];
    for (const item of items) {
      if (!item || item.visible === false) continue;
      if (isSeparator(item)) {
        built.push('separator');
        continue;
      }

      const children = resolveChildren(item);
      if (children.length > 0 || item.type === 'group') {
        const subItems = buildMenuItems(children, ctx);
        if (subItems.length === 0) continue;
        const name = (item.label || '').trim();
        if (!name) continue;
        built.push({ name, subMenu: subItems });
        continue;
      }

      const actionKey = normalizeAction(item.action);
      if (!actionKey || actionKey === 'separator') continue;
      
      const resolved = resolveAction(actionKey, ctx);
      if (resolved) {
        // 内置 action
        const needsRow = item.requiresRow ?? resolved.requiresRow ?? false;
        if (needsRow && !ctx.params?.node) continue;

        const needsSelection = item.requiresSelection ?? resolved.requiresSelection ?? false;
        const disabled = item.disabled || (needsSelection && !hasSelection(ctx.params));

        if (resolved.builtIn) {
          if (disabled) continue;
          built.push(resolved.builtIn);
          continue;
        }

        built.push({
          name: item.label || resolved.label || actionKey,
          action: resolved.handler,
          disabled: Boolean(disabled)
        });
        continue;
      }

      // 内置 action 但函数未传入，跳过
      if (BUILTIN_ACTIONS.includes(actionKey)) {
        continue;
      }

      // 非内置 action，调用后端执行
      if (executeAction) {
        const needsRow = item.requiresRow ?? false;
        if (needsRow && !ctx.params?.node) continue;

        const needsSelection = item.requiresSelection ?? false;
        const disabled = item.disabled || (needsSelection && !hasSelection(ctx.params));

        // 默认刷新模式：需要选中行时刷新行，否则刷新全部
        const defaultRefreshMode = needsRow ? 'row' : 'all';
        const refreshMode = item.refreshMode ?? defaultRefreshMode;

        built.push({
          name: item.label || actionKey,
          action: () => {
            const row = resolveRow(ctx.params);
            executeAction(actionKey, { data: row || {}, selectedRow: row, refreshMode });
          },
          disabled: Boolean(disabled)
        });
      }
    }

    return normalizeSeparators(built);
  }

  function normalizeSeparators(items: any[]): any[] {
    const result: any[] = [];
    for (const item of items) {
      if (item === 'separator') {
        if (result.length === 0 || result[result.length - 1] === 'separator') continue;
      }
      result.push(item);
    }
    if (result[result.length - 1] === 'separator') result.pop();
    return result;
  }

  function resolveCustomExportConfigs(): CustomExportConfig[] {
    const raw = (customExportConfigs as any)?.value ?? customExportConfigs;
    return Array.isArray(raw) ? raw : [];
  }

  function buildCustomExportSubMenu(): any[] {
    const configs = resolveCustomExportConfigs();
    if (configs.length === 0 || !executeCustomExport) return [];

    const subMenuItems: any[] = [];
    for (const config of configs) {
      subMenuItems.push({
        name: `${config.exportName} - 导出当前`,
        action: () => executeCustomExport(config.exportCode, 'current')
      });
      subMenuItems.push({
        name: `${config.exportName} - 导出所有`,
        action: () => executeCustomExport(config.exportCode, 'all')
      });
    }
    return subMenuItems;
  }

  function getMasterContextMenuItems(params: any) {
    const config = resolveMenuConfig(masterMenuConfig);
    if (!config) return [];
    const items = buildMenuItems(config.items || [], { type: 'master', params });

    // 添加自定义导出子菜单
    const customExportSubMenu = buildCustomExportSubMenu();
    if (customExportSubMenu.length > 0) {
      items.push('separator');
      items.push({
        name: LABEL_CUSTOM_EXPORT,
        subMenu: customExportSubMenu
      });
    }

    return normalizeSeparators(items);
  }

  function getDetailContextMenuItems(masterId: number, masterRowKey: string, tabKey: string) {
    return (params: any) => {
      const config = resolveMenuByTab(tabKey);
      if (!config) return [];
      return buildMenuItems(config.items || [], { type: 'detail', params, masterId, masterRowKey, tabKey });
    };
  }

  return {
    getMasterContextMenuItems,
    getDetailContextMenuItems
  };
}
