-- =====================================================
-- 成本评估页面改造：合并原料/辅料/包材到一个表格
-- 去掉侧边栏 Tab，所有明细在一个 Grid 中展示
-- =====================================================

-- 1. 删除旧的 TABS 组件配置
DELETE FROM T_COST_PAGE_COMPONENT
WHERE PAGE_CODE = 'cost-pinggu' AND COMPONENT_KEY = 'detailTabs';

-- 2. 新增单一 TABS 组件（只有一个 Tab，显示所有明细，包含聚合和级联计算）
INSERT INTO T_COST_PAGE_COMPONENT (
    ID,
    PAGE_CODE,
    COMPONENT_KEY,
    COMPONENT_TYPE,
    PARENT_KEY,
    SORT_ORDER,
    REF_TABLE_CODE,
    COMPONENT_CONFIG,
    CREATE_BY
)
VALUES (
    SEQ_COST_PAGE_COMPONENT.NEXTVAL,
    'cost-pinggu',
    'detailTabs',
    'TABS',
    'root',
    2,
    'CostPingguDtl',
    '{
      "mode": "group",
      "tabs": [
        {
          "key": "all",
          "title": "明细",
          "columns": ["dtlUseflag", "apexGoodsname", "spec", "perHl", "exaddMater", "batchQty", "price", "costBatch", "apexFactoryname", "memo"]
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
    }',
    'system'
);

COMMIT;

-- 验证配置
SELECT 
    COMPONENT_KEY,
    COMPONENT_TYPE,
    SORT_ORDER,
    COMPONENT_CONFIG
FROM T_COST_PAGE_COMPONENT
WHERE PAGE_CODE = 'cost-pinggu'
ORDER BY SORT_ORDER;
