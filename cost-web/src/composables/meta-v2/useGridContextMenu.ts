const LABEL_ADD = '\u65b0\u589e';
const LABEL_COPY = '\u590d\u5236';
const LABEL_DELETE = '\u5220\u9664';
const LABEL_SAVE = '\u4fdd\u5b58';
const LABEL_SAVE_GRID = '\u4fdd\u5b58\u5217\u914d\u7f6e';
const LABEL_EXPORT_SELECTED = '\u5bfc\u51fa\u9009\u4e2d';
const LABEL_EXPORT_CURRENT = '\u5bfc\u51fa\u5f53\u524d';
const LABEL_EXPORT_ALL = '\u5bfc\u51fa\u5168\u90e8';

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
  masterGridKey?: string | null;
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
    masterGridKey
  } = params;

  function getMasterContextMenuItems(params: any) {
    const items: any[] = [{ name: LABEL_ADD, action: () => addMasterRow() }];
    if (params.node) {
      items.push({ name: LABEL_COPY, action: () => copyMasterRow(params.node.data) });
      items.push({ name: LABEL_DELETE, action: () => deleteMasterRow(params.node.data) });
    }
    if (saveGridConfig) {
      const key = masterGridKey || 'masterGrid';
      items.push({ name: LABEL_SAVE_GRID, action: () => saveGridConfig(key, params.api, params.columnApi) });
    }
    if (exportSelected || exportCurrent || exportAll) {
      items.push('separator');
      if (exportSelected) items.push({ name: LABEL_EXPORT_SELECTED, action: () => exportSelected() });
      if (exportCurrent) items.push({ name: LABEL_EXPORT_CURRENT, action: () => exportCurrent() });
      if (exportAll) items.push({ name: LABEL_EXPORT_ALL, action: () => exportAll() });
    }
    items.push('separator', { name: LABEL_SAVE, action: () => save() }, 'separator', 'copy', 'paste');
    return items;
  }

  function getDetailContextMenuItems(masterId: number, tabKey: string) {
    return (params: any) => {
      const items: any[] = [{ name: LABEL_ADD, action: () => addDetailRow(masterId, tabKey) }];
      if (params.node) {
        items.push({ name: LABEL_COPY, action: () => copyDetailRow(masterId, tabKey, params.node.data) });
        items.push({ name: LABEL_DELETE, action: () => deleteDetailRow(masterId, tabKey, params.node.data) });
      }
      if (saveGridConfig) {
        items.push({ name: LABEL_SAVE_GRID, action: () => saveGridConfig(tabKey, params.api, params.columnApi) });
      }
      items.push('separator', 'copy', 'paste');
      return items;
    };
  }

  return {
    getMasterContextMenuItems,
    getDetailContextMenuItems
  };
}
