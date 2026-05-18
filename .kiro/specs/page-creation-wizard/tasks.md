# Implementation Plan: 页面创建向导 (Page Creation Wizard)

## Overview

将页面创建向导功能按依赖顺序实现：后端 DTO → 后端 Service → 后端 Controller → 前端 API → 前端状态管理 → 前端 Step 组件 → 前端面板集成 → 生成后跳转。后端使用 Java/Spring Boot，前端使用 TypeScript/Vue 3 + Naive UI + AG Grid。

## Tasks

- [ ] 1. 后端 DTO 与 Service 层
  - [ ] 1.1 创建 WizardPayload 及相关 DTO 类
    - 在 `cost-server/src/main/java/com/cost/costserver/metadata/entity/` 下创建：
      - `WizardPayload.java`：包含 parentId、resourceName、resourceCode、icon、mode、pageCode、masterTable、detailTables
      - `WizardTable.java`：包含 queryView、targetTable、tableCode、tableName、pkColumn、sequenceName、parentFkColumn、columns
      - `WizardColumn.java`：包含 columnName、targetColumn、headerText、dataType、displayOrder、isVirtual、visible、editable、filterable、widgetType
      - `WizardResult.java`：包含 pageCode、createdCount
    - _Requirements: 8.1_

  - [ ] 1.2 创建 WizardGenerateService
    - 在 `cost-server/src/main/java/com/cost/costserver/metadata/service/` 下创建 `WizardGenerateService.java`
    - 注入 MetaConfigService、DynamicMapper、MetadataService、AppWebSocketHandler
    - 实现 `@Transactional generate(WizardPayload)` 方法：
      - 校验 pageCode 不重复（查 T_COST_RESOURCE）
      - 按顺序创建：Resource → TableMetadata → ColumnMetadata → PageComponent → PageRule
      - 主表先创建，从表设 parentTableCode + parentFkColumn
      - 创建 root LAYOUT 组件 → masterGrid GRID → detail DETAIL_GRID
      - 为每个组件生成 COLUMN_OVERRIDE 和 BUTTON 规则
      - 清缓存 + WebSocket 广播
    - 实现 `getViewSql(owner, viewName)` 方法：查询 DBA_VIEWS.TEXT，处理 CLOB
    - 实现 `getPkColumn(owner, tableName)` 方法：查询 ALL_CONSTRAINTS + ALL_CONS_COLUMNS
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 9.1, 9.2, 9.4, 9.5, 9.6, 9.7, 11.1–11.8_

  - [ ]* 1.3 编写 WizardGenerateService 单元测试
    - 测试 generate() 正常流程（单表模式、主从模式）
    - 测试 pageCode 重复时抛异常
    - 测试 getPkColumn 返回正确主键列
    - 测试 getViewSql 处理 CLOB
    - _Requirements: 8.1, 8.2, 8.3_

- [ ] 2. 后端 Controller 层
  - [ ] 2.1 在 MetaConfigController 中添加向导端点
    - 添加 `POST /meta-config/wizard/generate`：接收 WizardPayload，调用 WizardGenerateService.generate()
    - 添加 `GET /meta-config/wizard/pk-column`：接收 owner + tableName 参数
    - 复用已有 @ModelAttribute requireAdminUser() 权限校验
    - _Requirements: 8.1, 9.5, 9.6, 12.1, 12.2_

  - [ ]* 2.2 编写 Controller 集成测试
    - 测试 admin 用户正常访问
    - 测试非 admin 用户返回 403
    - 测试完整生成流程端到端
    - _Requirements: 12.1, 12.2, 12.3_

- [ ] 3. Checkpoint - 后端完成验证
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 4. 前端 API 层
  - [ ] 4.1 创建 wizard.ts API 文件
    - 在 `cost-web/src/service/api/wizard.ts` 创建：
      - `generateWizard(payload)` → POST /meta-config/wizard/generate
      - `fetchPkColumn(tableName, owner)` → GET /meta-config/wizard/pk-column
    - 复用已有的 request 函数和错误处理模式（参考 meta-config.ts）
    - 导出 WizardPayload、WizardTable、WizardColumn 等 TypeScript 接口
    - _Requirements: 7.4, 7.5, 8.1_

