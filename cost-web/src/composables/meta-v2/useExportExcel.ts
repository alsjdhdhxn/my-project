import { h, ref } from 'vue';
import type { Ref } from 'vue';
import { NCheckbox, NCollapse, NCollapseItem, NDivider, NInput } from 'naive-ui';
import type { ParsedPageConfig } from '@/logic/calc-engine';
import { exportPageExcel } from '@/service/api/export';
import {
  fetchExportHeaderConfig,
  fetchExportUserPref,
  resetExportUserPref,
  saveExportHeaderConfig,
  saveExportUserPref
} from '@/service/api/export-config';

type NotifyFn = (message: string) => void;

type ExportOptions = {
  useUserConfig: boolean;
  remember: boolean;
};

type HeaderItem = {
  field: string;
  defaultHeader: string;
  customHeader: string;
  visible: boolean;
};

type HeaderSection = {
  key: string;
  title: string;
  items: HeaderItem[];
};

const LABEL_EXPORT = '\u5bfc\u51fa';
const LABEL_USE_CONFIG = '\u4f7f\u7528\u5f53\u524d\u5217\u914d\u7f6e';
const LABEL_REMEMBER = '\u4ee5\u540e\u6309\u6b64\u914d\u7f6e\u6253\u5370';
const LABEL_CANCEL = '\u53d6\u6d88';
const LABEL_SELECT_ONE = '\u8bf7\u9009\u62e9\u4e00\u884c';
const LABEL_ONLY_ONE = '\u53ea\u80fd\u5bfc\u51fa\u4e00\u884c';
const LABEL_NO_DATA = '\u5f53\u524d\u6ca1\u6709\u53ef\u5bfc\u51fa\u7684\u6570\u636e';
const LABEL_EXPORT_OK = '\u5bfc\u51fa\u5df2\u5f00\u59cb';
const LABEL_RESET_OK = '\u5bfc\u51fa\u914d\u7f6e\u5df2\u91cd\u7f6e';
const LABEL_RESET_FAIL = '\u5bfc\u51fa\u914d\u7f6e\u91cd\u7f6e\u5931\u8d25';
const LABEL_HEADER_CONFIG = '\u8868\u5934\u914d\u7f6e';
const LABEL_HEADER_SAVE_OK = '\u8868\u5934\u914d\u7f6e\u5df2\u4fdd\u5b58';
const LABEL_HEADER_SAVE_FAIL = '\u8868\u5934\u914d\u7f6e\u4fdd\u5b58\u5931\u8d25';
const LABEL_PREF_SAVE_FAIL = '\u5bfc\u51fa\u914d\u7f6e\u4fdd\u5b58\u5931\u8d25';
const LABEL_NO_PERMISSION = '\u65e0\u6743\u9650';
const LABEL_MASTER = '\u4e3b\u8868';
const LABEL_FIELD = '\u5b57\u6bb5';
const LABEL_DEFAULT_HEADER = '\u9ed8\u8ba4\u8868\u5934';
const LABEL_CUSTOM_HEADER = '\u81ea\u5b9a\u4e49\u8868\u5934';
const LABEL_VISIBLE = '\u663e\u793a';
const LABEL_SAVE = '\u4fdd\u5b58';

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

function resolveGridKey(value?: { value?: string | null } | string | null) {
  const key = (value as any)?.value ?? value;
  return typeof key === 'string' && key.trim().length > 0 ? key : 'masterGrid';
}

function resolveAdminFlag(value?: Ref<boolean> | boolean): boolean {
  if (!value) return false;
  if (typeof value === 'boolean') return value;
  return Boolean(value.value);
}

