import { request } from '../request';

// ==================== 类型定义 ====================

export interface RoleVO {
  id?: number;
  roleCode: string;
  roleName: string;
  description?: string;
  createTime?: string;
  updateTime?: string;
  createBy?: string;
  updateBy?: string;
}

export interface UserRoleVO {
  id?: number;
  userId: number;
  username?: string;
  realName?: string;
  roleId?: number;
  createTime?: string;
  createBy?: string;
}

export interface RolePageVO {
  id?: number;
  roleId?: number;
  pageCode: string;
  pageName?: string;
  buttonPolicy?: string;
  columnPolicy?: string;
  createTime?: string;
  updateTime?: string;
  createBy?: string;
  updateBy?: string;
}

export interface UserSimpleVO {
  id: number;
  username: string;
  realName?: string;
}

export interface PageSimpleVO {
  pageCode: string;
  pageName: string;
}

// ==================== 角色管理 ====================

export function fetchRoles() {
  return request<RoleVO[]>({ url: '/role-manage/roles' });
}

export function createRole(role: RoleVO) {
  return request<RoleVO>({ url: '/role-manage/role', method: 'post', data: role });
}

export function updateRole(id: number, role: RoleVO) {
  return request<RoleVO>({ url: `/role-manage/role/${id}`, method: 'put', data: role });
}

export function deleteRole(id: number) {
  return request<void>({ url: `/role-manage/role/${id}`, method: 'delete' });
}

// ==================== 角色人员管理 ====================

export function fetchUsersByRole(roleId: number) {
  return request<UserRoleVO[]>({ url: `/role-manage/role/${roleId}/users` });
}

export function addUserToRole(roleId: number, userRole: UserRoleVO) {
  return request<UserRoleVO>({ url: `/role-manage/role/${roleId}/user`, method: 'post', data: userRole });
}

export function removeUserFromRole(id: number) {
  return request<void>({ url: `/role-manage/user-role/${id}`, method: 'delete' });
}

// ==================== 角色页面管理 ====================

export function fetchPagesByRole(roleId: number) {
  return request<RolePageVO[]>({ url: `/role-manage/role/${roleId}/pages` });
}

export function addPageToRole(roleId: number, rolePage: RolePageVO) {
  return request<RolePageVO>({ url: `/role-manage/role/${roleId}/page`, method: 'post', data: rolePage });
}

export function updateRolePage(id: number, rolePage: RolePageVO) {
  return request<RolePageVO>({ url: `/role-manage/role-page/${id}`, method: 'put', data: rolePage });
}

export function removePageFromRole(id: number) {
  return request<void>({ url: `/role-manage/role-page/${id}`, method: 'delete' });
}

// ==================== 辅助查询 ====================

export function fetchAllUsers() {
  return request<UserSimpleVO[]>({ url: '/role-manage/users' });
}

export function fetchAllPages() {
  return request<PageSimpleVO[]>({ url: '/role-manage/pages' });
}
