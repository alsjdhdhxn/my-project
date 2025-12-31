# Design Document: calc-engine-v4

## Overview

重构成本评估页面，实现四层解耦架构：

```
┌─────────────────────────────────────────────────────────────┐
│                    View Layer (视图层)                       │
│  eval-v4/index.vue - 纯布局和事件绑定，< 150 行              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Adapter Layer (适配层)                     │
│  useGridAdapter.ts - AG Grid ↔ Store 双向同步               │
│  - 监听 Store 变化 → Transaction API 更新 Grid              │
│  - 监听 Grid 编辑 → 通知 Store 更新                         │
│  - 编辑冲突处理（编辑中暂停响应式更新）                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    State Layer (状态层)                      │
│  useEvalStore.ts - Pinia Store，单一数据源                  │
│  - masterRows: 主表数据                                      │
│  - detailRows: 当前从表数据                                  │
│  - detailCache: 切换主表时的从表缓存                         │
│  - watchEffect: 响应式触发计算                               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Domain Layer (领域层)                      │
│  calculator.ts - 纯 TS 函数，无 Vue/AG Grid 依赖            │
│  - calcRowFields(): 行级计算                                 │
│  - calcAggregates(): 聚合计算                                │
│  - buildSaveParams(): 构建保存参数                           │
└─────────────────────────────────────────────────────────────┘
```

## Architecture

### 数据流

```
API 加载 → Pinia Store (JSON) → AG Grid (显示)
                ↑                    │
                │                    │ 用户编辑
                │                    ▼
                └──── Store.updateField() ←───┘
                           │
                           ▼
                    Calculator (纯函数)
                           │
                           ▼
                    Store 更新计算字段
                           │
                           ▼
                    AG Grid 刷新显示
```

### 核心原则

1. **Pinia 是数据库，AG Grid 是显示器** - 所有数据存储在 Store，Grid 只负责渲染
2. **单向数据流** - 用户编辑 → Store → Calculator → Store → Grid
3. **纯函数计算** - Calculator 不依赖 Vue/AG Grid，可独立测试
4. **响应式级联** - watchEffect 自动触发 A→B→C→D 计算
5. **约定大于配置** - 减少冗余配置，遵循命名约定
6. **组件可复用** - 所有组件从元数据驱动，不绑定具体业务

### 约定规则

| 约定 | 说明 | 效果 |
|------|------|------|
| 主表组件 key = `masterGrid` | 固定命名 | 从表自动关联，无需配置 |
| 从表组件 type = `TABS` | 自动识别 | 主表选中时自动加载从表 |
| 外键字段 = `PARENT_FK_COLUMN` | 从 TABLE_METADATA 读取 | 无需在页面配置中重复 |
| 计算列 `IS_VIRTUAL=1` | 标记计算列 | 自动不可编辑 |
| 数字类型默认值 = 0 | 自动处理 | 无需配置 default |
| 文本类型默认值 = '' | 自动处理 | 无需配置 default |

### 可复用组件设计

| 组件 | 输入 | 职责 | 适用场景 |
|------|------|------|----------|
| `useMasterDetailStore` | pageCode | 通用主从表 Store | 任何主从页面 |
| `useGridAdapter` | store, gridApi | Grid ↔ Store 同步 | 任何 AG Grid |
| `useCalcEngine` | calcRules, broadcast | 行级计算 + 广播 | 任何有计算的页面 |
| `useAggEngine` | aggregates | 聚合计算 | 任何有聚合的页面 |
| `MasterDetailPage` | pageCode | 通用主从页面 | 任何主从布局 |
| `MetaTabs` | COMPONENT_CONFIG | 多 Tab Grid 渲染 | 任何 TABS 组件 |

```vue
<!-- 任何主从页面都这样用，只传 pageCode -->
<MasterDetailPage pageCode="cost-eval" />
<MasterDetailPage pageCode="cost-order" />
<MasterDetailPage pageCode="cost-budget" />
```

### 潜在问题与解决方案

