-- ============================================================
-- 视图定义
-- 成本管理系统所有视图
-- ============================================================

-- 客户视图
CREATE OR REPLACE VIEW T_COST_CUSTOMER_V AS
SELECT CUSTOMID, CUSTOMNAME, ZONE, ISERP, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY
FROM T_COST_CUSTOMER
WHERE DELETED = 0;

-- 分销商视图
CREATE OR REPLACE VIEW T_COST_TRANPOSER_V AS
SELECT CUSTOMID, TRANPOSID, TRANPOSNAME, ISERP, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY
FROM T_COST_TRANPOSER
WHERE DELETED = 0;

-- 外币视图(关联ERP)
CREATE OR REPLACE VIEW T_COST_FORMONEY_V AS
SELECT
    a.FMID,
    NVL(a.FMOPCODE, b.FMOPCODE) AS FMOPCODE,
    NVL(a.FMNAME, b.FMNAME) AS FMNAME,
    NVL(a.FMSIGN, b.FMSIGN) AS FMSIGN,
    NVL(a.FMUNIT, b.FMUNIT) AS FMUNIT,
    NVL(a.FMRATE, b.FMRATE) AS FMRATE,
    a.USESTATUS, a.DELETED, a.CREATE_TIME, a.UPDATE_TIME, a.CREATE_BY, a.UPDATE_BY
FROM T_COST_FORMONEY a
LEFT JOIN pub_formoney_v@hyerp b ON a.FMID = b.FMID
WHERE a.DELETED = 0 OR a.DELETED IS NULL;

-- 产品视图
CREATE OR REPLACE VIEW T_COST_GOODS_V AS
SELECT a.GOODSID, a.GOODSNO, a.GOODSNAME, a.PRICE, a.SUQTY, a.USEFLAG, a.FACTORYNAME,
       a.STANDARDTYPE, a.ZX_PL, a.ZX_MINIMUM, a.APPROVEDOCNO, a.BASEUNITQTY, a.ZX_CUSTOMERID,
       b.CUSTOMNAME, a.TARGETMARKET, a.HOLDERSNAME, a.ISERP, a.GOODSTYPE, a.PACKTYPE,
       c.TRANPOSNAME, a.BOMID, a.LASTSUQTY, a.TRANPOSID, b.ZONE,
       a.DELETED, a.CREATE_TIME, a.UPDATE_TIME, a.CREATE_BY, a.UPDATE_BY
FROM T_COST_GOODS a, T_COST_CUSTOMER b, T_COST_TRANPOSER c
WHERE a.USEFLAG = '产成品' AND a.DELETED = 0
  AND a.ZX_CUSTOMERID = b.CUSTOMID(+)
  AND a.TRANPOSID = c.TRANPOSID(+);

-- 物料价格视图
CREATE OR REPLACE VIEW T_COST_GOODS_PRICE_V AS
SELECT GOODSID, GOODSNAME, PRICE, USEFLAG, GOODSTYPE, PACKTYPE, FACTORYNAME,
       DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY, ISERP,
       CASE
           WHEN ISERP = 1 AND NVL(LOWER(UPDATE_BY), '#') <> 'system' AND PRICE IS NULL THEN 'erp-price-null'
           WHEN ISERP = 1 AND NVL(LOWER(UPDATE_BY), '#') <> 'system' THEN 'erp-updated'
           WHEN ISERP = 1 THEN 'erp'
           ELSE NULL
       END AS ROW_CLASS_FLAG
FROM T_COST_GOODS_PRICE;

-- 用户视图
CREATE OR REPLACE VIEW V_COST_USER AS
SELECT u.ID, u.USERNAME, u.PASSWORD, u.REAL_NAME, u.EMAIL, u.PHONE, u.DEPARTMENT_ID,
       d.DEPT_NAME, u.STATUS, u.DELETED, u.CREATE_BY, u.CREATE_TIME, u.UPDATE_BY, u.UPDATE_TIME
FROM T_COST_USER u
LEFT JOIN T_COST_DEPARTMENT d ON u.DEPARTMENT_ID = d.ID
WHERE u.DELETED = 0;

-- 审计日志视图
CREATE OR REPLACE VIEW V_COST_AUDIT_LOG AS
SELECT ID, USER_NAME, OPERATION_TIME, PAGE_CODE, TABLE_CODE, TABLE_NAME,
       RECORD_ID, OPERATION_TYPE, FIELD_CHANGES, CREATE_TIME, 0 AS DELETED
FROM T_COST_AUDIT_LOG;

