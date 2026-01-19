# Meta-V2 契约说明（Runtime / 渲染器 / 错误隔离）

本文档定义 Meta-V2 的运行时契约、渲染器契约以及错误隔离与日志规范，用于保证组件解耦、可扩展与可维护。

---

## 1. 运行时契约（MetaRuntime）

### 1.1 运行时核心结构
MetaRuntime 必须提供以下核心字段（最小可用）：

```ts
type MetaRuntime = {
  pageCode: string;
  componentStateByKey: Ref<ComponentStateByKey> | ComponentStateByKey;
  status?: Ref<'loading' | 'ready' | 'error'> | 'loading' | 'ready' | 'error';
  pageError?: Ref<MetaError | null> | MetaError | null;
  reportComponentError?: (componentKey: string, stage: RuntimeStage, message: string, raw?: unknown) => void;
};
```

要求：
- `componentStateByKey` 为组件状态的唯一入口（渲染器只读该结构）。
- `ComponentState` 结构必须为“纯值”（不直接存 Ref）；渲染器端会做 `unref` 防御，但不应依赖。

### 1.2 初始化阶段（6 阶段）
执行顺序如下：
```
loadComponents → parseConfig → loadMeta → compileRules → buildStates → applyExtensions
```
规则：
- `loadComponents` / `parseConfig` 失败 → 页面级 `status=error`，渲染错误占位。
- 其余阶段失败 → 只影响对应组件，记录 `componentState.status=error`，页面继续渲染。

### 1.3 功能开关（features）
原则：**不再做页面级 Runtime 切换**，由 Runtime 根据元数据自动判断：

- `detailTabs`：`pageConfig.tabs` 是否存在
- `broadcast`：`broadcastFields` 是否存在
- `aggregates`：`compiledAggRules` 是否存在
- `lookup`：主/从 lookup 规则是否存在
- `export/contextMenu`：是否存在 GRID 组件

Runtime 会基于上述判断自动更新 `features`，并在关键方法处做 gating（如 `broadcastToDetail`、`runDetailCalc`、`export*`）。

---

## 2. ComponentState 契约

### 2.1 公共字段
```ts
type ComponentStateBase = {
  componentKey: string;
  componentType: string;
  status: 'ready' | 'loading' | 'error';
  error?: MetaError;
};
```

### 2.2 GridState
```ts
type GridState = ComponentStateBase & {
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
```

### 2.3 FormState
```ts
type FormState = ComponentStateBase & {
  renderer?: any;        // 自定义渲染器
  placeholder?: string;  // 未配置时的占位文案
};
```

### 2.4 ButtonState
```ts
type ButtonState = ComponentStateBase & {
  disabled?: boolean;
  onClick?: (context: any) => void;
};
```

---

## 3. 渲染器契约

### 3.1 MetaGrid
输入：
- `component`：PageComponent
- `runtime`：MetaRuntime

行为：
- 仅从 `componentStateByKey[componentKey]` 读取状态。
- `status=loading` → 显示 loading 占位。
- `status=error` → 显示错误占位（不影响其它组件）。
- `rowData/columnDefs` 为主渲染数据。
- 事件全部来自 `GridState`，渲染器只负责透传。

### 3.2 MetaForm
输入同 MetaGrid。
行为：
- `status=error` → 显示错误占位。
- 若 `renderer` 未配置 → 使用 placeholder。

### 3.3 MetaButton
输入同 MetaGrid。
行为：
- `status=error` → 显示错误占位。
- 若 `state.onClick` 存在优先执行；否则根据 `componentConfig.action` 调 runtime 方法。

---

## 4. 错误隔离与日志规范

### 4.1 错误隔离
层级：
1. Runtime 内部阶段错误 → 写入 `componentStateByKey`（组件级，不影响页面）。
2. MetaPageRenderer 内部 RendererBoundary 捕获渲染错误 → 写入 `componentStateByKey`，只影响该组件。

### 4.2 日志格式
统一格式：
```
[MetaV2][pageCode][componentKey][stage] message
```

### 4.3 错误结构
```ts
type MetaError = {
  code: string;
  message: string;
  stage: RuntimeStage;
  pageCode: string;
  componentKey?: string;
  raw?: unknown;
};
```

---