| # | 问题 | 风险等级 | 解决方案 |
|---|------|----------|----------|
| 1 | watchEffect 频繁触发 | 中 | 使用 watchEffect + nextTick 批量处理 |
| 2 | 编辑冲突 | 高 | 细粒度控制：只暂停当前编辑单元格，其他单元格正常更新 |
| 3 | detailCache 内存膨胀 | 中 | 限制缓存数量（如最多 10 个），超出时清理最早的 |
| 4 | multi 模式复杂性 | 中 | 使用 Map<tabKey, { rows, columns, calcRules }> 结构 |
| 5 | setRowData 丢失状态 | 高 | 使用 applyTransaction({ update }) 增量更新 |
| 6 | 计算依赖顺序 | 高 | 拓扑排序 + 多轮计算直到稳定（最多 3 轮） |
| 7 | 新增主表行的从表 | 中 | selectMaster 检测新增行，初始化空从表 |
| 8 | 新增行保存后外键 | 高 | 保存成功后重新加载数据，或后端返回映射关系 |
| 9 | multi 模式保存 | 中 | buildSaveParams 区分 group/multi 模式 |
| 10 | watch deep 性能 | 中 | 改用 computed + shallowRef，或监听 length |
| 11 | clearChanges 内部字段 | 低 | 过滤 _ 开头的字段再创建 _originalValues |

### 深度风险分析（稳定性关键）

#### 风险 12: watchEffect 循环依赖导致无限循环

**场景**: 如果计算规则配置错误，A 依赖 B，B 依赖 A，会导致无限循环。

**解决方案**:
```typescript
// 1. 启动时检测循环依赖
function detectCycle(rules: CalcRule[]): string[] | null {
  const graph = new Map<string, string[]>();
  rules.forEach(r => graph.set(r.field, r.dependencies));
  
  const visited = new Set<string>();
  const stack = new Set<string>();
  
  function dfs(node: string, path: string[]): string[] | null {
    if (stack.has(node)) return [...path, node]; // 发现循环
    if (visited.has(node)) return null;
    
    visited.add(node);
    stack.add(node);
    
    for (const dep of graph.get(node) || []) {
      const cycle = dfs(dep, [...path, node]);
      if (cycle) return cycle;
    }
    
    stack.delete(node);
    return null;
  }
  
  for (const field of graph.keys()) {
    const cycle = dfs(field, []);
    if (cycle) return cycle;
  }
  return null;
}

// 2. 运行时保护：最多 3 轮计算
const MAX_CALC_ROUNDS = 3;
```

#### 风险 13: applyTransaction 行匹配失败

**场景**: AG Grid 的 `applyTransaction({ update })` 依赖 `getRowId` 匹配行。如果 ID 不一致（如新增行的临时 ID），会导致更新失败。

**解决方案**:
```typescript
// Grid 配置必须设置 getRowId
const gridOptions = {
  getRowId: (params) => String(params.data.id),
  // ...
};

// Adapter 中处理新增行
function syncToGrid(newRows: RowData[]) {
  const api = gridApi.value;
  if (!api) return;
  
  const currentIds = new Set<string>();
  api.forEachNode(node => currentIds.add(String(node.data?.id)));
  
  const toAdd = newRows.filter(r => !currentIds.has(String(r.id)));
  const toUpdate = newRows.filter(r => currentIds.has(String(r.id)));
  const toRemove: any[] = [];
  
  api.forEachNode(node => {
    if (!newRows.some(r => r.id === node.data?.id)) {
      toRemove.push(node.data);
    }
  });
  
  api.applyTransaction({ add: toAdd, update: toUpdate, remove: toRemove });
}
```

#### 风险 14: 浮点数精度导致变更检测误判

**场景**: `0.1 + 0.2 !== 0.3`，导致计算后的值与原值比较时误判为"已变更"。

**解决方案**:
```typescript
const EPSILON = 0.0001;

function isValueEqual(a: any, b: any): boolean {
  if (a === b) return true;
  if (typeof a === 'number' && typeof b === 'number') {
    return Math.abs(a - b) < EPSILON;
  }
  return false;
}

// 在 markChange 和 isDirty 计算中统一使用
```

#### 风险 15: 切换主表时从表数据丢失

**场景**: 用户在从表新增行后，切换主表，再切回来，新增行丢失。

**解决方案**:
```typescript
function selectMaster(id: number) {
  // 1. 先缓存当前从表（包括新增行）
  if (currentMasterId.value != null) {
    saveToCache(currentMasterId.value, [...detailRows.value]);
  }
  
  // 2. 切换
  currentMasterId.value = id;
  
  // 3. 从缓存恢复（如果有）
  if (detailCache.has(id)) {
    detailRows.value = detailCache.get(id)!;
    updateCacheOrder(id);
  } else {
    // 需要从 API 加载
    detailRows.value = [];
  }
}
```

#### 风险 16: 并发编辑导致数据覆盖

**场景**: 用户 A 和用户 B 同时编辑同一行，后保存的覆盖先保存的。