async function confirmExportOptions(): Promise<ExportOptions | null> {
  if (!window.$dialog) {
    return { useUserConfig: true, remember: false };
  }
  return new Promise(resolve => {
    const useUserConfig = ref(true);
    const remember = ref(false);
    window.$dialog?.create({
      title: LABEL_EXPORT,
      content: () =>
        h(
          'div',
          { style: { display: 'flex', flexDirection: 'column', gap: '8px' } },
          [
            h(
              NCheckbox,
              {
                checked: useUserConfig.value,
                'onUpdate:checked': (value: boolean) => {
                  useUserConfig.value = value;
                }
              },
              { default: () => LABEL_USE_CONFIG }
            ),
            h(
              NCheckbox,
              {
                checked: remember.value,
                'onUpdate:checked': (value: boolean) => {
                  remember.value = value;
                }
              },
              { default: () => LABEL_REMEMBER }
            )
          ]
        ),
      positiveText: LABEL_SAVE,
      negativeText: LABEL_CANCEL,
      onPositiveClick: () => resolve({ useUserConfig: useUserConfig.value, remember: remember.value }),
      onNegativeClick: () => resolve(null),
      onClose: () => resolve(null)
    });
  });
}

export function useExportExcel(params: {
  pageCode: string;
  masterGridApi: { value: any | null };
  masterGridKey?: { value?: string | null } | string | null;
  pageConfig?: Ref<ParsedPageConfig | null>;
  isAdmin?: Ref<boolean> | boolean;
  notifyInfo: NotifyFn;
  notifyError: NotifyFn;
  notifySuccess: NotifyFn;
}) {
  const {
    pageCode,
    masterGridApi,
    masterGridKey,
    pageConfig,
    isAdmin,
    notifyInfo,
    notifyError,
    notifySuccess
  } = params;

  const prefLoaded = ref(false);
  const prefCache = ref<{ autoExport?: boolean; useUserConfig?: boolean } | null>(null);
  const canEditHeader = resolveAdminFlag(isAdmin);

  async function loadUserPref() {
    if (prefLoaded.value) return;
    const { data, error } = await fetchExportUserPref(pageCode);
    prefLoaded.value = true;
    if (!error) {
      prefCache.value = data || null;
    }
  }

  async function resolveExportOptions() {
    await loadUserPref();
    if (prefCache.value?.autoExport) {
      return {
        useUserConfig: prefCache.value.useUserConfig ?? true,
        remember: true
      };
    }
    return confirmExportOptions();
  }

  async function persistUserPref(useUserConfig: boolean) {
    const { error } = await saveExportUserPref(pageCode, {
      autoExport: true,
      useUserConfig
    });
    if (error) {
      notifyError(LABEL_PREF_SAVE_FAIL);
      return false;
    }
    prefCache.value = { autoExport: true, useUserConfig };
    prefLoaded.value = true;
    return true;
  }

  const runExport = async (mode: 'selected' | 'current' | 'all', ids?: number[]) => {
    const options = await resolveExportOptions();
    if (!options) return;

    const useUserConfig = options.useUserConfig;
    const finalMode = !useUserConfig && mode === 'current' ? 'all' : mode;

    if (options.remember && !prefCache.value?.autoExport) {
      await persistUserPref(useUserConfig);
    }

    try {
      notifyInfo(LABEL_EXPORT_OK);
      const { blob, filename } = await exportPageExcel(pageCode, {
        mode: finalMode,
        useUserConfig,
        masterIds: ids,
        masterGridKey: resolveGridKey(masterGridKey)
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

  const resetExportConfig = async () => {
    const { error } = await resetExportUserPref(pageCode);
    if (error) {
      notifyError(LABEL_RESET_FAIL);
      return;
    }
    prefCache.value = null;
    prefLoaded.value = true;
    notifySuccess(LABEL_RESET_OK);
  };

  const openHeaderConfig = async () => {
    if (!resolveAdminFlag(isAdmin)) {
      notifyError(LABEL_NO_PERMISSION);
      return;
    }
    if (!window.$dialog) return;

    const sections = await loadHeaderSections();
    if (sections.length === 0) {
      notifyError(LABEL_HEADER_SAVE_FAIL);
      return;
    }

    const expanded = sections.map(section => section.key);
    window.$dialog?.create({
      title: LABEL_HEADER_CONFIG,
      content: () =>
        h(
          'div',
          { style: { maxHeight: '60vh', overflow: 'auto' } },
          [
            h(
              NCollapse,
              { defaultExpandedNames: expanded },
              {
                default: () =>
                  sections.map(section =>
                    h(
                      NCollapseItem,
                      { title: section.title, name: section.key },
                      {
                        default: () => renderHeaderSection(section)
                      }
                    )
                  )
              }
            )
          ]
        ),
      positiveText: LABEL_EXPORT,
      negativeText: LABEL_CANCEL,
      async onPositiveClick() {
        const ok = await saveHeaderSections(sections);
        if (!ok) return false;
        notifySuccess(LABEL_HEADER_SAVE_OK);
        return undefined;
      }
    });
  };

  async function loadHeaderSections(): Promise<HeaderSection[]> {
    const sections: HeaderSection[] = [];
    const masterKey = resolveGridKey(masterGridKey);
    const masterItems = await fetchHeaderItems(masterKey);
    if (masterItems.length > 0) {
      sections.push({ key: masterKey, title: LABEL_MASTER, items: masterItems });
    }

    const tabs = pageConfig?.value?.tabs || [];
    for (const tab of tabs) {
      if (!tab?.key) continue;
      const items = await fetchHeaderItems(tab.key);
      if (items.length === 0) continue;
      const title = tab.title || tab.key;
      sections.push({ key: tab.key, title, items });
    }
    return sections;
  }

  async function fetchHeaderItems(gridKey: string): Promise<HeaderItem[]> {
    const { data, error } = await fetchExportHeaderConfig(pageCode, gridKey);
    if (error || !data) {
      notifyError(LABEL_HEADER_SAVE_FAIL);
      return [];
    }
    return data.map(item => ({
      field: item.field,
      defaultHeader: item.defaultHeader,
      customHeader: item.customHeader || '',
      visible: item.visible ?? true
    }));
  }

  async function saveHeaderSections(sections: HeaderSection[]) {
    for (const section of sections) {
      const payload = section.items.map(item => ({
        field: item.field,
        header: item.customHeader?.trim() || '',
        visible: item.visible
      }));
      const { error } = await saveExportHeaderConfig(pageCode, section.key, payload);
      if (error) {
        notifyError(LABEL_HEADER_SAVE_FAIL);
        return false;
      }
    }
    return true;
  }

  function renderHeaderSection(section: HeaderSection) {
    return h('div', { style: { display: 'flex', flexDirection: 'column', gap: '8px' } }, [
      h(
        'div',
        {
          style: { display: 'grid', gridTemplateColumns: '160px 1fr 1fr 80px', gap: '8px', fontWeight: '600' }
        },
        [LABEL_FIELD, LABEL_DEFAULT_HEADER, LABEL_CUSTOM_HEADER, LABEL_VISIBLE]
      ),
      h(NDivider, { style: { margin: '4px 0' } }),
      ...section.items.map(item =>
        h(
          'div',
          {
            style: { display: 'grid', gridTemplateColumns: '160px 1fr 1fr 80px', gap: '8px', alignItems: 'center' }
          },
          [
            h('div', item.field),
            h('div', item.defaultHeader),
            h(NInput, {
              value: item.customHeader,
              placeholder: item.defaultHeader,
              'onUpdate:value': (value: string) => {
                item.customHeader = value;
              }
            }),
            h(NCheckbox, {
              checked: item.visible,
              'onUpdate:checked': (value: boolean) => {
                item.visible = value;
              }
            })
          ]
        )
      )
    ]);
  }

  return {
    exportSelected,
    exportCurrent,
    exportAll,
    resetExportConfig,
    openHeaderConfig: canEditHeader ? openHeaderConfig : undefined
  };
}