## 5. 扩展规范（新增组件类型）
- 必须注册渲染器（`component-renderer-registry`）。
- 必须在 `componentStateByKey` 中创建对应 `ComponentState`。
- 错误必须通过 `reportComponentError` 上报，遵循日志格式。

---

## 6. 元数据配置示例（按组件）

### 6.1 LAYOUT（容器）
```sql
INSERT INTO T_COST_PAGE_COMPONENT
(PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG)
VALUES
('cost-pinggu-v2', 'root', 'LAYOUT', NULL, 0, '{"direction":"vertical","gap":8}');
```

### 6.2 GRID（单表）
```sql
INSERT INTO T_COST_PAGE_COMPONENT
(PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG)
VALUES
('user-manage', 'grid', 'GRID', 'root', 1, 'CostUser', '{"height":"100%"}');
```

### 6.3 GRID（主表）
```sql
INSERT INTO T_COST_PAGE_COMPONENT
(PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG)
VALUES
('cost-pinggu-v2', 'masterGrid', 'GRID', 'root', 1, 'CostPinggu', '{"height":"50%","selectionMode":"single"}');
```

### 6.4 TABS（明细 Tabs）
```sql
INSERT INTO T_COST_PAGE_COMPONENT
(PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG)
VALUES
('cost-pinggu-v2', 'detailTabs', 'TABS', 'root', 2,
'{
  "mode": "multi",
  "tabs": [
    {"key": "material", "title": "原料/辅料", "tableCode": "CostMaterial"},
    {"key": "package", "title": "包材", "tableCode": "CostPackage"}
  ],
  "broadcast": ["apexPl", "pPerpack", "sPerback", "xPerback"]
}');
```

### 6.5 FORM（表单，示例）
```sql
INSERT INTO T_COST_PAGE_COMPONENT
(PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG)
VALUES
('cost-pinggu-v2', 'masterForm', 'FORM', 'root', 3, '{"rendererKey":"default"}');
```

### 6.6 BUTTON（按钮，示例）
```sql
INSERT INTO T_COST_PAGE_COMPONENT
(PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG)
VALUES
('cost-pinggu-v2', 'btnSave', 'BUTTON', 'root', 4,
'{"text":"保存","type":"primary","size":"small","action":"save"}');
```

---

## 7. 规则配置示例（按 RULE_TYPE）

### 7.1 COLUMN_OVERRIDE（列覆盖）
```sql
INSERT INTO T_COST_PAGE_RULE (PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES)
VALUES ('cost-pinggu-v2', 'masterGrid', 'COLUMN_OVERRIDE',
'[
  {"field":"id","visible":false,"editable":false},
  {"field":"goodsname","width":180,"editable":true,"searchable":true},
  {"field":"totalCost","width":160,"editable":false}
]');
```

### 7.2 CALC（行级计算）
```sql
INSERT INTO T_COST_PAGE_RULE (PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES)
VALUES ('cost-pinggu-v2', 'masterGrid', 'CALC',
'[
  {"field":"salemoney","expression":"outPriceRmb / pPerpack * apexPl * (yield / 100)",
   "triggerFields":["outPriceRmb","pPerpack","apexPl","yield","totalCost"]}
]');
```

### 7.3 VALIDATION（校验）
```sql
INSERT INTO T_COST_PAGE_RULE (PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES)
VALUES ('cost-pinggu-v2', 'material', 'VALIDATION',
'[
  {"field":"perHl","required":true,"min":0.001,"message":"每片含量必填且必须大于0"},
  {"field":"price","required":true,"min":0,"message":"单价必填且不能为负数"}
]');
```

### 7.4 LOOKUP（弹窗回填）
```sql
INSERT INTO T_COST_PAGE_RULE (PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES)
VALUES ('cost-pinggu-v2', 'material', 'LOOKUP',
'[
  {"field":"apexGoodsname","lookupCode":"material",
   "mapping":{"apexGoodsname":"materialName","spec":"spec","price":"price"}}
]');
```