**解决方案**:
```typescript
// 后端使用 updateTime 做乐观锁检查（已有）
// 前端保存时携带 updateTime
const saveItem = {
  id: row.id,
  data: { ... },
  updateTime: row.updateTime  // 后端会校验
};

// 后端返回 409 Conflict 时，提示用户刷新
if (error?.code === 409) {
  message.error('数据已被其他用户修改，请刷新后重试');
}
```

#### 风险 17: 大数据量下 watchEffect 性能问题

**场景**: 从表有 1000+ 行时，每次主表字段变化都要遍历计算所有行。

**解决方案**:
```typescript
// 1. 使用 Web Worker 处理计算（可选）
// 2. 分批处理 + requestIdleCallback
async function batchCalc(rows: RowData[], context: any, rules: CalcRule[]) {
  const BATCH_SIZE = 100;
  for (let i = 0; i < rows.length; i += BATCH_SIZE) {
    const batch = rows.slice(i, i + BATCH_SIZE);
    batch.forEach(row => {
      const results = calcRowFields(row, context, rules);
      Object.assign(row, results);
    });
    
    // 让出主线程
    if (i + BATCH_SIZE < rows.length) {
      await new Promise(r => requestIdleCallback(r));
    }
  }
}

// 3. 实际场景：成本评估从表通常 < 100 行，暂不需要优化
```

#### 风险 18: Tab 切换时 Grid 未正确刷新

**场景**: 隐藏的 Tab 对应的 Grid 没有挂载，切换回来时数据不同步。

**解决方案**:
```typescript
// 使用 v-show 而非 v-if，保持 Grid 实例
<div v-for="tab in tabs" :key="tab.key" v-show="tab.visible">
  <AgGridVue ... />
</div>

// 或者在 Tab 切换时强制刷新
watch(() => visibleTabs.value, () => {
  nextTick(() => {
    visibleTabs.value.forEach(tab => {
      const api = gridApis.get(tab.key);
      api?.refreshCells({ force: true });
    });
  });
});
```

#### 风险 19: 删除行后聚合计算不更新

**场景**: 用户删除从表行，但主表的聚合字段没有重新计算。

**解决方案**:
```typescript
function deleteRow(rowId: number, isMaster: boolean) {
  // ... 删除逻辑
  
  // 触发聚合重算
  if (!isMaster) {
    nextTick(() => {
      const aggResults = calcAggregates(visibleDetailRows.value, aggRules.value);
      // 更新主表
    });
  }
}
```

#### 风险 20: 保存失败后状态不一致

**场景**: 保存部分成功后网络断开，导致前端状态与后端不一致。

**解决方案**:
```typescript
async function handleSave() {
  // 1. 保存前快照
  const snapshot = {
    masterRows: JSON.parse(JSON.stringify(masterRows.value)),
    detailRows: JSON.parse(JSON.stringify(detailRows.value)),
    detailCache: new Map(detailCache)
  };
  
  try {
    await saveDynamicData(params);
    // 成功：清除变更标记
    clearChanges();
  } catch (e) {
    // 失败：恢复快照（可选，或保持当前状态让用户重试）
    message.error('保存失败，请重试');
    // 不恢复快照，让用户可以重试
  }
}
```

#### 风险 21: mathjs 表达式注入

**场景**: 如果计算表达式来自用户输入（虽然目前是元数据配置），可能存在代码注入风险。

**解决方案**:
```typescript
// 1. 表达式只能来自元数据（数据库配置），不接受用户输入
// 2. 使用 mathjs 的 limitedEvaluate 限制可用函数
import { create, all } from 'mathjs';

const math = create(all);
const limitedEvaluate = math.evaluate;

// 禁用危险函数
math.import({
  import: function () { throw new Error('Function import is disabled'); },
  createUnit: function () { throw new Error('Function createUnit is disabled'); },
  evaluate: function () { throw new Error('Function evaluate is disabled'); },
  parse: function () { throw new Error('Function parse is disabled'); },
  simplify: function () { throw new Error('Function simplify is disabled'); },
  derivative: function () { throw new Error('Function derivative is disabled'); }
}, { override: true });
```

#### 风险 22: 新增行的临时 ID 冲突

**场景**: 快速连续新增多行，`-Date.now()` 可能产生相同 ID。

**解决方案**:
```typescript
let tempIdCounter = 0;

function generateTempId(): number {
  return -(Date.now() * 1000 + tempIdCounter++);
}

// 或使用 UUID
import { nanoid } from 'nanoid';
function generateTempId(): string {
  return `temp_${nanoid()}`;
}
```

### 风险等级汇总

