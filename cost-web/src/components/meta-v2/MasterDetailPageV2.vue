<template>
  <div class="master-detail-page-v2">
    <div v-if="pageError" class="error">
      <NEmpty :description="pageError.message || 'Page config error'" />
    </div>
    <MetaPageRenderer v-else-if="isReady" :components="pageComponents" :runtime="runtime" />
    <div v-else class="loading">
      <NSpin size="large" />
    </div>
    <LookupDialog
      v-if="currentLookupRule"
      ref="lookupDialogRef"
      :lookupCode="currentLookupRule.lookupCode"
      :mapping="currentLookupRule.mapping"
      @select="onLookupSelect"
      @cancel="onLookupCancel"
    />
  </div>
</template>

<script setup lang="ts">
import { onMounted } from 'vue';
import { NEmpty, NSpin, useMessage } from 'naive-ui';
import MetaPageRenderer from '@/components/meta-v2/renderers/MetaPageRenderer.vue';
import LookupDialog from '@/components/meta-v2/LookupDialog.vue';
import { useMetaRuntime } from '@/composables/meta-v2/useMetaRuntime';

const props = defineProps<{ pageCode: string }>();
const message = useMessage();

const runtime = useMetaRuntime({
  pageCode: props.pageCode,
  notifyInfo: (msg) => message.info(msg),
  notifyError: (msg) => message.error(msg),
  notifySuccess: (msg) => message.success(msg)
});

const { isReady, pageComponents, init } = runtime;
const { lookupDialogRef, currentLookupRule, onLookupSelect, onLookupCancel } = runtime;
const pageError = (runtime as any).pageError;

onMounted(async () => {
  await init();
});
</script>

<style scoped>
.master-detail-page-v2 { width: 100%; height: 100%; }
.loading { display: flex; justify-content: center; align-items: center; height: 100%; }
.error { display: flex; justify-content: center; align-items: center; height: 100%; }
/* 单元格变更颜色标识 */
:deep(.cell-new) { background-color: #0b3d91 !important; color: #ffffff; }
:deep(.cell-user-changed) { background-color: #b7f4b3 !important; color: #1a1a1a !important; }
:deep(.cell-calc-changed) { background-color: #fff2a8 !important; color: #1a1a1a !important; }
:deep(.cell-deleted) { background-color: #f8d7da !important; text-decoration: line-through; }
/* 行级样式 */
:deep(.row-deleted) { opacity: 0.5; }
:deep(.row-new) { background-color: #0b3d91; color: #ffffff; font-style: italic; }
:deep(.row-confirmed) { background-color: #e6ffed !important; } /* 浅绿色背景 */
:deep(.row-iserp) { background-color: #e6ffed !important; }
:deep(.row-iserp-updated) { background-color: #fff2a8 !important; }
:deep(.row-iserp-price-null) { background-color: #f8d7da !important; }
/* 表头样式 */
:deep(.ag-header-cell-label) { white-space: normal !important; line-height: 1.2; }
:deep(.ag-header-cell) { height: auto !important; }
</style>
