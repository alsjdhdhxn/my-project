-- Rollback for CALC tableCode.field migration
-- Date: 2026-03-04

-- Safety check
SELECT COUNT(*) AS backup_rows
FROM T_COST_PAGE_RULE_CALC_BAK_20260304;

-- Restore CALC rows by ID (only revert fields changed in this migration)
MERGE INTO T_COST_PAGE_RULE t
USING (
  SELECT b.ID, b.RULES, b.UPDATE_TIME
  FROM T_COST_PAGE_RULE_CALC_BAK_20260304 b
) s
ON (t.ID = s.ID)
WHEN MATCHED THEN
  UPDATE SET
    t.RULES = s.RULES,
    t.UPDATE_TIME = s.UPDATE_TIME;

COMMIT;

-- Verify
SELECT COUNT(*) AS restored_rows
FROM T_COST_PAGE_RULE t
WHERE t.RULE_TYPE = 'CALC'
  AND NVL(t.DELETED, 0) = 0
  AND EXISTS (
    SELECT 1 FROM T_COST_PAGE_RULE_CALC_BAK_20260304 b WHERE b.ID = t.ID
  );
