<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { NButton, NTabs, NTabPane, NEmpty, NTag, NPopconfirm, NModal, NForm, NFormItem, NInput, NSelect, NInputGroup, useMessage, NScrollbar, NCheckbox, NSpace } from 'naive-ui';
import { Icon } from '@iconify/vue';
import type { RoleVO, UserRoleVO, RolePageVO, UserSimpleVO, PageSimpleVO } from '@/service/api/role-manage';
import {
  fetchRoles, createRole, updateRole, deleteRole,
  fetchUsersByRole, addUserToRole, removeUserFromRole,
  fetchPagesByRole, addPageToRole, updateRolePage, removePageFromRole,
  fetchAllUsers, fetchAllPages, searchRoles
} from '@/service/api/role-manage';

const message = useMessage();

// ==================== 查询面板 ====================
const showSearchPanel = ref(false);

interface SearchCondition {
  field: string;
  fieldLabel: string;
  operator: string;
  value: string;
  enabled: boolean;
}

const searchConditions = ref<SearchCondition[]>([
  { field: 'roleCode', fieldLabel: '角色编码', operator: 'like', value: '', enabled: false },
  { field: 'roleName', fieldLabel: '角色名称', operator: 'like', value: '', enabled: false },
  { field: 'username', fieldLabel: '包含用户', operator: 'like', value: '', enabled: false },
  { field: 'pageCode', fieldLabel: '包含页面', operator: 'like', value: '', enabled: false },
]);

const operatorOptions = [
  { label: '等于', value: 'eq' },
  { label: '不等于', value: 'ne' },
  { label: '包含', value: 'like' },
  { label: '开头是', value: 'likeLeft' },
  { label: '结尾是', value: 'likeRight' },
  { label: '大于', value: 'gt' },
  { label: '大于等于', value: 'ge' },
  { label: '小于', value: 'lt' },
  { label: '小于等于', value: 'le' },
  { label: 'IN', value: 'in' },
];

const activeFilters = ref<string[]>([]);
const isSearching = ref(false);

function openSearchPanel() {
  showSearchPanel.value = true;
}

async function executeSearch() {
  const enabledConditions = searchConditions.value.filter(c => c.enabled && c.value);
  
  if (enabledConditions.length === 0) {
    // 无条件，加载全部
    await loadRoles();
    activeFilters.value = [];
    showSearchPanel.value = false;
    return;
  }

  isSearching.value = true;
  try {
    // 构建查询参数
    const conditions = enabledConditions.map(c => ({
      field: c.field,
      operator: c.operator,
      value: c.value
    }));

    const data = await searchRoles(conditions);
    roles.value = data || [];
    
    // 更新筛选标签
    activeFilters.value = enabledConditions.map(c => {
      const op = operatorOptions.find(o => o.value === c.operator);
      return `${c.fieldLabel} ${op?.label || c.operator} "${c.value}"`;
    });

    showSearchPanel.value = false;
    
    if (roles.value.length === 0) {
      message.warning('未找到匹配的角色');
      selectedRoleId.value = null;
    } else {
      message.success(`找到 ${roles.value.length} 个角色`);
      selectedRoleId.value = roles.value[0].id ?? null;
    }
  } catch (e) {
    console.error('查询失败', e);
    message.error('查询失败');
  } finally {
    isSearching.value = false;
  }
}

async function clearSearch() {
  searchConditions.value.forEach(c => {
    c.enabled = false;
    c.value = '';
  });
  activeFilters.value = [];
  await loadRoles();
}

// ==================== 角色列表 ====================
const roles = ref<RoleVO[]>([]);
const selectedRoleId = ref<number | null>(null);
const loadingRoles = ref(false);

const selectedRole = computed(() => roles.value.find(r => r.id === selectedRoleId.value));

const filteredRoles = computed(() => roles.value);

async function loadRoles() {
  loadingRoles.value = true;
  try {
    const data = await fetchRoles();
    roles.value = data || [];
    if (roles.value.length > 0 && !selectedRoleId.value) {
      selectedRoleId.value = roles.value[0].id ?? null;
    }
  } catch (e) {
    console.error('加载角色失败', e);
    roles.value = [];
  } finally {
    loadingRoles.value = false;
  }
}

