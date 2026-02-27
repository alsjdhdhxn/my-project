---
inclusion: always
---

# 核心数据库表结构

本项目使用 Oracle 数据库，以下是元数据驱动体系的核心表结构。修改涉及这些表的代码时必须参考此文档。

## T_COST_TABLE_METADATA（表元数据）

定义系统中所有业务表的元信息。

| 字段 | 类型 | 说明 |
|------|------|------|
| ID | NUMBER(19) | 主键 |
| TABLE_CODE | VARCHAR2(64) | 表代码（唯一），如 CostPinggu、CostMaterial |
| TABLE_NAME | VARCHAR2(128) | 表中文名 |
| QUERY_VIEW | VARCHAR2(64) | 查询用的视图名（可空，空则用 TARGET_TABLE） |
| TARGET_TABLE | VARCHAR2(64) | 实际写入的物理表名 |
| SEQUENCE_NAME | VARCHAR2(64) | 序列名（用于生成 ID） |
| PK_COLUMN | VARCHAR2(64) | 主键列名，默认 'ID' |
| PARENT_TABLE_CODE | VARCHAR2(64) | 父表代码（主从关系） |
| PARENT_FK_COLUMN | VARCHAR2(64) | 外键列名（关联父表） |
| AUDIT_ENABLED | NUMBER(1) | 是否启用审计 |
| VALIDATION_RULES | CLOB | 验证规则（JSON） |
| ACTION_RULES | CLOB | 动作规则（JSON） |
| DELETED | NUMBER(1) | 软删除标记 |

注意：此表没有 VISIBLE、EDITABLE 字段。

## T_COST_COLUMN_METADATA（列元数据）

定义每张表有哪些列，是前端 AG Grid 列定义的基础数据源。

| 字段 | 类型 | 说明 |
|------|------|------|
| ID | NUMBER(19) | 主键 |
| TABLE_METADATA_ID | NUMBER(19) | 外键，关联 T_COST_TABLE_METADATA.ID |
| FIELD_NAME | VARCHAR2(64) | 字段名（对应前端 ColDef.field） |
| COLUMN_NAME | VARCHAR2(64) | 数据库物理列名 |
| QUERY_COLUMN | VARCHAR2(128) | 查询列表达式（可含别名、函数） |
| TARGET_COLUMN | VARCHAR2(64) | 写入目标列名 |
| HEADER_TEXT | VARCHAR2(128) | 列标题（前端显示） |
| DATA_TYPE | VARCHAR2(32) | 数据类型，默认 'text' |
| DISPLAY_ORDER | NUMBER(5) | 显示顺序 |
| SORTABLE | NUMBER(1) | 是否可排序 |
| FILTERABLE | NUMBER(1) | 是否可筛选 |
| IS_VIRTUAL | NUMBER(1) | 是否虚拟列 |
| DICT_TYPE | VARCHAR2(64) | 字典类型 |
| DELETED | NUMBER(1) | 软删除标记 |

注意：此表没有 VISIBLE、EDITABLE 字段！列的可见性和可编辑性由 T_COST_PAGE_RULE 中的 COLUMN_OVERRIDE 规则控制。

## T_COST_PAGE_RULE（页面规则）

存储所有页面级配置规则，是元数据驱动的核心。

| 字段 | 类型 | 说明 |
|------|------|------|
| ID | NUMBER(19) | 主键 |
| PAGE_CODE | VARCHAR2(64) | 页面代码 |
| COMPONENT_KEY | VARCHAR2(64) | 组件标识 |
| RULE_TYPE | VARCHAR2(32) | 规则类型（见下方枚举） |
| RULES | CLOB | 规则内容（JSON） |
| SORT_ORDER | NUMBER(5) | 排序 |
| DESCRIPTION | VARCHAR2(200) | 描述 |
| DELETED | NUMBER(1) | 软删除标记 |