-- 客户Lookup视图
CREATE OR REPLACE VIEW V_COST_CUSTOMER_LOOKUP AS
SELECT a.CUSTOMID, a.CUSTOMNAME, a.ZONE AS COUNTRY, b.TRANPOSNAME AS LIVERY, b.TRANPOSID, 0 AS DELETED
FROM T_COST_CUSTOMER_V a, T_COST_TRANPOSER_V b
WHERE a.CUSTOMID = b.CUSTOMID;

-- 产品Lookup视图
CREATE OR REPLACE VIEW V_COST_GOODS_LOOKUP AS
SELECT a.GOODSID, a.GOODSNAME, a.APPROVEDOCNO AS MA_NO, a.ZX_PL AS APEX_PL, a.HOLDERSNAME AS MAH,
       a.ZX_MINIMUM AS P_PERPACK, a.BASEUNITQTY AS S_PERBACK, a.ZX_CUSTOMERID AS CUSTOMID, a.CUSTOMNAME,
       CASE WHEN a.ISERP = 0 AND b.PGOODSID IS NULL THEN 'ERP未搭建BOM' ELSE 'ERP已搭建BOM' END AS MEMO,
       a.GOODSTYPE AS STRENGTH, a.TRANPOSNAME AS LIVERY, a.DELETED
FROM T_COST_GOODS_V a
LEFT JOIN mpcs_pr_bom_doc@hyerp b ON a.GOODSID = b.PGOODSID AND b.USESTATUS = 1 AND a.ISERP = 1
WHERE a.USEFLAG = '产成品' AND (a.DELETED = 0 OR a.DELETED IS NULL);

-- 按物料查产品视图
CREATE OR REPLACE VIEW V_COST_GOODS_BY_APEX AS
SELECT c.GOODSID AS P_GOODSID, c.GOODSNAME, c.GOODSTYPE, c.PACKTYPE, c.TRANPOSID, c.TRANPOSNAME,
       c.ZX_CUSTOMERID, c.CUSTOMNAME, c.ZONE, a.APEX_GOODSID AS GOODSID, 0 AS DELETED
FROM T_COST_PINGGU_DTL a, T_COST_PINGGU b, T_COST_GOODS_V c
WHERE a.DOCID = b.DOCID AND b.GOODSID = c.GOODSID;

-- 物料成本核算明细视图(关联主表)
CREATE OR REPLACE VIEW T_COST_PINGGU_DTL_V AS
SELECT a.docid, a.apex_goodsid, a.apex_goodsname, a.dtl_useflag, a.spec, a.per_hl, a.exadd_mater,
       a.batch_qty, a.price, a.cost_batch, a.memo, a.dtlid, a.apex_factoryname, a.apex_factoryid,
       a.modifydate, a.base_price, a.suqty, a.goodstype, a.goodsname_en,
       b.APEX_PL, b.P_PERPACK, b.S_PERBACK, b.X_PERBACK
FROM t_cost_pinggu_dtl a, t_cost_pinggu b
WHERE a.docid = b.docid;

-- 原辅料明细视图
CREATE OR REPLACE VIEW V_COST_PINGGU_MATERIAL AS
SELECT d.DTLID AS ID, d.DOCID AS MASTER_ID, d.APEX_GOODSID, d.APEX_GOODSNAME, d.DTL_USEFLAG,
    d.SPEC, d.PER_HL, d.PRICE, d.BATCH_QTY, d.COST_BATCH, d.APEX_FACTORYNAME,
    d.BASE_PRICE, d.GOODSTYPE, d.EXADD_MATER, d.MEMO, d.DELETED, d.CREATE_TIME, d.UPDATE_TIME,
    d.CREATE_BY, d.UPDATE_BY,
    CASE WHEN d.DTL_USEFLAG = '辅料' AND REGEXP_LIKE(d.APEX_GOODSNAME, '胶囊') THEN 'B'
         WHEN d.DTL_USEFLAG IN ('原料', '辅料') THEN 'C' ELSE NULL END AS FORMULA_TYPE
FROM T_COST_PINGGU_DTL d
WHERE d.DTL_USEFLAG IN ('原料', '辅料') AND (d.DELETED = 0 OR d.DELETED IS NULL);