function selectRole(id: number) {
  selectedRoleId.value = id;
}

// ==================== 角色编辑弹窗 ====================
const showRoleModal = ref(false);
const roleForm = ref<RoleVO>({ roleCode: '', roleName: '', description: '' });
const isEditRole = ref(false);
const savingRole = ref(false);

function openAddRole() {
  isEditRole.value = false;
  roleForm.value = { roleCode: '', roleName: '', description: '' };
  showRoleModal.value = true;
}

function openEditRole(role: RoleVO) {
  isEditRole.value = true;
  roleForm.value = { ...role };
  showRoleModal.value = true;
}

async function saveRole() {
  if (!roleForm.value.roleCode || !roleForm.value.roleName) {
    message.warning('请填写角色编码和名称');
    return;
  }
  savingRole.value = true;
  try {
    if (isEditRole.value && roleForm.value.id) {
      await updateRole(roleForm.value.id, roleForm.value);
      message.success('更新成功');
    } else {
      const newRole = await createRole(roleForm.value);
      selectedRoleId.value = newRole.id!;
      message.success('创建成功');
    }
    showRoleModal.value = false;
    await loadRoles();
  } finally {
    savingRole.value = false;
  }
}

async function handleDeleteRole(id: number) {
  await deleteRole(id);
  message.success('删除成功');
  if (selectedRoleId.value === id) {
    selectedRoleId.value = null;
  }
  await loadRoles();
}

// ==================== 角色人员 ====================
const userRoles = ref<UserRoleVO[]>([]);
const loadingUsers = ref(false);
const allUsers = ref<UserSimpleVO[]>([]);

async function loadUserRoles() {
  if (!selectedRoleId.value) return;
  loadingUsers.value = true;
  try {
    const data = await fetchUsersByRole(selectedRoleId.value);
    userRoles.value = data || [];
  } catch (e) {
    console.error('加载角色人员失败', e);
    userRoles.value = [];
  } finally {
    loadingUsers.value = false;
  }
}

// 添加用户弹窗
const showAddUserModal = ref(false);
const selectedUserId = ref<number | null>(null);
const addingUser = ref(false);

async function openAddUser() {
  if (allUsers.value.length === 0) {
    allUsers.value = await fetchAllUsers();
  }
  selectedUserId.value = null;
  showAddUserModal.value = true;
}

const availableUsers = computed(() => {
  const existingIds = new Set(userRoles.value.map(ur => ur.userId));
  return allUsers.value.filter(u => !existingIds.has(u.id));
});

async function handleAddUser() {
  if (!selectedUserId.value || !selectedRoleId.value) return;
  addingUser.value = true;
  try {
    await addUserToRole(selectedRoleId.value, { userId: selectedUserId.value });
    message.success('添加成功');
    showAddUserModal.value = false;
    await loadUserRoles();
  } finally {
    addingUser.value = false;
  }
}

async function handleRemoveUser(id: number) {
  await removeUserFromRole(id);
  message.success('移除成功');
  await loadUserRoles();
}

// ==================== 角色页面 ====================
const rolePages = ref<RolePageVO[]>([]);
const loadingPages = ref(false);
const allPages = ref<PageSimpleVO[]>([]);

async function loadRolePages() {
  if (!selectedRoleId.value) return;
  loadingPages.value = true;
  try {
    const data = await fetchPagesByRole(selectedRoleId.value);
    rolePages.value = data || [];
  } catch (e) {
    console.error('加载角色页面失败', e);
    rolePages.value = [];
  } finally {
    loadingPages.value = false;
  }
}

// 添加页面弹窗
const showAddPageModal = ref(false);
const pageForm = ref<RolePageVO>({ pageCode: '', buttonPolicy: '["*"]', columnPolicy: '' });
const addingPage = ref(false);

async function openAddPage() {
  if (allPages.value.length === 0) {
    allPages.value = await fetchAllPages();
  }
  pageForm.value = { pageCode: '', buttonPolicy: '["*"]', columnPolicy: '' };
  showAddPageModal.value = true;
}

const availablePages = computed(() => {
  const existingCodes = new Set(rolePages.value.map(rp => rp.pageCode));
  return allPages.value.filter(p => !existingCodes.has(p.pageCode));
});

