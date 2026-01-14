<template>
  <div class="master-detail-page-v2">
    <MetaPageRenderer v-if="isReady" :components="pageComponents" :runtime="runtime" />
    <div v-else class="loading">
      <NSpin size="large" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted } from 'vue';
import { NSpin, useMessage } from 'naive-ui';
import MetaPageRenderer from '@/components/meta-v2/renderers/MetaPageRenderer.vue';
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

onMounted(async () => {
  await init();
});
</script>

<style scoped>
.master-detail-page-v2 { width: 100%; height: 100%; }
.loading { display: flex; justify-content: center; align-items: center; height: 100%; }
</style>
