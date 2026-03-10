import { request } from '../request';

// ==================== 目录管理 ====================

export async function fetchAllResources() {
  const { data } = await request<any[]>({ url: '/meta-config/resources' });
  return data || [];
}

export async function saveResource(data: Record<string, any>) {
  const { data: res, error } = await request<any>({ url: '/meta-config/resource', method: 'POST', data });
  if (error) throw error;
  return res;
}

export async function deleteResource(id: number) {
  const { error } = await request<any>({ url: `/meta-config/resource/${id}`, method: 'DELETE' });
  if (error) throw error;
}

// ==================== 表管理 ====================

export async function fetchAllTableMeta() {
  const { data } = await request<any[]>({ url: '/meta-config/tables' });
  return data || [];
}

/** 根据 pageCode 查询关联的表元数据 */
export async function fetchTablesByPageCode(pageCode: string) {
  const { data } = await request<any[]>({ url: '/meta-config/tables-by-page', params: { pageCode } });
  return data || [];
}

export async function saveTableMeta(data: Record<string, any>) {
  const { data: res, error } = await request<any>({ url: '/meta-config/table', method: 'POST', data });
  if (error) throw error;
  return res;
}

export async function deleteTableMeta(id: number) {
  const { error } = await request<any>({ url: `/meta-config/table/${id}`, method: 'DELETE' });
  if (error) throw error;
}

export async function fetchColumnsByTableId(tableId: number) {
  const { data } = await request<any[]>({ url: `/meta-config/table/${tableId}/columns` });
  return data || [];
}

export async function saveColumnMeta(data: Record<string, any>) {
  const { data: res, error } = await request<any>({ url: '/meta-config/column', method: 'POST', data });
  if (error) throw error;
  return res;
}

export async function deleteColumnMeta(id: number) {
  const { error } = await request<any>({ url: `/meta-config/column/${id}`, method: 'DELETE' });
  if (error) throw error;
}

/** 查询视图/表的物理列结构 */
export async function fetchViewColumns(viewName: string, owner = 'CMX') {
  const { data } = await request<any[]>({ url: '/meta-config/view-columns', params: { viewName, owner } });
  return data || [];
}

/** 根据 pageCode 查询关联的 lookupCode 列表 */
export async function fetchLookupCodesByPageCode(pageCode: string) {
  const { data } = await request<string[]>({ url: '/meta-config/lookup-codes-by-page', params: { pageCode } });
  return data || [];
}

// ==================== 页面管理 ====================

export async function fetchAllPageComponents() {
  const { data } = await request<any[]>({ url: '/meta-config/components' });
  return data || [];
}

export async function savePageComponent(data: Record<string, any>) {
  const { data: res, error } = await request<any>({ url: '/meta-config/component', method: 'POST', data });
  if (error) throw error;
  return res;
}

export async function deletePageComponent(id: number) {
  const { error } = await request<any>({ url: `/meta-config/component/${id}`, method: 'DELETE' });
  if (error) throw error;
}

export async function fetchRulesByComponent(pageCode: string, componentKey: string) {
  const { data } = await request<any[]>({ url: '/meta-config/rules', params: { pageCode, componentKey } });
  return data || [];
}

export async function savePageRule(data: Record<string, any>) {
  const { data: res, error } = await request<any>({ url: '/meta-config/rule', method: 'POST', data });
  if (error) throw error;
  return res;
}

export async function deletePageRule(id: number) {
  const { error } = await request<any>({ url: `/meta-config/rule/${id}`, method: 'DELETE' });
  if (error) throw error;
}

// ==================== Lookup管理 ====================

export async function fetchAllLookupConfigs() {
  const { data } = await request<any[]>({ url: '/meta-config/lookups' });
  return data || [];
}

export async function saveLookupConfig(data: Record<string, any>) {
  const { data: res, error } = await request<any>({ url: '/meta-config/lookup', method: 'POST', data });
  if (error) throw error;
  return res;
}

export async function deleteLookupConfig(id: number) {
  const { error } = await request<any>({ url: `/meta-config/lookup/${id}`, method: 'DELETE' });
  if (error) throw error;
}

// ==================== 导出配置管理 ====================

export async function fetchAllExportConfigs() {
  const { data } = await request<any[]>({ url: '/meta-config/export-configs' });
  return data || [];
}

export async function saveExportConfig(data: Record<string, any>) {
  const { data: res, error } = await request<any>({ url: '/meta-config/export-config', method: 'POST', data });
  if (error) throw error;
  return res;
}

export async function deleteExportConfig(id: number) {
  const { error } = await request<any>({ url: `/meta-config/export-config/${id}`, method: 'DELETE' });
  if (error) throw error;
}

export async function fetchExportConfigDetails(configId: number) {
  const { data } = await request<any[]>({ url: `/meta-config/export-config/${configId}/details` });
  return data || [];
}

export async function saveExportConfigDetail(data: Record<string, any>) {
  const { data: res, error } = await request<any>({
    url: '/meta-config/export-config-detail',
    method: 'POST',
    data
  });
  if (error) throw error;
  return res;
}

export async function deleteExportConfigDetail(id: number) {
  const { error } = await request<any>({ url: `/meta-config/export-config-detail/${id}`, method: 'DELETE' });
  if (error) throw error;
}
