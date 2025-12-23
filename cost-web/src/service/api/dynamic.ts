import { request } from '../request';

/** 查询动态数据列表 */
export function fetchDynamicData(tableCode: string, params?: Record<string, any>) {
  return request<Api.Common.PageResult<any>>({
    url: `/api/data/${tableCode}`,
    params
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
