# Implementation Plan: calc-engine-v4

## Overview

重构 eval-v3 → eval-v4，实现四层解耦架构：View → Adapter → State → Domain
遵循：约定大于配置、组件可复用

## Tasks

- [x] 1. Domain Layer: 纯函数计算引擎
  - [x] 1.1 创建 `src/logic/calc-engine/calculator.ts`
    - 实现 `calcRowFields()` 行级计算纯函数
    - 实现 `calcAggregates()` 聚合计算纯函数
    - 实现 `evalCondition()` 条件判断（支持 JS 语法）
    - 使用 mathjs，支持 context 变量
    - _Requirements: 3.1, 3.2, 3.3, 3.4_
  - [x] 1.2 创建 `src/logic/calc-engine/parser.ts`
    - 实现 `parseCalcRules()` 从 COMPONENT_CONFIG 解析计算规则
    - 实现 `parseAggRules()` 从 COMPONENT_CONFIG 解析聚合规则
    - 实现 `parseTabConfig()` 解析 Tab 配置（支持 group/multi 模式）
    - _Requirements: 5.1, 12.3, 12.4, 13.1, 13.2_
  - [x] 1.3 创建 `src/logic/calc-engine/builder.ts`
    - 实现 `buildSaveParams()` 构建保存参数
    - 支持 group 模式和 multi 模式
    - 处理新增行外键、变更记录
    - _Requirements: 19.1, 19.2, 19.3, 19.4, 19.5_

- [x] 2. State Layer: 通用主从表 Store
  - [x] 2.1 创建 `src/store/modules/master-detail/index.ts`
    - 接收 pageCode，从元数据自动初始化
    - 定义 RowData 接口（含 _isNew, _isDeleted, _changeType, _originalValues）
    - 实现 masterRows, detailRows, currentMasterId 状态
    - 实现 detailCache + LRU 清理（MAX_CACHE_SIZE=10）
    - _Requirements: 1.1, 1.2, 1.4, 6.1, 6.2, 6.3_
  - [x] 2.2 实现 Store Actions
    - `loadMaster()` / `loadDetail()` 加载数据
    - `selectMaster()` 切换主表，缓存/恢复从表
    - `updateField()` 更新字段，标记 changeType
    - `addRow()` / `deleteRow()` 新增/删除行
    - `clearChanges()` 保存成功后清除标记
    - _Requirements: 1.3, 6.4, 6.5, 9.2, 9.3_
  - [x] 2.3 实现响应式计算
    - 监听 broadcast 字段变化 → 触发从表重算
    - 监听从表变化 → 触发聚合重算
    - watchEffect + nextTick 批量处理
    - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [x] 3. Adapter Layer: Grid 适配器
  - [x] 3.1 创建 `src/composables/useGridAdapter.ts`
    - 监听 Store 变化，使用 applyTransaction 同步到 Grid
    - 细粒度 editingCell 控制，编辑中暂停该单元格更新
    - 处理 add/update/remove 三种情况
    - _Requirements: 2.1, 2.2, 2.3, 2.4_
  - [x] 3.2 实现单元格样式
    - 用户修改：绿色背景 (#e6ffe6)
    - 级联计算：黄色背景 (#fffde6)
    - 通过 cellClassRules 实现
    - _Requirements: 15.1, 15.2, 15.3_

- [ ] 4. Checkpoint - 核心层完成
  - 确保 calculator 纯函数可独立测试
  - 确保 Store 数据流正确
  - 确保 Adapter 同步正常

- [x] 5. View Layer: 通用主从页面组件
  - [x] 5.1 创建 `src/components/meta-v2/MasterDetailPage.vue`
    - 只接收 pageCode，其他全从元数据读取
    - 使用 NSplit 布局（vertical, min=0.2, max=0.8）
    - 主表 AG Grid + 从表 MetaTabs
    - _Requirements: 7.1, 7.2, 7.3, 11.1, 11.2, 11.3_
  - [x] 5.2 创建 `src/components/meta-v2/MetaTabs.vue`
    - 解析 COMPONENT_CONFIG.tabs 渲染多 Tab
    - 支持 group 模式（单表分组）和 multi 模式（多表）
    - 每个 Tab 渲染独立的 AG Grid
    - _Requirements: 5.2, 5.3, 5.5, 5.6_
  - [x] 5.3 实现工具栏
    - 快速搜索、刷新按钮
    - Tab 显示/隐藏切换
    - 使用 MetaFloatToolbar
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_
  - [x] 5.4 实现键盘快捷键
    - Ctrl+S 保存（已实现）
    - Ctrl+Enter 新增行（待完善）
    - Delete 删除选中行（待完善）
    - _Requirements: 17.1, 17.2, 17.3, 17.4_

- [ ] 6. Checkpoint - 基础功能完成
  - 确保主从表联动正常
  - 确保计算和聚合正确
  - 确保切换主表不丢失数据

- [ ] 7. 保存与验证
  - [ ] 7.1 实现数据验证
    - 从 COLUMN_METADATA.RULES_CONFIG 提取验证规则
    - 支持 required, notZero, min, max, pattern
    - _Requirements: 10.1, 10.2, 10.3, 10.4_
  - [x] 7.2 实现保存流程
    - 调用 buildSaveParams() 构建参数
    - 调用 saveDynamicData API
    - 成功后 clearChanges() + 重新加载
    - _Requirements: 6.4, 6.5, 14.1, 14.2_
  - [x] 7.3 实现离开提示
    - beforeunload 检测 isDirty
    - _Requirements: 6.6_

- [x] 8. 路由配置
  - [x] 8.1 创建 `src/views/cost/eval-v4/index.vue`
    - 只需一行：`<MasterDetailPage pageCode="cost-eval" />`
    - _Requirements: 7.1_

- [ ] 9. Final Checkpoint
  - 确保所有功能正常
  - 确保与 v3 功能对等
  - 确保组件可复用（换个 pageCode 就能用）

## Notes

- 约定：主表组件 key 固定为 `masterGrid`
- 约定：从表组件 type 为 `TABS`
- 约定：外键从 TABLE_METADATA.PARENT_FK_COLUMN 读取
- 所有组件只依赖 pageCode，不绑定具体业务
