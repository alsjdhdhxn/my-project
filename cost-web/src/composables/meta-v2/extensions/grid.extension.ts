import type { PageComponentWithRules } from '@/composables/meta-v2/types';
import { registerComponentExtension } from '@/composables/meta-v2/registry';
import { parseRoleBindingRule } from '@/composables/meta-v2/usePageRules';
import { useMasterGridBindings } from '@/composables/meta-v2/useMasterGridBindings';

function normalizeRole(role?: string): string | null {
  if (!role) return null;
  const normalized = role.trim().toUpperCase();
  return normalized.length > 0 ? normalized : null;
}

function collectByType(components: PageComponentWithRules[], type: string): PageComponentWithRules[] {
  const result: PageComponentWithRules[] = [];
  const visit = (component: PageComponentWithRules) => {
    if (component.componentType === type) result.push(component);
    if (Array.isArray(component.children)) component.children.forEach(visit);
  };
  components.forEach(visit);
  return result;
}

function isMasterGrid(component: PageComponentWithRules, components: PageComponentWithRules[], role?: string | null): boolean {
  if (role === 'MASTER_GRID' || role === 'MASTER') return true;
  const grids = collectByType(components, 'GRID');
  return grids.length === 1 && grids[0].componentKey === component.componentKey;
}

export function register(): void {
  registerComponentExtension({
    key: 'grid-master-bindings',
    order: 10,
    match: component => component.componentType === 'GRID',
    apply: ({ component, componentRules, pageComponents, runtime, state }) => {
      if (!runtime) return;
      const roleRule = parseRoleBindingRule(component.componentKey, componentRules);
      const role = normalizeRole(roleRule?.role);
      if (!isMasterGrid(component, pageComponents, role)) return;

      const bindings = useMasterGridBindings({
        runtime,
        metaRowClassGetter: runtime.masterRowClassGetter?.value,
        gridOptions: runtime.masterGridOptions?.value,
        columnDefs: runtime.masterColumnDefs
      });
      state.rowData = runtime.masterRows;
      state.columnDefs = runtime.masterColumnDefs;
      state.defaultColDef = bindings.defaultColDef;
      state.rowSelection = bindings.rowSelection;
      state.autoSizeStrategy = bindings.autoSizeStrategy;
      state.getRowId = bindings.getRowId;
      state.getRowClass = bindings.getRowClass;
      state.getContextMenuItems = bindings.getContextMenuItems;
      state.gridOptions = bindings.gridOptions;
      state.rowHeight = bindings.rowHeight;
      state.headerHeight = bindings.headerHeight;
      state.onGridReady = bindings.onGridReady;
      state.onCellEditingStarted = bindings.onCellEditingStarted;
      state.onCellEditingStopped = bindings.onCellEditingStopped;
      state.onCellValueChanged = bindings.onCellValueChanged;
      state.onCellClicked = bindings.onCellClicked;
    }
  });
}
