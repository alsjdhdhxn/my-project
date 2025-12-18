# 成本管理系统开发规则

> 本规则用于约束项目开发，确保架构一致性，所有代码生成和修改必须遵循以下规范。

## 核心参考文档

开发时必须参考以下文档，确保实现与架构设计一致：

- 架构设计：#[[file:成本管理系统架构总结.md]]
- 技术栈：#[[file:技术栈清单-MP动态查询方案.md]]

---

## 角色与沟通

- 你是项目全权负责人，负责功能设计、架构设计、代码质量，我是你的主管
- 遇到不确定的地方必须征求我的意见，不要擅自决策
- 我说错的地方要直接指出，不要盲目认同
- 不啰嗦讲重点，不要动不动写一大堆 md 文档
- 发现可以改进的地方主动提出并实施

---

## 通用开发原则

- **职责清晰**：每个文件、每个函数职责单一，不相关的代码不要混在一起
- **合理拆分**：大文件、大函数要及时拆分，使用合适的设计模式
- **类型统一**：前后端类型、字段、命名保持一致，避免 dataList/listData/items 这种不一致
- **影响评估**：任何改动都要评估对现有功能的影响，避免误删已有功能
- **生产优先**：不随便引入测试功能或依赖，不给生产环境增加负担
- **直面问题**：遇到问题要直面并解决，备选方案必须由我决策
- **主动重构**：发现字段冗余、命名不一致、代码重复时，主动优化
- **保持整洁**：修改功能时删除无用代码，重复代码立即抽象为公共方法

---

## 接口规范

统一响应格式：

```json
{
  "code": 200,
  "message": "success",
  "data": {}
}
```

状态码约定：

| code | 说明 |
|------|------|
| 200 | 成功 |
| 400 | 参数错误 |
| 401 | 未登录/Token 失效 |
| 403 | 无权限 |
| 500 | 服务器错误 |

分页数据格式：

```json
{
  "code": 200,
  "message": "success",
  "data": {
    "list": [],
    "total": 100,
    "page": 1,
    "pageSize": 20
  }
}
```

- 字段命名：统一使用 camelCase（驼峰），前后端保持一致
- 时间格式：统一使用 `yyyy-MM-dd HH:mm:ss` 格式，如 `2025-12-16 10:30:00`

---

## 开发环境

- 前端启动：`pnpm dev`（端口 5173）
- 后端启动：`mvn spring-boot:run` 或 IDEA 运行（端口 8080）
- 服务启动：我习惯自己启动服务，你不要擅自启动

---

## 一、架构原则（成本管理系统专属）

### 1.1 元数据驱动（核心原则）

- 所有 CRUD 页面必须通过元数据配置生成，禁止为单个业务表编写独立的 Controller/Service/Mapper
- 新增业务表只需配置 `T_COST_TABLE_METADATA` 和 `T_COST_COLUMN_METADATA`，前端自动渲染
- 动态查询使用 `DynamicMapper` + `QueryWrapper`，禁止为每个表创建独立 Mapper

### 1.2 数据访问分层

| 表类型 | 访问方式 | 说明 |
|--------|----------|------|
| 元数据表 | MyBatis-Plus + 实体类 | T_COST_TABLE_METADATA、T_COST_COLUMN_METADATA 等 |
| 基础数据/权限表 | MyBatis-Plus + 实体类 | T_COST_USER、T_COST_ROLE、T_COST_DEPARTMENT 等 |
| 业务数据表 | DynamicMapper | T_COST_DEMO 等，通过元数据驱动 |

- 元数据表和基础数据/权限表可以使用实体类，因为是系统基础设施
- 业务数据表禁止创建实体类，必须走 DynamicMapper 动态查询

### 1.2 组件树驱动页面

- 页面结构由 `T_COST_PAGE_COMPONENT` 组件树定义，前端只需一个通用渲染器
- 单表、主从、复杂布局都通过组件树配置，渲染器递归解析
- 禁止为常规 CRUD 页面编写独立的 Vue 组件

```vue
<!-- 通用页面渲染器：只传 pageCode -->
<DynamicPage pageCode="cost-master" />
```

### 1.3 三层计算模型

| 层级 | 配置位置 | 执行位置 | 场景 |
|------|----------|----------|------|
| 行级计算 | COLUMN_METADATA.RULES_CONFIG | 前端 | 金额 = 数量 × 单价 |
| 聚合计算 | PAGE_COMPONENT (LOGIC_AGG) | 前端 LogicEngine | 主表.总金额 = SUM(从表.金额) |
| 级联计算 | COLUMN_METADATA.RULES_CONFIG | 前端 | 税额 = 总金额 × 税率 |