async function handleAddPage() {
  if (!pageForm.value.pageCode || !selectedRoleId.value) return;
  addingPage.value = true;
  try {
    await addPageToRole(selectedRoleId.value, pageForm.value);
    message.success('添加成功');
    showAddPageModal.value = false;
    await loadRolePages();
  } finally {
    addingPage.value = false;
  }
}

// 编辑页面权限弹窗
const showEditPageModal = ref(false);
const editPageForm = ref<RolePageVO>({ pageCode: '' });
const editingPage = ref(false);

function openEditPage(page: RolePageVO) {
  editPageForm.value = { ...page };
  showEditPageModal.value = true;
}

async function handleUpdatePage() {
  if (!editPageForm.value.id) return;
  editingPage.value = true;
  try {
    await updateRolePage(editPageForm.value.id, editPageForm.value);
    message.success('更新成功');
    showEditPageModal.value = false;
    await loadRolePages();
  } finally {
    editingPage.value = false;
  }
}

async function handleRemovePage(id: number) {
  await removePageFromRole(id);
  message.success('移除成功');
  await loadRolePages();
}

// ==================== 监听和初始化 ====================
watch(selectedRoleId, () => {
  loadUserRoles();
  loadRolePages();
});

loadRoles();

function isAllButtonPolicy(policy: string | undefined): boolean {
  return policy === '["*"]';
}
</script>

