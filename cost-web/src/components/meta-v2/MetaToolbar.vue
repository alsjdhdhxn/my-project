<template>
  <div class="meta-toolbar">
    <NSpace>
      <!-- 左侧按钮 -->
      <NButton v-if="showAdd" type="primary" @click="emit('add')">
        <template #icon><span class="i-carbon-add" /></template>
        新增
      </NButton>
      <NButton v-if="showDelete" :disabled="!hasSelection" @click="emit('delete')">
        <template #icon><span class="i-carbon-trash-can" /></template>
        删除
      </NButton>
      <NButton v-if="showSave" type="primary" :disabled="!isDirty" @click="emit('save')">
        <template #icon><span class="i-carbon-save" /></template>
        保存
      </NButton>
      <NButton v-if="showRefresh" @click="emit('refresh')">
        <template #icon><span class="i-carbon-refresh" /></template>
        刷新
      </NButton>
      
      <!-- 插槽：自定义按钮 -->
      <slot name="buttons" />
    </NSpace>

    <div class="toolbar-right">
      <!-- 前端搜索 -->
      <NInput
        v-if="showSearch"
        v-model:value="searchText"
        placeholder="搜索..."
        clearable
        style="width: 200px"
        @update:value="onSearchChange"
      >
        <template #prefix>
          <span class="i-carbon-search" />
        </template>
      </NInput>

      <!-- 高级查询按钮 -->
      <NButton v-if="showAdvancedQuery" @click="emit('advancedQuery')">
        <template #icon><span class="i-carbon-filter" /></template>
        高级查询
      </NButton>

      <!-- 插槽：右侧自定义 -->
      <slot name="right" />

      <!-- 脏数据提示 -->
      <span v-if="isDirty" class="dirty-hint">有未保存的修改</span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { NButton, NSpace, NInput } from 'naive-ui';

const props = withDefaults(defineProps<{
  /** 是否显示新增按钮 */
  showAdd?: boolean;
  /** 是否显示删除按钮 */
  showDelete?: boolean;
  /** 是否显示保存按钮 */
  showSave?: boolean;
  /** 是否显示刷新按钮 */
  showRefresh?: boolean;
  /** 是否显示搜索框 */
  showSearch?: boolean;
  /** 是否显示高级查询按钮 */
  showAdvancedQuery?: boolean;
  /** 是否有选中行 */
  hasSelection?: boolean;
  /** 是否有未保存的修改 */
  isDirty?: boolean;
}>(), {
  showAdd: true,
  showDelete: true,
  showSave: true,
  showRefresh: true,
  showSearch: true,
  showAdvancedQuery: true,
  hasSelection: false,
  isDirty: false
});

const emit = defineEmits<{
  (e: 'add'): void;
  (e: 'delete'): void;
  (e: 'save'): void;
  (e: 'refresh'): void;
  (e: 'search', text: string): void;
  (e: 'advancedQuery'): void;
}>();

const searchText = ref('');

function onSearchChange(text: string) {
  emit('search', text);
}
</script>

<style scoped>
.meta-toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 12px;
  background: #fff;
  border-radius: 4px;
}

.toolbar-right {
  display: flex;
  align-items: center;
  gap: 12px;
}

.dirty-hint {
  color: #f5222d;
  font-size: 12px;
}
</style>
