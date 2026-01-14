import MasterDetailLayoutRenderer from '@/components/meta-v2/renderers/MasterDetailLayoutRenderer.vue';
import { registerComponentRenderer } from '@/composables/meta-v2/component-renderer-registry';
import { parseRoleBindingRule, parseRelationRule } from '@/composables/meta-v2/usePageRules';
import type { PageComponentWithRules } from '@/composables/meta-v2/types';

function normalizeRole(role?: string): string | null {
  if (!role) return null;
  const normalized = role.trim().toUpperCase();
  return normalized.length > 0 ? normalized : null;
}

function hasRole(component: PageComponentWithRules, role: string): boolean {
  const rules = component.rules || [];
  const roleRule = parseRoleBindingRule(component.componentKey, rules);
  const normalized = normalizeRole(roleRule?.role);
  if (normalized === role) return true;
  if (Array.isArray(component.children)) {
    return component.children.some(child => hasRole(child, role));
  }
  return false;
}

function hasComponentType(component: PageComponentWithRules, type: string): boolean {
  if (component.componentType === type) return true;
  if (Array.isArray(component.children)) {
    return component.children.some(child => hasComponentType(child, type));
  }
  return false;
}

function hasRelation(component: PageComponentWithRules): boolean {
  const rules = component.rules || [];
  if (parseRelationRule(component.componentKey, rules)) return true;
  if (Array.isArray(component.children)) {
    return component.children.some(child => hasRelation(child));
  }
  return false;
}

function isMasterDetailLayout(component: PageComponentWithRules): boolean {
  if (!hasComponentType(component, 'GRID')) return false;
  if (hasRelation(component)) return true;
  if (hasRole(component, 'DETAIL_TABS') || hasRole(component, 'DETAIL')) return true;
  if (hasComponentType(component, 'TABS')) return true;
  return false;
}

export function register(): void {
  registerComponentRenderer({
    key: 'layout-master-detail',
    componentType: 'LAYOUT',
    order: 10,
    match: ({ component }) => isMasterDetailLayout(component),
    renderer: MasterDetailLayoutRenderer
  });
}
