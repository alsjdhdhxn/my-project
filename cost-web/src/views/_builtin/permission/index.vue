<script setup lang="ts">
import { ref, computed, watch, h } from 'vue';
import { NCard, NSpace, NButton, NIcon, NTabs, NTabPane, NEmpty, NTag, NPopconfirm, NModal, NForm, NFormItem, NInput, NSelect, useMessage } from 'naive-ui';
import { Add as AddIcon, TrashOutline as DeleteIcon, CreateOutline as EditIcon, PersonOutline as UserIcon, DocumentOutline as PageIcon, ShieldCheckmarkOutline as RoleIcon } from '@vicons/ionicons5';
import type { RoleVO, UserRoleVO, RolePageVO, UserSimpleVO, PageSimpleVO } from '@/service/api/role-manage';
import {
  fetchRoles, createRole, updateRole, deleteRole,
  fetchUsersByRole, addUserToRole, removeUserFromRole,
  fetchPagesByRole, addPageToRole, updateRolePage, removePageFromRole,
  fetchAllUsers, fetchAllPages
} from '@/service/api/role-manage';

const message = useMessage();

// ==================== 角色列表 ====================
const roles = ref<RoleVO[]>([]);
const selectedRoleId = ref<number | null>(null);
const loadingRoles = ref(false);

const selectedRole = computed(() => roles.value.find(r => r.id === selectedRoleId.value));

