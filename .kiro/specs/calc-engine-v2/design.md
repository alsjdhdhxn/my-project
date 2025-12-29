# 计算引擎 V2 - 技术设计

## 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                      DynamicPage                             │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  DataStore  │←→│ CalcEngine  │←→│   ChangeTracker     │  │
│  │  (Pinia)    │  │  (math.js)  │  │   (user/cascade)    │  │
│  └──────┬──────┘  └─────────────┘  └─────────────────────┘  │
│         │                                                    │
│         ▼                                                    │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    MetaGrid (render only)                ││
│  │  - 从 DataStore 读取数据                                  ││
│  │  - 编辑事件回写 DataStore                                 ││
│  │  - cellStyle 根据 _changeType 显示颜色                    ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## 模块设计

### 1. GridStore (useGridStore.ts)

> 实际实现使用 composable 而非 Pinia Store，支持多实例（主表、多个从表各自独立）

```typescript
export function useGridStore<T extends RowData = RowData>(options: GridStoreOptions = {}) {
  const rows: Ref<T[]> = ref([]);
  const isLoaded = ref(false);

  // 加载数据，保存原始值快照用于变更追踪
  function load(data: Record<string, any>[], preserveState = false) {
    rows.value = data.map(row => ({
      ...row,
      _changeType: preserveState ? (row._changeType || {}) : {},
      _originalValues: preserveState ? (row._originalValues || {...row}) : {...row}
    })) as T[];
    isLoaded.value = true;
  }

  // 更新字段
  function updateField(rowId: number | string, field: string, value: any) { ... }

  // 标记变更（比较原始值，相同则移除标记）
  function markChange(rowId: number | string, field: string, type: 'user' | 'cascade') { ... }

  // 新增行（临时负数ID）
  function addRow(data: Partial<T> = {}): T { ... }

  // 删除行（标记删除或直接移除新增行）
  function deleteRow(rowId: number | string) { ... }

  // 清除变更标记（保存成功后调用）
  function clearChanges() { ... }

  // 计算属性
  const isDirty = computed(() => ...);      // 是否有未保存修改
  const changedRows = computed(() => ...);  // 变更的行
  const visibleRows = computed(() => ...);  // 可见行（排除已删除）

  return { rows, visibleRows, isLoaded, isDirty, changedRows, load, getRow, updateField, markChange, addRow, deleteRow, reset, clearChanges };
}
```

### 2. CalcEngine (useCalcEngine.ts)

#### 数据结构示例（评估单）

```typescript
// 主表
master: {
  id: 1,
  apexPl: 100,      // 批量(万片) - 可编辑
  yield: 98,        // 收率(%) - 可编辑
  totalYl: 0,       // 原料合计 - 聚合计算（不可编辑）
  totalFl: 0,       // 辅料合计 - 聚合计算（不可编辑）
  totalCost: 0      // 总成本 - 聚合计算（不可编辑）
}

// 从表
details: [
  { id: 1, useFlag: '原料', perHl: 125.5, price: 280, batchQty: 0, costBatch: 0 },
  { id: 2, useFlag: '原料', perHl: 45.2,  price: 15,  batchQty: 0, costBatch: 0 },
  { id: 3, useFlag: '辅料', perHl: 1050,  price: 0.035, batchQty: 0, costBatch: 0 },
]
```

#### 计算规则配置

