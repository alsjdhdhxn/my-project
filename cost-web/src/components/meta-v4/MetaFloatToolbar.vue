<template>
  <div 
    ref="toolbarRef"
    class="meta-float-toolbar"
    :class="{ expanded: isExpanded }"
    :style="{ top: `${posY}px` }"
  >
    <!-- 收起状态：只显示图标（可拖动） -->
    <div 
      v-show="!isExpanded"
      class="toolbar-trigger"
      @mousedown="onTriggerMouseDown"
      @click="onTriggerClick"
    >
      <icon-carbon-overflow-menu-vertical class="trigger-icon" />
    </div>
    
    <!-- 展开状态：显示完整内容 -->
    <div v-show="isExpanded" class="toolbar-content">
      <!-- 拖动手柄 -->
      <div class="drag-handle" @mousedown="startDrag">
        <icon-carbon-draggable class="drag-icon" />
      </div>
      
      <!-- 内容区域 -->
      <div class="toolbar-body">
        <!-- 默认插槽 -->
        <slot />
      </div>
      
      <!-- 收起按钮 -->
      <NButton size="small" quaternary @click="isExpanded = false">
        <template #icon><icon-carbon-close /></template>
      </NButton>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue';
import { NButton } from 'naive-ui';

const toolbarRef = ref<HTMLElement>();
const isExpanded = ref(false);

// 拖动相关
const posY = ref(200);
const isDragging = ref(false);
const dragStartY = ref(0);
const dragStartPosY = ref(0);
const hasMoved = ref(false);

// 收起状态点击（区分拖动和点击）
function onTriggerMouseDown(e: MouseEvent) {
  hasMoved.value = false;
  dragStartY.value = e.clientY;
  dragStartPosY.value = posY.value;
  isDragging.value = true;
  e.preventDefault();
}

function onTriggerClick() {
  // 只有没拖动过才展开
  if (!hasMoved.value) {
    isExpanded.value = true;
  }
}

// 展开状态拖动
function startDrag(e: MouseEvent) {
  isDragging.value = true;
  dragStartY.value = e.clientY;
  dragStartPosY.value = posY.value;
  e.preventDefault();
}

function onMouseMove(e: MouseEvent) {
  if (!isDragging.value) return;
  const deltaY = e.clientY - dragStartY.value;
  if (Math.abs(deltaY) > 3) {
    hasMoved.value = true;
  }
  const newY = dragStartPosY.value + deltaY;
  posY.value = Math.max(50, Math.min(window.innerHeight - 100, newY));
}

function onMouseUp() {
  isDragging.value = false;
}

onMounted(() => {
  document.addEventListener('mousemove', onMouseMove);
  document.addEventListener('mouseup', onMouseUp);
});

onUnmounted(() => {
  document.removeEventListener('mousemove', onMouseMove);
  document.removeEventListener('mouseup', onMouseUp);
});
</script>

<style scoped>
.meta-float-toolbar {
  position: fixed;
  right: 0;
  z-index: 100;
  display: flex;
  align-items: flex-start;
}

.toolbar-trigger {
  width: 24px;
  height: 48px;
  background: #fff;
  border: 1px solid #e8e8e8;
  border-right: none;
  border-radius: 4px 0 0 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  box-shadow: -2px 0 8px rgba(0, 0, 0, 0.1);
}

.toolbar-trigger:hover {
  background: #f5f5f5;
}

.trigger-icon {
  font-size: 16px;
  color: #666;
}

.toolbar-content {
  display: flex;
  align-items: flex-start;
  gap: 4px;
  padding: 8px;
  background: #fff;
  border: 1px solid #e8e8e8;
  border-right: none;
  border-radius: 4px 0 0 4px;
  box-shadow: -2px 0 8px rgba(0, 0, 0, 0.1);
}

.drag-handle {
  width: 20px;
  height: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: grab;
  color: #999;
  flex-shrink: 0;
}

.drag-handle:active {
  cursor: grabbing;
}

.drag-icon {
  font-size: 14px;
}

.toolbar-body {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.toolbar-body :deep(.toolbar-row) {
  display: flex;
  align-items: center;
  gap: 4px;
}
</style>
