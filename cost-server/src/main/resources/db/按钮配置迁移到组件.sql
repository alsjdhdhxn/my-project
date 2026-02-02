-- =====================================================
-- 按钮配置迁移：从 T_COST_PAGE_RULE 迁移到 T_COST_PAGE_COMPONENT.COMPONENT_CONFIG
-- =====================================================
-- 改造说明：
-- 1. 将按钮配置从 T_COST_PAGE_RULE (rule_type='BUTTON') 迁移到组件的 COMPONENT_CONFIG JSON 中
-- 2. 按钮配置放在 "buttons" 数组中
-- 3. 对于 TABS 组件，按钮配置放在每个 tab 的 "buttons" 数组中
-- 4. 每个按钮都有 label 字段显示中文名称
-- =====================================================

-- 1. user-manage masterGrid (ID=5)
UPDATE T_COST_PAGE_COMPONENT SET COMPONENT_CONFIG = '{"buttons":[{"action":"addRow","label":"新增"},{"action":"deleteRow","label":"删除","requiresRow":true},{"action":"resetPassword","label":"初始化密码","position":"toolbar","requiresRow":true,"method":"userService.resetPassword"},{"action":"save","label":"保存"}]}'
WHERE ID = 5;

-- 2. dept-manage masterGrid (ID=6)
UPDATE T_COST_PAGE_COMPONENT SET COMPONENT_CONFIG = '{"buttons":[{"action":"addRow","label":"新增"},{"action":"deleteRow","label":"删除","requiresRow":true},{"action":"save","label":"保存"}]}'
WHERE ID = 6;

-- 3. formoney-manage grid (ID=62)
UPDATE T_COST_PAGE_COMPONENT SET COMPONENT_CONFIG = '{"height":"100%","selectionMode":"single","buttons":[{"action":"addRow","label":"新增"},{"action":"copyRow","label":"复制","requiresRow":true},{"action":"deleteRow","label":"删除","requiresRow":true},{"action":"saveGridConfig","label":"保存列配置"},{"label":"导出","items":[{"action":"exportSelected","label":"导出选中","requiresSelection":true},{"action":"exportCurrent","label":"导出当前页"},{"action":"exportAll","label":"导出全部"},{"action":"resetExportConfig","label":"重置导出配置"},{"action":"openHeaderConfig","label":"配置导出表头"}]},{"action":"save","label":"保存"},{"action":"clipboard.copy","label":"复制"},{"action":"clipboard.paste","label":"粘贴"},{"action":"SYNC_ERP_RATE","label":"同步ERP汇率","position":"toolbar","type":"primary","sql":"UPDATE T_COST_FORMONEY SET FMRATE = NULL, CREATE_TIME = NULL, UPDATE_TIME = NULL WHERE CREATE_BY = ''system''"}]}'
WHERE ID = 62;

-- 4. customer-manage masterGrid (ID=84)
UPDATE T_COST_PAGE_COMPONENT SET COMPONENT_CONFIG = '{"height":"50%","selectionMode":"single","buttons":[{"action":"addRow","label":"新增"},{"action":"copyRow","label":"复制","requiresRow":true},{"action":"deleteRow","label":"删除","requiresRow":true},{"action":"saveGridConfig","label":"保存列配置"},{"label":"导出","items":[{"action":"exportSelected","label":"导出选中","requiresSelection":true},{"action":"exportCurrent","label":"导出当前页"},{"action":"exportAll","label":"导出全部"},{"action":"resetExportConfig","label":"重置导出配置"},{"action":"openHeaderConfig","label":"配置导出表头"}]},{"action":"save","label":"保存"},{"action":"clipboard.copy","label":"复制"},{"action":"clipboard.paste","label":"粘贴"}]}'
WHERE ID = 84;

-- 5. customer-manage detailTabs (ID=85)
UPDATE T_COST_PAGE_COMPONENT SET COMPONENT_CONFIG = '{"mode":"single","tabs":[{"key":"tranposer","title":"分销商","tableCode":"CostTranposer","buttons":[{"action":"addRow","label":"新增"},{"action":"copyRow","label":"复制","requiresRow":true},{"action":"deleteRow","label":"删除","requiresRow":true},{"action":"saveGridConfig","label":"保存列配置"},{"label":"导出","items":[{"action":"exportSelected","label":"导出选中","requiresSelection":true},{"action":"exportCurrent","label":"导出当前页"},{"action":"exportAll","label":"导出全部"},{"action":"resetExportConfig","label":"重置导出配置"},{"action":"openHeaderConfig","label":"配置导出表头"}]},{"action":"save","label":"保存"},{"action":"clipboard.copy","label":"复制"},{"action":"clipboard.paste","label":"粘贴"}]}]}'
WHERE ID = 85;

