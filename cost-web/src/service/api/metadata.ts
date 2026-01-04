import { request } from '../request';

/** 获取表元数据 */
export function fetchTableMetadata(tableCode: string) {
  return request<Api.Metadata.TableMetadata>({
    url: `/api/metadata/table/${tableCode}`
  });
}

/** 获取页面组件树 */
export function fetchPageComponents(pageCode: string) {
  return request<Api.Metadata.PageComponent[]>({
    url: `/api/metadata/page/${pageCode}`
  });
}

/** 获取字典项 */
export function fetchDictItems(dictType: string) {
  return request<Api.Metadata.DictItem[]>({
    url: `/api/metadata/dict/${dictType}`
  });
}

/** 获取弹窗选择器配置 */
export function fetchLookupConfig(lookupCode: string) {
  return request<Api.Metadata.LookupConfig>({
    url: `/api/metadata/lookup/${lookupCode}`
  });
}