| 等级 | 数量 | 问题编号 |
|------|------|----------|
| 高 | 5 | 2, 5, 6, 8, 16 |
| 中 | 9 | 1, 3, 4, 7, 9, 10, 12, 15, 17 |
| 低 | 8 | 11, 13, 14, 18, 19, 20, 21, 22 |

### 关键实现检查清单

- [ ] 循环依赖检测（启动时）
- [ ] 浮点数比较使用 EPSILON
- [ ] applyTransaction 正确配置 getRowId
- [ ] 切换主表时正确缓存/恢复从表
- [ ] 删除行后触发聚合重算
- [ ] 临时 ID 生成不冲突
- [ ] watchEffect 有 calcPending 防抖
- [ ] 多轮计算有 MAX_ROUNDS 限制

## Components and Interfaces

### 1. Domain Layer: calculator.ts

```typescript
// src/logic/calc-engine/calculator.ts

/** 计算规则（从元数据解析） */
export interface CalcRule {
  field: string;
  expression: string;
  dependencies: string[];
  order: number;
}

/** 聚合规则（从页面组件解析） */
export interface AggRule {
  sourceField: string;
  targetField: string;
  algorithm: 'SUM' | 'AVG' | 'COUNT' | 'MAX' | 'MIN';
  filter?: string; // "useFlag=='原料'"
}

/** Tab 配置 */
export interface TabConfig {
  key: string;
  title: string;
  mode: 'group' | 'multi';
  // group 模式
  groupField?: string;
  groupValue?: string;
  // multi 模式
  tableCode?: string;
  // 通用
  columns: string[];
  sumField?: string;
  sumTo?: string;
}

/**
 * 行级计算 - 纯函数
 * @param row 行数据
 * @param context 上下文（主表字段如 apexPl, yield）
 * @param rules 计算规则
 * @returns 计算后的字段值 Map
 */
export function calcRowFields(
  row: Record<string, any>,
  context: Record<string, any>,
  rules: CalcRule[]
): Record<string, number>;

/**
 * 聚合计算 - 纯函数
 * @param rows 从表行数组
 * @param rules 聚合规则
 * @returns 聚合结果 Map
 */
export function calcAggregates(
  rows: Record<string, any>[],
  rules: AggRule[]
): Record<string, number>;

/**
 * 构建保存参数 - 纯函数
 */
export function buildSaveParams(
  masterRows: RowData[],
  detailCache: Map<number, RowData[]>,
  currentMasterId: number | null,
  currentDetails: RowData[]
): SaveParam[];

/**
 * 解析元数据中的计算规则
 */
export function parseCalcRules(columns: ColumnMetadata[]): CalcRule[];

/**
 * 解析页面组件中的聚合规则
 */
export function parseAggRules(components: PageComponent[]): AggRule[];

/**
 * 解析 Tab 配置
 */
export function parseTabConfig(components: PageComponent[]): TabConfig[];
```

### 2. State Layer: useEvalStore.ts