<template>
  <div class="permission-page">
    <!-- 左侧：角色列表 -->
    <div class="role-panel">
      <div class="panel-header">
        <span class="panel-title">角色管理</span>
        <NSpace :size="4">
          <NButton size="small" @click="openSearchPanel">
            <template #icon><Icon icon="mdi:magnify" /></template>
            查询
          </NButton>
          <NButton type="primary" size="small" @click="openAddRole">
            <template #icon><Icon icon="mdi:plus" /></template>
            新增
          </NButton>
        </NSpace>
      </div>
      
      <!-- 当前筛选条件 -->
      <div v-if="activeFilters.length > 0" class="filter-tags">
        <NTag v-for="(f, i) in activeFilters" :key="i" size="small" closable @close="clearSearch">
          {{ f }}
        </NTag>
        <NButton text size="tiny" type="error" @click="clearSearch">清除全部</NButton>
      </div>

      <NScrollbar class="role-list">
        <div
          v-for="role in filteredRoles"
          :key="role.id ?? 0"
          class="role-card"
          :class="{ active: selectedRoleId === role.id }"
          @click="role.id && selectRole(role.id)"
        >
          <div class="role-info">
            <div class="role-name">{{ role.roleName }}</div>
            <div class="role-code">{{ role.roleCode }}</div>
          </div>
          <div class="role-actions">
            <NButton quaternary circle size="tiny" @click.stop="openEditRole(role)">
              <template #icon><Icon icon="mdi:pencil-outline" /></template>
            </NButton>
            <NPopconfirm v-if="role.id" @positive-click="handleDeleteRole(role.id)">
              <template #trigger>
                <NButton quaternary circle size="tiny" @click.stop>
                  <template #icon><Icon icon="mdi:delete-outline" class="text-red-500" /></template>
                </NButton>
              </template>
              确定删除「{{ role.roleName }}」？
            </NPopconfirm>
          </div>
        </div>
        <NEmpty v-if="filteredRoles.length === 0" description="暂无角色" class="mt-8" />
      </NScrollbar>
    </div>

    <!-- 右侧：详情区域 -->
    <div class="detail-panel">
      <template v-if="selectedRole">
        <div class="detail-header">
          <div class="selected-role-info">
            <Icon icon="mdi:shield-account-outline" class="text-2xl text-primary" />
            <div>
              <div class="text-lg font-medium">{{ selectedRole.roleName }}</div>
              <div class="text-xs text-gray-400">{{ selectedRole.roleCode }}</div>
            </div>
          </div>
        </div>

        <NTabs type="line" animated class="detail-tabs">
          <!-- Tab1: 角色人员 -->
          <NTabPane name="users">
            <template #tab>
              <div class="tab-label">
                <Icon icon="mdi:account-group-outline" />
                <span>成员管理</span>
                <NTag size="small" round :bordered="false">{{ userRoles.length }}</NTag>
              </div>
            </template>

            <div class="tab-toolbar">
              <NButton type="primary" size="small" @click="openAddUser">
                <template #icon><Icon icon="mdi:account-plus-outline" /></template>
                添加成员
              </NButton>
            </div>

            <div class="data-list">
              <div v-for="ur in userRoles" :key="ur.id ?? 0" class="data-item">
                <div class="item-avatar">
                  <Icon icon="mdi:account" class="text-lg" />
                </div>
                <div class="item-info">
                  <div class="item-title">{{ ur.realName || ur.username }}</div>
                  <div class="item-desc">{{ ur.username }}</div>
                </div>
                <div class="item-actions">
                  <NPopconfirm v-if="ur.id" @positive-click="handleRemoveUser(ur.id)">
                    <template #trigger>
                      <NButton quaternary circle size="small">
                        <template #icon><Icon icon="mdi:close" class="text-gray-400 hover:text-red-500" /></template>
                      </NButton>
                    </template>
                    确定移除该成员？
                  </NPopconfirm>
                </div>
              </div>
              <NEmpty v-if="userRoles.length === 0" description="暂无成员" class="py-12" />
            </div>
          </NTabPane>

          <!-- Tab2: 角色页面 -->
          <NTabPane name="pages">
            <template #tab>
              <div class="tab-label">
                <Icon icon="mdi:file-document-outline" />
                <span>页面权限</span>
                <NTag size="small" round :bordered="false">{{ rolePages.length }}</NTag>
              </div>
            </template>

            <div class="tab-toolbar">
              <NButton type="primary" size="small" @click="openAddPage">
                <template #icon><Icon icon="mdi:file-plus-outline" /></template>
                添加页面
              </NButton>
            </div>

            <div class="data-list">
              <div v-for="rp in rolePages" :key="rp.id ?? 0" class="data-item">
                <div class="item-avatar page">
                  <Icon icon="mdi:file-document-outline" class="text-lg" />
                </div>
                <div class="item-info">
                  <div class="item-title">{{ rp.pageName || rp.pageCode }}</div>
                  <div class="item-desc">{{ rp.pageCode }}</div>
                </div>
                <div class="item-tags">
                  <NTag v-if="isAllButtonPolicy(rp.buttonPolicy)" type="success" size="small" :bordered="false">全部按钮</NTag>
                  <NTag v-else-if="rp.buttonPolicy" type="warning" size="small" :bordered="false">部分按钮</NTag>
                </div>
                <div class="item-actions">
                  <NButton quaternary circle size="small" @click="openEditPage(rp)">
                    <template #icon><Icon icon="mdi:pencil-outline" class="text-gray-400" /></template>
                  </NButton>
                  <NPopconfirm v-if="rp.id" @positive-click="handleRemovePage(rp.id)">
                    <template #trigger>
                      <NButton quaternary circle size="small">
                        <template #icon><Icon icon="mdi:close" class="text-gray-400 hover:text-red-500" /></template>
                      </NButton>
                    </template>
                    确定移除该页面权限？
                  </NPopconfirm>
                </div>
              </div>
              <NEmpty v-if="rolePages.length === 0" description="暂无页面权限" class="py-12" />
            </div>
          </NTabPane>
        </NTabs>
      </template>

      <div v-else class="empty-state">
        <Icon icon="mdi:shield-off-outline" class="text-6xl text-gray-300" />
        <div class="text-gray-400 mt-4">请选择一个角色</div>
      </div>
    </div>

    <!-- 角色编辑弹窗 -->
    <NModal v-model:show="showRoleModal" preset="card" :title="isEditRole ? '编辑角色' : '新增角色'" class="w-420px">
      <NForm label-placement="left" label-width="70" size="small">
        <NFormItem label="角色编码" required>
          <NInput v-model:value="roleForm.roleCode" placeholder="请输入" :disabled="isEditRole" />
        </NFormItem>
        <NFormItem label="角色名称" required>
          <NInput v-model:value="roleForm.roleName" placeholder="请输入" />
        </NFormItem>
        <NFormItem label="描述">
          <NInput v-model:value="roleForm.description" type="textarea" placeholder="请输入" :rows="3" />
        </NFormItem>
      </NForm>
      <template #footer>
        <div class="flex justify-end gap-2">
          <NButton size="small" @click="showRoleModal = false">取消</NButton>
          <NButton type="primary" size="small" :loading="savingRole" @click="saveRole">确定</NButton>
        </div>
      </template>
    </NModal>

    <!-- 添加用户弹窗 -->
    <NModal v-model:show="showAddUserModal" preset="card" title="添加成员" class="w-380px">
      <NSelect
        v-model:value="selectedUserId"
        :options="availableUsers.map(u => ({ label: `${u.realName || u.username} (${u.username})`, value: u.id }))"
        placeholder="请选择用户"
        filterable
        size="small"
      />
      <template #footer>
        <div class="flex justify-end gap-2">
          <NButton size="small" @click="showAddUserModal = false">取消</NButton>
          <NButton type="primary" size="small" :loading="addingUser" :disabled="!selectedUserId" @click="handleAddUser">确定</NButton>
        </div>
      </template>
    </NModal>

    <!-- 添加页面弹窗 -->
    <NModal v-model:show="showAddPageModal" preset="card" title="添加页面权限" class="w-420px">
      <NForm label-placement="left" label-width="70" size="small">
        <NFormItem label="页面" required>
          <NSelect
            v-model:value="pageForm.pageCode"
            :options="availablePages.map(p => ({ label: `${p.pageName} (${p.pageCode})`, value: p.pageCode }))"
            placeholder="请选择"
            filterable
          />
        </NFormItem>
        <NFormItem label="按钮权限">
          <NInput v-model:value="pageForm.buttonPolicy" placeholder='["*"] 表示全部' />
        </NFormItem>
        <NFormItem label="列权限">
          <NInput v-model:value="pageForm.columnPolicy" type="textarea" placeholder="JSON格式，留空表示全部" :rows="2" />
        </NFormItem>
      </NForm>
      <template #footer>
        <div class="flex justify-end gap-2">
          <NButton size="small" @click="showAddPageModal = false">取消</NButton>
          <NButton type="primary" size="small" :loading="addingPage" :disabled="!pageForm.pageCode" @click="handleAddPage">确定</NButton>
        </div>
      </template>
    </NModal>

    <!-- 编辑页面权限弹窗 -->
    <NModal v-model:show="showEditPageModal" preset="card" title="编辑页面权限" class="w-420px">
      <NForm label-placement="left" label-width="70" size="small">
        <NFormItem label="页面">
          <NInput :value="editPageForm.pageName || editPageForm.pageCode" disabled />
        </NFormItem>
        <NFormItem label="按钮权限">
          <NInput v-model:value="editPageForm.buttonPolicy" placeholder='["*"] 表示全部' />
        </NFormItem>
        <NFormItem label="列权限">
          <NInput v-model:value="editPageForm.columnPolicy" type="textarea" placeholder="JSON格式，留空表示全部" :rows="2" />
        </NFormItem>
      </NForm>
      <template #footer>
        <div class="flex justify-end gap-2">
          <NButton size="small" @click="showEditPageModal = false">取消</NButton>
          <NButton type="primary" size="small" :loading="editingPage" @click="handleUpdatePage">确定</NButton>
        </div>
      </template>
    </NModal>

    <!-- 查询面板 -->
    <NModal v-model:show="showSearchPanel" preset="card" title="查询条件" class="w-560px">
      <div class="search-condition-list">
        <div v-for="(cond, idx) in searchConditions" :key="idx" class="search-condition-row">
          <NCheckbox v-model:checked="cond.enabled" class="w-100px">
            {{ cond.fieldLabel }}
          </NCheckbox>
          <NSelect
            v-model:value="cond.operator"
            :options="operatorOptions"
            size="small"
            class="w-100px"
          />
          <NInput
            v-model:value="cond.value"
            size="small"
            class="flex-1"
            :placeholder="cond.operator === 'in' ? '多个值用逗号分隔' : '请输入'"
            @input="() => { if (cond.value) cond.enabled = true }"
            @keyup.enter="executeSearch"
          />
        </div>
      </div>
      <template #footer>
        <div class="flex justify-between">
          <NButton size="small" @click="clearSearch">重置</NButton>
          <NSpace :size="8">
            <NButton size="small" @click="showSearchPanel = false">取消</NButton>
            <NButton type="primary" size="small" :loading="isSearching" @click="executeSearch">查询</NButton>
          </NSpace>
        </div>
      </template>
    </NModal>
  </div>
