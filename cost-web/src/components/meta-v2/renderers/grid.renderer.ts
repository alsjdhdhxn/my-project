import MetaGrid from '@/components/meta-v2/renderers/MetaGrid.vue';
import { registerComponentRenderer } from '@/composables/meta-v2/component-renderer-registry';

export function register(): void {
  registerComponentRenderer({
    key: 'grid-default',
    componentType: 'GRID',
    order: 100,
    renderer: MetaGrid
  });
}
