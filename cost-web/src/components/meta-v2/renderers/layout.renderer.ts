import LayoutRenderer from '@/components/meta-v2/renderers/LayoutRenderer.vue';
import { registerComponentRenderer } from '@/composables/meta-v2/component-renderer-registry';

export function register(): void {
  registerComponentRenderer({
    key: 'layout-default',
    componentType: 'LAYOUT',
    order: 100,
    renderer: LayoutRenderer
  });
}
