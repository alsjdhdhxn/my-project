<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { NEmpty } from 'naive-ui';
import MasterDetailPageV3 from '@/v3/components/MasterDetailPageV3.vue';

const props = defineProps<{ pageCode?: string }>();
const route = useRoute();

// 优先使用 prop 传入的 pageCode（v-show 多实例模式），否则从 route.meta 取
const effectivePageCode = computed(() => {
  return props.pageCode || (route.meta?.pageCode as string) || '';
});
</script>

<template>
  <MasterDetailPageV3 v-if="effectivePageCode" :page-code="effectivePageCode" />
  <div v-else class="h-full flex items-center justify-center">
    <NEmpty description="Page config not found" />
  </div>
</template>