-- 6. cost-pinggu masterGrid (ID=114)
UPDATE T_COST_PAGE_COMPONENT SET COMPONENT_CONFIG = '{"height":"50%","selectionMode":"single","buttons":[{"action":"addRow","label":"新增"},{"action":"copyRow","label":"复制","requiresRow":true},{"action":"deleteRow","label":"删除","requiresRow":true},{"action":"generateFromBom","label":"由BOM生成明细","requiresRow":true,"procedure":"P_COST_BOM_INSERT","params":[{"source":"data.id","mode":"IN","jdbcType":"NUMERIC"}]},{"action":"saveGridConfig","label":"保存列配置"},{"action":"save","label":"保存"},{"action":"clipboard.copy","label":"复制"},{"action":"clipboard.paste","label":"粘贴"}]}'
WHERE ID = 114;

-- 7. cost-pinggu detailTabs (ID=115)
UPDATE T_COST_PAGE_COMPONENT SET COMPONENT_CONFIG = '{"mode":"multi","tabs":[{"key":"material","title":"原料/辅料","tableCode":"CostMaterial","buttons":[{"action":"addRow","label":"新增"},{"action":"copyRow","label":"复制","requiresRow":true},{"action":"deleteRow","label":"删除","requiresRow":true},{"action":"saveGridConfig","label":"保存列配置"},{"action":"clipboard.copy","label":"复制"},{"action":"clipboard.paste","label":"粘贴"}]},{"key":"package","title":"包材","tableCode":"CostPackage","buttons":[{"action":"addRow","label":"新增"},{"action":"copyRow","label":"复制","requiresRow":true},{"action":"deleteRow","label":"删除","requiresRow":true},{"action":"saveGridConfig","label":"保存列配置"},{"action":"clipboard.copy","label":"复制"},{"action":"clipboard.paste","label":"粘贴"}]}]}'
WHERE ID = 115;

-- 8. goods-manage grid (ID=124)
UPDATE T_COST_PAGE_COMPONENT SET COMPONENT_CONFIG = '{"height":"100%","buttons":[{"action":"addRow","label":"新增"},{"action":"copyRow","label":"复制","requiresRow":true},{"action":"deleteRow","label":"删除","requiresRow":true},{"action":"saveGridConfig","label":"保存列配置"},{"label":"导出","items":[{"action":"exportSelected","label":"导出选中","requiresSelection":true},{"action":"exportCurrent","label":"导出当前页"},{"action":"exportAll","label":"导出全部"},{"action":"resetExportConfig","label":"重置导出配置"},{"action":"openHeaderConfig","label":"配置导出表头"}]},{"action":"save","label":"保存"},{"action":"clipboard.copy","label":"复制"},{"action":"clipboard.paste","label":"粘贴"}]}'
WHERE ID = 124;

-- 9. goods-price-manage grid (ID=126)
UPDATE T_COST_PAGE_COMPONENT SET COMPONENT_CONFIG = '{"height":"100%","buttons":[{"action":"addRow","label":"新增"},{"action":"copyRow","label":"复制","requiresRow":true},{"action":"deleteRow","label":"删除","requiresRow":true},{"action":"saveGridConfig","label":"保存列配置"},{"label":"导出","items":[{"action":"exportSelected","label":"导出选中","requiresSelection":true},{"action":"exportCurrent","label":"导出当前页"},{"action":"exportAll","label":"导出全部"},{"action":"resetExportConfig","label":"重置导出配置"},{"action":"openHeaderConfig","label":"配置导出表头"}]},{"action":"save","label":"保存"},{"action":"clipboard.copy","label":"复制"},{"action":"clipboard.paste","label":"粘贴"}]}'
WHERE ID = 126;

-- =====================================================
-- 删除 T_COST_PAGE_RULE 中的 BUTTON 类型记录
-- =====================================================
DELETE FROM T_COST_PAGE_RULE WHERE RULE_TYPE = 'BUTTON';

COMMIT;

-- 验证：查看更新后的组件配置
SELECT ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, COMPONENT_CONFIG 
FROM T_COST_PAGE_COMPONENT 
WHERE DELETED = 0 
ORDER BY PAGE_CODE, SORT_ORDER;
