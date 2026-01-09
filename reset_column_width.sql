-- =====================================================
-- 将所有列的宽度设置为 NULL，让 AG Grid 自动调整列宽
-- =====================================================

UPDATE T_COST_COLUMN_METADATA
SET WIDTH = NULL
WHERE WIDTH IS NOT NULL;

COMMIT;

-- 查看更新结果
SELECT COUNT(*) AS updated_count
FROM T_COST_COLUMN_METADATA
WHERE WIDTH IS NULL;