```typescript
// src/stores/useEvalStore.ts

export interface RowData {
  id: number | null;
  _isNew?: boolean;
  _isDeleted?: boolean;
  _changeType?: Record<string, 'user' | 'cascade'>;
  _originalValues?: Record<string, any>;
  [key: string]: any;
}

// 缓存配置
const MAX_CACHE_SIZE = 10;

export const useEvalStore = defineStore('eval-v4', () => {
  // ========== State ==========
  const masterRows = ref<RowData[]>([]);
  const currentMasterId = ref<number | null>(null);
  const detailRows = ref<RowData[]>([]);
  
  // 使用 Map 管理缓存，支持 LRU 清理
  const detailCache = reactive(new Map<number, RowData[]>());
  const cacheOrder = ref<number[]>([]); // 记录访问顺序，用于 LRU
  
  // 元数据
  const calcRules = ref<CalcRule[]>([]);
  const aggRules = ref<AggRule[]>([]);
  const tabConfig = ref<TabConfig[]>([]);
  
  // multi 模式：每个 Tab 独立的数据和元数据
  const multiTabData = reactive(new Map<string, {
    rows: RowData[];
    columns: any[];
    calcRules: CalcRule[];
  }>());
  
  // ========== Getters ==========
  const currentMaster = computed(() => 
    masterRows.value.find(r => r.id === currentMasterId.value)
  );
  
  const visibleMasterRows = computed(() => 
    masterRows.value.filter(r => !r._isDeleted)
  );
  
  const visibleDetailRows = computed(() => 
    detailRows.value.filter(r => !r._isDeleted)
  );
  
  // 按 Tab 分组的从表数据（group 模式）
  const detailRowsByTab = computed(() => {
    const result: Record<string, RowData[]> = {};
    for (const tab of tabConfig.value) {
      if (tab.mode === 'group' && tab.groupField) {
        result[tab.key] = visibleDetailRows.value.filter(
          r => r[tab.groupField!] === tab.groupValue
        );
      } else if (tab.mode === 'multi') {
        result[tab.key] = multiTabData.get(tab.key)?.rows.filter(r => !r._isDeleted) || [];
      }
    }
    return result;
  });
  
  const isDirty = computed(() => {
    // 检查主表
    if (masterRows.value.some(r => r._isNew || r._isDeleted || Object.keys(r._changeType || {}).length > 0)) {
      return true;
    }
    // 检查当前从表
    if (detailRows.value.some(r => r._isNew || r._isDeleted || Object.keys(r._changeType || {}).length > 0)) {
      return true;
    }
    // 检查缓存
    for (const rows of detailCache.values()) {
      if (rows.some(r => r._isNew || r._isDeleted || Object.keys(r._changeType || {}).length > 0)) {
        return true;
      }
    }
    return false;
  });
  
  // ========== Actions ==========
  function loadMaster(data: any[]) {
    masterRows.value = data.map(row => ({
      ...row,
      _changeType: {},
      _originalValues: { ...row }
    }));
  }
  
  function loadDetail(data: any[]) {
    detailRows.value = data.map(row => ({
      ...row,
      _changeType: {},
      _originalValues: { ...row }
    }));
  }
  
  function selectMaster(id: number) {
    // 缓存当前从表
    if (currentMasterId.value != null) {
      saveToCache(currentMasterId.value, [...detailRows.value]);
    }
    
    currentMasterId.value = id;
    
    // 检查是否是新增行（负数 ID）
    const masterRow = masterRows.value.find(r => r.id === id);
    if (masterRow?._isNew) {
      // 新增行，初始化空从表
      detailRows.value = [];
      return;
    }
    
    // 从缓存加载或返回空（需要外部调用 loadDetail）
    if (detailCache.has(id)) {
      detailRows.value = detailCache.get(id)!;
      updateCacheOrder(id);
    } else {
      detailRows.value = [];
    }
  }
  
  function saveToCache(masterId: number, rows: RowData[]) {
    // LRU 清理
    if (detailCache.size >= MAX_CACHE_SIZE && !detailCache.has(masterId)) {
      const oldest = cacheOrder.value.shift();
      if (oldest != null) {
        detailCache.delete(oldest);
      }
    }
    
    detailCache.set(masterId, rows);
    updateCacheOrder(masterId);
  }
  
  function updateCacheOrder(masterId: number) {
    const idx = cacheOrder.value.indexOf(masterId);
    if (idx > -1) {
      cacheOrder.value.splice(idx, 1);
    }
    cacheOrder.value.push(masterId);
  }
  
  function updateField(rowId: number, field: string, value: any, type: 'user' | 'cascade') {
    // 查找行（主表或从表）
    let row = masterRows.value.find(r => r.id === rowId);
    if (!row) {
      row = detailRows.value.find(r => r.id === rowId);
    }
    if (!row) return;
    
    // 更新值
    row[field] = value;
    
    // 标记变更
    if (!row._changeType) row._changeType = {};
    const originalValue = row._originalValues?.[field];
    
    // 比较是否恢复原值
    const isEqual = value === originalValue || 
      (typeof value === 'number' && typeof originalValue === 'number' && 
       Math.abs(value - originalValue) < 0.0001);
    
    if (isEqual) {
      delete row._changeType[field];
    } else {
      row._changeType[field] = type;
    }
  }
  
  function addMasterRow(defaults: Record<string, any>) {
    const tempId = -Date.now();
    const newRow: RowData = {
      id: tempId,
      ...defaults,
      _isNew: true,
      _changeType: {},
      _originalValues: {}
    };
    masterRows.value.push(newRow);
    return newRow;
  }
  
  function addDetailRow(tabKey: string, defaults: Record<string, any>) {
    const tempId = -Date.now() - Math.random();
    const tab = tabConfig.value.find(t => t.key === tabKey);
    
    const newRow: RowData = {
      id: tempId,
      ...defaults,
      _isNew: true,
      _changeType: {},
      _originalValues: {}
    };
    
    // 设置分组字段
    if (tab?.mode === 'group' && tab.groupField) {
      newRow[tab.groupField] = tab.groupValue;
    }
    
    detailRows.value.push(newRow);
    return newRow;
  }
  
  function deleteRow(rowId: number, isMaster: boolean) {
    const rows = isMaster ? masterRows.value : detailRows.value;
    const row = rows.find(r => r.id === rowId);
    if (!row) return;
    
    if (row._isNew) {
      // 新增行直接移除
      const idx = rows.indexOf(row);
      if (idx > -1) rows.splice(idx, 1);
    } else {
      // 已有行标记删除
      row._isDeleted = true;
    }
    
    // 如果删除主表行，清理缓存
    if (isMaster && detailCache.has(rowId)) {
      detailCache.delete(rowId);
    }
  }
  
  function clearChanges() {
    // 辅助函数：过滤内部字段
    const filterInternalFields = (obj: any) => {
      const result: Record<string, any> = {};
      for (const [key, value] of Object.entries(obj)) {
        if (!key.startsWith('_')) {
          result[key] = value;
        }
      }
      return result;
    };
    
    // 清除主表变更标记
    masterRows.value = masterRows.value
      .filter(r => !r._isDeleted)
      .map(r => ({
        ...r,
        _isNew: false,
        _changeType: {},
        _originalValues: filterInternalFields(r)
      }));
    
    // 清除从表变更标记
    detailRows.value = detailRows.value
      .filter(r => !r._isDeleted)
      .map(r => ({
        ...r,
        _isNew: false,
        _changeType: {},
        _originalValues: filterInternalFields(r)
      }));
    
    // 清除缓存
    detailCache.clear();
    cacheOrder.value = [];
  }
  
  // ========== 响应式计算 ==========
  // 使用 watchEffect + nextTick 批量处理
  let calcPending = false;
  
  watchEffect(() => {
    if (!currentMaster.value || calcPending) return;
    
    // 读取依赖（触发响应式追踪）
    const apexPl = currentMaster.value.apexPl || 0;
    const yieldVal = currentMaster.value.yield || 100;
    
    // 批量处理
    calcPending = true;
    nextTick(() => {
      const context = { apexPl, yield: yieldVal };
      
      // 多轮计算直到稳定（最多 3 轮）
      for (let round = 0; round < 3; round++) {
        let hasChange = false;
        
        for (const row of detailRows.value) {
          if (row._isDeleted) continue;
          const results = calcRowFields(row, context, calcRules.value);
          for (const [field, value] of Object.entries(results)) {
            if (Math.abs((row[field] || 0) - value) > 0.0001) {
              row[field] = value;
              markChange(row.id, field, 'cascade');
              hasChange = true;
            }
          }
        }
        
        if (!hasChange) break;
      }
      
      // 聚合计算
      const aggResults = calcAggregates(visibleDetailRows.value, aggRules.value);
      for (const [field, value] of Object.entries(aggResults)) {
        if (Math.abs((currentMaster.value![field] || 0) - value) > 0.0001) {
          currentMaster.value![field] = value;
          markChange(currentMaster.value!.id, field, 'cascade');
        }
      }
      
      calcPending = false;
    });
  });
  
  function markChange(rowId: any, field: string, type: 'user' | 'cascade') {
    let row = masterRows.value.find(r => r.id === rowId);
    if (!row) row = detailRows.value.find(r => r.id === rowId);
    if (!row) return;
    
    if (!row._changeType) row._changeType = {};
    const originalValue = row._originalValues?.[field];
    const currentValue = row[field];
    
    const isEqual = currentValue === originalValue || 
      (typeof currentValue === 'number' && typeof originalValue === 'number' && 
       Math.abs(currentValue - originalValue) < 0.0001);
    
    if (isEqual) {
      delete row._changeType[field];
    } else {
      row._changeType[field] = type;
    }
  }
  
  return {
    masterRows, currentMasterId, detailRows, detailCache, multiTabData,
    currentMaster, visibleMasterRows, visibleDetailRows, detailRowsByTab,
    isDirty, calcRules, aggRules, tabConfig,
    loadMaster, loadDetail, selectMaster, updateField,
    addMasterRow, addDetailRow, deleteRow, clearChanges
  };
});
```