- [ ] 5. 前端状态管理
  - [ ] 5.1 创建 useWizardState.ts composable
    - 在 `cost-web/src/views/_builtin/meta-config/panels/composables/useWizardState.ts` 创建
    - 定义 WizardState 接口：currentStep、step1（parentId/name/code/icon）、step2（mode/pageCode/masterTable/detailTables）
    - 定义 WizardTableState、WizardColumnState 接口
    - 实现 reactive 状态管理，步骤切换不重置数据
    - 实现步骤校验函数：validateStep1()、validateStep2()
    - 实现 generateResourceCode(name)：中文名 → UPPER_SNAKE_CASE
    - 实现 classifyColumns()：视图列名与目标表列名做直接匹配（不区分大小写）
    - 实现 buildPayload()：从 state 组装提交载荷
    - _Requirements: 1.3, 1.4, 1.5, 2.3, 4.3, 4.4, 4.5_

  - [ ]* 5.2 编写属性测试：Resource Code 生成与校验
    - **Property 3: Resource code generation and validation**
    - **Validates: Requirements 2.3, 2.4**
    - 使用 fast-check 验证：任意非空字符串生成的编码匹配 `^[A-Z0-9_]{1,64}$`

  - [ ]* 5.3 编写属性测试：表/视图名校验
    - **Property 4: Table/view name validation**
    - **Validates: Requirements 3.7**
    - 使用 fast-check 验证：名称接受当且仅当匹配 `^[A-Za-z0-9_]+$` 且长度 ≤ 64

  - [ ]* 5.4 编写属性测试：列真实/虚拟分类
    - **Property 5: Column real/virtual classification with defaults**
    - **Validates: Requirements 4.3, 4.4, 4.5**
    - 使用 fast-check 验证：视图列名与目标表列名做不区分大小写直接匹配时为真实列，否则为虚拟列

  - [ ]* 5.5 编写属性测试：Oracle 数据类型映射
    - **Property 6: Oracle DATA_TYPE mapping**
    - **Validates: Requirements 4.9, 6.4, 6.5**
    - 使用 fast-check 验证：NUMBER/FLOAT→number, DATE/TIMESTAMP→date, 其他→text

  - [ ]* 5.6 编写属性测试：FK 预选逻辑
    - **Property 7: FK pre-selection logic**
    - **Validates: Requirements 5.2**
    - 使用 fast-check 验证：主表 PK 列名与从表列名大小写不敏感匹配时预选

  - [ ]* 5.7 编写属性测试：排序号重复检测
    - **Property 8: Duplicate display order detection**
    - **Validates: Requirements 6.6**
    - 使用 fast-check 验证：存在重复 displayOrder 时校验失败

  - [ ]* 5.8 编写属性测试：虚拟列可编辑校验
    - **Property 9: Virtual column editable validation**
    - **Validates: Requirements 6.7**
    - 使用 fast-check 验证：虚拟列 editable=true 且 TARGET_COLUMN 不在目标表中时校验失败

  - [ ]* 5.9 编写属性测试：虚拟列转真实列
    - **Property 10: Virtual-to-real column promotion**
    - **Validates: Requirements 6.8**
    - 使用 fast-check 验证：虚拟列指定 TARGET_COLUMN 存在于目标表时自动转为真实列

  - [ ]* 5.10 编写属性测试：默认按钮生成
    - **Property 13: Default button generation**
    - **Validates: Requirements 9.1, 9.2**
    - 使用 fast-check 验证：单表模式={query,add,delete,save}，主从模式主表含 query，从表不含

  - [ ]* 5.11 编写属性测试：自动推导标识符
    - **Property 14: Auto-derived identifiers**
    - **Validates: Requirements 9.3, 9.4, 9.7**
    - 使用 fast-check 验证：SEQUENCE_NAME = "SEQ_" + TARGET_TABLE；COMPONENT_KEY = tableCode

  - [ ]* 5.12 编写属性测试：COLUMN_OVERRIDE 规则生成
    - **Property 15: COLUMN_OVERRIDE rule generation**
    - **Validates: Requirements 11.1–11.6**
    - 使用 fast-check 验证：每个组件一条规则，虚拟列强制 editable=false，宽度 60-600

- [ ] 6. 前端 Step1 组件 - 目录配置
  - [ ] 6.1 创建 WizardStep1.vue
    - 在 `cost-web/src/views/_builtin/meta-config/panels/components/WizardStep1.vue` 创建
    - 使用 NTreeSelect 加载资源树（复用 fetchAllResources）选择父级目录
    - NInput 输入目录名称，blur 时自动生成编码
    - NInput 输入编码（限制 UPPER_SNAKE_CASE，maxLength=64）
    - NSelect 选择图标（默认 folder）
    - 实现校验提示：名称必填、父级必选、编码重复检测、长度限制
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9_

