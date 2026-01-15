import { getServiceBaseURL } from '@/utils/service';
import { getAuthorization } from '@/service/request/shared';

export type ExportExcelPayload = {
  mode: 'selected' | 'current' | 'all';
  useUserConfig: boolean;
  masterIds?: number[];
  masterGridKey?: string | null;
};

const isHttpProxy = import.meta.env.DEV && import.meta.env.VITE_HTTP_PROXY === 'Y';
const { baseURL } = getServiceBaseURL(import.meta.env, isHttpProxy);

function parseFileName(contentDisposition: string | null, fallback: string) {
  if (!contentDisposition) return fallback;
  const match = /filename\*?=(?:UTF-8''|\"?)([^\";]+)/i.exec(contentDisposition);
  if (!match || !match[1]) return fallback;
  try {
    return decodeURIComponent(match[1]);
  } catch {
    return match[1];
  }
}

export async function exportPageExcel(pageCode: string, payload: ExportExcelPayload) {
  const Authorization = getAuthorization();
  const response = await fetch(`${baseURL}/api/export/page/${pageCode}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(Authorization ? { Authorization } : {})
    },
    body: JSON.stringify(payload)
  });

  if (!response.ok) {
    let message = 'export failed';
    try {
      const data = await response.json();
      if (data?.msg) message = data.msg;
    } catch {
      // ignore
    }
    throw new Error(message);
  }

  const blob = await response.blob();
  const fallback = `${pageCode}.xlsx`;
  const filename = parseFileName(response.headers.get('content-disposition'), fallback);

  return { blob, filename };
}
