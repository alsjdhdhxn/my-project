-- ============================================================
-- 移除 BROADCAST 规则（前端已自动推断广播字段）
-- 执行时间: 2026-02-11
-- 说明: 前端 compileRules() 现在会自动从 detail CALC 规则中
--       推断哪些字段是主表字段，不再需要手动维护 BROADCAST 规则
-- ============================================================

-- 1. 备份 BROADCAST 规则（软删除前先备份）
CREATE TABLE T_COST_PAGE_RULE_BROADCAST_BAK AS
SELECT * FROM T_COST_PAGE_RULE
WHERE RULE_TYPE = 'BROADCAST' AND (DELETED = 0 OR DELETED IS NULL);

-- 2. 软删除 BROADCAST 规则
UPDATE T_COST_PAGE_RULE
SET DELETED = 1, UPDATE_TIME = SYSTIMESTAMP
WHERE RULE_TYPE = 'BROADCAST' AND (DELETED = 0 OR DELETED IS NULL);

COMMIT;

-- 回滚脚本（如需恢复）:
-- UPDATE T_COST_PAGE_RULE t
-- SET t.DELETED = 0, t.UPDATE_TIME = SYSTIMESTAMP
-- WHERE t.ID IN (SELECT ID FROM T_COST_PAGE_RULE_BROADCAST_BAK);
-- COMMIT;
