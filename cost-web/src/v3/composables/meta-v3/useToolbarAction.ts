import type { useDialog } from 'naive-ui';

export type ToolbarItem = {
  action?: string;
  label?: string;
  type?: string;
  disabled?: boolean;
  confirm?: string;
  requiresRow?: boolean;
  refreshMode?: 'all' | 'row' | 'detail' | 'none';
};

export type ExecuteActionFn = (
  actionCode: string,
  options?: {
    data?: Record<string, any>;
    selectedRow?: Record<string, any> | null;
    refreshMode?: 'all' | 'row' | 'detail' | 'none';
  }
) => Promise<void>;

export type ToolbarActionContext = {
  getSelectedRow: () => Record<string, any> | null;
  executeAction: ExecuteActionFn;
  dialog: ReturnType<typeof useDialog>;
};

/**
 * 处理工具栏/右键菜单按钮点击
 * 统一处理 refreshMode 逻辑和确认弹窗
 */
export async function handleToolbarAction(
  item: ToolbarItem,
  ctx: ToolbarActionContext
): Promise<void> {
  if (!item.action) return;

  const { getSelectedRow, executeAction, dialog } = ctx;
  const row = getSelectedRow();

  // 默认刷新模式：需要选中行时刷新行，否则刷新全部
  const defaultRefreshMode = item.requiresRow ? 'row' : 'all';
  const refreshMode = item.refreshMode ?? defaultRefreshMode;

  const doExecute = async () => {
    await executeAction(item.action!, {
      data: row || {},
      selectedRow: row,
      refreshMode
    });
  };

  // 如果有确认提示
  if (item.confirm) {
    dialog.warning({
      title: '确认',
      content: item.confirm,
      positiveText: '确定',
      negativeText: '取消',
      onPositiveClick: doExecute
    });
    return;
  }

  await doExecute();
}

/**
 * 计算按钮的 refreshMode
 * 用于右键菜单等场景
 */
export function resolveRefreshMode(
  item: { requiresRow?: boolean; refreshMode?: 'all' | 'row' | 'detail' | 'none' }
): 'all' | 'row' | 'detail' | 'none' {
  const defaultRefreshMode = item.requiresRow ? 'row' : 'all';
  return item.refreshMode ?? defaultRefreshMode;
}
