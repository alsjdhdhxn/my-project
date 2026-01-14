const LABEL_ADD = '\u65b0\u589e';
const LABEL_COPY = '\u590d\u5236';
const LABEL_DELETE = '\u5220\u9664';
const LABEL_SAVE = '\u4fdd\u5b58';

export function useGridContextMenu(params: {
  addMasterRow: () => void;
  deleteMasterRow: (row: any) => void;
  copyMasterRow: (row: any) => void;
  addDetailRow: (masterId: number, tabKey: string) => void;
  deleteDetailRow: (masterId: number, tabKey: string, row: any) => void;
  copyDetailRow: (masterId: number, tabKey: string, row: any) => void;
  save: () => void;
}) {
  const {
    addMasterRow,
    deleteMasterRow,
    copyMasterRow,
    addDetailRow,
    deleteDetailRow,
    copyDetailRow,
    save
  } = params;

  function getMasterContextMenuItems(params: any) {
    const items: any[] = [{ name: LABEL_ADD, action: () => addMasterRow() }];
    if (params.node) {
      items.push({ name: LABEL_COPY, action: () => copyMasterRow(params.node.data) });
      items.push({ name: LABEL_DELETE, action: () => deleteMasterRow(params.node.data) });
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
      items.push('separator', 'copy', 'paste');
      return items;
    };
  }

  return {
    getMasterContextMenuItems,
    getDetailContextMenuItems
  };
}
