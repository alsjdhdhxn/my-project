<script setup lang="ts">
import { ref } from 'vue';
import { NTabs, NTabPane } from 'naive-ui';
import DirectoryPanel from './panels/DirectoryPanel.vue';
import TablePanel from './panels/TablePanel.vue';
import PagePanel from './panels/PagePanel.vue';
import LookupPanel from './panels/LookupPanel.vue';

const activeTab = ref('directory');
</script>

<template>
  <div class="meta-config-page">
    <NTabs v-model:value="activeTab" type="line" animated>
      <NTabPane name="directory" tab="目录管理">
        <DirectoryPanel />
      </NTabPane>
      <NTabPane name="table" tab="表管理">
        <TablePanel />
      </NTabPane>
      <NTabPane name="page" tab="页面管理">
        <PagePanel />
      </NTabPane>
      <NTabPane name="lookup" tab="Lookup管理">
        <LookupPanel />
      </NTabPane>
    </NTabs>
  </div>
</template>

<style scoped>
.meta-config-page {
  height: 100%;
  padding: 12px 16px;
  display: flex;
  flex-direction: column;
  background: #f5f7fb;
}
.meta-config-page :deep(.n-tabs) {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.meta-config-page :deep(.n-tabs .n-tabs-pane-wrapper) {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.meta-config-page :deep(.n-tabs .n-tab-pane) {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
</style>