### 3. Adapter Layer: useGridAdapter.ts

```typescript
// src/composables/useGridAdapter.ts

export interface GridAdapterOptions {
  store: ReturnType<typeof useEvalStore>;
  gridApi: Ref<GridApi | null>;
  rowsGetter: () => RowData[];
  pkField?: string;
}

export function useGridAdapter(options: GridAdapterOptions) {
  const { store, gridApi, rowsGetter, pkField = 'id' } = options;
  
  // 当前正在编辑的单元格（细粒度控制）
  const editingCell = ref<{ rowId: any; field: string } | null>(null);
  
  // 监听 Store 变化，同步到 Grid（使用 applyTransaction 增量更新）
  watch(
    () => rowsGetter(),
    (newRows) => {
      if (!gridApi.value) return;
      
      // 使用 applyTransaction 增量更新，保持滚动位置
      gridApi.value.applyTransaction({ update: [...newRows] });
      
      // 刷新单元格样式（排除正在编辑的单元格）
      const rowNodes: any[] = [];
      gridApi.value.forEachNode(node => {
        if (editingCell.value && node.data?.[pkField] === editingCell.value.rowId) {
          // 正在编辑的行，只刷新非编辑列
          gridApi.value!.refreshCells({
            rowNodes: [node],
            columns: Object.keys(node.data).filter(c => c !== editingCell.value!.field),
            force: true
          });
        } else {
          rowNodes.push(node);
        }
      });
      
      if (rowNodes.length > 0) {
        gridApi.value.refreshCells({ rowNodes, force: true });
      }
    },
    { deep: true }
  );
  
  // Grid 编辑事件处理
  function onCellValueChanged(event: CellValueChangedEvent) {
    const field = event.colDef.field;
    const rowId = event.data?.[pkField];
    if (!field || rowId == null) return;
    
    // 通知 Store 更新
    store.updateField(rowId, field, event.newValue, 'user');
  }
  
  function onCellEditingStarted(event: any) {
    editingCell.value = {
      rowId: event.data?.[pkField],
      field: event.colDef?.field
    };
  }
  
  function onCellEditingStopped() {
    editingCell.value = null;
  }
  
  return {
    editingCell,
    onCellValueChanged,
    onCellEditingStarted,
    onCellEditingStopped
  };
}
```

