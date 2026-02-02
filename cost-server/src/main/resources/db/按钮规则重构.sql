-- =====================================================
-- 按钮规则重构：合并 TOOLBAR 和 CONTEXT_MENU 为 BUTTON
-- =====================================================
-- 改造说明：
-- 1. 将 RULE_TYPE='TOOLBAR' 和 RULE_TYPE='CONTEXT_MENU' 合并为 RULE_TYPE='BUTTON'
-- 2. 在 JSON 的每个按钮项中添加 position 字段：
--    - position: 'toolbar' - 显示在页面工具栏
--    - position: 'context' - 显示在右键菜单（默认，可省略）
--    - position: 'both' - 两处都显示
-- =====================================================

-- 1. formoney-manage grid: 合并 CONTEXT_MENU(ID=142) 和 TOOLBAR(ID=330)
UPDATE T_COST_PAGE_RULE SET RULE_TYPE = 'BUTTON', RULES = '{"items":[{"action":"addRow"},{"action":"copyRow","requiresRow":true},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"saveGridConfig"},{"type":"separator"},{"label":"导出","items":[{"action":"exportSelected","requiresSelection":true},{"action":"exportCurrent"},{"action":"exportAll"},{"type":"separator"},{"action":"resetExportConfig"},{"action":"openHeaderConfig"}]},{"type":"separator"},{"action":"save"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"},{"action":"SYNC_ERP_RATE","label":"同步ERP汇率","position":"toolbar","type":"primary","sql":"UPDATE T_COST_FORMONEY SET FMRATE = NULL, CREATE_TIME = NULL, UPDATE_TIME = NULL WHERE CREATE_BY = ''system''"}]}'
WHERE ID = 142;
DELETE FROM T_COST_PAGE_RULE WHERE ID = 330;

-- 2. goods-manage grid (ID=515)
UPDATE T_COST_PAGE_RULE SET RULE_TYPE = 'BUTTON', RULES = '{"items":[{"action":"addRow"},{"action":"copyRow","requiresRow":true},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"saveGridConfig"},{"type":"separator"},{"label":"导出","items":[{"action":"exportSelected","requiresSelection":true},{"action":"exportCurrent"},{"action":"exportAll"},{"type":"separator"},{"action":"resetExportConfig"},{"action":"openHeaderConfig"}]},{"type":"separator"},{"action":"save"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}'
WHERE ID = 515;

-- 3. goods-price-manage grid (ID=522)
UPDATE T_COST_PAGE_RULE SET RULE_TYPE = 'BUTTON', RULES = '{"items":[{"action":"addRow"},{"action":"copyRow","requiresRow":true},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"saveGridConfig"},{"type":"separator"},{"label":"导出","items":[{"action":"exportSelected","requiresSelection":true},{"action":"exportCurrent"},{"action":"exportAll"},{"type":"separator"},{"action":"resetExportConfig"},{"action":"openHeaderConfig"}]},{"type":"separator"},{"action":"save"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}'
WHERE ID = 522;

-- 4. customer-manage masterGrid (ID=278)
UPDATE T_COST_PAGE_RULE SET RULE_TYPE = 'BUTTON', RULES = '{"items":[{"action":"addRow"},{"action":"copyRow","requiresRow":true},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"saveGridConfig"},{"type":"separator"},{"label":"导出","items":[{"action":"exportSelected","requiresSelection":true},{"action":"exportCurrent"},{"action":"exportAll"},{"type":"separator"},{"action":"resetExportConfig"},{"action":"openHeaderConfig"}]},{"type":"separator"},{"action":"save"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}'
WHERE ID = 278;

-- 5. customer-manage tranposer (ID=279)
UPDATE T_COST_PAGE_RULE SET RULE_TYPE = 'BUTTON', RULES = '{"items":[{"action":"addRow"},{"action":"copyRow","requiresRow":true},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"saveGridConfig"},{"type":"separator"},{"label":"导出","items":[{"action":"exportSelected","requiresSelection":true},{"action":"exportCurrent"},{"action":"exportAll"},{"type":"separator"},{"action":"resetExportConfig"},{"action":"openHeaderConfig"}]},{"type":"separator"},{"action":"save"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}'
WHERE ID = 279;

-- 6. user-manage masterGrid (ID=13)
UPDATE T_COST_PAGE_RULE SET RULE_TYPE = 'BUTTON', RULES = '{"items":[{"action":"addRow"},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"save"}]}'
WHERE ID = 13;

-- 7. dept-manage masterGrid (ID=15)
UPDATE T_COST_PAGE_RULE SET RULE_TYPE = 'BUTTON', RULES = '{"items":[{"action":"addRow"},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"save"}]}'
WHERE ID = 15;

-- 8. cost-pinggu masterGrid (ID=497)
UPDATE T_COST_PAGE_RULE SET RULE_TYPE = 'BUTTON', RULES = '{"items":[{"action":"addRow"},{"action":"copyRow","requiresRow":true},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"generateFromBom","label":"由BOM生成明细","requiresRow":true,"procedure":"P_COST_BOM_INSERT","params":[{"source":"data.id","mode":"IN","jdbcType":"NUMERIC"}]},{"type":"separator"},{"action":"saveGridConfig"},{"type":"separator"},{"action":"save"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}'
WHERE ID = 497;

-- 9. cost-pinggu material (ID=493)
UPDATE T_COST_PAGE_RULE SET RULE_TYPE = 'BUTTON', RULES = '{"items":[{"action":"addRow"},{"action":"copyRow","requiresRow":true},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"saveGridConfig"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}'
WHERE ID = 493;

-- 10. cost-pinggu package (ID=494)
UPDATE T_COST_PAGE_RULE SET RULE_TYPE = 'BUTTON', RULES = '{"items":[{"action":"addRow"},{"action":"copyRow","requiresRow":true},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"saveGridConfig"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}'
WHERE ID = 494;

-- 11. cost-pinggu detailTabs (ID=495)
UPDATE T_COST_PAGE_RULE SET RULE_TYPE = 'BUTTON', RULES = '{"items":[{"action":"addRow"},{"action":"copyRow","requiresRow":true},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"saveGridConfig"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}'
WHERE ID = 495;

COMMIT;

-- 验证：查看更新后的数据
SELECT ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE FROM T_COST_PAGE_RULE WHERE RULE_TYPE IN ('BUTTON', 'TOOLBAR', 'CONTEXT_MENU') AND DELETED = 0 ORDER BY PAGE_CODE, COMPONENT_KEY;
