<template>
  <div class="master-detail-page-v3">
    <div v-if="pageError" class="state">
      <NEmpty :description="pageError.message || 'Page config error'" />
    </div>
    <MasterDetailLayoutV3 v-else-if="isReady" :runtime="runtime" />
    <div v-else class="state">
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
import MasterDetailLayoutV3 from '@/v3/components/MasterDetailLayoutV3.vue';
import LookupDialog from '@/v3/components/LookupDialog.vue';
import { useMetaRuntime } from '@/v3/composables/meta-v3/useMetaRuntime';

const props = defineProps<{ pageCode: string }>();
const message = useMessage();

const runtime = useMetaRuntime({
  pageCode: props.pageCode,
  notifyInfo: (msg) => message.info(msg),
  notifyError: (msg) => message.error(msg),
  notifySuccess: (msg) => message.success(msg)
});

const { isReady, init } = runtime;
const { lookupDialogRef, currentLookupRule, onLookupSelect, onLookupCancel } = runtime as any;
const pageError = (runtime as any).pageError;

onMounted(async () => {
  await init();
});
</script>

<style scoped>
.master-detail-page-v3 {
  width: calc(100% + 32px);
  height: calc(100% + 32px);
  margin: -16px;
  display: flex;
  flex-direction: column;
  background: #f5f7fb;
}

.state {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
}

/* 鍗曞厓鏍煎彉鏇撮鑹叉爣璇?*/
:deep(.cell-new) { background-color: #0b3d91 !important; color: #ffffff; }
:deep(.cell-user-changed) { background-color: #b7f4b3 !important; color: #1a1a1a !important; }
:deep(.cell-calc-changed) { background-color: #fff2a8 !important; color: #1a1a1a !important; }
:deep(.cell-deleted) { background-color: #f8d7da !important; text-decoration: line-through; }
/* 琛岀骇鏍峰紡 */
:deep(.row-deleted) { opacity: 0.5; }
:deep(.row-new) { background-color: #0b3d91; color: #ffffff; font-style: italic; }
:deep(.row-confirmed) { background-color: #e6ffed !important; }
:deep(.row-iserp) { background-color: #e6ffed !important; }
:deep(.row-iserp-updated) { background-color: #fff2a8 !important; }
:deep(.row-iserp-price-null) { background-color: #f8d7da !important; }
/* 琛ㄥご鏍峰紡 */
:deep(.ag-header-cell-label) { white-space: normal !important; line-height: 1.2; }
:deep(.ag-header-cell) { height: auto !important; }
</style>