RULE_TYPE 枚举值：
- COLUMN_OVERRIDE — 列覆盖（visible、editable、width、cellEditor、precision 等）
- CELL_EDITABLE — 单元格级可编辑规则（基于条件控制哪些字段可编辑）
- ROW_EDITABLE — 行级可编辑规则
- GRID_STYLE — 行/单元格样式规则（backgroundColor、color 等）
- CALC — 前端计算规则
- AGGREGATE — 聚合规则（主从表汇总）
- VALIDATION — 验证规则
- LOOKUP — Lookup 弹窗配置
- BROADCAST — 主从表广播字段
- BUTTON — 按钮配置（右键菜单 + 工具栏）
- GRID_OPTIONS — Grid 选项（autoSizeColumns、cacheBlockSize 等）
- RELATION — 关联关系
- ROLE_BINDING — 角色绑定
- NESTED_CONFIG / SUMMARY_CONFIG — 嵌套/汇总配置

## T_COST_PAGE_COMPONENT（页面组件）

定义页面的组件树结构。

| 字段 | 类型 | 说明 |
|------|------|------|
| ID | NUMBER(19) | 主键 |
| PAGE_CODE | VARCHAR2(64) | 页面代码 |
| COMPONENT_KEY | VARCHAR2(64) | 组件标识（PAGE_CODE + COMPONENT_KEY 唯一） |
| COMPONENT_TYPE | VARCHAR2(32) | 组件类型（GRID、FORM、TAB 等） |
| PARENT_KEY | VARCHAR2(64) | 父组件标识 |
| COMPONENT_CONFIG | CLOB | 组件配置（JSON，含 buttons 等） |
| REF_TABLE_CODE | VARCHAR2(64) | 关联的表代码 |
| SLOT_NAME | VARCHAR2(32) | 插槽名 |
| SORT_ORDER | NUMBER(5) | 排序 |
| DELETED | NUMBER(1) | 软删除标记 |

## T_COST_ROLE_PAGE（角色页面权限）

控制角色对页面的按钮、列、行级权限。

| 字段 | 类型 | 说明 |
|------|------|------|
| ID | NUMBER(19) | 主键 |
| ROLE_ID | NUMBER(19) | 角色 ID |
| PAGE_CODE | VARCHAR2(64) | 页面代码 |
| BUTTON_POLICY | VARCHAR2(1000) | 按钮权限策略（JSON） |
| COLUMN_POLICY | CLOB | 列权限策略（JSON，控制哪些列可见/可编辑） |
| ROW_POLICY | VARCHAR2(2000) | 行级数据权限（SQL 条件） |

注意：ROLE_ID + PAGE_CODE 有唯一约束。

## T_COST_RESOURCE（页面资源/菜单）

定义系统菜单和页面资源。

| 字段 | 类型 | 说明 |
|------|------|------|
| ID | NUMBER(19) | 主键 |
| RESOURCE_NAME | VARCHAR2(128) | 资源名称 |
| RESOURCE_TYPE | VARCHAR2(20) | 资源类型 |
| PAGE_CODE | VARCHAR2(64) | 关联页面代码 |
| ICON | VARCHAR2(64) | 图标 |
| ROUTE | VARCHAR2(128) | 路由 |
| PARENT_ID | NUMBER(19) | 父资源 ID |
| SORT_ORDER | NUMBER(5) | 排序 |
| IS_HARDCODED | NUMBER(1) | 是否硬编码 |

## 关键业务规则（踩坑记录）

1. COLUMN_OVERRIDE 只能覆盖已有列的属性，不能创建新列。列的来源只有 T_COST_COLUMN_METADATA。
2. 可编辑优先级：COLUMN_OVERRIDE editable:false > CELL_EDITABLE > COLUMN_OVERRIDE editable:true
3. T_COST_COLUMN_METADATA 没有 VISIBLE 和 EDITABLE 字段，这两个属性完全由 COLUMN_OVERRIDE 规则决定。
4. 权限配置 UI（listPageColumns）应以 T_COST_COLUMN_METADATA 为基础列表，COLUMN_OVERRIDE 只决定默认勾选状态。
5. admin 用户绕过所有权限检查（isSuperAdmin()）。
6. 前端 WebSocket 推送后，editable/rowClass/rowStyle 回调必须动态获取最新规则，不能用闭包捕获旧值。
