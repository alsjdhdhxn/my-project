-- =====================================================
-- 三层嵌套测试页面配置
-- 页面代码: nested-test
-- 复用 CostPinggu / CostPingguDtl 表结构
-- =====================================================

-- 0. 清理旧数据
DELETE FROM T_COST_PAGE_COMPONENT WHERE PAGE_CODE = 'nested-test';
DELETE FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'nested-test';
COMMIT;

-- 1. 页面组件配置（首次执行用 INSERT）
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'nested-test', 'root', 'LAYOUT', NULL, 0, '{"direction":"vertical","gap":8}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'nested-test', 'masterGrid', 'GRID', 'root', 1, 'CostPinggu', '{"height":"100%","selectionMode":"single"}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'nested-test', 'detailTabs', 'TABS', 'root', 2, 'CostPingguDtl',
'{"mode":"group","groupField":"dtlUseflag","tabs":[{"key":"material","title":"原辅料","values":["原料","辅料"],"columns":["apexGoodsname","spec","perHl","price","batchQty","costBatch"]},{"key":"package","title":"包材","values":["包材","非印字包材","印字包材"],"columns":["apexGoodsname","spec","price","batchQty","costBatch"]}],"broadcast":["apexPl","yield"],"calcRules":[{"field":"batchQty","expression":"apexPl * perHl / 100 / yield * 100","triggerFields":["perHl"],"condition":"dtlUseflag !== ''包材'' && dtlUseflag !== ''非印字包材''"},{"field":"costBatch","expression":"batchQty * price","triggerFields":["batchQty","price"]}],"aggregates":[{"sourceField":"costBatch","targetField":"totalYl","algorithm":"SUM","filter":"dtlUseflag === ''原料''"},{"sourceField":"costBatch","targetField":"totalFl","algorithm":"SUM","filter":"dtlUseflag === ''辅料''"},{"sourceField":"costBatch","targetField":"totalBc","algorithm":"SUM","filter":"dtlUseflag === ''包材'' || dtlUseflag === ''非印字包材''"},{"targetField":"totalCost","expression":"totalYl + totalFl + totalBc"}],"masterCalcRules":[{"field":"salemoney","expression":"outPriceRmb / pPerpack * apexPl * (yield / 100)","triggerFields":["outPriceRmb","pPerpack","apexPl","yield","totalCost"]},{"field":"jgfBatch","expression":"salemoney - totalCost","triggerFields":["salemoney","totalCost"]},{"field":"jgfPerqp","expression":"jgfBatch / apexPl * 1000","triggerFields":["jgfBatch","apexPl"]},{"field":"mlPerqp","expression":"jgfPerqp - costPerqp","triggerFields":["jgfPerqp","costPerqp"]},{"field":"yJgRe","expression":"jgfPerqp / 1000 * annualQty","triggerFields":["jgfPerqp","annualQty"]},{"field":"yMl","expression":"mlPerqp / 1000 * annualQty","triggerFields":["mlPerqp","annualQty"]},{"field":"ySale","expression":"salemoney / apexPl * annualQty","triggerFields":["salemoney","apexPl","annualQty"]}],"nestedConfig":{"enabled":true,"groupLabelField":"groupLabel","summaryColumns":[{"field":"totalAmount","headerName":"合计金额","width":120},{"field":"rowCount","headerName":"行数","width":80}],"summaryAggregates":[{"sourceField":"costBatch","targetField":"totalAmount","algorithm":"SUM"},{"sourceField":"id","targetField":"rowCount","algorithm":"COUNT"}]}}', 'system');

-- 2. 菜单配置
DECLARE
    v_parent_id NUMBER;
BEGIN
    SELECT ID INTO v_parent_id FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'cost';
    INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
    VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'nested-test', '三层嵌套测试', 'PAGE', 'nested-test', 'mdi:layers-triple', '/cost/nested-test', v_parent_id, 99, 'system');
END;
/

COMMIT;

-- =====================================================
-- 已有数据时用 UPDATE 更新配置
-- =====================================================
UPDATE T_COST_PAGE_COMPONENT 
SET COMPONENT_CONFIG = '{"mode":"group","groupField":"dtlUseflag","tabs":[{"key":"material","title":"原辅料","values":["原料","辅料"],"columns":["apexGoodsname","spec","perHl","price","batchQty","costBatch"]},{"key":"package","title":"包材","values":["包材","非印字包材","印字包材"],"columns":["apexGoodsname","spec","price","batchQty","costBatch"]}],"broadcast":["apexPl","yield"],"calcRules":[{"field":"batchQty","expression":"apexPl * perHl / 100 / yield * 100","triggerFields":["perHl"],"condition":"dtlUseflag !== ''包材'' && dtlUseflag !== ''非印字包材''"},{"field":"costBatch","expression":"batchQty * price","triggerFields":["batchQty","price"]}],"aggregates":[{"sourceField":"costBatch","targetField":"totalYl","algorithm":"SUM","filter":"dtlUseflag === ''原料''"},{"sourceField":"costBatch","targetField":"totalFl","algorithm":"SUM","filter":"dtlUseflag === ''辅料''"},{"sourceField":"costBatch","targetField":"totalBc","algorithm":"SUM","filter":"dtlUseflag === ''包材'' || dtlUseflag === ''非印字包材''"},{"targetField":"totalCost","expression":"totalYl + totalFl + totalBc"}],"masterCalcRules":[{"field":"salemoney","expression":"outPriceRmb / pPerpack * apexPl * (yield / 100)","triggerFields":["outPriceRmb","pPerpack","apexPl","yield","totalCost"]},{"field":"jgfBatch","expression":"salemoney - totalCost","triggerFields":["salemoney","totalCost"]},{"field":"jgfPerqp","expression":"jgfBatch / apexPl * 1000","triggerFields":["jgfBatch","apexPl"]},{"field":"mlPerqp","expression":"jgfPerqp - costPerqp","triggerFields":["jgfPerqp","costPerqp"]},{"field":"yJgRe","expression":"jgfPerqp / 1000 * annualQty","triggerFields":["jgfPerqp","annualQty"]},{"field":"yMl","expression":"mlPerqp / 1000 * annualQty","triggerFields":["mlPerqp","annualQty"]},{"field":"ySale","expression":"salemoney / apexPl * annualQty","triggerFields":["salemoney","apexPl","annualQty"]}],"nestedConfig":{"enabled":true,"groupLabelField":"groupLabel","summaryColumns":[{"field":"totalAmount","headerName":"合计金额","width":120},{"field":"rowCount","headerName":"行数","width":80}],"summaryAggregates":[{"sourceField":"costBatch","targetField":"totalAmount","algorithm":"SUM"},{"sourceField":"id","targetField":"rowCount","algorithm":"COUNT"}]}}'
WHERE PAGE_CODE = 'nested-test' AND COMPONENT_KEY = 'detailTabs';

COMMIT;