---

## 二、后端开发规范

### 2.1 技术栈约束

| 组件 | 必须使用 | 禁止使用 |
|------|----------|----------|
| 框架 | Spring Boot 3.2.x | Spring Boot 2.x |
| 持久层 | MyBatis-Plus 3.5.5+ | 原生 MyBatis、JPA |
| 连接池 | Druid | HikariCP |
| 安全 | Spring Security + JWT | Shiro |
| 工具库 | Hutool | Apache Commons |

### 2.2 动态数据接口规范

```text
GET    /api/data/{tableCode}           - 查询列表
POST   /api/data/{tableCode}/search    - 高级查询
GET    /api/data/{tableCode}/{id}      - 查询单条
POST   /api/data/{tableCode}           - 新增
PUT    /api/data/{tableCode}/{id}      - 更新
DELETE /api/data/{tableCode}/{id}      - 删除（软删除）
```

- 所有业务数据接口必须走 `DynamicDataController`
- 禁止为单个业务表创建独立的 Controller

### 2.3 元数据接口规范

```text
GET    /api/metadata/table/{tableCode}     - 获取表元数据 + 列元数据
GET    /api/metadata/page/{pageCode}       - 获取页面组件树
GET    /api/metadata/lookup/{lookupCode}   - 获取弹窗选择器配置
GET    /api/metadata/dict/{dictType}       - 获取字典项
```

- 元数据接口由 `MetadataController` 统一提供
- 前端缓存元数据，避免重复请求

### 2.4 SQL 安全三道防线

1. **元数据白名单**：表名、列名必须在元数据中定义
2. **QueryWrapper 预编译**：查询条件值自动预编译
3. **Druid WallFilter**：禁止 DROP、TRUNCATE、多语句执行

### 2.5 Mapper 规范

- 使用 `@Select`/`@Insert`/`@Update` 注解，禁止使用 XML 配置
- 动态表名使用 `${tableName}`，必须经过白名单校验
- 动态值使用 `#{value}`，自动预编译

---

## 三、前端开发规范

### 3.1 技术栈约束

| 组件 | 必须使用 | 禁止使用 |
|------|----------|----------|
| 基础框架 | Soybean Admin | 其他模板 |
| UI 组件库 | Naive UI | Element Plus、Ant Design |
| 表格 | AG Grid | VxeTable、原生 table |
| 表单生成 | form-create | Formily |
| 状态管理 | Pinia | Vuex |

### 3.2 组件封装规范

必须封装以下元数据驱动组件，由 `DynamicPage` 渲染器递归调用：

| 组件名 | 对应 COMPONENT_TYPE | 职责 |
|--------|---------------------|------|
| DynamicPage | - | 页面渲染器，根据 pageCode 加载组件树并递归渲染 |
| MetaLayout | LAYOUT | 布局容器，支持嵌套 |
| MetaGrid | GRID | AG Grid 表格，根据 REF_METADATA_ID 获取列定义 |
| MetaForm | FORM | 表单/查询区，根据 REF_METADATA_ID 获取字段定义 |
| MetaButton | BUTTON | 按钮/工具栏 |
| MetaFormDialog | - | 弹窗表单（新增/编辑） |

组件接收参数：
```typescript
interface ComponentProps {
  config: PageComponent;      // T_COST_PAGE_COMPONENT 记录
  pageContext: PageContext;   // 页面上下文（共享数据、事件总线）
}
```

### 3.3 页面渲染流程

```
1. 路由传入 pageCode
2. DynamicPage 调用 /api/metadata/page/{pageCode} 获取组件树
3. 递归渲染组件树，每个组件根据 COMPONENT_TYPE 选择对应渲染器
4. GRID/FORM 组件根据 REF_METADATA_ID 获取列/字段元数据
5. LOGIC_xxx 组件注册到 LogicEngine，建立响应式监听
```

### 3.4 禁止事项

- 禁止为单个业务表编写独立的 Vue 页面组件
- 禁止在组件中硬编码列定义，必须从元数据获取
- 禁止绕过 LogicEngine 直接写计算逻辑

---

## 四、元数据配置规范

### 4.1 表元数据 (T_COST_TABLE_METADATA)

