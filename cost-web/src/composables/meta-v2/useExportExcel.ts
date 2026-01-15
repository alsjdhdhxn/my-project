import { h, ref } from 'vue';
import { NCheckbox } from 'naive-ui';
import { exportPageExcel } from '@/service/api/export';

type NotifyFn = (message: string) => void;

const LABEL_EXPORT = '\u5bfc\u51fa';
const LABEL_USE_CONFIG = '\u4f7f\u7528\u5f53\u524d\u5217\u914d\u7f6e';
const LABEL_CANCEL = '\u53d6\u6d88';
const LABEL_SELECT_ONE = '\u8bf7\u9009\u62e9\u4e00\u884c';
const LABEL_ONLY_ONE = '\u53ea\u80fd\u5bfc\u51fa\u4e00\u884c';
const LABEL_NO_DATA = '\u5f53\u524d\u6ca1\u6709\u53ef\u5bfc\u51fa\u7684\u6570\u636e';
const LABEL_EXPORT_OK = '\u5bfc\u51fa\u5df2\u5f00\u59cb';

function toNumber(value: any): number | null {
  if (value == null) return null;
  const num = Number(value);
  return Number.isFinite(num) ? num : null;
}

function downloadBlob(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

async function confirmUseConfig(): Promise<boolean | null> {
  if (!window.$dialog) {
    return true;
  }
  return new Promise(resolve => {
    const checked = ref(true);
    window.$dialog?.create({
      title: LABEL_EXPORT,
      content: () =>
        h(
          NCheckbox,
          {
            checked: checked.value,
            'onUpdate:checked': (value: boolean) => {
              checked.value = value;
            }
          },
          { default: () => LABEL_USE_CONFIG }
        ),
      positiveText: LABEL_EXPORT,
      negativeText: LABEL_CANCEL,
      onPositiveClick: () => resolve(checked.value),
      onNegativeClick: () => resolve(null),
      onClose: () => resolve(null)
    });
  });
}

export function useExportExcel(params: {
  pageCode: string;
  masterGridApi: { value: any | null };
  masterGridKey?: { value?: string | null } | string | null;
  notifyInfo: NotifyFn;
  notifyError: NotifyFn;
  notifySuccess: NotifyFn;
}) {
  const { pageCode, masterGridApi, masterGridKey, notifyInfo, notifyError, notifySuccess } = params;

  const resolveGridKey = () => {
    const key = (masterGridKey as any)?.value ?? masterGridKey;
    return typeof key === 'string' && key.trim().length > 0 ? key : 'masterGrid';
  };

  const runExport = async (mode: 'selected' | 'current' | 'all', ids?: number[]) => {
    const useUserConfig = await confirmUseConfig();
    if (useUserConfig == null) return;

    const finalMode = !useUserConfig && mode === 'current' ? 'all' : mode;

    try {
      notifyInfo(LABEL_EXPORT_OK);
      const { blob, filename } = await exportPageExcel(pageCode, {
        mode: finalMode,
        useUserConfig,
        masterIds: ids,
        masterGridKey: resolveGridKey()
      });
      downloadBlob(blob, filename);
      notifySuccess(LABEL_EXPORT_OK);
    } catch (error: any) {
      notifyError(error?.message || 'export failed');
    }
  };

  const exportSelected = async () => {
    const api = masterGridApi.value;
    const rows = api?.getSelectedRows?.() || [];
    if (!rows || rows.length === 0) {
      notifyError(LABEL_SELECT_ONE);
      return;
    }
    if (rows.length > 1) {
      notifyError(LABEL_ONLY_ONE);
      return;
    }
    const id = toNumber(rows[0]?.id);
    if (id == null) {
      notifyError(LABEL_SELECT_ONE);
      return;
    }
    await runExport('selected', [id]);
  };

  const exportCurrent = async () => {
    const api = masterGridApi.value;
    const ids: number[] = [];
    api?.forEachNodeAfterFilterAndSort?.((node: any) => {
      const id = toNumber(node?.data?.id);
      if (id != null) ids.push(id);
    });
    if (ids.length === 0) {
      notifyError(LABEL_NO_DATA);
      return;
    }
    await runExport('current', ids);
  };

  const exportAll = async () => {
    await runExport('all');
  };

  return {
    exportSelected,
    exportCurrent,
    exportAll
  };
}
