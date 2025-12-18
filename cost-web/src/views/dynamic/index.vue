<template>
  <div class="h-full p-16px">
    <DynamicPage v-if="pageCode" :page-code="pageCode" />
    <NEmpty v-else description="未配置 pageCode" />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { NEmpty } from 'naive-ui';
import DynamicPage from '@/components/meta/DynamicPage.vue';

defineOptions({
  name: 'DynamicPageView'
});

const route = useRoute();
const pageCode = computed(() => (route.meta?.pageCode as string) || '');
</script>
