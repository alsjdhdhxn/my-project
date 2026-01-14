import MetaForm from '@/components/meta-v2/renderers/MetaForm.vue';
import { registerComponentRenderer } from '@/composables/meta-v2/component-renderer-registry';

export function register(): void {
  registerComponentRenderer({
    key: 'form-default',
    componentType: 'FORM',
    order: 100,
    renderer: MetaForm
  });
}
