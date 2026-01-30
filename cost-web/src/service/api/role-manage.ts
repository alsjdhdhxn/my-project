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
  id?: number;
  pageCode: string;
  pageName: string;
  resourceType?: string;  // DIRECTORY, PAGE
  parentId?: number;
  children?: PageSimpleVO[];
}

export interface ResourcePermissionVO {
  id?: number;
  resourceCode?: string;
  resourceName?: string;
  resourceType?: string;  // DIRECTORY, PAGE
  pageCode?: string;
  icon?: string;
  route?: string;
  parentId?: number;
  sortOrder?: number;
  rolePageId?: number;      // 有值表示已授权
  buttonPolicy?: string;
  columnPolicy?: string;
  isAuthorized?: number;    // 1=已授权, 0=未授权
  children?: ResourcePermissionVO[];
}

// ==================== 角色管理 ====================

export async function fetchRoles() {
  const { data } = await request<RoleVO[]>({ url: '/role-manage/roles' });
  return data || [];
}

export async function createRole(role: RoleVO) {
  const { data, error } = await request<RoleVO>({ url: '/role-manage/role', method: 'post', data: role });
  if (error) throw error;
  return data!;
}

export async function updateRole(id: number, role: RoleVO) {
  const { data, error } = await request<RoleVO>({ url: `/role-manage/role/${id}`, method: 'put', data: role });
  if (error) throw error;
  return data!;
}

export async function deleteRole(id: number) {
  const { error } = await request<void>({ url: `/role-manage/role/${id}`, method: 'delete' });
  if (error) throw error;
}

// ==================== 角色人员管理 ====================

export async function fetchUsersByRole(roleId: number) {
  const { data } = await request<UserRoleVO[]>({ url: `/role-manage/role/${roleId}/users` });
  return data || [];
}

export async function addUserToRole(roleId: number, userRole: Partial<UserRoleVO>) {
  const { data, error } = await request<UserRoleVO>({ url: `/role-manage/role/${roleId}/user`, method: 'post', data: userRole });
  if (error) throw error;
  return data!;
}

export async function removeUserFromRole(id: number) {
  const { error } = await request<void>({ url: `/role-manage/user-role/${id}`, method: 'delete' });
  if (error) throw error;
}

// ==================== 角色页面管理 ====================

export async function fetchPagesByRole(roleId: number) {
  const { data } = await request<RolePageVO[]>({ url: `/role-manage/role/${roleId}/pages` });
  return data || [];
}

export async function addPageToRole(roleId: number, rolePage: Partial<RolePageVO>) {
  const { data, error } = await request<RolePageVO>({ url: `/role-manage/role/${roleId}/page`, method: 'post', data: rolePage });
  if (error) throw error;
  return data!;
}

export async function updateRolePage(id: number, rolePage: Partial<RolePageVO>) {
  const { data, error } = await request<RolePageVO>({ url: `/role-manage/role-page/${id}`, method: 'put', data: rolePage });
  if (error) throw error;
  return data!;
}

export async function removePageFromRole(id: number) {
  const { error } = await request<void>({ url: `/role-manage/role-page/${id}`, method: 'delete' });
  if (error) throw error;
}

// ==================== 辅助查询 ====================

export async function fetchAllUsers() {
  const { data } = await request<UserSimpleVO[]>({ url: '/role-manage/users' });
  return data || [];
}

export async function fetchAllPages() {
  const { data } = await request<PageSimpleVO[]>({ url: '/role-manage/pages' });
  return data || [];
}

export async function fetchResourcePermissionTree(roleId: number) {
  const { data } = await request<ResourcePermissionVO[]>({ url: `/role-manage/role/${roleId}/resource-tree` });
  return data || [];
}

export interface PageButtonVO {
  buttonKey: string;
  buttonLabel: string;
}

export async function fetchPageButtons(pageCode: string) {
  const { data } = await request<PageButtonVO[]>({ url: `/role-manage/page/${pageCode}/buttons` });
  return data || [];
}

// ==================== 高级查询 ====================

export interface SearchCondition {
  field: string;
  operator: string;
  value: string;
}

export async function searchRoles(conditions: SearchCondition[]) {
  const { data } = await request<RoleVO[]>({ 
    url: '/role-manage/roles/search', 
    method: 'post',
    data: conditions
  });
  return data || [];
}
