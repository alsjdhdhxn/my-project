/**
 * 元数据解析器
 * 从 PAGE_COMPONENT.COMPONENT_CONFIG 解析计算规则、聚合规则、Tab 配置
 */
import type { CalcRule, AggRule } from './calculator';

// ==================== 类型定义 ====================

/** Tab 配置 */
export interface TabConfig {
  key: string;
  title: string;
  mode: 'group' | 'multi';
  // group 模式
  groupField?: string;
  groupValue?: string;
  groupValues?: string[]; // 多个分组值
  // multi 模式
  tableCode?: string;
  // 通用
  columns: string[];
}

/** TABS 组件配置（从数据库读取） */
export interface TabsComponentConfig {
  mode: 'group' | 'multi';
  groupField?: string;
  tabs: Array<{
    key: string;
    title: string;
    value?: string; // group 模式的分组值
    values?: string[]; // group 模式的多个分组值
    tableCode?: string; // multi 模式的表代码
    columns: string[];
  }>;
  broadcast?: string[];
  calcRules?: CalcRule[];
  aggregates?: AggRule[];
  postProcess?: string; // 聚合后处理表达式
  masterCalcRules?: CalcRule[]; // 主表计算规则
}

/** 页面组件（从 API 返回） */
export interface PageComponent {
  id: number;
  pageCode: string;
  componentKey: string;
  componentType: string;
  parentKey?: string;
  sortOrder: number;
  refTableCode?: string;
  componentConfig?: string;
  children?: PageComponent[];
}

/** 企业版功能配置 */
export interface EnterpriseConfig {
  enableSidebar?: boolean;        // 启用侧边栏
  enableExcelExport?: boolean;    // 启用 Excel 导出
  enableRangeSelection?: boolean; // 启用范围选择
  groupBy?: string[];             // 分组字段
  aggregations?: Array<{          // 聚合配置
    field: string;
    aggFunc: 'sum' | 'min' | 'max' | 'avg' | 'count' | 'first' | 'last';
  }>;
  groupColumnName?: string;       // 分组列名称
}

/** 解析结果 */
export interface ParsedPageConfig {
  masterTableCode: string;
  detailTableCode: string;
  tabs: TabConfig[];
  broadcast: string[];
  calcRules: CalcRule[];
  aggregates: AggRule[];
  groupField?: string;
  mode: 'group' | 'multi';
  postProcess?: string; // 聚合后处理表达式
  masterCalcRules: CalcRule[]; // 主表计算规则
  enterpriseConfig?: EnterpriseConfig; // 企业版功能配置
}

// ==================== 解析函数 ====================

/**
 * 解析页面组件树，提取主从表配置
 */
export function parsePageComponents(components: PageComponent[]): ParsedPageConfig | null {
  // 约定：主表组件 key = masterGrid
  const masterGrid = findComponent(components, 'masterGrid', 'GRID');
  if (!masterGrid) {
    console.warn('[Parser] 未找到 masterGrid 组件');
    return null;
  }

  // 解析主表组件的企业版配置
  const masterConfig = parseComponentConfig<{ enterpriseConfig?: EnterpriseConfig }>(masterGrid.componentConfig);
  const enterpriseConfig = masterConfig?.enterpriseConfig;

  // 约定：从表组件 type = TABS（可选，单表页面没有）
  const detailTabs = findComponentByType(components, 'TABS');
  if (!detailTabs) {
    // 单表模式
    return {
      masterTableCode: masterGrid.refTableCode || '',
      detailTableCode: '',
      tabs: [],
      broadcast: [],
      calcRules: [],
      aggregates: [],
      mode: 'group',
      masterCalcRules: [],
      enterpriseConfig
    };
  }

  const config = parseComponentConfig<TabsComponentConfig>(detailTabs.componentConfig);
  if (!config) {
    console.warn('[Parser] TABS 组件配置解析失败');
    return null;
  }

  // 解析 Tab 配置
  const tabs = parseTabConfig(config);

  return {
    masterTableCode: masterGrid.refTableCode || '',
    detailTableCode: detailTabs.refTableCode || '',
    tabs,
    broadcast: config.broadcast || [],
    calcRules: config.calcRules || [],
    aggregates: config.aggregates || [],
    groupField: config.groupField,
    mode: config.mode || 'group',
    postProcess: config.postProcess,
    masterCalcRules: config.masterCalcRules || [],
    enterpriseConfig
  };
}

