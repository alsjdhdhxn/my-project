# 功能盘点与重构边界 2026-05-23

## 当前导出

数据库已从 `jdbc:oracle:thin:@//192.168.11.5:1521/orcl` 的 `cmx` schema 导出到项目同级目录：

`../sql20260523`

导出文件：

- `00_schema_tables.sql`: 67 个表/物化视图表结构
- `01_sequences.sql`: 96 个序列
- `02_views.sql`: 29 个视图
- `03_program_units.sql`: 20 个包/过程/函数
- `04_triggers.sql`: 0 个触发器
- `05_indexes.sql`: 38 个普通索引
- `10_data.sql`: 全表数据，约 478MB
- `manifest.md`: 表清单和行数

辅助脚本：

- `scripts/OracleSqlExporter.java`
- `scripts/export-oracle-schema-data.ps1`

## 后端功能域

### 元数据域

主要代码：

- `cost-server/src/main/java/com/cost/costserver/metadata/service/MetadataService.java`
- `cost-server/src/main/java/com/cost/costserver/metadata/service/MetaConfigService.java`
- `cost-server/src/main/java/com/cost/costserver/metadata/service/WizardGenerateService.java`
- `cost-server/src/main/java/com/cost/costserver/metadata/controller/MetadataController.java`
- `cost-server/src/main/java/com/cost/costserver/metadata/controller/MetaConfigController.java`

主要表：

- `T_COST_TABLE_METADATA`
- `T_COST_COLUMN_METADATA`
- `T_COST_PAGE_COMPONENT`
- `T_COST_PAGE_RULE`
- `T_COST_LOOKUP_CONFIG`
- `T_COST_DICTIONARY_TYPE`
- `T_COST_DICTIONARY_ITEM`

当前职责混杂：

- 元数据读取、缓存、列权限合并、用户表格偏好合并在 `MetadataService` 中交织。
- 配置中心 `MetaConfigService` 同时负责资源、页面、表、列、组件、规则、Lookup、导出、审批配置、向导生成的查询支撑。
- 前端显示配置、后端数据查询配置、权限裁剪规则都依赖同一批 JSON 字段，缺少强类型边界。

建议拆分：

- `metadata.catalog`: 表/列/字典/Lookup 的只读目录服务。
- `metadata.page`: 页面组件树、页面规则、默认按钮配置。
- `metadata.config`: 配置中心写入、校验、发布。
- `metadata.cache`: 缓存键、失效策略、WebSocket 元数据变更事件。
- `metadata.schema`: 配置 JSON 的 DTO、版本、迁移和兼容层。

### 权限域

主要代码：

- `cost-server/src/main/java/com/cost/costserver/auth/service/PermissionService.java`
- `cost-server/src/main/java/com/cost/costserver/auth/service/RoleManageService.java`
- `cost-server/src/main/java/com/cost/costserver/config/SecurityConfig.java`
- `cost-server/src/main/java/com/cost/costserver/auth/filter/JwtAuthenticationFilter.java`

主要表：

- `T_COST_USER`
- `T_COST_ROLE`
- `T_COST_USER_ROLE`
- `T_COST_ROLE_PAGE`
- `T_COST_RESOURCE`
- `T_COST_DEPARTMENT`

当前职责混杂：

- 页面权限、按钮权限、列权限、行权限都在 `PermissionService` 内解析和合并。
- 行权限直接产出 SQL 片段，再由动态查询拼接。
- `DynamicDataService` 和 `ApprovalRuntimeService` 直接知道按钮 key，例如 `save`、`approval.apply`、`approval.approve`。

建议拆分：

- `permission.model`: PagePermission、ButtonPolicy、ColumnPolicy、RowPolicy。
- `permission.resolver`: 多角色合并、默认策略、按钮 key 归一化。
- `permission.sql`: 行权限 SQL 编译器，只输出受控的 `SqlCondition` 对象。
- `permission.guard`: 页面、按钮、列、行访问守卫。

### 动态 SQL / 数据访问域

主要代码：

- `cost-server/src/main/java/com/cost/costserver/dynamic/service/DynamicDataService.java`
- `cost-server/src/main/java/com/cost/costserver/dynamic/mapper/DynamicMapper.java`
- `cost-server/src/main/java/com/cost/costserver/dynamic/service/ValidationService.java`
- `cost-server/src/main/java/com/cost/costserver/dynamic/action/executor/SqlActionExecutor.java`
- `cost-server/src/main/java/com/cost/costserver/dynamic/action/executor/ProcedureActionExecutor.java`