### 4. View Layer: index.vue

```vue
<!-- src/views/cost/eval-v4/index.vue -->
<template>
  <div class="eval-v4-page">
    <MetaFloatToolbar>
      <!-- 工具栏内容 -->
    </MetaFloatToolbar>
    
    <NSplit v-if="isReady" direction="vertical" :default-size="0.5">
      <template #1>
        <AgGridVue
          :rowData="store.visibleMasterRows"
          :columnDefs="masterColumns"
          @grid-ready="onMasterGridReady"
          @cell-value-changed="masterAdapter.onCellValueChanged"
          @selection-changed="onMasterSelectionChanged"
        />
      </template>
      
      <template #2>
        <div class="detail-grids">
          <div v-for="tab in visibleTabs" :key="tab.key">
            <AgGridVue
              :rowData="store.detailRowsByTab[tab.key]"
              :columnDefs="getDetailColumns(tab)"
              @cell-value-changed="(e) => detailAdapter.onCellValueChanged(e, tab.key)"
            />
          </div>
        </div>
      </template>
    </NSplit>
  </div>
</template>

<script setup lang="ts">
// 约 100 行：初始化、事件绑定、生命周期
</script>
```

## Data Models

### RowData 结构

```typescript
interface RowData {
  // 业务字段
  id: number | null;
  evalNo?: string;
  productName?: string;
  apexPl?: number;
  yield?: number;
  // ... 其他业务字段
  
  // 内部状态字段（以 _ 开头）
  _isNew?: boolean;           // 新增行
  _isDeleted?: boolean;       // 已删除
  _changeType?: Record<string, 'user' | 'cascade'>;  // 字段变更类型
  _originalValues?: Record<string, any>;  // 原始值快照
}
```

### Tab 配置结构（数据库）

```json
{
  "mode": "group",
  "masterGrid": "masterGrid",
  "groupField": "useFlag",
  "tabs": [
    {
      "key": "material",
      "title": "原料",
      "value": "原料",
      "columns": ["materialName", "perHl", "price", "batchQty", "costBatch"],
      "sumField": "costBatch",
      "sumTo": "totalYl"
    },
    {
      "key": "package",
      "title": "包材",
      "value": "包材",
      "columns": ["materialName", "packSpec", "price", "packQty", "packCost"],
      "sumField": "packCost",
      "sumTo": "totalPack"
    }
  ]
}
```

### 多表模式配置