-- 包材明细视图
CREATE OR REPLACE VIEW V_COST_PINGGU_PACKAGE AS
SELECT d.DTLID AS ID, d.DOCID AS MASTER_ID, d.APEX_GOODSID, d.APEX_GOODSNAME, d.DTL_USEFLAG,
    d.SPEC, d.PER_HL, d.EXADD_MATER, d.PRICE, d.BATCH_QTY, d.COST_BATCH, d.SUQTY,
    d.APEX_FACTORYNAME, d.MEMO, d.DELETED, d.CREATE_TIME, d.UPDATE_TIME, d.CREATE_BY, d.UPDATE_BY,
    CASE WHEN REGEXP_LIKE(d.APEX_GOODSNAME, '桶|说明书|小盒|标签|瓶|盖') THEN 'A'
         WHEN REGEXP_LIKE(d.APEX_GOODSNAME, '硬片|铝箔|复合膜') THEN 'D'
         WHEN REGEXP_LIKE(d.APEX_GOODSNAME, '大纸箱') THEN 'E'
         WHEN REGEXP_LIKE(d.APEX_GOODSNAME, '托盘') THEN 'F' ELSE NULL END AS FORMULA_TYPE
FROM T_COST_PINGGU_DTL d
WHERE d.DTL_USEFLAG IN ('非印字包材', '印字包材') AND (d.DELETED = 0 OR d.DELETED IS NULL);

-- 按物料查成品视图
CREATE OR REPLACE VIEW V_COST_PGOODS_BY_MGOODS AS
SELECT a.apex_goodsid goodsid, a.apex_goodsname, a.dtl_useflag, b.factoryname, a.price, b.goodsno,
       d.goodsid pgoodsid, d.goodsno pgoodsno, d.goodsname, c.apex_pl, a.batch_qty, a.deleted
FROM T_COST_PINGGU_DTL a, t_cost_goods b, t_cost_pinggu c, t_cost_goods d
WHERE a.apex_goodsid = b.goodsid AND a.docid = c.docid AND c.goodsid = d.goodsid
  AND a.deleted = 0 AND b.deleted = 0 AND c.deleted = 0 AND d.deleted = 0;

-- 角色视图
CREATE OR REPLACE VIEW V_COST_ROLE AS
SELECT r.ID, r.ROLE_CODE, r.ROLE_NAME, r.DESCRIPTION FROM T_COST_ROLE r;

-- 角色页面权限视图
CREATE OR REPLACE VIEW V_COST_ROLE_PAGE AS
SELECT rp.ID, rp.ROLE_ID, rp.PAGE_CODE, res.RESOURCE_NAME AS PAGE_NAME,
       rp.BUTTON_POLICY, rp.COLUMN_POLICY, rp.ROW_POLICY
FROM T_COST_ROLE_PAGE rp
LEFT JOIN T_COST_RESOURCE res ON rp.PAGE_CODE = res.PAGE_CODE;

-- 用户角色视图
CREATE OR REPLACE VIEW V_COST_USER_ROLE AS
SELECT ur.ID, ur.USER_ID, u.USERNAME, u.REAL_NAME, ur.ROLE_ID
FROM T_COST_USER_ROLE ur
LEFT JOIN T_COST_USER u ON ur.USER_ID = u.ID AND u.DELETED = 0;

-- 资源权限视图
CREATE OR REPLACE VIEW V_COST_RESOURCE_PERMISSION AS
SELECT res.ID, res.PAGE_CODE, res.RESOURCE_NAME, res.RESOURCE_TYPE, res.IS_HARDCODED,
       res.ICON, res.ROUTE, res.PARENT_ID, res.SORT_ORDER,
       r.ID AS ROLE_ID, r.ROLE_CODE, r.ROLE_NAME,
       rp.ID AS ROLE_PAGE_ID, rp.BUTTON_POLICY, rp.COLUMN_POLICY, rp.ROW_POLICY,
       CASE WHEN rp.ID IS NOT NULL THEN 1 ELSE 0 END AS IS_AUTHORIZED
FROM T_COST_RESOURCE res
CROSS JOIN T_COST_ROLE r
LEFT JOIN T_COST_ROLE_PAGE rp ON rp.PAGE_CODE = res.PAGE_CODE AND rp.ROLE_ID = r.ID
ORDER BY res.SORT_ORDER;

-- BOM产品树视图(关联ERP)
CREATE OR REPLACE VIEW T_COST_BOM_GOODS_TREE_V AS
SELECT a.treeid, a.pid, a.goodsid, b.goodsname,
       (CASE
         WHEN b.zx_wms_goodsclass IN (1, 12) AND b.gspflag = 1 AND b.goodsno LIKE '%A%' THEN '4'
         WHEN b.zx_wms_goodsclass IN (10) AND b.gspflag = 1 THEN '0'
         WHEN b.zx_wms_goodsclass IN (7, 8, 9) AND b.gspflag = 1 THEN '1'
         WHEN b.zx_wms_goodsclass IN (5, 13) AND b.gspflag = 1 THEN '3'
         WHEN b.zx_wms_goodsclass IN (6) AND b.gspflag = 1 THEN '5'
         WHEN b.zx_wms_goodsclass IN (1, 2, 3, 4) AND b.gspflag = 1 AND b.goodsno NOT LIKE '%A%' THEN '2'
       END) useflag,
       b.standardtype, a.lvcode, a.useqty, a.entryid