```typescript
import { compile, MathNode } from 'mathjs';

// 从表行内计算规则
interface CalcRule {
  field: string;           // 目标字段（不可编辑）
  expression: string;      // math.js 表达式
  dependencies: {
    master: string[];      // 依赖的主表字段
    detail: string[];      // 依赖的从表字段（同行）
  };
  order: number;           // 计算顺序（处理级联依赖）
}

// 聚合规则
interface AggRule {
  targetField: string;     // 主表目标字段
  sourceField: string;     // 从表源字段
  algorithm: 'SUM' | 'AVG' | 'COUNT' | 'MAX' | 'MIN';
  filter?: (row: Record<string, any>) => boolean;
}

// 硬编码示例（评估单）
const calcRules: CalcRule[] = [
  {
    field: 'batchQty',
    expression: 'master.apexPl * perHl / 100 / master.yield * 100',
    dependencies: { master: ['apexPl', 'yield'], detail: ['perHl'] },
    order: 1  // 先算
  },
  {
    field: 'costBatch',
    expression: 'batchQty * price',
    dependencies: { master: [], detail: ['batchQty', 'price'] },
    order: 2  // 后算（依赖 batchQty）
  }
];

const aggRules: AggRule[] = [
  { targetField: 'totalYl', sourceField: 'costBatch', algorithm: 'SUM', filter: row => row.useFlag === '原料' },
  { targetField: 'totalFl', sourceField: 'costBatch', algorithm: 'SUM', filter: row => row.useFlag === '辅料' },
  { targetField: 'totalCost', sourceField: 'costBatch', algorithm: 'SUM' }
];
```

#### 核心实现

```typescript
export function useCalcEngine(store: DataStore) {
  // 预编译表达式，按 order 排序
  const compiledRules = calcRules.map(rule => ({
    ...rule,
    compiled: compile(rule.expression)
  })).sort((a, b) => a.order - b.order);

  // 主表字段变化 → 批量计算所有从表行
  function onMasterChange(field: string) {
    // 1. 找出所有受影响的规则（包括级联）
    const affected = getAffectedRules('master', field);
    if (affected.length === 0) return;

    // 2. 批量计算所有从表行
    store.details.forEach(row => {
      affected.forEach(rule => {
        const scope = { master: store.master, ...row };
        row[rule.field] = round2(rule.compiled.evaluate(scope));
        row._changeType = row._changeType || {};
        row._changeType[rule.field] = 'cascade';
      });
    });

    // 3. 一次性聚合（不管多少行，只执行一次）
    runAggregates();
  }

  // 从表字段变化 → 只计算当前行
  function onDetailChange(rowId: number, field: string) {
    const row = store.details.find(r => r.id === rowId);
    if (!row) return;

    // 1. 找出所有受影响的规则（包括级联）
    const affected = getAffectedRules('detail', field);
    
    if (affected.length > 0) {
      // 2. 只计算当前行
      affected.forEach(rule => {
        const scope = { master: store.master, ...row };
        row[rule.field] = round2(rule.compiled.evaluate(scope));
        row._changeType = row._changeType || {};
        row._changeType[rule.field] = 'cascade';
      });
    }

    // 3. 聚合（即使没有计算规则，字段变化也可能影响聚合）
    runAggregates();
  }

  // 获取受影响的规则（BFS 处理级联依赖）
  function getAffectedRules(source: 'master' | 'detail', field: string) {
    const affected = new Set<string>();
    const queue = [field];

    while (queue.length > 0) {
      const current = queue.shift()!;
      compiledRules.forEach(rule => {
        const deps = source === 'master' ? rule.dependencies.master : rule.dependencies.detail;
        // 首次查找用原始 source，级联查找用 detail
        const checkDeps = affected.size === 0 ? deps : rule.dependencies.detail;
        if (checkDeps.includes(current) && !affected.has(rule.field)) {
          affected.add(rule.field);
          queue.push(rule.field); // 级联：这个字段变化可能影响其他规则
        }
      });
      // 首次查找后，后续都是 detail 内部级联
      source = 'detail';
    }

    // 按 order 排序返回
    return compiledRules.filter(r => affected.has(r.field));
  }

  // 执行聚合
  function runAggregates() {
    aggRules.forEach(rule => {
      const rows = rule.filter ? store.details.filter(rule.filter) : store.details;
      let result = 0;
      
      switch (rule.algorithm) {
        case 'SUM':
          result = rows.reduce((sum, r) => sum + (Number(r[rule.sourceField]) || 0), 0);
          break;
        case 'AVG':
          result = rows.length > 0 
            ? rows.reduce((sum, r) => sum + (Number(r[rule.sourceField]) || 0), 0) / rows.length 
            : 0;
          break;
        case 'COUNT':
          result = rows.length;
          break;
        case 'MAX':
          result = rows.length > 0 ? Math.max(...rows.map(r => Number(r[rule.sourceField]) || 0)) : 0;
          break;
        case 'MIN':
          result = rows.length > 0 ? Math.min(...rows.map(r => Number(r[rule.sourceField]) || 0)) : 0;
          break;
      }

      store.master[rule.targetField] = round2(result);
      store.master._changeType = store.master._changeType || {};
      store.master._changeType[rule.targetField] = 'cascade';
    });
  }

  function round2(v: number): number {
    return Math.round(v * 100) / 100;
  }

  return { onMasterChange, onDetailChange };
}
```