</template>

<style scoped>
.permission-page {
  display: flex;
  height: 100%;
  gap: 16px;
  padding: 16px;
  background: #f5f7fa;
}

/* 左侧角色面板 */
.role-panel {
  width: 280px;
  flex-shrink: 0;
  background: #fff;
  border-radius: 8px;
  display: flex;
  flex-direction: column;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
}

.panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px;
  border-bottom: 1px solid #f0f0f0;
}

.panel-title {
  font-size: 15px;
  font-weight: 600;
  color: #1f2937;
}

.search-box {
  padding: 0 16px 12px;
}

.filter-tags {
  padding: 8px 16px;
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  align-items: center;
  background: #fef9c3;
  border-bottom: 1px solid #fde047;
}

.dark .filter-tags {
  background: #422006;
  border-color: #854d0e;
}

.search-condition-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.search-condition-row {
  display: flex;
  align-items: center;
  gap: 8px;
}

.role-list {
  flex: 1;
  padding: 0 12px 12px;
}

.role-card {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px;
  margin-bottom: 8px;
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.2s;
  border: 1px solid transparent;
}

.role-card:hover {
  background: #f9fafb;
}

.role-card.active {
  background: #eff6ff;
  border-color: #3b82f6;
}

.role-info {
  flex: 1;
  min-width: 0;
}

