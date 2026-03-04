-- CALC rule migration to tableCode.field mode
-- Date: 2026-03-04
--
-- Workflow:
-- 1) Run this script to create backup/staging tables.
-- 2) Fill T_COST_PAGE_RULE_CALC_PATCH_20260304 with transformed RULES JSON.
-- 3) Run merge update section.
-- 4) Validate with verification queries.

-- ------------------------------------------------------------------
-- 0. Backup table (idempotent)
-- ------------------------------------------------------------------
DECLARE
  v_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*) INTO v_exists
  FROM USER_TABLES
  WHERE TABLE_NAME = 'T_COST_PAGE_RULE_CALC_BAK_20260304';

  IF v_exists = 0 THEN
    EXECUTE IMMEDIATE '
      CREATE TABLE T_COST_PAGE_RULE_CALC_BAK_20260304 AS
      SELECT * FROM T_COST_PAGE_RULE WHERE 1 = 2
    ';
  END IF;
END;
/

INSERT INTO T_COST_PAGE_RULE_CALC_BAK_20260304
SELECT t.*
FROM T_COST_PAGE_RULE t
WHERE t.RULE_TYPE = 'CALC'
  AND NVL(t.DELETED, 0) = 0
  AND NOT EXISTS (
    SELECT 1 FROM T_COST_PAGE_RULE_CALC_BAK_20260304 b WHERE b.ID = t.ID
  );

COMMIT;

-- ------------------------------------------------------------------
-- 1. Staging patch table (idempotent)
-- ------------------------------------------------------------------
DECLARE
  v_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*) INTO v_exists
  FROM USER_TABLES
  WHERE TABLE_NAME = 'T_COST_PAGE_RULE_CALC_PATCH_20260304';

  IF v_exists = 0 THEN
    EXECUTE IMMEDIATE '
      CREATE TABLE T_COST_PAGE_RULE_CALC_PATCH_20260304 (
        ID NUMBER PRIMARY KEY,
        PAGE_CODE VARCHAR2(100),
        COMPONENT_KEY VARCHAR2(100),
        RULES_NEW CLOB,
        COMMENT_TEXT VARCHAR2(200)
      )
    ';
  END IF;
END;
/

-- ------------------------------------------------------------------
-- 2. Fill patch rows
-- ------------------------------------------------------------------
-- Replace this section with generated INSERT statements after reviewing
-- exported CALC rules and table code mapping.
--
-- Example:
-- INSERT INTO T_COST_PAGE_RULE_CALC_PATCH_20260304 (ID, PAGE_CODE, COMPONENT_KEY, RULES_NEW, COMMENT_TEXT)
-- VALUES (
--   475,
--   'cost-pinggu',
--   'masterGrid',
--   q'~[
--     {"field":"salemoney","expression":"T_COST_PINGGU.outPriceRmb / T_COST_PINGGU.pPerpack * T_COST_PINGGU.apexPl * (T_COST_PINGGU.yield / 100)","triggerFields":["T_COST_PINGGU.outPriceRmb","T_COST_PINGGU.pPerpack","T_COST_PINGGU.apexPl","T_COST_PINGGU.yield"]}
--   ]~',
--   'migrated by tableCode.field script'
-- );

-- ------------------------------------------------------------------
-- 3. Apply patch
-- ------------------------------------------------------------------
MERGE INTO T_COST_PAGE_RULE t
USING (
  SELECT p.ID, p.RULES_NEW
  FROM T_COST_PAGE_RULE_CALC_PATCH_20260304 p
) s
ON (
  t.ID = s.ID
  AND t.RULE_TYPE = 'CALC'
  AND NVL(t.DELETED, 0) = 0
)
WHEN MATCHED THEN
  UPDATE SET
    t.RULES = s.RULES_NEW,
    t.UPDATE_TIME = SYSTIMESTAMP;

COMMIT;

-- ------------------------------------------------------------------
-- 4. Verification
-- ------------------------------------------------------------------
SELECT COUNT(*) AS calc_rules_total
FROM T_COST_PAGE_RULE
WHERE RULE_TYPE = 'CALC' AND NVL(DELETED, 0) = 0;

SELECT COUNT(*) AS calc_rules_patched
FROM T_COST_PAGE_RULE t
WHERE t.RULE_TYPE = 'CALC'
  AND NVL(t.DELETED, 0) = 0
  AND EXISTS (
    SELECT 1 FROM T_COST_PAGE_RULE_CALC_PATCH_20260304 p WHERE p.ID = t.ID
  );

SELECT t.ID, t.PAGE_CODE, t.COMPONENT_KEY
FROM T_COST_PAGE_RULE t
WHERE t.RULE_TYPE = 'CALC'
  AND NVL(t.DELETED, 0) = 0
  AND EXISTS (
    SELECT 1 FROM T_COST_PAGE_RULE_CALC_PATCH_20260304 p WHERE p.ID = t.ID
  )
ORDER BY t.PAGE_CODE, t.COMPONENT_KEY, t.ID;
