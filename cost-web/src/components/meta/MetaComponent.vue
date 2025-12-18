<template>
  <component :is="componentMap[config.componentType]" :config="config" :page-context="pageContext">
    <MetaComponent
      v-for="child in sortedChildren"
      :key="child.componentKey"
      :config="child"
      :page-context="pageContext"
    />
  </component>
</template>

<script setup lang="ts">
import { computed, type Component } from 'vue';
import MetaLayout from './MetaLayout.vue';
import MetaGrid from './MetaGrid.vue';
import MetaForm from './MetaForm.vue';
import MetaButton from './MetaButton.vue';
import MetaTabs from './MetaTabs.vue';

const props = defineProps<{
  config: Api.Metadata.PageComponent;
  pageContext: any;
}>();

const componentMap: Record<string, Component> = {
  LAYOUT: MetaLayout,
  GRID: MetaGrid,
  FORM: MetaForm,
  BUTTON: MetaButton,
  TABS: MetaTabs
};

const sortedChildren = computed(() => {
  return [...(props.config.children || [])].sort((a, b) => a.sortOrder - b.sortOrder);
});
</script>