#### 场景验证

**场景1：主表 apexPl 从 100 改为 200**

```
触发：onMasterChange('apexPl')

执行流程：
1. getAffectedRules('master', 'apexPl')
   - batchQty 依赖 master.apexPl → 加入
   - costBatch 依赖 detail.batchQty → 级联加入
   - 返回 [batchQty, costBatch]（按 order 排序）

2. 遍历所有从表行，按顺序计算：
   - 行1: batchQty = 200*125.5/100/98*100 = 256.12
          costBatch = 256.12*280 = 71713.6
   - 行2: batchQty = 92.24, costBatch = 1383.6
   - 行3: batchQty = 2142.86, costBatch = 75.0

3. runAggregates()（一次）：
   - totalYl = 71713.6 + 1383.6 = 73097.2
   - totalFl = 75.0
   - totalCost = 73172.2

性能：3行计算 + 1次聚合，主表只更新1次
```

**场景2：从表第1行 perHl 从 125.5 改为 150**

```
触发：onDetailChange(1, 'perHl')

执行流程：
1. getAffectedRules('detail', 'perHl')
   - batchQty 依赖 detail.perHl → 加入
   - costBatch 依赖 detail.batchQty → 级联加入
   - 返回 [batchQty, costBatch]

2. 只计算行1：
   - batchQty = 100*150/100/98*100 = 153.06
   - costBatch = 153.06*280 = 42856.8

3. runAggregates()（一次）

性能：1行计算 + 1次聚合
```

**场景3：从表第1行 price 从 280 改为 300**

```
触发：onDetailChange(1, 'price')

执行流程：
1. getAffectedRules('detail', 'price')
   - costBatch 依赖 detail.price → 加入
   - 无其他级联
   - 返回 [costBatch]

2. 只计算行1：
   - costBatch = 128.06*300 = 38418.0

3. runAggregates()（一次）

性能：1行计算 + 1次聚合
```

#### 关键保障

