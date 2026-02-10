-- ============================================================
-- ROW_CLASS 规则：className 模式 → style 模式
-- 将所有使用 className 的 ROW_CLASS 规则改为内联 style
-- ============================================================

-- 1. 备份
CREATE TABLE T_COST_PAGE_RULE_ROWCLASS_BAK AS
SELECT * FROM T_COST_PAGE_RULE WHERE RULE_TYPE = 'ROW_CLASS' AND DELETED = 0;

-- 2. goods-manage / grid (ID=516)
-- row-confirmed → 绿底 #e6ffed
UPDATE T_COST_PAGE_RULE SET
  RULES = '[{"field":"iserp","operator":"eq","value":1,"style":{"backgroundColor":"#e6ffed"}}]',
  UPDATE_TIME = SYSTIMESTAMP
WHERE ID = 516 AND DELETED = 0;

-- 3. customer-manage / masterGrid (ID=276)
-- row-confirmed → 绿底 #e6ffed
UPDATE T_COST_PAGE_RULE SET
  RULES = '[{"field":"iserp","operator":"eq","value":1,"style":{"backgroundColor":"#e6ffed"}}]',
  UPDATE_TIME = SYSTIMESTAMP
WHERE ID = 276 AND DELETED = 0;

-- 4. customer-manage / tranposer (ID=277)
-- row-confirmed → 绿底 #e6ffed
UPDATE T_COST_PAGE_RULE SET
  RULES = '[{"field":"iserp","operator":"eq","value":1,"style":{"backgroundColor":"#e6ffed"}}]',
  UPDATE_TIME = SYSTIMESTAMP
WHERE ID = 277 AND DELETED = 0;

-- 5. goods-price-manage / grid (ID=520)
-- row-iserp → 绿底 #e6ffed
-- row-iserp-updated → 黄底 #fff2a8
-- row-iserp-price-null → 红底 #f8d7da
UPDATE T_COST_PAGE_RULE SET
  RULES = '[{"field":"rowClassFlag","operator":"eq","value":"erp","style":{"backgroundColor":"#e6ffed"}},{"field":"rowClassFlag","operator":"eq","value":"erp-updated","style":{"backgroundColor":"#fff2a8"}},{"field":"rowClassFlag","operator":"eq","value":"erp-price-null","style":{"backgroundColor":"#f8d7da"}}]',
  UPDATE_TIME = SYSTIMESTAMP
WHERE ID = 520 AND DELETED = 0;

COMMIT;

-- 6. 验证：不应再有 className 的 ROW_CLASS 规则
SELECT ID, PAGE_CODE, COMPONENT_KEY, RULES
FROM T_COST_PAGE_RULE
WHERE RULE_TYPE = 'ROW_CLASS' AND DELETED = 0
AND RULES LIKE '%className%';