FROM MPCS_MRP_GOODS_TREE_V@HYERP a, pub_goods@HYERP b
WHERE a.goodsid = b.goodsid;

-- ============================================================
-- 液体版视图
-- ============================================================

-- 物料成本核算明细视图_液体(关联主表)
CREATE OR REPLACE VIEW T_COST_PINGGU_DTL_LQ_V AS
SELECT a.docid, a.apex_goodsid, a.apex_goodsname, a.dtl_useflag, a.spec, a.per_hl, a.exadd_mater,
       a.batch_qty, a.price, a.cost_batch, a.memo, a.dtlid, a.apex_factoryname, a.apex_factoryid,
       a.modifydate, a.base_price, a.suqty, a.goodstype, a.goodsname_en,
       b.APEX_PL, b.P_PERPACK, b.S_PERBACK, b.X_PERBACK
FROM t_cost_pinggu_dtl_lq a, t_cost_pinggu_lq b
WHERE a.docid = b.docid;

-- 原辅料明细视图_液体
CREATE OR REPLACE VIEW V_COST_PINGGU_MATERIAL_LQ AS
SELECT d.DTLID AS ID, d.DOCID AS MASTER_ID, d.APEX_GOODSID, d.APEX_GOODSNAME, d.DTL_USEFLAG,
    d.SPEC, d.PER_HL, d.PRICE, d.BATCH_QTY, d.COST_BATCH, d.APEX_FACTORYNAME,
    d.BASE_PRICE, d.GOODSTYPE, d.EXADD_MATER, d.MEMO, d.DELETED, d.CREATE_TIME, d.UPDATE_TIME,
    d.CREATE_BY, d.UPDATE_BY,
    CASE WHEN d.DTL_USEFLAG = '辅料' AND REGEXP_LIKE(d.APEX_GOODSNAME, '胶囊') THEN 'B'
         WHEN d.DTL_USEFLAG IN ('原料', '辅料') THEN 'C' ELSE NULL END AS FORMULA_TYPE
FROM T_COST_PINGGU_DTL_LQ d
WHERE d.DTL_USEFLAG IN ('原料', '辅料') AND (d.DELETED = 0 OR d.DELETED IS NULL);

-- 包材明细视图_液体
CREATE OR REPLACE VIEW V_COST_PINGGU_PACKAGE_LQ AS
SELECT d.DTLID AS ID, d.DOCID AS MASTER_ID, d.APEX_GOODSID, d.APEX_GOODSNAME, d.DTL_USEFLAG,
    d.SPEC, d.PER_HL, d.EXADD_MATER, d.PRICE, d.BATCH_QTY, d.COST_BATCH, d.SUQTY,
    d.APEX_FACTORYNAME, d.MEMO, d.DELETED, d.CREATE_TIME, d.UPDATE_TIME, d.CREATE_BY, d.UPDATE_BY,
    CASE WHEN REGEXP_LIKE(d.APEX_GOODSNAME, '桶|说明书|小盒|标签|瓶|盖') THEN 'A'
         WHEN REGEXP_LIKE(d.APEX_GOODSNAME, '硬片|铝箔|复合膜') THEN 'D'
         WHEN REGEXP_LIKE(d.APEX_GOODSNAME, '大纸箱') THEN 'E'
         WHEN REGEXP_LIKE(d.APEX_GOODSNAME, '托盘') THEN 'F' ELSE NULL END AS FORMULA_TYPE
FROM T_COST_PINGGU_DTL_LQ d
WHERE d.DTL_USEFLAG IN ('非印字包材', '印字包材') AND (d.DELETED = 0 OR d.DELETED IS NULL);

-- 按物料查成品视图_液体
CREATE OR REPLACE VIEW V_COST_PGOODS_BY_MGOODS_LQ AS
SELECT a.apex_goodsid goodsid, a.apex_goodsname, a.dtl_useflag, b.factoryname, a.price, b.goodsno,
       d.goodsid pgoodsid, d.goodsno pgoodsno, d.goodsname, c.apex_pl, a.batch_qty, a.deleted
FROM T_COST_PINGGU_DTL_LQ a, t_cost_goods b, t_cost_pinggu_lq c, t_cost_goods d
WHERE a.apex_goodsid = b.goodsid AND a.docid = c.docid AND c.goodsid = d.goodsid
  AND a.deleted = 0 AND b.deleted = 0 AND c.deleted = 0 AND d.deleted = 0;
