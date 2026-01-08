import { request } from '../request';

/** 查询动态数据列表 */
export function fetchDynamicData(tableCode: string, params?: Record<string, any>) {
  return request<Api.Common.PageResult<any>>({
    url: `/api/data/${tableCode}`,
    params
  });
}

/** 高级查询（支持 pageCode 数据权限） */
export function searchDynamicData(tableCode: string, params: {
  page?: number;
  pageSize?: number;
  sortField?: string;
  sortOrder?: string;
  pageCode?: string;
  conditions?: Array<{ field: string; operator: string; value: any; value2?: any }>;
}) {
  return request<Api.Common.PageResult<any>>({
    url: `/api/data/${tableCode}/search`,
    method: 'POST',
    data: params
  });
}

/** 查询单条数据 */
export function fetchDynamicDataById(tableCode: string, id: number | string) {
  return request<any>({
    url: `/api/data/${tableCode}/${id}`
  });
}

/** 新增数据 */
export function createDynamicData(tableCode: string, data: Record<string, any>) {
  return request<any>({
    url: `/api/data/${tableCode}`,
    method: 'POST',
    data
  });
}

/** 更新数据 */
export function updateDynamicData(tableCode: string, id: number | string, data: Record<string, any>) {
  return request<any>({
    url: `/api/data/${tableCode}/${id}`,
    method: 'PUT',
    data
  });
}

/** 删除数据 */
export function deleteDynamicData(tableCode: string, id: number | string) {
  return request<any>({
    url: `/api/data/${tableCode}/${id}`,
    method: 'DELETE'
  });
}

/** 通用保存（支持单表/主从表/主从多Tab，含变更追踪和乐观锁） */
export function saveDynamicData(param: {
  master: any;
  details?: Record<string, any[]>;
}) {
  return request<number>({
    url: '/api/data/save',
    method: 'POST',
    data: param
  });
}

/** 执行执行器 */
export function executeAction(tableCode: string, params: {
  group?: string;
  actionCodes?: string[];
  data?: Record<string, any>;
  validateGroup?: string;
}) {
  return request<any>({
    url: `/api/data/${tableCode}/execute`,
    method: 'POST',
    data: params
  });
}