```json
{
  "mode": "multi",
  "masterGrid": "masterGrid",
  "tabs": [
    {
      "key": "material",
      "title": "原料",
      "tableCode": "CostEvalMaterial",
      "columns": ["materialName", "perHl", "price", "batchQty", "costBatch"]
    },
    {
      "key": "labor",
      "title": "人工",
      "tableCode": "CostEvalLabor",
      "columns": ["laborType", "hours", "rate", "cost"]
    }
  ]
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Calculator Pure Function Correctness

*For any* row data and context, calling `calcRowFields()` with the same inputs SHALL always produce the same outputs, and the function SHALL not modify the input objects.

**Validates: Requirements 3.2, 3.3, 3.4**

### Property 2: Cascade Calculation Chain

*For any* master row with fields (apexPl, yield) and detail rows with fields (perHl, price), when master fields change, the cascade calculation SHALL produce:
- batchQty = apexPl * perHl / 100 / yield * 100
- costBatch = batchQty * price
- totalYl = SUM(costBatch) where useFlag='原料'

**Validates: Requirements 4.1, 4.2, 4.3**

### Property 3: Change Tracking State Management

*For any* row, after a field is modified:
- If modified by user, `_changeType[field]` SHALL be 'user'
- If modified by calculation, `_changeType[field]` SHALL be 'cascade'
- If value returns to `_originalValues[field]`, the change marker SHALL be removed

**Validates: Requirements 6.1, 6.2, 6.3**

### Property 4: Tab Mode Configuration

*For any* Tab configuration:
- If mode='group', rows SHALL be filtered by groupField matching groupValue
- If mode='multi', each tab SHALL load from its own tableCode
- Both modes SHALL support all calculation and aggregation features

**Validates: Requirements 5.2, 5.3, 5.6**

### Property 5: Aggregation Calculation

*For any* set of detail rows and aggregation rules:
- SUM algorithm SHALL return sum of sourceField values
- Filter expression SHALL correctly filter rows before aggregation
- Result SHALL be assigned to targetField on master row

**Validates: Requirements 13.1, 13.2, 13.3, 13.4**

### Property 6: Save Parameter Construction

*For any* set of changed rows:
- Only rows with _isNew, _isDeleted, or non-empty _changeType SHALL be included
- Each record SHALL have correct status (added/modified/deleted)
- Changes array SHALL include oldValue from _originalValues

**Validates: Requirements 19.1, 19.2, 19.3, 19.4, 19.5**

### Property 7: Validation Rule Execution

*For any* row and validation rules:
- Rules SHALL be executed in order specified by 'order' field
- First failing rule SHALL stop validation and return error
- All rule types (required, notZero, min, max, pattern) SHALL work correctly

**Validates: Requirements 10.1, 10.2, 10.3**

### Property 8: In-Place Mutation Performance

*For any* calculation operation, the Store SHALL mutate existing row objects in-place rather than creating new objects, preserving object identity.

**Validates: Requirements 4.4**

## Error Handling

1. **API 错误** - 显示错误消息，不修改 Store 状态
2. **计算错误** - 捕获异常，记录日志，返回 0 或保持原值
3. **验证错误** - 显示第一个错误消息，阻止保存
4. **元数据解析错误** - 记录警告，跳过无效配置

## Testing Strategy

### Unit Tests (单元测试)

- `calculator.test.ts` - 测试纯函数计算逻辑
- `validator.test.ts` - 测试验证规则
- `parser.test.ts` - 测试元数据解析

### Property-Based Tests (属性测试)

使用 fast-check 库进行属性测试：

```typescript
import fc from 'fast-check';

// Property 1: Calculator Pure Function
test('calcRowFields is pure', () => {
  fc.assert(
    fc.property(
      fc.record({ perHl: fc.float(), price: fc.float() }),
      fc.record({ apexPl: fc.float(), yield: fc.float({ min: 1 }) }),
      (row, context) => {
        const rowCopy = { ...row };
        const result1 = calcRowFields(row, context, rules);
        const result2 = calcRowFields(row, context, rules);
        
        // 结果相同
        expect(result1).toEqual(result2);
        // 输入未被修改
        expect(row).toEqual(rowCopy);
      }
    )
  );
});

// Property 2: Cascade Calculation
test('cascade calculation produces correct results', () => {
  fc.assert(
    fc.property(
      fc.float({ min: 0, max: 1000 }), // apexPl
      fc.float({ min: 1, max: 100 }),  // yield
      fc.float({ min: 0, max: 100 }),  // perHl
      fc.float({ min: 0, max: 1000 }), // price
      (apexPl, yieldVal, perHl, price) => {
        const expectedBatchQty = apexPl * perHl / 100 / yieldVal * 100;
        const expectedCostBatch = expectedBatchQty * price;
        
        const result = calcRowFields(
          { perHl, price },
          { apexPl, yield: yieldVal },
          rules
        );
        
        expect(result.batchQty).toBeCloseTo(expectedBatchQty, 2);
        expect(result.costBatch).toBeCloseTo(expectedCostBatch, 2);
      }
    )
  );
});
```

### Integration Tests

- 测试 Store 与 Calculator 的集成
- 测试 API 加载和保存流程