```sql
-- TABLE_CODE 使用大驼峰命名
-- QUERY_VIEW 用于查询（可关联多表）
-- TARGET_TABLE 用于保存（单表）
INSERT INTO T_COST_TABLE_METADATA (TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME)
VALUES ('CostMaster', '成本主表', 'V_COST_MASTER', 'T_COST_MASTER', 'SEQ_COST_MASTER');
```

### 4.2 列元数据 (T_COST_COLUMN_METADATA)

```sql
-- FIELD_NAME 使用小驼峰命名
-- DATA_TYPE: text/number/date/select/lookup
-- RULES_CONFIG 存储行级计算规则
INSERT INTO T_COST_COLUMN_METADATA (TABLE_METADATA_ID, FIELD_NAME, HEADER_TEXT, DATA_TYPE, EDITABLE, RULES_CONFIG)
VALUES (1, 'amount', '金额', 'number', 0, '{"calculate":{"expression":"quantity*unitPrice","triggerFields":["quantity","unitPrice"]}}');
```

### 4.3 页面组件 (T_COST_PAGE_COMPONENT)

```sql
-- COMPONENT_TYPE: GRID/FORM/BUTTON/LAYOUT/LOGIC_AGG/LOGIC_FIELD/LOGIC_MAPPING
-- LOGIC_AGG 用于跨组件聚合计算
INSERT INTO T_COST_PAGE_COMPONENT (PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, COMPONENT_CONFIG)
VALUES ('cost-master', 'agg_total', 'LOGIC_AGG', '{"sourceComponent":"detailGrid","sourceField":"amount","targetComponent":"masterForm","targetField":"totalAmount","algorithm":"SUM"}');
```

---

## 五、权限配置规范

### 5.1 四层权限模型

| 层级 | 配置表 | 控制粒度 |
|------|--------|----------|
| 页面权限 | T_COST_ROLE_PAGE.PAGE_CODE | 能否访问页面 |
| 按钮权限 | T_COST_ROLE_PAGE.BUTTON_POLICY | 能否执行操作 |
| 列权限 | T_COST_ROLE_PAGE.COLUMN_POLICY | 列可见/可编辑 |
| 数据权限 | T_COST_ROLE_PAGE_DATA_RULE | 行级数据过滤 |

### 5.2 权限合并规则

```text
基础层 (COLUMN_METADATA) → 限制层 (ROLE_PAGE) → 偏好层 (USER_GRID_CONFIG)
```

- 角色权限只能收紧，不能放宽
- 用户偏好不能突破角色限制

---

## 六、命名规范

### 6.1 数据库命名

| 对象 | 规范 | 示例 |
|------|------|------|
| 表名 | T_COST_大写下划线 | T_COST_MASTER |
| 视图 | V_COST_大写下划线 | V_COST_MASTER |
| 序列 | SEQ_大写下划线 | SEQ_COST_MASTER |
| 索引 | IDX_表名_列名 | IDX_COST_MASTER_CODE |

### 6.2 代码命名

| 对象 | 规范 | 示例 |
|------|------|------|
| tableCode | 大驼峰 | CostMaster |
| fieldName | 小驼峰 | costDate |
| 组件 Key | 小驼峰 | masterForm |
| 页面 Code | 小写中划线 | cost-master |

---

## 七、禁止事项清单

1. ❌ 禁止为单个业务表创建独立的 Controller/Service/Mapper
2. ❌ 禁止为单个业务表创建独立的 Vue 页面组件
3. ❌ 禁止在代码中硬编码表名、列名
4. ❌ 禁止使用 XML 配置 MyBatis SQL
5. ❌ 禁止绕过元数据直接操作数据库
6. ❌ 禁止在前端硬编码计算逻辑，必须配置在元数据中
7. ❌ 禁止使用 Element Plus、Ant Design 等非 Naive UI 组件
8. ❌ 禁止使用 Vuex 替代 Pinia
9. ❌ 禁止擅自创建实体类（Entity）或 Service，必须先征求主管意见

---

## 八、技术查询优先级

遇到不熟悉的技术或 API 时，按以下顺序查询：

1. **优先使用 MCP 查询官方文档**：通过 MCP 工具获取官方最新文档
2. **查询成熟项目案例**：如果官方文档查不到，搜索 GitHub 上成熟项目的实现方式
3. **最后才进行推测**：只有在前两步都无法获取信息时，才基于经验进行合理推测，并明确告知用户这是推测

禁止在未查证的情况下直接编造 API 用法或配置方式。
