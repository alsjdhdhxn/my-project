<script setup lang="ts">
import { computed, defineComponent, h } from 'vue';
import type { RouteLocationNormalizedLoaded } from 'vue-router';
import { useRoute } from 'vue-router';
import { LAYOUT_SCROLL_EL_ID } from '@sa/materials';
import { useAppStore } from '@/store/modules/app';
import { useThemeStore } from '@/store/modules/theme';
import { useRouteStore } from '@/store/modules/route';
import { useTabStore } from '@/store/modules/tab';

defineOptions({
  name: 'GlobalContent'
});

interface Props {
  /** Show padding for content */
  showPadding?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  showPadding: true
});

const route = useRoute();
const appStore = useAppStore();
const themeStore = useThemeStore();
const routeStore = useRouteStore();
const tabStore = useTabStore();

const transitionName = computed(() => (themeStore.page.animate ? themeStore.page.animateMode : ''));

// 根据路由 meta.noPadding 或 props 决定是否显示 padding
// 有 pageCode 的动态页面默认不显示 padding（表格需要撑满）
const shouldShowPadding = computed(() => {
  if (route.meta?.noPadding) return false;
  // 有 pageCode 的页面不显示 padding
  if (route.meta?.pageCode) {
    return false;
  }
  return props.showPadding;
});

function resetScroll() {
  const el = document.querySelector(`#${LAYOUT_SCROLL_EL_ID}`);

  el?.scrollTo({ left: 0, top: 0 });
}

/** 给组件注入路由 name，让 KeepAlive 的 include 能匹配到 */
const componentCache = new Map<string, any>();
function wrapComponent(component: any, route: RouteLocationNormalizedLoaded) {
  const routeName = route.name as string;
  if (!routeName || !component) return component;
  // 组件已经有匹配的 name，直接返回
  if (component.name === routeName) return component;
  // 缓存包装组件，避免重复创建导致 KeepAlive 失效
  if (componentCache.has(routeName)) return componentCache.get(routeName);
  const wrapped = defineComponent({
    name: routeName,
    setup() {
      return () => h(component);
    }
  });
  componentCache.set(routeName, wrapped);
  return wrapped;
}
</script>

<template>
  <RouterView v-slot="{ Component, route }">
    <Transition
      :name="transitionName"
      mode="out-in"
      @before-leave="appStore.setContentXScrollable(true)"
      @after-leave="resetScroll"
      @after-enter="appStore.setContentXScrollable(false)"
    >
      <KeepAlive :include="routeStore.cacheRoutes" :exclude="routeStore.excludeCacheRoutes">
        <component
          :is="wrapComponent(Component, route)"
          v-if="appStore.reloadFlag"
          :key="tabStore.getTabIdByRoute(route)"
          :class="{ 'p-16px': shouldShowPadding }"
          class="flex-grow bg-layout transition-300"
        />
      </KeepAlive>
    </Transition>
  </RouterView>
</template>

<style></style>
