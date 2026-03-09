-- ============================================================
-- TABS 拆分为 DETAIL_GRID 增量更新
-- 将原来一行 TABS 组件拆分为多行 DETAIL_GRID 组件
-- 每个从表 tab 独立一行，componentConfig 只存自己的 buttons/title
-- ============================================================

-- 0. 备份即将修改的数据（防止出问题可回滚）
CREATE TABLE T_COST_PAGE_COMPONENT_BAK_TABS AS
SELECT * FROM t_cost_page_component WHERE component_type = 'TABS' AND deleted = 0;

CREATE TABLE T_COST_PAGE_RULE_BAK_TABS AS
SELECT * FROM t_cost_page_rule WHERE component_key = 'detailTabs' AND deleted = 0;

-- 1. 删除旧的 TABS 组件
DELETE FROM t_cost_page_component WHERE component_type = 'TABS' AND deleted = 0;

-- 2. 插入拆分后的 DETAIL_GRID 组件

-- ============ wms-shipping (原 ID=175) ============
-- wmsQty: 库存汇总
INSERT INTO t_cost_page_component (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SLOT_NAME, SORT_ORDER, DELETED, CREATE_BY, UPDATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'wms-shipping', 'wmsQty', 'DETAIL_GRID', 'root',
'{"title":"库存汇总","buttons":[{"action":"batchSelect","label":"从库存添加","batchSelectConfig":{"lookupCode":"wmsQtyLookup","title":"选择库存","mapping":{"GOODSID":"GOODSID","GOODSGP":"GOODSGP","LOTNO":"LOTNO","GOODSNO":"GOODSNO","PACKSIZE":"PACKSIZE","QTY_SHOW":"QTY_SHOW","PCS":"PCS"}}},{"action":"deleteRow","label":"删除","requiresRow":true},{"type":"separator"},{"action":"save","label":"保存"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}',
'WmsQty', NULL, 2, 0, 'system', 'system');

-- wmsQtyDetail: 库存明细
INSERT INTO t_cost_page_component (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SLOT_NAME, SORT_ORDER, DELETED, CREATE_BY, UPDATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'wms-shipping', 'wmsQtyDetail', 'DETAIL_GRID', 'root',
'{"title":"库存明细","buttons":[{"action":"addRow","label":"新增"},{"action":"deleteRow","label":"删除","requiresRow":true},{"type":"separator"},{"action":"save","label":"保存"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}',
'WmsQtyDetail', NULL, 3, 0, 'system', 'system');

-- ============ customer-manage (原 ID=85) ============
-- tranposer: 分销商
INSERT INTO t_cost_page_component (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SLOT_NAME, SORT_ORDER, DELETED, CREATE_BY, UPDATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'customer-manage', 'tranposer', 'DETAIL_GRID', 'root',
'{"title":"分销商","buttons":[{"action":"addRow","label":"新增"},{"action":"copyRow","label":"复制","requiresRow":true},{"action":"deleteRow","label":"删除","requiresRow":true},{"action":"saveGridConfig","label":"保存列配置"},{"label":"导出","items":[{"action":"exportSelected","label":"导出选中","requiresSelection":true},{"action":"exportCurrent","label":"导出当前页"},{"action":"exportAll","label":"导出全部"},{"action":"resetExportConfig","label":"重置导出配置"},{"action":"openHeaderConfig","label":"配置导出表头"}]},{"action":"save","label":"保存"},{"action":"clipboard.copy","label":"复制"},{"action":"clipboard.paste","label":"粘贴"}]}',
'CostTranposer', NULL, 2, 0, 'system', 'system');