| 机制 | 作用 |
|------|------|
| order 字段 | 保证 batchQty 先于 costBatch 计算 |
| BFS 级联查找 | 自动发现 batchQty → costBatch 依赖链 |
| 批量+延迟聚合 | 主表变化时遍历所有行，但聚合只执行一次 |
| 单行计算 | 从表变化时只算当前行，性能最优 |
| math.js 预编译 | 表达式只编译一次，执行时直接 evaluate |
```

### 3. AggEngine (useAggEngine.ts)

> 聚合计算从 CalcEngine 拆分为独立模块，支持从 PAGE_COMPONENT 的 LOGIC_AGG 配置读取规则

```typescript
export function useAggEngine() {
  const rules: AggRule[] = [];
  let dataSources: DataSourceMap = {};
  let targetStore: GridStore | null = null;

  // 注册聚合规则（从 LOGIC_AGG 组件配置解析）
  function registerAggRules(aggRules: AggRule[]) { ... }

  // 设置数据源映射（组件Key → Store）
  function setDataSources(sources: DataSourceMap) { ... }

  // 设置目标 Store 和当前行 ID
  function setTarget(store: GridStore, rowId: any) { ... }

  // 执行聚合计算（两轮：先聚合，再表达式）
  function calculate() {
    // 第一轮：SUM/AVG/COUNT 等聚合
    rules.forEach(rule => {
      if (rule.algorithm && rule.source && rule.sourceField) {
        const value = aggregate(filteredRows, rule.sourceField, rule.algorithm);
        results[rule.targetField] = value;
      }
    });

    // 第二轮：表达式计算（依赖第一轮结果）
    rules.forEach(rule => {
      if (rule.expression && !rule.algorithm) {
        const context = { ...currentRow, ...results };
        results[rule.targetField] = compile(rule.expression).evaluate(context);
      }
    });

    // 更新目标 Store 并标记为级联计算
    targetStore.updateFields(targetRowId, results);
    Object.keys(results).forEach(field => targetStore.markChange(targetRowId, field, 'cascade'));
  }

  return { registerAggRules, setDataSources, setTarget, calculate };
}

// 从 PAGE_COMPONENT 提取聚合规则
export function extractAggRules(components: PageComponent[]): AggRule[] { ... }
```

### 4. ChangeTracker（已集成到 GridStore）

> 变更追踪已集成到 useGridStore，通过 `_changeType` 和 `_originalValues` 字段实现

```typescript
interface RowData {
  id: number | null;
  _changeType?: Record<string, 'user' | 'cascade'>;  // 字段变更类型
  _originalValues?: Record<string, any>;              // 原始值快照
  _isNew?: boolean;                                   // 是否新增行
  _isDeleted?: boolean;                               // 是否已删除
  [key: string]: any;
}

// markChange 会比较当前值和原始值
// - 相同：移除变更标记
// - 不同：标记变更类型
```
```

### 5. MetaGrid 组件

> 纯渲染组件，数据来自 GridStore，支持 Lookup 弹窗

```typescript
const props = defineProps<{
  columns: ColDef[];
  store: GridStore;
  calcEngine?: CalcEngine;
  columnMeta?: ColumnMetadata[];  // 用于 Lookup 配置
  defaultNewRow?: Record<string, any>;
  firstEditableField?: string;
}>();

// 数据绑定
const rowData = computed(() => props.store.visibleRows.value);

// 单元格样式（变更追踪）
function getCellStyle(params: CellClassParams) {
  const changeType = params.data?._changeType?.[params.colDef?.field || ''];
  if (changeType === 'user') return { backgroundColor: '#e6ffe6' };
  if (changeType === 'cascade') return { backgroundColor: '#fffde6' };
  return null;
}

// 编辑回调
function onCellValueChanged(event: CellValueChangedEvent) {
  props.store.markChange(rowId, field, 'user');
  if (props.calcEngine) {
    props.calcEngine.onFieldChange(rowId, field);
  }
  // 刷新 Grid 显示
  gridApi.value.applyTransaction({ update: [row] });
  gridApi.value.refreshCells({ rowNodes: [rowNode], force: true });
}

// Lookup 点击处理
function onCellClicked(event: CellClickedEvent) {
  const lookupConfig = getLookupConfig(fieldName);
  if (lookupConfig) {
    lookupRef.value?.open();
  }
}

// Lookup 选择回调（多字段回填）
function onLookupSelect(data: Record<string, any>) {
  for (const [targetField, newValue] of Object.entries(data)) {
    props.store.updateField(rowId, targetField, newValue);
    props.store.markChange(rowId, targetField, 'user');
  }
  // 触发计算引擎
  changedFields.forEach(field => props.calcEngine?.onFieldChange(rowId, field));
}

// 快捷键
// Ctrl+Enter: 新增行
// Delete: 删除选中行
```
```

### 6. 布局（NSplit 可拖动分隔）

```vue
<template>
  <NSplit
    direction="vertical"
    :default-size="0.5"
    :min="0.2"
    :max="0.8"
    class="split-container"
  >
    <template #1>
      <div class="master-section">
        <MetaGrid :store="masterStore" ... />
      </div>
    </template>
    <template #2>
      <div class="detail-section">
        <!-- 多 Tab 并排显示 -->
        <div class="detail-grids">
          <div v-for="tab in visibleTabs" :key="tab.key" class="detail-grid-wrapper">
            <MetaGrid :store="detailStores[tab.key]" ... />
          </div>
        </div>
      </div>
    </template>
  </NSplit>
