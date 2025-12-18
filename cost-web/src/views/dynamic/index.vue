<template>
  <div class="h-full p-16px">
    <NCard :title="pageTitle" class="h-full">
      <NEmpty description="动态页面开发中...">
        <template #extra>
          <NText depth="3">pageCode: {{ pageCode }}</NText>
        </template>
      </NEmpty>
    </NCard>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { NCard, NEmpty, NText } from 'naive-ui';

defineOptions({
  name: 'DynamicPage'
});

const route = useRoute();

const pageCode = computed(() => route.meta?.pageCode as string || route.name as string);
const pageTitle = computed(() => route.meta?.title || '动态页面');
</script>