### 7.5 AGGREGATE（主从聚合）
```sql
INSERT INTO T_COST_PAGE_RULE (PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES)
VALUES ('cost-pinggu-v2', 'masterGrid', 'AGGREGATE',
'[
  {"sourceField":"costBatch","targetField":"totalYl","algorithm":"SUM","sourceTab":"material","filter":"dtlUseflag === ''原料''"},
  {"sourceField":"costBatch","targetField":"totalFl","algorithm":"SUM","sourceTab":"material","filter":"dtlUseflag === ''辅料''"},
  {"sourceField":"costBatch","targetField":"totalBc","algorithm":"SUM","sourceTab":"package"},
  {"targetField":"totalCost","expression":"totalYl + totalFl + totalBc"}
]');
```

### 7.6 BROADCAST（主到明细字段广播）
```sql
INSERT INTO T_COST_PAGE_RULE (PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES)
VALUES ('cost-pinggu-v2', 'detailTabs', 'BROADCAST',
'["apexPl","pPerpack","sPerback","xPerback"]');
```

### 7.7 SUMMARY_CONFIG（汇总行配置）
```sql
INSERT INTO T_COST_PAGE_RULE (PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES)
VALUES ('cost-pinggu-v2', 'detailTabs', 'SUMMARY_CONFIG',
'{
  "summaryHeaderField": "summaryLabel",
  "summaryHeaderLabel": "分类",
  "summaryFields": [
    {"sourceField":"costBatch","targetField":"totalAmount","algorithm":"SUM"},
    {"sourceField":"id","targetField":"rowCount","algorithm":"COUNT"}
  ]
}');
```

### 7.8 RELATION（主从关系）
```sql
INSERT INTO T_COST_PAGE_RULE (PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES)
VALUES ('cost-pinggu-v2', 'detailTabs', 'RELATION',
'{
  "masterKey": "id",
  "detailKey": "masterId",
  "detailType": "tabs"
}');
```

### 7.9 GRID_OPTIONS（表格选项）
```sql
INSERT INTO T_COST_PAGE_RULE (PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES)
VALUES ('cost-pinggu-v2', 'masterGrid', 'GRID_OPTIONS',
'{
  "enableFilter": true,
  "enableSort": true,
  "rowSelection": { "mode": "singleRow", "enableClickSelection": true }
}');
```

### 7.10 CONTEXT_MENU（右键菜单）
```sql
INSERT INTO T_COST_PAGE_RULE (PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES)
VALUES ('cost-pinggu-v2', 'masterGrid', 'CONTEXT_MENU',
'[
  {"key":"add","label":"新增","action":"addMasterRow"},
  {"key":"copy","label":"复制","action":"copyMasterRow","requiresSelection":true},
  {"key":"delete","label":"删除","action":"deleteMasterRow","requiresSelection":true},
  {"key":"save","label":"保存","action":"save"}
]');
```

---

## 8. 页面级示例（完整片段）

### 8.1 单表页面（无 Tabs）
核心要求：
- 只需要一个 `GRID` 组件
- 无 `RELATION` / `AGGREGATE` / `BROADCAST`

```sql
-- 组件
INSERT INTO T_COST_PAGE_COMPONENT (PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG)
VALUES ('user-manage', 'grid', 'GRID', 'root', 1, 'CostUser', '{"height":"100%"}');

-- 列覆盖（可选）
INSERT INTO T_COST_PAGE_RULE (PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES)
VALUES ('user-manage', 'grid', 'COLUMN_OVERRIDE',
'[{"field":"username","width":160,"editable":true},{"field":"status","width":100}]');
```

### 8.2 主从页面（Tabs 明细）
核心要求：
- `masterGrid` + `detailTabs`
- 明细需要 `RELATION` + `AGGREGATE` + `CALC`/`LOOKUP` 等规则

```sql
-- 组件
INSERT INTO T_COST_PAGE_COMPONENT (PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG)
VALUES ('cost-pinggu-v2', 'masterGrid', 'GRID', 'root', 1, 'CostPinggu', '{"height":"50%"}');

INSERT INTO T_COST_PAGE_COMPONENT (PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG)
VALUES ('cost-pinggu-v2', 'detailTabs', 'TABS', 'root', 2,
'{"mode":"multi","tabs":[{"key":"material","title":"原料/辅料","tableCode":"CostMaterial"}]}');

-- 规则
INSERT INTO T_COST_PAGE_RULE (PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES)
VALUES ('cost-pinggu-v2', 'detailTabs', 'RELATION',
'{"masterKey":"id","detailKey":"masterId","detailType":"tabs"}');
```
