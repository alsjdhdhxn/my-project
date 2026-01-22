<template>
  <MasterDetailPageV3 v-if="pageCode" :pageCode="pageCode" />
  <div v-else class="flex items-center justify-center h-full">
    <NEmpty description="Page config not found" />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { NEmpty } from 'naive-ui';
import MasterDetailPageV3 from '@/v3/components/MasterDetailPageV3.vue';

const route = useRoute();

const pageCode = computed(() => {
  return (route.meta?.pageCode as string) || '';
});
</script>

