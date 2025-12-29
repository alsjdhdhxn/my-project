# 计算引擎 V2 - 实现任务

## Phase 1: 硬编码原型（评估单页面）

> 目标：用硬编码方式跑通完整流程，验证架构可行性

### Task 1.1: 创建独立测试页面
- [x] `cost-web/src/views/cost/eval-v2/index.vue`
- [x] 硬编码主表列定义、从表列定义
- [x] 多 Tab 并排布局，内部滚动

### Task 1.2: DataStore (硬编码版)
- [x] `cost-web/src/views/cost/eval-v2/useDataStore.ts`
- [x] master: { id, evalNo, productName, apexPl, yield, totalYl, totalFl, totalPack, totalCost }
- [x] details: { material: [], auxiliary: [], package: [] } 按类型分组
- [x] loadMaster, loadDetails, updateField
- [x] Tab 配置：visible 控制显示/隐藏
- [x] _changeType 变更追踪集成

### Task 1.3: CalcEngine (硬编码版)
- [x] `cost-web/src/views/cost/eval-v2/useCalcEngine.ts`
- [x] 安装 mathjs: `pnpm add mathjs`
- [x] 硬编码计算规则：
  - [x] 原料/辅料: batchQty = master.apexPl * perHl / 100 / master.yield * 100
  - [x] 原料/辅料: costBatch = batchQty * price
  - [x] 包材: packQty = master.apexPl * 1000
  - [x] 包材: packCost = packQty * price
  - [x] totalYl = SUM(material.costBatch)
  - [x] totalFl = SUM(auxiliary.costBatch)
  - [x] totalPack = SUM(package.packCost)
  - [x] totalCost = totalYl + totalFl + totalPack
- [x] BFS 级联依赖解析

### Task 1.4: ChangeTracker (硬编码版)
- [x] _changeType 集成在 useDataStore.ts 中
- [x] 单元格样式：绿色(用户编辑)/黄色(级联计算)

### Task 1.5: 多 Tab 并排显示
- [x] 三个 Tab（原料/辅料/包材）并排显示
- [x] Tab 开关按钮控制显示/隐藏
- [x] 关闭按钮（x）在 Tab 头部
- [x] 数据存储在 JSON，关闭 Tab 不丢失数据

### Task 1.6: 集成测试
- [x] 选中主表 → 加载从表（按 useFlag 分组）
- [x] 编辑 apexPl → 所有从表计算列更新（黄色）
- [x] 编辑 perHl/price → 级联计算 → 主表聚合更新
- [x] 用户编辑显示绿色，级联计算显示黄色

### Task 1.7: 测试数据
- [x] V6__add_package_support.sql（包材字段 + 测试数据）
- [x] V7__add_test_data.sql（3个额外评估单）

## Phase 2: 抽象为通用模块

### Task 2.1: 通用 GridStore
- [x] `cost-web/src/composables/useGridStore.ts`
- [x] 泛型支持任意表结构
- [x] load, getRow, updateField, markChange
- [x] addRow, deleteRow（标记删除）
- [x] isDirty, changedRows, visibleRows

### Task 2.2: 通用 CalcEngine
- [x] `cost-web/src/composables/useCalcEngine.ts`
- [x] registerCalcRule(field, expression, dependencies)
- [x] registerAggRule(source, target, algorithm, filter)
- [x] onFieldChange, onContextChange, initCalc
- [x] BFS 级联依赖解析

### Task 2.3: 通用组件
- [x] `cost-web/src/components/meta-v2/MetaGrid.vue`
- [x] `cost-web/src/components/meta-v2/MetaToolbar.vue`
- [x] 前端搜索（quickFilter）
- [x] 高级查询按钮（占位）
- [x] 表头自动换行（wrapHeaderText + autoHeaderHeight）
- [x] 主从表可拖动分隔（NSplit）
- [x] 鼠标悬停自动聚焦（mouseenter → focus）
- [x] 空表格支持 Ctrl+Enter 新增

### Task 2.4: 元数据驱动的单元格样式
- [x] `cost-web/src/composables/useMetaColumns.ts`
- [x] 解析 RULES_CONFIG.style 配置
- [x] 使用 cellClassRules 实现条件样式
- [x] 动态 CSS 注入（injectDynamicStyles）
- [x] 支持 contains/startsWith/endsWith/equals/compare 条件
- [x] 编辑后样式实时更新

### Task 2.5: 测试页面
- [x] `cost-web/src/views/cost/eval-v3/index.vue`
- [x] 使用通用组件重构评估单页面

## Phase 3: 元数据驱动（已完成）

### Task 3.1: 解析 RULES_CONFIG
- [x] 从 COLUMN_METADATA.RULES_CONFIG 读取表达式
- [x] 自动注册到 CalcEngine

### Task 3.2: 解析 LOGIC_AGG
- [x] 从 PAGE_COMPONENT 读取聚合配置
- [x] 自动注册到 AggEngine
- [x] 创建 useAggEngine.ts 聚合引擎
- [x] 支持 SUM/AVG/COUNT/MAX/MIN 算法
- [x] 支持 filter 过滤条件
- [x] 支持 expression 表达式计算

## Phase 4: 后端支持

### Task 4.1: 保存功能
- [x] 主从表批量保存接口（后端已有 /api/data/save）
- [x] 前端 handleSave 实现
- [x] 构建 SaveParam（status: added/modified/deleted/unchanged）
- [x] 变更追踪（_changeType）转换为 changes 数组
- [x] 保存后清除变更标记并刷新

### Task 4.2: 验证器 + 执行器
- [x] 后端 `ValidationService.java` - 验证服务
- [x] `TableMetadata` / `TableMetadataDTO` 添加 `validationRules` 字段
- [x] `DynamicDataService.save()` 集成后端验证
- [x] 前端 `useValidator.ts` - 前端验证器
- [x] `eval-v3/index.vue` handleSave 集成前端验证
- [x] SQL 迁移 `V8__add_validation_rules.sql`
- [x] 验证流程：前端1→2 → 后端1→执行器1 → 后端2→执行器2 → 后端3→执行器3

### Task 4.3: 操作日志
- [ ] T_COST_OPERATION_LOG 表结构
- [ ] 前端耗时采集：validation, serialize, request
- [ ] 后端耗时采集：connection, validation, sqlExecution, commit
- [ ] 响应头 X-Timing 传递后端耗时

## 完成进度

| Phase | 状态 |
|-------|------|
| Phase 1 | ✅ 完成 |
| Phase 2 | ✅ 完成（已验证主从联动） |
| Phase 3 | ✅ 完成 |
| Phase 4 | 🔄 进行中（4.1 已完成，4.2 已完成，4.3 待开始） |
