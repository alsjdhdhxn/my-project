<template>
  <AgGridNativeTest v-if="pageCode === 'aggrid-native-test'" :pageCode="pageCode" />
  <MasterDetailPageV2 v-else-if="pageCode === 'cost-pinggu-v2'" :pageCode="pageCode" />
  <MasterDetailPage v-else-if="pageCode" :pageCode="pageCode" />
  <div v-else class="flex items-center justify-center h-full">
    <NEmpty description="页面配置不存在" />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { NEmpty } from 'naive-ui';
import MasterDetailPage from '@/components/meta-v4/MasterDetailPage.vue';
import MasterDetailPageV2 from '@/components/meta-v2/MasterDetailPageV2.vue';
import AgGridNativeTest from '@/components/meta-v4/AgGridNativeTest.vue';

const route = useRoute();

// 从路由 meta 中获取 pageCode
const pageCode = computed(() => {
  return (route.meta?.pageCode as string) || '';
});
</script>