主要风险：

- `DynamicMapper` 使用 `${sql}` 直接执行完整 SQL。
- `DynamicDataService` 约 1412 行，同时负责查询、保存、主从表保存、权限注入、字段映射、历史对比、Lookup、校验、审计、默认值处理。
- 行权限、筛选条件、排序、Lookup keyword 使用字符串拼接，已有部分校验，但策略分散。
- `SqlActionExecutor` 将规则 SQL 模板渲染后直接执行。

建议拆分：

- `dynamic.metadata`: 从元数据得到可查询/可写字段白名单。
- `dynamic.query`: 查询条件对象、排序对象、分页对象、SQL builder。
- `dynamic.command`: 新增、修改、删除、主从保存。
- `dynamic.lookup`: Lookup 数据源与搜索。
- `dynamic.validation`: 保存前校验和规则执行。
- `dynamic.audit`: 操作日志、审计日志写入。
- `dynamic.executor`: sql/proc/java action 执行器，统一安全校验和事务边界。

### 审批流域

主要代码：

- `cost-server/src/main/java/com/cost/costserver/approval/ApprovalRuntimeService.java`
- `cost-server/src/main/java/com/cost/costserver/approval/ApprovalRuntimeController.java`
- `pkg_wf_approval_body_tmp.sql`
- `审批流落地SQL步骤.md`

主要表：

- `WF_FLOW_DEF`
- `WF_FLOW_CONDITION`
- `WF_FLOW_NODE`
- `WF_FLOW_APPROVER`
- `WF_APPROVAL_MAIN`
- `WF_APPROVAL_DETAIL`
- `WF_APPROVAL_LOG`
- `WF_FLOW_NODE_ACTION_CONFIG`

当前职责混杂：

- Java 层负责权限和接口编排，核心流转在 Oracle 包 `PKG_WF_APPROVAL`。
- 审批动作还会根据节点配置再调用业务过程。
- 业务单据状态由包内动态 SQL 回写，依赖 `T_COST_TABLE_METADATA` 的目标表和主键字段。

建议拆分：

- `approval.definition`: 流程定义、条件、节点、审批人。
- `approval.runtime`: 申请、审批、驳回、取消、进度。
- `approval.integration`: 调用存储过程和业务回写适配器。
- `approval.action`: 节点动作配置和执行。
- `approval.query`: 待办、已办、日志、进度查询。

### 推送域

主要代码：

- `cost-server/src/main/java/com/cost/costserver/config/WebSocketConfig.java`
- `cost-server/src/main/java/com/cost/costserver/config/AppWebSocketHandler.java`
- `cost-web/src/v3/composables/meta-v3/useWebSocket.ts`
- `cost-web/src/v3/components/MasterDetailPageV3.vue`

当前用途：

- WebSocket `/ws` 支持广播和定向推送。
- 前端在元数据配置变更时触发热重载。

建议拆分：

- `notification.channel`: WebSocket session 管理。
- `notification.event`: 元数据变更、审批待办、数据变更等事件模型。
- `notification.publisher`: 后端业务事件发布。
- `notification.subscriber`: 前端订阅和路由分发。

## 前端功能域

### 显示层

主要代码：

- `cost-web/src/v3/components/meta-v3/renderers/MetaPageRendererV3.vue`
- `cost-web/src/v3/components/meta-v3/renderers/MetaGridV3.vue`
- `cost-web/src/v3/components/meta-v3/renderers/MetaFormV3.vue`
- `cost-web/src/v3/components/meta-v3/renderers/MetaButtonV3.vue`
- `cost-web/src/v3/components/detail/DetailGridV3.vue`
- `cost-web/src/v3/components/detail/DetailPanelV3.vue`

当前特点：

- 组件渲染器已有 registry，方向是对的。
- 页面运行时对象传入 renderer，导致 renderer 很容易访问过多能力。

建议边界：

- Renderer 只处理 UI 和事件转发。
- Runtime facade 对外暴露最小接口，例如 `query`、`mutate`、`action`、`permission`。
- 组件配置 schema 与 renderer props 分开管理。

### 计算层

主要代码：

- `cost-web/src/v3/logic/calc-engine/calculator.ts`
- `cost-web/src/v3/logic/calc-engine/parser.ts`
- `cost-web/src/v3/logic/calc-engine/validator.ts`
- `cost-web/src/v3/composables/meta-v3/useCalcBroadcast.ts`
- `docs/tablecode-calc-migration-playbook.md`

