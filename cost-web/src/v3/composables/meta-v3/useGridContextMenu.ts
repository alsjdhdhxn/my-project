import type { ContextMenuItemRule, ContextMenuRule } from '@/v3/composables/meta-v3/types';
import type { CustomExportConfig } from '@/service/api/export-config';

const LABEL_ADD = '新增';
const LABEL_COPY = '复制';
const LABEL_DELETE = '删除';
const LABEL_SAVE = '保存';
const LABEL_SAVE_GRID = '保存列配置';
const LABEL_EXPORT_SELECTED = '导出选中';
const LABEL_EXPORT_CURRENT = '导出当前';
const LABEL_EXPORT_ALL = '导出全部';
const LABEL_RESET_EXPORT = '重置导出配置';
const LABEL_HEADER_CONFIG = '表头配置';
const LABEL_CUSTOM_EXPORT = '自定义导出';

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
  /** 自定义导出配置列表 */
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
        // 可选 action（如 openHeaderConfig）在函数未传入时静默跳过，不打印警告
        // 只对真正未知的 action 打印警告
        const optionalActions = ['openHeaderConfig', 'exportSelected', 'exportCurrent', 'exportAll', 'resetExportConfig', 'saveGridConfig'];
        if (!optionalActions.includes(actionKey)) {
          console.warn('[ContextMenu] unknown action', actionKey);
        }
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
      // 每个配置提供两个选项：导出当前、导出所有
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

