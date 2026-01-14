# 页面规则改造设计文档

## 概述

将计算、验证、弹窗回填、列覆盖等规则从列元数据（T_COST_COLUMN_METADATA）移到页面规则表（T_COST_PAGE_RULE），实现同一个表在不同页面可以有不同行为。

## 架构设计

### 数据流变化

**改造前**：
```
前端 → 获取列元数据 → 从 RULES_CONFIG 提取规则 → 应用规则
```

**改造后**：
```
前端 → 获取页面组件 + 页面规则 → 从 T_COST_PAGE_RULE 读取规则 → 应用规则
```

### 规则类型定义

| RULE_TYPE | 说明 | RULES 格式 |
|-----------|------|-----------|
| COLUMN_OVERRIDE | 列覆盖 | `[{field, width, visible, editable, searchable, required}]` |
| CALC | 计算规则 | `[{field, expression, triggerFields, formulaField?, formulas?}]` |
| VALIDATION | 验证规则 | `[{field, required, min, max, pattern, message}]` |
| LOOKUP | 弹窗回填 | `[{field, lookupCode, mapping}]` |
| AGGREGATE | 聚合规则 | `[{sourceField, targetField, algorithm, filter?, expression?}]` |

约束：每个组件 + RULE_TYPE 只保留一条记录；需要多条规则时合并到同一条 RULES JSON 数组。

## 组件设计

### 后端组件

#### PageRule 实体类

```java
@Data
@TableName("T_COST_PAGE_RULE")
public class PageRule {
    @TableId(type = IdType.INPUT)
    private Long id;
    private String pageCode;
    private String componentKey;
    private String ruleType;
    private String rules;  // JSON
    private Integer sortOrder;
    private String description;
    private Integer deleted;
}
```

#### PageRuleMapper

```java
@Mapper
public interface PageRuleMapper extends BaseMapper<PageRule> {
}
```

#### MetadataService 扩展

```java
// 新增方法
public List<PageRuleDTO> getPageRules(String pageCode) {
    List<PageRule> rules = pageRuleMapper.selectList(
        new LambdaQueryWrapper<PageRule>()
            .eq(PageRule::getPageCode, pageCode)
            .eq(PageRule::getDeleted, 0)
            .orderByAsc(PageRule::getSortOrder)
    );
    return rules.stream().map(PageRuleDTO::from).toList();
}
```

#### PageComponentDTO 扩展

```java
// 在返回页面组件时附带该组件的规则
public record PageComponentDTO(
    // ... 现有字段
    List<PageRuleDTO> rules  // 新增：该组件的规则
) {}
```

说明：页面规则按 componentKey 绑定到组件返回，每个组件仅包含自己的规则。

### 前端组件

说明：仅修改规则取值来源，保持现有解析与执行逻辑不变；字段映射与现有列定义保持一致。

#### 规则类型定义

```typescript
// types/page-rule.ts
export interface PageRule {
  id: number;
  pageCode: string;
  componentKey: string;
  ruleType: 'COLUMN_OVERRIDE' | 'CALC' | 'VALIDATION' | 'LOOKUP' | 'AGGREGATE';
  rules: string;  // JSON 字符串
  sortOrder: number;
}

export interface ColumnOverrideRule {
  field: string;
  width?: number;
  visible?: boolean;
  editable?: boolean;
  searchable?: boolean;
  required?: boolean;
}

export interface CalcRule {
  field: string;
  expression: string;
  triggerFields: string[];
  formulaField?: string;
  formulas?: Record<string, { expression: string; triggerFields: string[] }>;
}

export interface ValidationRule {
  field: string;
  required?: boolean;
  min?: number;
  max?: number;
  pattern?: string;
  message?: string;
}

export interface LookupRule {
  field: string;
  lookupCode: string;
  mapping: Record<string, string>;
}

export interface AggregateRule {
  sourceField?: string;
  targetField: string;
  algorithm?: 'SUM' | 'AVG' | 'COUNT' | 'MAX' | 'MIN';
  filter?: string;
  expression?: string;
  sourceTab?: string;
}
```

#### useMetaColumns.ts 改造

```typescript
// 新增：从页面规则提取列覆盖配置（rules 为该组件的规则）
export function applyColumnOverrides(
  columns: ColDef[],
  rules: PageRule[]
): ColDef[] {
  const overrideRule = rules.find(
    r => r.ruleType === 'COLUMN_OVERRIDE'
  );
  if (!overrideRule) return columns;
  
  const overrides: ColumnOverrideRule[] = JSON.parse(overrideRule.rules);
  const overrideMap = new Map(overrides.map(o => [o.field, o]));
  
  return columns.map(col => {
    const override = overrideMap.get(col.field as string);
    if (!override) return col;
    return {
      ...col,
      width: override.width ?? col.width,
      hide: override.visible === false,
      editable: override.editable ?? col.editable
    };
  });
}
```