/**
 * 解析 Tab 配置
 */
export function parseTabConfig(config: TabsComponentConfig): TabConfig[] {
  return config.tabs.map(tab => ({
    key: tab.key,
    title: tab.title,
    mode: config.mode || 'group',
    groupField: config.groupField,
    groupValue: tab.value,
    groupValues: tab.values, // 多个分组值
    tableCode: tab.tableCode,
    columns: tab.columns || []
  }));
}

/**
 * 解析计算规则（从 COMPONENT_CONFIG）
 */
export function parseCalcRules(config: TabsComponentConfig): CalcRule[] {
  if (!config.calcRules) return [];

  return config.calcRules.map((rule, idx) => ({
    field: rule.field,
    expression: rule.expression,
    triggerFields: rule.triggerFields || [],
    condition: rule.condition,
    order: rule.order ?? idx
  }));
}

/**
 * 解析聚合规则（从 COMPONENT_CONFIG）
 */
export function parseAggRules(config: TabsComponentConfig): AggRule[] {
  if (!config.aggregates) return [];

  return config.aggregates.map(rule => ({
    sourceField: rule.sourceField,
    targetField: rule.targetField,
    algorithm: rule.algorithm,
    filter: rule.filter,
    expression: rule.expression
  }));
}

/**
 * 从组件树中查找指定 key 的组件
 */
function findComponent(
  components: PageComponent[],
  key: string,
  type?: string
): PageComponent | null {
  for (const comp of components) {
    if (comp.componentKey === key && (!type || comp.componentType === type)) {
      return comp;
    }
    if (comp.children) {
      const found = findComponent(comp.children, key, type);
      if (found) return found;
    }
  }
  return null;
}

/**
 * 从组件树中查找指定类型的组件
 */
function findComponentByType(components: PageComponent[], type: string): PageComponent | null {
  for (const comp of components) {
    if (comp.componentType === type) {
      return comp;
    }
    if (comp.children) {
      const found = findComponentByType(comp.children, type);
      if (found) return found;
    }
  }
  return null;
}

/**
 * 解析组件配置 JSON
 */
function parseComponentConfig<T>(configStr?: string): T | null {
  if (!configStr) return null;
  try {
    return JSON.parse(configStr) as T;
  } catch (e) {
    console.warn('[Parser] JSON 解析失败:', configStr, e);
    return null;
  }
}

/**
 * 从列元数据提取默认值
 */
export function extractDefaultValues(
  columns: Array<{ fieldName: string; dataType: string; defaultValue?: any }>
): Record<string, any> {
  const defaults: Record<string, any> = {};

  for (const col of columns) {
    if (col.defaultValue !== undefined && col.defaultValue !== null) {
      defaults[col.fieldName] = col.defaultValue;
    } else {
      // 约定：数字类型默认 0，文本类型默认空字符串
      defaults[col.fieldName] = col.dataType === 'number' ? 0 : '';
    }
  }

  return defaults;
}

/**
 * 过滤列定义（根据 Tab 的 columns 配置）
 */
export function filterColumns<T extends { field?: string; fieldName?: string }>(
  allColumns: T[],
  visibleFields: string[]
): T[] {
  if (!visibleFields || visibleFields.length === 0) return allColumns;

  return allColumns.filter(col => {
    const field = col.field || col.fieldName;
    return field && visibleFields.includes(field);
  });
}
