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

<template>
  <MasterDetailPageV3 v-if="pageCode" :page-code="pageCode" />
  <div v-else class="h-full flex items-center justify-center">
    <NEmpty description="Page config not found" />
  </div>
</template>
