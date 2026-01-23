import type { ContextMenuItemRule, ContextMenuRule } from '@/v3/composables/meta-v3/types';
import type { CustomExportConfig } from '@/service/api/export-config';

const LABEL_ADD = '\u65b0\u589e';
const LABEL_COPY = '\u590d\u5236';
const LABEL_DELETE = '\u5220\u9664';
const LABEL_SAVE = '\u4fdd\u5b58';
const LABEL_SAVE_GRID = '\u4fdd\u5b58\u5217\u914d\u7f6e';
const LABEL_EXPORT_SELECTED = '\u5bfc\u51fa\u9009\u4e2d';
const LABEL_EXPORT_CURRENT = '\u5bfc\u51fa\u5f53\u524d';
const LABEL_EXPORT_ALL = '\u5bfc\u51fa\u5168\u90e8';
const LABEL_RESET_EXPORT = '\u91cd\u7f6e\u5bfc\u51fa\u914d\u7f6e';
const LABEL_HEADER_CONFIG = '\u8868\u5934\u914d\u7f6e';
const LABEL_CUSTOM_EXPORT = '\u81ea\u5b9a\u4e49\u5bfc\u51fa';

type MenuConfigInput = ContextMenuRule | { value?: ContextMenuRule | null } | null | undefined;

type MenuScope = {
  type: 'master' | 'detail';
  params: any;
  masterId?: number;
  tabKey?: string;
};

export function useGridContextMenu(params: {
  addMasterRow: () => void;
  deleteMasterRow: (row: any) => void;
  copyMasterRow: (row: any) => void;
  addDetailRow: (masterId: number, tabKey: string) => void;
  deleteDetailRow: (masterId: number, tabKey: string, row: any) => void;
  copyDetailRow: (masterId: number, tabKey: string, row: any) => void;
  save: () => void;
  saveGridConfig?: (gridKey: string, api: any, columnApi: any) => void;
  exportSelected?: () => void;
  exportCurrent?: () => void;
  exportAll?: () => void;
  resetExportConfig?: () => void;
  openHeaderConfig?: () => void;
  masterGridKey?: string | null;
  masterMenuConfig?: MenuConfigInput;
  detailMenuByTab?: Record<string, ContextMenuRule | null> | { value?: Record<string, ContextMenuRule | null> };
  /** 自定义导出配置列�?*/
  customExportConfigs?: CustomExportConfig[] | { value?: CustomExportConfig[] };
  /** 执行自定义导出的回调 */
  executeCustomExport?: (exportCode: string, mode: 'all' | 'current') => void;
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
    exportSelected,
    exportCurrent,
    exportAll,
    resetExportConfig,
    openHeaderConfig,
    masterGridKey,
    masterMenuConfig,
    detailMenuByTab,
    customExportConfigs,
    executeCustomExport
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
      case 'export.selected':
      case 'export_selected':
      case 'exportSelected':
        return 'exportSelected';
      case 'export.current':
      case 'export_current':
      case 'exportCurrent':
        return 'exportCurrent';
      case 'export.all':
      case 'export_all':
      case 'exportAll':
        return 'exportAll';
      case 'export.reset':
      case 'export_reset':
      case 'resetExportConfig':
        return 'resetExportConfig';
      case 'export.header':
      case 'export_header':
      case 'openHeaderConfig':
      case 'headerConfig':
        return 'openHeaderConfig';
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
            else if (ctx.masterId != null && ctx.tabKey) addDetailRow(ctx.masterId, ctx.tabKey);
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
              // 多选复制
              if (ctx.type === 'master') {
                selectedRows.forEach((row: any) => copyMasterRow(row));
              } else if (ctx.masterId != null && ctx.tabKey) {
                selectedRows.forEach((row: any) => copyDetailRow(ctx.masterId!, ctx.tabKey!, row));
              }
            } else {
              // 单行复制
              const row = resolveRow(ctx.params);
              if (!row) return;
              if (ctx.type === 'master') copyMasterRow(row);
              else if (ctx.masterId != null && ctx.tabKey) copyDetailRow(ctx.masterId, ctx.tabKey, row);
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
            
            if (selectedRows.length > 1) {
              // 多选删除
              if (ctx.type === 'master') {
                selectedRows.forEach((row: any) => deleteMasterRow(row));
              } else if (ctx.masterId != null && ctx.tabKey) {
                selectedRows.forEach((row: any) => deleteDetailRow(ctx.masterId!, ctx.tabKey!, row));
              }
            } else {
              // 单行删除
              const row = resolveRow(ctx.params);
              if (!row) return;
              if (ctx.type === 'master') deleteMasterRow(row);
              else if (ctx.masterId != null && ctx.tabKey) deleteDetailRow(ctx.masterId, ctx.tabKey, row);
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
      case 'exportSelected':
        return exportSelected ? { label: LABEL_EXPORT_SELECTED, requiresSelection: true, handler: () => exportSelected() } : null;
      case 'exportCurrent':
        return exportCurrent ? { label: LABEL_EXPORT_CURRENT, handler: () => exportCurrent() } : null;
      case 'exportAll':
        return exportAll ? { label: LABEL_EXPORT_ALL, handler: () => exportAll() } : null;
      case 'resetExportConfig':
        return resetExportConfig ? { label: LABEL_RESET_EXPORT, handler: () => resetExportConfig() } : null;
      case 'openHeaderConfig':
        return openHeaderConfig ? { label: LABEL_HEADER_CONFIG, handler: () => openHeaderConfig() } : null;
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
      if (!resolved) {
        console.warn('[ContextMenu] unknown action', actionKey);
        continue;
      }

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
      // 每个配置提供两个选项：导出当前、导出所�?
      subMenuItems.push({
        name: `${config.exportName} - \u5bfc\u51fa\u5f53\u524d`,
        action: () => executeCustomExport(config.exportCode, 'current')
      });
      subMenuItems.push({
        name: `${config.exportName} - \u5bfc\u51fa\u6240\u6709`,
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

  function getDetailContextMenuItems(masterId: number, tabKey: string) {
    return (params: any) => {
      const config = resolveMenuByTab(tabKey);
      if (!config) return [];
      return buildMenuItems(config.items || [], { type: 'detail', params, masterId, tabKey });
    };
  }

  return {
    getMasterContextMenuItems,
    getDetailContextMenuItems
  };
}

