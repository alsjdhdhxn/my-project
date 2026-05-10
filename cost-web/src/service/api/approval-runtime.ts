import { request } from '../request';

export type ApprovalRuntimePayload = {
  pageCode: string;
  pageName?: string;
  tableCode: string;
  billId: number | string;
  billNo?: string;
  billTitle?: string;
  conditionJson?: string;
  detailId?: number | string;
  comment?: string;
};

export function applyApproval(data: ApprovalRuntimePayload) {
  return request<any>({
    url: '/approval/runtime/apply',
    method: 'POST',
    data
  });
}

export function approveApproval(data: ApprovalRuntimePayload) {
  return request<any>({
    url: '/approval/runtime/approve',
    method: 'POST',
    data
  });
}

export function rejectApproval(data: ApprovalRuntimePayload) {
  return request<any>({
    url: '/approval/runtime/reject',
    method: 'POST',
    data
  });
}

export function fetchApprovalProgress(params: { pageCode: string; tableCode: string; billId: number | string }) {
  return request<any>({
    url: '/approval/runtime/progress',
    params
  });
}
