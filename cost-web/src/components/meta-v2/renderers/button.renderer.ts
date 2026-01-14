import MetaButton from '@/components/meta-v2/renderers/MetaButton.vue';
import { registerComponentRenderer } from '@/composables/meta-v2/component-renderer-registry';

export function register(): void {
  registerComponentRenderer({
    key: 'button-default',
    componentType: 'BUTTON',
    order: 100,
    renderer: MetaButton
  });
}