#### MasterDetailPageV2.vue 改造

```typescript
// 从页面规则读取各类规则（rules 为该组件的规则）
function extractRulesFromPageRules(rules: PageRule[]) {
  const calcRule = rules.find(r => r.ruleType === 'CALC');
  const validationRule = rules.find(r => r.ruleType === 'VALIDATION');
  const lookupRule = rules.find(r => r.ruleType === 'LOOKUP');
  const aggregateRule = rules.find(r => r.ruleType === 'AGGREGATE');
  
  return {
    calcRules: calcRule ? JSON.parse(calcRule.rules) : [],
    validationRules: validationRule ? JSON.parse(validationRule.rules) : [],
    lookupRules: lookupRule ? JSON.parse(lookupRule.rules) : [],
    aggregateRules: aggregateRule ? JSON.parse(aggregateRule.rules) : []
  };
}
```

## 数据模型

### T_COST_PAGE_RULE 表结构（已存在）

```sql
CREATE TABLE T_COST_PAGE_RULE (
    ID              NUMBER(19)      PRIMARY KEY,
    PAGE_CODE       VARCHAR2(64)    NOT NULL,
    COMPONENT_KEY   VARCHAR2(64)    NOT NULL,
    RULE_TYPE       VARCHAR2(32)    NOT NULL,
    RULES           CLOB            NOT NULL,
    SORT_ORDER      NUMBER(5)       DEFAULT 0,
    DESCRIPTION     VARCHAR2(200),
    DELETED         NUMBER(1)       DEFAULT 0,
    CREATE_TIME     TIMESTAMP       DEFAULT SYSTIMESTAMP,
    UPDATE_TIME     TIMESTAMP       DEFAULT SYSTIMESTAMP,
    CREATE_BY       VARCHAR2(64),
    UPDATE_BY       VARCHAR2(64)
);
```

### 页面规则数据示例

```sql
-- master 组件的列覆盖规则
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'cost-pinggu-v2', 'master', 'COLUMN_OVERRIDE', 
'[
  {"field":"id","visible":false},
  {"field":"goodsname","width":150,"editable":true,"searchable":true},
  {"field":"totalYl","editable":false},
  {"field":"totalFl","editable":false},
  {"field":"totalBc","editable":false},
  {"field":"totalCost","editable":false}
]', 'system');

-- master 组件的聚合规则
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'cost-pinggu-v2', 'master', 'AGGREGATE',
'[
  {"sourceField":"costBatch","targetField":"totalYl","algorithm":"SUM","sourceTab":"material","filter":"dtlUseflag === ''原料''"},
  {"sourceField":"costBatch","targetField":"totalFl","algorithm":"SUM","sourceTab":"material","filter":"dtlUseflag === ''辅料''"},
  {"sourceField":"costBatch","targetField":"totalBc","algorithm":"SUM","sourceTab":"package"},
  {"targetField":"totalCost","expression":"totalYl + totalFl + totalBc"}
]', 'system');

-- material 组件的计算规则
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'cost-pinggu-v2', 'material', 'CALC',
'[
  {"field":"batchQty","formulaField":"formulaType","formulas":{"C":{"expression":"perHl * apexPl * (1 + exaddMater / 100) / 1000000","triggerFields":["perHl","apexPl","exaddMater"]}}},
  {"field":"costBatch","expression":"batchQty * price","triggerFields":["batchQty","price"]}
]', 'system');
```

## 正确性属性

*正确性属性是系统在所有有效执行中应保持为真的特征或行为。属性是人类可读规范与机器可验证正确性保证之间的桥梁。*

### Property 1: 规则 JSON 解析一致性

*对于任意* 有效的页面规则记录，前端解析 RULES 字段后应得到符合对应 RULE_TYPE 类型定义的对象数组。

**Validates: Requirements 2.2, 5.3**

### Property 2: 列覆盖规则应用正确性

*对于任意* 列定义和列覆盖规则，应用覆盖后的列定义应正确反映覆盖配置（width、visible、editable 等）。

**Validates: Requirements 5.1**

## 错误处理

1. **规则 JSON 解析失败**：记录警告日志，使用空规则继续
2. **规则类型不匹配**：忽略该规则，记录警告
3. **字段不存在**：忽略该字段的规则配置

## 测试策略

### 单元测试

- 规则 JSON 解析函数测试
- 列覆盖应用函数测试
- 计算规则提取函数测试

### 集成测试

- 后端接口返回规则数据测试
- 前端页面加载并应用规则测试

### 属性测试

- 使用 fast-check 生成随机规则配置，验证解析和应用的正确性