.role-name {
  font-size: 14px;
  font-weight: 500;
  color: #1f2937;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.role-code {
  font-size: 12px;
  color: #9ca3af;
  margin-top: 2px;
}

.role-actions {
  display: flex;
  gap: 2px;
  opacity: 0;
  transition: opacity 0.2s;
}

.role-card:hover .role-actions {
  opacity: 1;
}

/* 右侧详情面板 */
.detail-panel {
  flex: 1;
  background: #fff;
  border-radius: 8px;
  display: flex;
  flex-direction: column;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
  overflow: hidden;
}

.detail-header {
  padding: 16px 20px;
  border-bottom: 1px solid #f0f0f0;
}

.selected-role-info {
  display: flex;
  align-items: center;
  gap: 12px;
}

.detail-tabs {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.detail-tabs :deep(.n-tabs-nav) {
  padding: 0 20px;
}

.detail-tabs :deep(.n-tab-pane) {
  flex: 1;
  display: flex;
  flex-direction: column;
  padding: 0 !important;
}

.tab-label {
  display: flex;
  align-items: center;
  gap: 6px;
}

.tab-toolbar {
  padding: 12px 20px;
  border-bottom: 1px solid #f5f5f5;
}

.data-list {
  flex: 1;
  padding: 8px 12px;
  overflow-y: auto;
}

.data-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 12px;
  border-radius: 6px;
  transition: background 0.2s;
}

.data-item:hover {
  background: #f9fafb;
}

.item-avatar {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: #eff6ff;
  color: #3b82f6;
  display: flex;
  align-items: center;
  justify-content: center;
}

.item-avatar.page {
  border-radius: 8px;
  background: #f0fdf4;
  color: #22c55e;
}

.item-info {
  flex: 1;
  min-width: 0;
}

.item-title {
  font-size: 14px;
  color: #1f2937;
}

.item-desc {
  font-size: 12px;
  color: #9ca3af;
  margin-top: 1px;
}

.item-tags {
  display: flex;
  gap: 4px;
}

.item-actions {
  display: flex;
  gap: 2px;
  opacity: 0;
  transition: opacity 0.2s;
}

.data-item:hover .item-actions {
  opacity: 1;
}

.empty-state {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

/* 暗色模式 */
.dark .permission-page {
  background: #111827;
}

.dark .role-panel,
.dark .detail-panel {
  background: #1f2937;
}

.dark .panel-header,
.dark .detail-header,
.dark .tab-toolbar {
  border-color: #374151;
}

.dark .panel-title,
.dark .role-name,
.dark .item-title {
  color: #f3f4f6;
}

.dark .role-card:hover,
.dark .data-item:hover {
  background: #374151;
}

.dark .role-card.active {
  background: #1e3a5f;
  border-color: #3b82f6;
}
</style>