</template>

<style scoped>
.split-container { flex: 1; min-height: 0; }
.detail-grids { display: flex; gap: 1px; }
.detail-grid-wrapper { flex: 1; min-width: 0; }
</style>
```

## 错误边界

每个模块用 try-catch 包裹，出错时：
1. 记录错误日志
2. 显示友好提示
3. 不影响其他模块运行

```typescript
function safeExecute<T>(fn: () => T, fallback: T, context: string): T {
  try {
    return fn();
  } catch (e) {
    console.error(`[${context}] 执行错误:`, e);
    return fallback;
  }
}
```

## 操作日志 API

```typescript
// POST /api/operation-log
interface OperationLog {
  // 基础信息
  userId: number;
  userName: string;
  ip: string;
  userAgent: string;
  
  // 操作信息
  tableCode: string;
  rowId: number;
  operation: 'UPDATE' | 'INSERT' | 'DELETE';
  changes: { field: string; oldValue: any; newValue: any }[];
  
  // 耗时分类（毫秒）
  timing: {
    total: number;           // 总耗时
    frontend: {
      validation: number;    // 前端校验
      serialize: number;     // 数据序列化
      request: number;       // 网络请求（从发起到收到响应）
    };
    backend: {
      total: number;         // 后端总耗时
      connection: number;    // 获取数据库连接
      validation: number;    // 后端校验
      sqlExecution: number;  // SQL 执行
      commit: number;        // 事务提交
      other: number;         // 其他（日志、缓存等）
    };
  };
  
  timestamp: string;
}
```

### 耗时采集方案

**前端采集：**
```typescript
const timing = {
  frontend: { validation: 0, serialize: 0, request: 0 },
  backend: { total: 0, connection: 0, validation: 0, sqlExecution: 0, commit: 0, other: 0 }
};

// 1. 校验耗时
const t1 = performance.now();
await validate();
timing.frontend.validation = performance.now() - t1;

// 2. 序列化耗时
const t2 = performance.now();
const payload = JSON.stringify(data);
timing.frontend.serialize = performance.now() - t2;

// 3. 请求耗时
const t3 = performance.now();
const response = await api.save(payload);
timing.frontend.request = performance.now() - t3;

// 4. 后端耗时从响应头获取
timing.backend = response.headers['X-Timing'];
```

**后端采集（拦截器 + ThreadLocal）：**
```java
@Component
public class TimingContext {
    private static final ThreadLocal<Map<String, Long>> TIMING = ThreadLocal.withInitial(HashMap::new);
    
    public static void record(String phase, long millis) {
        TIMING.get().put(phase, millis);
    }
    
    public static Map<String, Long> get() {
        return TIMING.get();
    }
    
    public static void clear() {
        TIMING.remove();
    }
}

// 在各阶段记录
// 1. 获取连接
long t1 = System.currentTimeMillis();
Connection conn = dataSource.getConnection();
TimingContext.record("connection", System.currentTimeMillis() - t1);

// 2. SQL 执行
long t2 = System.currentTimeMillis();
jdbcTemplate.update(sql, params);
TimingContext.record("sqlExecution", System.currentTimeMillis() - t2);

// 响应拦截器写入 Header
response.setHeader("X-Timing", JSON.toJSONString(TimingContext.get()));
TimingContext.clear();
```

后端异步写入日志表，不阻塞保存流程。
