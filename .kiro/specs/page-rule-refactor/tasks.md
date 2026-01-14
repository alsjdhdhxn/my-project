# 页面规则改造实施计划

## 概述

按照 SQL → 后端 → 前端 的顺序执行改造，确保每一步都可验证。

## 任务列表

- [ ] 1. 重写列元数据 INSERT 语句
  - 删除 EDITABLE、VISIBLE、WIDTH、SEARCHABLE、RULES_CONFIG 等字段
  - 只保留基础字段：ID、TABLE_METADATA_ID、FIELD_NAME、COLUMN_NAME、HEADER_TEXT、DATA_TYPE、DISPLAY_ORDER、SORTABLE、FILTERABLE、IS_VIRTUAL、DICT_TYPE
  - _Requirements: 1.1, 1.2, 1.3_

- [ ] 2. 新增页面规则数据
  - [ ] 2.1 新增 master 组件的 COLUMN_OVERRIDE 规则
    - _Requirements: 2.1_
  - [ ] 2.2 新增 master 组件的 AGGREGATE 规则（从 detailTabs 迁移）
    - _Requirements: 2.1, 3.2_
  - [ ] 2.3 新增 master 组件的 CALC 规则（从 detailTabs.masterCalcRules 迁移）
    - _Requirements: 2.1, 3.2_
  - [ ] 2.4 新增 material 组件的 COLUMN_OVERRIDE、CALC、VALIDATION、LOOKUP 规则
    - _Requirements: 2.1_
  - [ ] 2.5 新增 package 组件的 COLUMN_OVERRIDE、CALC、VALIDATION、LOOKUP 规则
    - _Requirements: 2.1_

- [ ] 3. 简化页面组件配置
  - 从 detailTabs 的 COMPONENT_CONFIG 中移除 aggregates、masterCalcRules
  - _Requirements: 3.1_

- [ ] 4. Checkpoint - 验证 SQL 执行
  - 确保 init.sql 可以完整执行，无语法错误
  - 验证页面规则数据已正确插入

- [ ] 5. 后端改动
  - [ ] 5.1 新增 PageRule 实体类
    - _Requirements: 4.1_
  - [ ] 5.2 新增 PageRuleMapper
    - _Requirements: 4.2_
  - [ ] 5.3 新增 PageRuleDTO
    - _Requirements: 4.3_
  - [ ] 5.4 修改 MetadataService，新增 getPageRules 方法
    - _Requirements: 4.3_
  - [ ] 5.5 修改 MetadataController，/api/metadata/page/{pageCode} 返回规则数据
    - _Requirements: 4.4_

- [ ] 6. Checkpoint - 验证后端接口
  - 调用 /api/metadata/page/cost-pinggu-v2 验证返回数据包含 rules 字段

- [ ] 7. 前端改动
  - [ ] 7.1 新增规则类型定义 types/page-rule.ts
    - _Requirements: 5.1, 5.2, 5.3_
  - [ ] 7.2 修改 useMetaColumns.ts，新增 applyColumnOverrides 函数
    - _Requirements: 5.1_
  - [ ] 7.3 修改 calc-engine/parser.ts，新增规则解析函数
    - _Requirements: 5.3_
  - [ ] 7.4 修改 MasterDetailPageV2.vue，从页面规则读取配置
    - _Requirements: 5.2_

- [ ] 8. Checkpoint - 功能验证
  - 确保页面正常加载，计算、验证、弹窗回填功能正常

## 注意事项

- 任务 1-3 是 SQL 改动，需要一起执行
- 任务 5 是后端改动，需要重启服务
- 任务 7 是前端改动，热更新即可
