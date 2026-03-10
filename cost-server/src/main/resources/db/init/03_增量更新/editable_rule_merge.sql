-- EDITABLE 规则迁移脚本
-- 说明：
-- 1. 将旧规则类型 ROW_EDITABLE / CELL_EDITABLE 统一迁移为 EDITABLE
-- 2. 本脚本按导出的原始脚本中的 4 条数据做精确迁移
-- 3. 迁移后代码只认 EDITABLE，不再兼容旧类型

-- ------------------------------------------------------------------
-- 0. 备份表（幂等）
-- ------------------------------------------------------------------
DECLARE
  v_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*) INTO v_exists
  FROM USER_TABLES
  WHERE TABLE_NAME = 'T_COST_PAGE_RULE_EDITABLE_BAK_20260310';

  IF v_exists = 0 THEN
    EXECUTE IMMEDIATE '
      CREATE TABLE T_COST_PAGE_RULE_EDITABLE_BAK_20260310 AS
      SELECT * FROM T_COST_PAGE_RULE WHERE 1 = 2
    ';
  END IF;
END;
/

INSERT INTO T_COST_PAGE_RULE_EDITABLE_BAK_20260310
SELECT t.*
FROM T_COST_PAGE_RULE t
WHERE t.ID IN (498, 499, 517, 521)
  AND NVL(t.DELETED, 0) = 0
  AND NOT EXISTS (
    SELECT 1
    FROM T_COST_PAGE_RULE_EDITABLE_BAK_20260310 b
    WHERE b.ID = t.ID
  );

COMMIT;

-- ------------------------------------------------------------------
-- 1. Patch 表（幂等）
-- ------------------------------------------------------------------
DECLARE
  v_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*) INTO v_exists
  FROM USER_TABLES
  WHERE TABLE_NAME = 'T_COST_PAGE_RULE_EDITABLE_PATCH_20260310';

  IF v_exists = 0 THEN
    EXECUTE IMMEDIATE '
      CREATE TABLE T_COST_PAGE_RULE_EDITABLE_PATCH_20260310 (
        ID NUMBER PRIMARY KEY,
        RULE_TYPE_NEW VARCHAR2(64),
        RULES_NEW CLOB,
        COMMENT_TEXT VARCHAR2(200)
      )
    ';
  END IF;
END;
/

MERGE INTO T_COST_PAGE_RULE_EDITABLE_PATCH_20260310 p
USING (
  SELECT 517 AS ID,
         'EDITABLE' AS RULE_TYPE_NEW,
         q'~[
  {
    "scope": "row",
    "logic": "AND",
    "conditions": [
      { "field": "ISERP", "operator": "ne", "value": 1 }
    ]
  }
]~' AS RULES_NEW,
         'goods-manage.grid row editable -> EDITABLE' AS COMMENT_TEXT
  FROM dual
  UNION ALL
  SELECT 498 AS ID,
         'EDITABLE' AS RULE_TYPE_NEW,
         q'~[
  {
    "scope": "row",
    "logic": "AND",
    "conditions": [
      { "field": "ISERP", "operator": "ne", "value": 1 }
    ]
  }
]~' AS RULES_NEW,
         'customer-manage.masterGrid row editable -> EDITABLE' AS COMMENT_TEXT
  FROM dual
  UNION ALL
  SELECT 499 AS ID,
         'EDITABLE' AS RULE_TYPE_NEW,
         q'~[
  {
    "scope": "row",
    "logic": "AND",
    "conditions": [
      { "field": "ISERP", "operator": "ne", "value": 1 }
    ]
  }
]~' AS RULES_NEW,
         'customer-manage.tranposer row editable -> EDITABLE' AS COMMENT_TEXT
  FROM dual
  UNION ALL
  SELECT 521 AS ID,
         'EDITABLE' AS RULE_TYPE_NEW,
         q'~[
  {
    "scope": "cell",
    "logic": "AND",
    "conditions": [
      { "field": "ISERP", "operator": "eq", "value": "1" }
    ],
    "editableFields": ["price"]
  }
]~' AS RULES_NEW,
         'goods-price-manage.grid cell editable -> EDITABLE' AS COMMENT_TEXT
  FROM dual
) s
ON (p.ID = s.ID)
WHEN MATCHED THEN
  UPDATE SET
    p.RULE_TYPE_NEW = s.RULE_TYPE_NEW,
    p.RULES_NEW = s.RULES_NEW,
    p.COMMENT_TEXT = s.COMMENT_TEXT
WHEN NOT MATCHED THEN
  INSERT (ID, RULE_TYPE_NEW, RULES_NEW, COMMENT_TEXT)
  VALUES (s.ID, s.RULE_TYPE_NEW, s.RULES_NEW, s.COMMENT_TEXT);

COMMIT;

-- ------------------------------------------------------------------
-- 2. 应用迁移
-- ------------------------------------------------------------------
MERGE INTO T_COST_PAGE_RULE t
USING (
  SELECT p.ID, p.RULE_TYPE_NEW, p.RULES_NEW
  FROM T_COST_PAGE_RULE_EDITABLE_PATCH_20260310 p
) s
ON (
  t.ID = s.ID
  AND NVL(t.DELETED, 0) = 0
)
WHEN MATCHED THEN
  UPDATE SET
    t.RULE_TYPE = s.RULE_TYPE_NEW,
    t.RULES = s.RULES_NEW,
    t.UPDATE_TIME = SYSTIMESTAMP;

COMMIT;

-- ------------------------------------------------------------------
-- 3. 校验
-- ------------------------------------------------------------------
SELECT t.ID, t.PAGE_CODE, t.COMPONENT_KEY, t.RULE_TYPE, t.RULES
FROM T_COST_PAGE_RULE t
WHERE t.ID IN (498, 499, 517, 521)
ORDER BY t.ID;

SELECT COUNT(*) AS remaining_old_editable_rules
FROM T_COST_PAGE_RULE
WHERE RULE_TYPE IN ('ROW_EDITABLE', 'CELL_EDITABLE')
  AND NVL(DELETED, 0) = 0;

SELECT COUNT(*) AS migrated_editable_rules
FROM T_COST_PAGE_RULE
WHERE RULE_TYPE = 'EDITABLE'
  AND ID IN (498, 499, 517, 521)
  AND NVL(DELETED, 0) = 0;
