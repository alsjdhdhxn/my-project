-- =====================================================
-- 价格对比视图改造
-- 在原有视图基础上 LEFT JOIN 物化视图，带出历史价格用于对比
-- =====================================================

-- 1. 修改原辅料视图，增加历史价格字段
CREATE OR REPLACE VIEW V_COST_PINGGU_MATERIAL AS
SELECT d.DTLID AS ID, d.DOCID AS MASTER_ID, d.APEX_GOODSID, d.APEX_GOODSNAME, d.DTL_USEFLAG,
    d.SPEC, d.PER_HL, d.PRICE, d.BATCH_QTY, d.COST_BATCH, d.APEX_FACTORYNAME, d.ZX_SOURCE,
    d.BASE_PRICE, d.GOODSTYPE, d.EXADD_MATER, d.MEMO, d.DELETED, d.CREATE_TIME, d.UPDATE_TIME,
    d.CREATE_BY, d.UPDATE_BY,
    CASE WHEN d.DTL_USEFLAG = '辅料' AND REGEXP_LIKE(d.APEX_GOODSNAME, '胶囊') THEN 'B'
         WHEN d.DTL_USEFLAG IN ('原料', '辅料') THEN 'C' ELSE NULL END AS FORMULA_TYPE,
    -- 历史价格（用于对比）
    h.PRICE AS HIS_PRICE
FROM T_COST_PINGGU_DTL d
LEFT JOIN MV_COST_PINGGU_DTL_HIS_LATEST h ON d.DTLID = h.DTLID
WHERE d.DTL_USEFLAG IN ('原料', '辅料') AND d.DELETED = 0;

-- 2. 修改包材视图，增加历史价格字段
CREATE OR REPLACE VIEW V_COST_PINGGU_PACKAGE AS
SELECT d.DTLID AS ID, d.DOCID AS MASTER_ID, d.APEX_GOODSID, d.APEX_GOODSNAME, d.DTL_USEFLAG,
    d.SPEC, d.PER_HL, d.EXADD_MATER, d.PRICE, d.BATCH_QTY, d.COST_BATCH, d.SUQTY,
    d.APEX_FACTORYNAME, d.ZX_SOURCE, d.MEMO, d.DELETED, d.CREATE_TIME, d.UPDATE_TIME,
    d.CREATE_BY, d.UPDATE_BY,
    CASE WHEN REGEXP_LIKE(d.APEX_GOODSNAME, '桶|说明书|小盒|标签|瓶|盖') THEN 'A'
         WHEN REGEXP_LIKE(d.APEX_GOODSNAME, '硬片|铝箔|复合膜') THEN 'D'
         WHEN REGEXP_LIKE(d.APEX_GOODSNAME, '大纸箱') THEN 'E'
         WHEN REGEXP_LIKE(d.APEX_GOODSNAME, '托盘') THEN 'F' ELSE NULL END AS FORMULA_TYPE,
    -- 历史价格（用于对比）
    h.PRICE AS HIS_PRICE
FROM T_COST_PINGGU_DTL d
LEFT JOIN MV_COST_PINGGU_DTL_HIS_LATEST h ON d.DTLID = h.DTLID
WHERE d.DTL_USEFLAG IN ('非印字包材', '印字包材') AND d.DELETED = 0;

-- 3. 在 t_cost_page_rule 中配置 COLUMN_OVERRIDE，启用价格对比
-- 原辅料 Grid
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'cost-pinggu', 'materialGrid', 'COLUMN_OVERRIDE', 
'[{"field":"price","rulesConfig":{"compare":{"enabled":true,"mode":"viewField","compareField":"hisPrice","format":"percent","upColor":"#e53935","downColor":"#43a047"}}}]',
0, 'system');

-- 包材 Grid
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'cost-pinggu', 'packageGrid', 'COLUMN_OVERRIDE',
'[{"field":"price","rulesConfig":{"compare":{"enabled":true,"mode":"viewField","compareField":"hisPrice","format":"percent","upColor":"#e53935","downColor":"#43a047"}}}]',
0, 'system');

COMMIT;