当前特点：

- 计算规则编译、聚合、主从广播、默认值解析都集中在前端。
- `calculator.ts` 有规则缓存，但与运行时缓存边界不够清晰。

建议拆分：

- `calc.parser`: 元数据 JSON 到规则模型。
- `calc.compiler`: 规则编译和缓存。
- `calc.runtime`: 行计算、聚合计算、主从广播。
- `calc.validation`: 规则合法性、迁移兼容检查。

### 缓存层

主要代码：

- 后端 `MetadataService.cache`
- 前端 `useWorkingSetStore`
- 前端 `useRuntimeMetadataReload`
- 前端 `calculator.ts` 的规则缓存
- 前端路由/tab/theme localStorage 缓存

当前问题：

- 缓存散落在服务、composable、store、工具函数里。
- 元数据变更、用户表格配置变更、数据刷新、计算规则刷新没有统一失效协议。

建议拆分：

- `cache.metadata`: table/page/component/rule 缓存。
- `cache.working-set`: 当前页面主从数据缓存。
- `cache.rule`: 计算规则编译缓存。
- `cache.user-preference`: 表格列宽、顺序、隐藏、固定列。
- 每个缓存定义 owner、key、ttl、invalidate event。

### 组装层

主要代码：

- `cost-web/src/v3/composables/meta-v3/runtime/index.ts`
- `cost-web/src/v3/composables/meta-v3/runtime/useRuntimeBootstrap.ts`
- `cost-web/src/v3/composables/meta-v3/useMetaConfig.ts`
- `cost-web/src/v3/composables/meta-v3/useMetaLoader.ts`
- `cost-web/src/v3/composables/meta-v3/useWorkingSetStore.ts`

当前特点：

- `useBaseRuntime` 已经尝试把 meta、workingSet、calc、lookup、search、export、actions 组装起来。
- 组装层仍直接创建大量子能力，导致横向依赖多，测试入口少。

建议拆分：

- `runtime.container`: 只负责依赖注入和生命周期。
- `runtime.capabilities`: grid、lookup、calc、approval、export、search 能力插件。
- `runtime.events`: 统一页面事件总线。
- `runtime.contract`: renderer 能访问的最小接口。

## 默认按钮行为

主要代码：

- `cost-web/src/v3/composables/meta-v3/useToolbarAction.ts`
- `cost-web/src/v3/components/meta-v3/renderers/MetaButtonV3.vue`
- `cost-server/src/main/java/com/cost/costserver/dynamic/service/PageRuleActionService.java`
- `cost-server/src/main/java/com/cost/costserver/dynamic/action/executor/*`

当前行为：

- 前端按钮根据 `action`、`requiresRow`、`refreshMode`、`confirm` 触发动作。
- 默认刷新策略：行级动作默认 `row`，非行级默认 `all`。
- 后端按 pageCode/componentKey/actionCode 找规则，再用 sql/proc/java executor 执行。

建议：

- 建立按钮动作注册表：内置动作、业务动作、审批动作、导出动作分组。
- 所有按钮 key 和动作 code 使用枚举/常量，不在服务里散落字符串。
- 后端动作结果返回统一 `ActionOutcome`，由前端决定刷新范围。

## 第一阶段重构路线

1. 建立 contracts：权限、元数据、动态查询、动作执行的 DTO 和接口先固定。
2. 从 `DynamicDataService` 抽出无状态 SQL builder，先用单元测试覆盖查询、排序、权限条件、Lookup。
3. 从 `PermissionService` 抽出 policy parser，避免行权限 SQL 到处传字符串。
4. 从 `MetadataService` 抽出 metadata cache 和 permission/user preference merger。
5. 将审批 Java 层拆为 runtime/procedure/action/query，保持 Oracle 包行为不变。
6. 前端把 `useBaseRuntime` 拆成 capability 插件，renderer 只拿 facade。
7. 清理老表和老备份表：`*_BAK*`、`*_20260519`、`PAGE_RULE0403` 先标记用途，再决定归档或迁移。

## 当前高风险点

- 动态 SQL 执行面过宽，必须优先收窄到白名单字段和受控条件对象。
- 行权限是 SQL 字符串，安全与可测试性都较弱。
- 后端大服务类超过 1000 行，单元测试难覆盖。
- 审批核心逻辑在数据库包内，Java 与 DB 包之间缺少版本化契约。
- 前端运行时组装能力过多，renderer 容易绕过边界直接操作内部状态。
