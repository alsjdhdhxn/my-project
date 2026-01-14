# 页面规则改造需求文档

## 目标

将计算、验证、弹窗回填、列覆盖等规则从列元数据移到页面规则表，实现同一个表在不同页面可以有不同行为。

## 术语表

- **T_COST_COLUMN_METADATA**: 列元数据表，存储字段的基础定义（字段名、类型、标题）
- **T_COST_PAGE_RULE**: 页面规则表，存储页面级别的规则配置
- **COLUMN_OVERRIDE**: 列覆盖规则，覆盖列的 editable、visible、width 等属性
- **CALC**: 计算规则，定义字段的计算公式
- **VALIDATION**: 验证规则，定义字段的校验逻辑
- **LOOKUP**: 弹窗回填规则，定义弹窗选择后的字段映射
- **AGGREGATE**: 聚合规则，定义从表到主表的聚合计算

## 需求列表

### 需求 1: 精简列元数据

**用户故事**: 作为开发者，我希望列元数据只保留字段的基础定义，以便同一个表在不同页面可以有不同的展示和行为。

#### 验收标准

1. T_COST_COLUMN_METADATA 表结构只保留基础字段：ID、TABLE_METADATA_ID、FIELD_NAME、COLUMN_NAME、QUERY_COLUMN、TARGET_COLUMN、HEADER_TEXT、DATA_TYPE、DISPLAY_ORDER、SORTABLE、FILTERABLE、IS_VIRTUAL、DICT_TYPE
2. 删除以下字段：WIDTH、VISIBLE、EDITABLE、REQUIRED、SEARCHABLE、DEFAULT_VALUE、LOOKUP_CONFIG_ID、RULES_CONFIG
3. 所有列元数据 INSERT 语句只使用基础字段

### 需求 2: 页面规则数据配置

**用户故事**: 作为开发者，我希望通过 T_COST_PAGE_RULE 表配置页面级别的规则，以便灵活控制不同页面的行为。

#### 验收标准

1. cost-pinggu-v2 页面配置以下规则：
   - master 组件: COLUMN_OVERRIDE、CALC、VALIDATION
   - material 组件: COLUMN_OVERRIDE、CALC、VALIDATION、LOOKUP
   - package 组件: COLUMN_OVERRIDE、CALC、VALIDATION、LOOKUP
   - master 组件: AGGREGATE（聚合规则）
2. 规则数据格式符合前端解析要求
3. 每个组件 + RULE_TYPE 仅保留一条记录；需要多条规则时合并到同一条 RULES JSON 数组中

### 需求 3: 简化页面组件配置

**用户故事**: 作为开发者，我希望页面组件配置更简洁，聚合和计算规则统一放到 T_COST_PAGE_RULE 表。

#### 验收标准

1. detailTabs 的 COMPONENT_CONFIG 中移除 aggregates、masterCalcRules
2. 这些规则迁移到 T_COST_PAGE_RULE 表

### 需求 4: 后端支持页面规则

**用户故事**: 作为前端开发者，我希望后端接口返回页面规则数据，以便前端渲染时使用。

#### 验收标准

1. 新增 PageRule 实体类
2. 新增 PageRuleMapper
3. MetadataService 新增 getPageRules(pageCode) 方法
4. /api/metadata/page/{pageCode} 接口返回时附带规则数据
5. 规则数据按 componentKey 挂在对应组件上（每个组件只返回自己的规则）

### 需求 5: 前端适配新数据结构

**用户故事**: 作为用户，我希望页面功能正常工作，计算、验证、弹窗回填等功能不受影响。

#### 验收标准

1. useMetaColumns.ts 从页面规则读取列覆盖配置
2. MasterDetailPageV2.vue 从页面规则读取 CALC/VALIDATION/LOOKUP/AGGREGATE
3. calc-engine.ts 适配新的规则数据结构
4. 仅调整规则取值来源，保持现有解析和执行逻辑不变
5. 列覆盖等字段映射与现有列定义保持一致（如 visible/editable/width 等）
6. 规则解析失败或字段不存在时记录警告并忽略该条