-- ============ cost-pinggu (原 ID=115) ============
-- material: 原料/辅料
INSERT INTO t_cost_page_component (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SLOT_NAME, SORT_ORDER, DELETED, CREATE_BY, UPDATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'cost-pinggu', 'material', 'DETAIL_GRID', 'root',
'{"title":"原料/辅料","buttons":[{"action":"addRow","label":"明细新增","position":"both","toolbarAlias":"新增原料"},{"action":"copyRow","label":"明细复制","requiresRow":true,"position":"context"},{"action":"deleteRow","label":"明细删除","requiresRow":true,"position":"both","toolbarAlias":"删除原料"},{"action":"saveGridConfig","label":"保存列配置","position":"context"},{"action":"clipboard.copy","label":"复制","position":"context"},{"action":"clipboard.paste","label":"粘贴","position":"context"}]}',
'CostMaterial', NULL, 2, 0, 'system', 'system');

-- package: 包材
INSERT INTO t_cost_page_component (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SLOT_NAME, SORT_ORDER, DELETED, CREATE_BY, UPDATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'cost-pinggu', 'package', 'DETAIL_GRID', 'root',
'{"title":"包材","buttons":[{"action":"addRow","label":"明细新增","position":"both","toolbarAlias":"新增包材"},{"action":"copyRow","label":"明细复制","requiresRow":true,"position":"context"},{"action":"deleteRow","label":"明细删除","requiresRow":true,"position":"both","toolbarAlias":"删除包材"},{"action":"saveGridConfig","label":"保存列配置","position":"context"},{"action":"clipboard.copy","label":"复制","position":"context"},{"action":"clipboard.paste","label":"粘贴","position":"context"}]}',
'CostPackage', NULL, 3, 0, 'system', 'system');

-- ============ cost-pinggu-lq (原 ID=178) ============
-- material: 原料/辅料
INSERT INTO t_cost_page_component (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SLOT_NAME, SORT_ORDER, DELETED, CREATE_BY, UPDATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'cost-pinggu-lq', 'material', 'DETAIL_GRID', 'root',
'{"title":"原料/辅料","buttons":[{"action":"addRow","label":"新增"},{"action":"copyRow","label":"复制","requiresRow":true},{"action":"deleteRow","label":"删除","requiresRow":true},{"action":"saveGridConfig","label":"保存列配置"},{"action":"clipboard.copy","label":"复制"},{"action":"clipboard.paste","label":"粘贴"}]}',
'CostMaterialLq', NULL, 2, 0, 'system', 'system');

-- package: 包材
INSERT INTO t_cost_page_component (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SLOT_NAME, SORT_ORDER, DELETED, CREATE_BY, UPDATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'cost-pinggu-lq', 'package', 'DETAIL_GRID', 'root',
'{"title":"包材","buttons":[{"action":"addRow","label":"新增"},{"action":"copyRow","label":"复制","requiresRow":true},{"action":"deleteRow","label":"删除","requiresRow":true},{"action":"saveGridConfig","label":"保存列配置"},{"action":"clipboard.copy","label":"复制"},{"action":"clipboard.paste","label":"粘贴"}]}',
'CostPackageLq', NULL, 3, 0, 'system', 'system');

COMMIT;

-- ============================================================
-- 3. 迁移 detailTabs 上的全局规则到 masterGrid
-- BROADCAST, SUMMARY_CONFIG 等全局配置移到主表
-- ============================================================

-- 将 detailTabs 的 BROADCAST 规则改为 masterGrid
UPDATE t_cost_page_rule
SET component_key = 'masterGrid'
WHERE component_key = 'detailTabs'
  AND rule_type = 'BROADCAST'
  AND deleted = 0;

-- 将 detailTabs 的 SUMMARY_CONFIG 规则改为 masterGrid
UPDATE t_cost_page_rule
SET component_key = 'masterGrid'
WHERE component_key = 'detailTabs'
  AND rule_type IN ('SUMMARY_CONFIG', 'NESTED_CONFIG')
  AND deleted = 0;

-- 删除 detailTabs 上不再需要的规则（ROLE_BINDING, RELATION）
UPDATE t_cost_page_rule
SET deleted = 1
WHERE component_key = 'detailTabs'
  AND rule_type IN ('ROLE_BINDING', 'RELATION')
  AND deleted = 0;

COMMIT;