- [ ] 7. 前端 Step2 组件 - 表导入与字段配置
  - [ ] 7.1 创建 WizardStep2.vue
    - 在 `cost-web/src/views/_builtin/meta-config/panels/components/WizardStep2.vue` 创建
    - 模式选择器：NRadioGroup（单表 / 主从）
    - 单表模式：1 组视图名+目标表名输入框
    - 主从模式：主表 + 动态从表列表（最多 5 张，至少保留 1 张；超 5 张显示警告）
    - 切换模式时清空已填值
    - 视图名/表名输入校验（字母+数字+下划线，≤64字符）
    - 填写视图名 + 目标表名后自动触发列导入：
      - 调用 fetchViewColumns 获取视图列
      - 调用 fetchViewColumns 获取目标表列
      - 调用 fetchPkColumn 获取主键
      - 执行 classifyColumns 直接列名匹配
    - AG Grid 显示列配置表格：字段名、标题、类型、真实/虚拟、TARGET_COLUMN、显示、编辑、查询、控件、排序号
    - 允许编辑：标题、数据类型、显示、编辑、查询、控件类型、排序号
    - 虚拟列编辑校验 + 虚拟转真实逻辑
    - 主从模式下 FK 选择：NSelect 展示从表列，预选与主表 PK 同名列
    - _Requirements: 3.1–3.7, 4.1–4.10, 5.1–5.4, 6.1–6.8_

  - [ ]* 7.2 编写 Step2 列导入逻辑单元测试
    - 测试 classifyColumns 具体场景
    - 测试 parseViewSqlAliases 各种 SQL 格式
    - 测试排序号重复检测
    - _Requirements: 4.3, 4.10, 6.6_

- [ ] 8. Checkpoint - 前端核心逻辑验证
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 9. 前端 Step3 组件 - 确认生成
  - [ ] 9.1 创建 WizardStep3.vue
    - 在 `cost-web/src/views/_builtin/meta-config/panels/components/WizardStep3.vue` 创建
    - 从 wizardState 组装生成清单（Manifest），分组展示：
      - 目录（名称 + 编码）
      - 表元数据（主表/从表标记 + tableCode）
      - 页面组件（类型 + 关联表）
      - 列配置（每表列数 + 真实/虚拟统计）
      - 按钮配置（各表的按钮列表）
      - 主从关系（FK 映射）
    - "确认生成"按钮：点击后立即禁用，调用 generateWizard API
    - 成功：显示"生成成功，共创建 X 条记录"
    - 失败/超时：恢复按钮可用，显示错误信息
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [ ] 10. 前端 WizardPanel.vue 面板 - 步骤编排
  - [ ] 10.1 创建 WizardPanel.vue
    - 在 `cost-web/src/views/_builtin/meta-config/panels/WizardPanel.vue` 创建
    - 使用 NSteps 组件显示 3 步进度条
    - 引入 WizardStep1、WizardStep2、WizardStep3 组件
    - 使用 useWizardState 管理全局状态
    - 实现上一步/下一步按钮逻辑：
      - 下一步前调用 validateStepN()，失败时高亮提示
      - 上一步不做任何清除，保留数据
    - 非 admin 用户不渲染（通过 inject 或 store 获取用户角色）
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 12.4_

- [ ] 11. 集成到 meta-config index.vue
  - [ ] 11.1 修改 meta-config/index.vue 添加向导 Tab
    - 导入 WizardPanel 组件
    - 添加 NTabPane（name="wizard", tab="页面向导"）
    - 仅 admin 用户显示该 Tab（条件渲染）
    - _Requirements: 1.1, 12.4_

- [ ] 12. 生成后跳转与路由刷新
  - [ ] 12.1 实现生成成功后的跳转逻辑
    - 在 WizardStep3 中生成成功后：
      - 调用 fetchAllResources 刷新资源菜单
      - 刷新前端路由表（基于新资源重建动态路由）
      - 清除元数据缓存
      - 使用 router.push 跳转到新页面路由
    - 跳转失败时显示手动链接
    - _Requirements: 10.1, 10.2, 10.3, 10.4_

- [ ] 13. Final checkpoint - 全部完成验证
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- 后端复用已有 MetaConfigService 的 save 方法，保持 ID 生成和审计字段一致
- 前端复用已有 fetchViewColumns、fetchAllResources 接口
- 所有向导端点受 @ModelAttribute requireAdminUser() 保护

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2"] },
    { "id": 2, "tasks": ["1.3", "2.1"] },
    { "id": 3, "tasks": ["2.2", "4.1"] },
    { "id": 4, "tasks": ["5.1"] },
    { "id": 5, "tasks": ["5.2", "5.3", "5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "5.10", "5.11", "5.12", "6.1"] },
    { "id": 6, "tasks": ["7.1"] },
    { "id": 7, "tasks": ["7.2", "9.1"] },
    { "id": 8, "tasks": ["10.1"] },
    { "id": 9, "tasks": ["11.1", "12.1"] }
  ]
}
```
