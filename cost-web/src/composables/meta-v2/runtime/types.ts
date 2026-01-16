import type { ColDef } from 'ag-grid-community';

export type RuntimeStage =
  | 'loadComponents'
  | 'parseConfig'
  | 'loadMeta'
  | 'compileRules'
  | 'buildStates'
  | 'applyExtensions'
  | 'render';

export type MetaError = {
  code: string;
  message: string;
  stage: RuntimeStage;
  pageCode: string;
  componentKey?: string;
  tableCode?: string;
  ruleType?: string;
  raw?: unknown;
};

export type RuntimeFeatures = {
  detailTabs?: boolean;
  broadcast?: boolean;
  aggregates?: boolean;
  lookup?: boolean;
  export?: boolean;
  contextMenu?: boolean;
};

export type ComponentStatus = 'ready' | 'loading' | 'error';

export type ComponentStateBase = {
  componentKey: string;
  componentType: string;
  status: ComponentStatus;
  error?: MetaError;
};

export type GridState = ComponentStateBase & {
  rowData: any[];
  columnDefs: ColDef[];
  defaultColDef?: ColDef;
  gridOptions?: Record<string, any>;
  rowSelection?: Record<string, any>;
  autoSizeStrategy?: any;
  getRowId?: (params: any) => string;
  getRowClass?: (params: any) => string | undefined;
  getContextMenuItems?: (params: any) => any[];
  rowHeight?: number;
  headerHeight?: number;
  onGridReady?: (event: any) => void;
  onCellValueChanged?: (event: any) => void;
  onCellClicked?: (event: any) => void;
  onCellEditingStarted?: (event: any) => void;
  onCellEditingStopped?: (event: any) => void;
};

export type ComponentState = ComponentStateBase | GridState;

export type RuntimeLogger = {
  log: (stage: RuntimeStage, message: string, componentKey?: string) => void;
  error: (err: MetaError) => void;
};