async function loadRoles() {
  loadingRoles.value = true;
  try {
    roles.value = await fetchRoles();
    if (roles.value.length > 0 && !selectedRoleId.value) {
      selectedRoleId.value = roles.value[0].id!;
    }
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
    userRoles.value = await fetchUsersByRole(selectedRoleId.value);
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
    rolePages.value = await fetchPagesByRole(selectedRoleId.value);
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
</script>

<template>
  <div class="h-full flex gap-4 p-4">
    <!-- 左侧：角色列表 -->
    <NCard class="w-320px flex-shrink-0" :bordered="false">
      <template #header>
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <NIcon :component="RoleIcon" size="20" class="text-primary" />
            <span class="font-medium">角色列表</span>
          </div>
          <NButton type="primary" size="small" @click="openAddRole">
            <template #icon><NIcon :component="AddIcon" /></template>
            新增
          </NButton>
        </div>
      </template>

      <div class="flex flex-col gap-2">
        <div
          v-for="role in roles"
          :key="role.id"
          class="role-item p-3 rounded-lg cursor-pointer transition-all"
          :class="{ 'role-item-active': selectedRoleId === role.id }"
          @click="selectRole(role.id!)"
        >
          <div class="flex items-center justify-between">
            <div class="flex-1 min-w-0">
              <div class="font-medium truncate">{{ role.roleName }}</div>
              <div class="text-xs text-gray-400 mt-1">{{ role.roleCode }}</div>
            </div>
            <div class="flex gap-1 opacity-0 group-hover:opacity-100 role-actions">
              <NButton text size="tiny" @click.stop="openEditRole(role)">
                <NIcon :component="EditIcon" />
              </NButton>
              <NPopconfirm @positive-click="handleDeleteRole(role.id!)">
                <template #trigger>
                  <NButton text size="tiny" type="error" @click.stop>
                    <NIcon :component="DeleteIcon" />
                  </NButton>
                </template>
                确定删除角色「{{ role.roleName }}」吗？
              </NPopconfirm>
            </div>
          </div>
          <div v-if="role.description" class="text-xs text-gray-500 mt-2 truncate">
            {{ role.description }}
          </div>
        </div>

        <NEmpty v-if="roles.length === 0" description="暂无角色" class="py-8" />
      </div>
    </NCard>

    <!-- 右侧：从表Tab -->
    <NCard class="flex-1" :bordered="false">
      <template #header>
        <div class="flex items-center gap-2">
          <NTag v-if="selectedRole" type="primary" size="small">{{ selectedRole.roleName }}</NTag>
          <span v-else class="text-gray-400">请选择角色</span>
        </div>
      </template>

      <NTabs v-if="selectedRoleId" type="line" animated>
        <!-- Tab1: 角色人员 -->
        <NTabPane name="users">
          <template #tab>
            <div class="flex items-center gap-1">
              <NIcon :component="UserIcon" />
              <span>角色人员</span>
              <NTag size="small" round>{{ userRoles.length }}</NTag>
            </div>
          </template>

          <div class="mb-3">
            <NButton type="primary" size="small" @click="openAddUser">
              <template #icon><NIcon :component="AddIcon" /></template>
              添加人员
            </NButton>
          </div>

          <div class="grid gap-2">
            <div
              v-for="ur in userRoles"
              :key="ur.id"
              class="user-item flex items-center justify-between p-3 rounded-lg bg-gray-50 dark:bg-gray-800"
            >
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">
                  <NIcon :component="UserIcon" size="20" class="text-primary" />
                </div>
                <div>
                  <div class="font-medium">{{ ur.realName || ur.username }}</div>
                  <div class="text-xs text-gray-400">{{ ur.username }} · ID: {{ ur.userId }}</div>
                </div>
              </div>
              <NPopconfirm @positive-click="handleRemoveUser(ur.id!)">
                <template #trigger>
                  <NButton text type="error" size="small">
                    <NIcon :component="DeleteIcon" />
                  </NButton>
                </template>
                确定移除该用户吗？
              </NPopconfirm>
            </div>

            <NEmpty v-if="userRoles.length === 0" description="暂无人员" class="py-8" />
          </div>
        </NTabPane>

        <!-- Tab2: 角色页面 -->
        <NTabPane name="pages">
          <template #tab>
            <div class="flex items-center gap-1">
              <NIcon :component="PageIcon" />
              <span>角色页面</span>
              <NTag size="small" round>{{ rolePages.length }}</NTag>
            </div>
          </template>

          <div class="mb-3">
            <NButton type="primary" size="small" @click="openAddPage">
              <template #icon><NIcon :component="AddIcon" /></template>
              添加页面
            </NButton>
          </div>

          <div class="grid gap-2">
            <div
              v-for="rp in rolePages"
              :key="rp.id"
              class="page-item flex items-center justify-between p-3 rounded-lg bg-gray-50 dark:bg-gray-800"
            >
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-lg bg-success/10 flex items-center justify-center">
                  <NIcon :component="PageIcon" size="20" class="text-success" />
                </div>
                <div>
                  <div class="font-medium">{{ rp.pageName || rp.pageCode }}</div>
                  <div class="text-xs text-gray-400">{{ rp.pageCode }}</div>
                </div>
              </div>
              <div class="flex items-center gap-2">
                <NTag v-if="rp.buttonPolicy === '[\"*\"]'" type="success" size="small">全部按钮</NTag>
                <NTag v-else-if="rp.buttonPolicy" type="info" size="small">部分按钮</NTag>
                <NButton text size="small" @click="openEditPage(rp)">
                  <NIcon :component="EditIcon" />
                </NButton>
                <NPopconfirm @positive-click="handleRemovePage(rp.id!)">
                  <template #trigger>
                    <NButton text type="error" size="small">
                      <NIcon :component="DeleteIcon" />
                    </NButton>
                  </template>
                  确定移除该页面权限吗？
                </NPopconfirm>
              </div>
            </div>

            <NEmpty v-if="rolePages.length === 0" description="暂无页面权限" class="py-8" />
          </div>
        </NTabPane>
      </NTabs>

      <NEmpty v-else description="请先选择一个角色" class="py-16" />
    </NCard>

    <!-- 角色编辑弹窗 -->
    <NModal v-model:show="showRoleModal" preset="card" :title="isEditRole ? '编辑角色' : '新增角色'" class="w-450px">
      <NForm label-placement="left" label-width="80">
        <NFormItem label="角色编码" required>
          <NInput v-model:value="roleForm.roleCode" placeholder="请输入角色编码" :disabled="isEditRole" />
        </NFormItem>
        <NFormItem label="角色名称" required>
          <NInput v-model:value="roleForm.roleName" placeholder="请输入角色名称" />
        </NFormItem>
        <NFormItem label="描述">
          <NInput v-model:value="roleForm.description" type="textarea" placeholder="请输入描述" />
        </NFormItem>
      </NForm>
      <template #footer>
        <div class="flex justify-end gap-2">
          <NButton @click="showRoleModal = false">取消</NButton>
          <NButton type="primary" :loading="savingRole" @click="saveRole">保存</NButton>
        </div>
      </template>
    </NModal>

    <!-- 添加用户弹窗 -->
    <NModal v-model:show="showAddUserModal" preset="card" title="添加人员" class="w-400px">
      <NSelect
        v-model:value="selectedUserId"
        :options="availableUsers.map(u => ({ label: `${u.realName || u.username} (${u.username})`, value: u.id }))"
        placeholder="请选择用户"
        filterable
      />
      <template #footer>
        <div class="flex justify-end gap-2">
          <NButton @click="showAddUserModal = false">取消</NButton>
          <NButton type="primary" :loading="addingUser" :disabled="!selectedUserId" @click="handleAddUser">添加</NButton>
        </div>
      </template>
    </NModal>

    <!-- 添加页面弹窗 -->
    <NModal v-model:show="showAddPageModal" preset="card" title="添加页面权限" class="w-450px">
      <NForm label-placement="left" label-width="80">
        <NFormItem label="页面" required>
          <NSelect
            v-model:value="pageForm.pageCode"
            :options="availablePages.map(p => ({ label: `${p.pageName} (${p.pageCode})`, value: p.pageCode }))"
            placeholder="请选择页面"
            filterable
          />
        </NFormItem>
        <NFormItem label="按钮权限">
          <NInput v-model:value="pageForm.buttonPolicy" placeholder='["*"] 表示全部按钮' />
        </NFormItem>
        <NFormItem label="列权限">
          <NInput v-model:value="pageForm.columnPolicy" type="textarea" placeholder="JSON格式，留空表示全部列" />
        </NFormItem>
      </NForm>
      <template #footer>
        <div class="flex justify-end gap-2">
          <NButton @click="showAddPageModal = false">取消</NButton>
          <NButton type="primary" :loading="addingPage" :disabled="!pageForm.pageCode" @click="handleAddPage">添加</NButton>
        </div>
      </template>
    </NModal>

    <!-- 编辑页面权限弹窗 -->
    <NModal v-model:show="showEditPageModal" preset="card" title="编辑页面权限" class="w-450px">
      <NForm label-placement="left" label-width="80">
        <NFormItem label="页面">
          <NInput :value="editPageForm.pageName || editPageForm.pageCode" disabled />
        </NFormItem>
        <NFormItem label="按钮权限">
          <NInput v-model:value="editPageForm.buttonPolicy" placeholder='["*"] 表示全部按钮' />
        </NFormItem>
        <NFormItem label="列权限">
          <NInput v-model:value="editPageForm.columnPolicy" type="textarea" placeholder="JSON格式，留空表示全部列" />
        </NFormItem>
      </NForm>
      <template #footer>
        <div class="flex justify-end gap-2">
          <NButton @click="showEditPageModal = false">取消</NButton>
          <NButton type="primary" :loading="editingPage" @click="handleUpdatePage">保存</NButton>
        </div>
      </template>
    </NModal>
  </div>
</template>

<style scoped>
.role-item {
  background: var(--n-color-hover);
  border: 2px solid transparent;
}

.role-item:hover {
  background: var(--n-color-hover);
}

.role-item:hover .role-actions {
  opacity: 1;
}

.role-item-active {
  background: var(--n-color-target);
  border-color: var(--n-color-target);
  box-shadow: 0 0 0 2px rgba(var(--primary-color), 0.2);
}

.user-item,
.page-item {
  transition: all 0.2s;
}

.user-item:hover,
.page-item:hover {
  transform: translateX(4px);
}
</style>
