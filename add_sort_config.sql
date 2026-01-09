-- =====================================================
-- 为成本评估明细表添加自定义排序配置
-- 方案：使用 comparator 自定义排序（原料 → 辅料 → 印字包材 → 非印字包材）
-- =====================================================

-- 1. 更新 dtlUseflag 列元数据，添加 comparator 配置
UPDATE T_COST_COLUMN_METADATA
SET RULES_CONFIG = '{"comparator":"customCategorySort"}'
WHERE TABLE_METADATA_ID = (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostPingguDtl')
  AND FIELD_NAME = 'dtlUseflag';

-- 2. 更新 TABS 配置，添加 initialSort
UPDATE T_COST_PAGE_COMPONENT
SET COMPONENT_CONFIG = '{
  "mode": "group",
  "tabs": [
    {
      "key": "all",
      "title": "明细",
      "columns": ["dtlUseflag", "apexGoodsname", "spec", "perHl", "exaddMater", "batchQty", "price", "costBatch", "apexFactoryname", "memo"],
      "initialSort": [
        {"colId": "dtlUseflag", "sort": "asc"}
      ]
    }
  ],
  "broadcast": ["apexPl", "pPerpack", "sPerback", "xPerback"],
  "aggregates": [
    {"sourceField": "costBatch", "targetField": "totalYl", "algorithm": "SUM", "filter": "dtlUseflag === ''原料''"},
    {"sourceField": "costBatch", "targetField": "totalFl", "algorithm": "SUM", "filter": "dtlUseflag === ''辅料''"},
    {"sourceField": "costBatch", "targetField": "totalBc", "algorithm": "SUM", "filter": "dtlUseflag === ''印字包材'' || dtlUseflag === ''非印字包材''"},
    {"targetField": "totalCost", "expression": "totalYl + totalFl + totalBc"}
  ],
  "postProcess": "if (totalYl > 0) { totalYl /= 1.13; totalFl /= 1.13; totalBc /= 1.13; totalCost = totalYl + totalFl + totalBc; }",
  "masterCalcRules": [
    {"field": "salemoney", "expression": "outPriceRmb / pPerpack * apexPl * (yield / 100)", "triggerFields": ["outPriceRmb", "pPerpack", "apexPl", "yield", "totalCost"]},
    {"field": "jgfBatch", "expression": "salemoney - totalCost", "triggerFields": ["salemoney", "totalCost"]},
    {"field": "jgfPerqp", "expression": "jgfBatch / apexPl * 1000", "triggerFields": ["jgfBatch", "apexPl"]},
    {"field": "mlPerqp", "expression": "jgfPerqp - costPerqp", "triggerFields": ["jgfPerqp", "costPerqp"]},
    {"field": "yJgRe", "expression": "jgfPerqp / 1000 * annualQty", "triggerFields": ["jgfPerqp", "annualQty"]},
    {"field": "yMl", "expression": "mlPerqp / 1000 * annualQty", "triggerFields": ["mlPerqp", "annualQty"]},
    {"field": "ySale", "expression": "salemoney / apexPl * annualQty", "triggerFields": ["salemoney", "apexPl", "annualQty"]}
  ]
}'
WHERE PAGE_CODE = 'cost-pinggu' AND COMPONENT_KEY = 'detailTabs';

COMMIT;
