import { request } from '../request';

export type ExportUserPref = {
  autoExport?: boolean;
  useUserConfig?: boolean;
};

export type ExportHeaderConfigDTO = {
  field: string;
  defaultHeader: string;
  customHeader?: string | null;
  visible?: boolean | null;
};

export type ExportHeaderConfigItem = {
  field: string;
  header?: string | null;
  visible?: boolean | null;
};

export function fetchExportUserPref(pageCode: string) {
  return request<ExportUserPref | null>({
    url: `/api/export-config/prefs/${pageCode}`
  });
}

export function saveExportUserPref(pageCode: string, payload: ExportUserPref) {
  return request<void>({
    url: `/api/export-config/prefs/${pageCode}`,
    method: 'POST',
    data: payload
  });
}

export function resetExportUserPref(pageCode: string) {
  return request<void>({
    url: `/api/export-config/prefs/${pageCode}`,
    method: 'DELETE'
  });
}

export function fetchExportHeaderConfig(pageCode: string, gridKey: string) {
  return request<ExportHeaderConfigDTO[]>({
    url: `/api/export-config/headers/${pageCode}/${gridKey}`
  });
}

export function saveExportHeaderConfig(pageCode: string, gridKey: string, headers: ExportHeaderConfigItem[]) {
  return request<void>({
    url: `/api/export-config/headers/${pageCode}/${gridKey}`,
    method: 'POST',
    data: { headers }
  });
}
