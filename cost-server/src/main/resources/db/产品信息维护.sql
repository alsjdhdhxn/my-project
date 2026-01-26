-- =====================================================
-- 产品信息维护 初始化脚本
-- =====================================================
-- 数据来源：通过定时任务从ERP同步
-- 存储过程：SP_SYNC_COST_GOODS
-- =====================================================

-- =====================================================
-- A. 删除表和序列
-- =====================================================
BEGIN EXECUTE IMMEDIATE 'DROP VIEW T_COST_GOODS_V'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE T_COST_GOODS CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE SEQ_COST_GOODS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- =====================================================
-- B. 删除元数据
-- =====================================================
DELETE FROM T_COST_ROLE_PAGE WHERE PAGE_CODE = 'goods-manage';
DELETE FROM T_COST_PAGE_RULE WHERE PAGE_CODE = 'goods-manage';
DELETE FROM T_COST_PAGE_COMPONENT WHERE PAGE_CODE = 'goods-manage';
DELETE FROM T_COST_COLUMN_METADATA WHERE TABLE_METADATA_ID IN (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostGoods');
DELETE FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostGoods';
DELETE FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'goods';
COMMIT;

-- =====================================================
-- C. 创建表结构
-- =====================================================
CREATE TABLE T_COST_GOODS (
    GOODSID        NUMBER(19) PRIMARY KEY,
    GOODSNAME      VARCHAR2(1000),
    PRICE          NUMBER,
    SUQTY          NUMBER,
    USEFLAG        VARCHAR2(100) DEFAULT '产成品',
    FACTORYNAME    VARCHAR2(1500),
    STANDARDTYPE   VARCHAR2(500),
    ZX_PL          NUMBER,
    ZX_MINIMUM     NUMBER,
    APPROVEDOCNO   VARCHAR2(500),
    BASEUNITQTY    NUMBER,
    ZX_CUSTOMERID  NUMBER(19),
    CUSTOMNAME     VARCHAR2(1000),
    TARGETMARKET   VARCHAR2(1000),
    HOLDERSNAME    VARCHAR2(1000),
    ISERP          NUMBER(1) DEFAULT 0,
    GOODSTYPE      VARCHAR2(500),
    PACKTYPE       VARCHAR2(500),
    TRANPOSNAME    VARCHAR2(1000),
    BOMID          NUMBER(19),
    LASTSUQTY      NUMBER,
    TRANPOSID      NUMBER(19),
    DELETED        NUMBER(1) DEFAULT 0,
    CREATE_TIME    TIMESTAMP DEFAULT SYSTIMESTAMP,
    UPDATE_TIME    TIMESTAMP DEFAULT SYSTIMESTAMP,
    CREATE_BY      VARCHAR2(320),
    UPDATE_BY      VARCHAR2(320)
);

CREATE SEQUENCE SEQ_COST_GOODS START WITH 1 INCREMENT BY 1;
COMMIT;

-- =====================================================
-- D. 创建视图（只显示产成品）
-- =====================================================
CREATE OR REPLACE VIEW T_COST_GOODS_V AS
SELECT GOODSID,
       GOODSNAME,
       PRICE,
       SUQTY,
       USEFLAG,
       FACTORYNAME,
       STANDARDTYPE,
       ZX_PL,
       ZX_MINIMUM,
       APPROVEDOCNO,
       BASEUNITQTY,
       ZX_CUSTOMERID,
       CUSTOMNAME,
       TARGETMARKET,
       HOLDERSNAME,
       ISERP,
       GOODSTYPE,
       PACKTYPE,
       TRANPOSNAME,
       BOMID,
       LASTSUQTY,
       TRANPOSID,
       DELETED,
       CREATE_TIME,
       UPDATE_TIME,
       CREATE_BY,
       UPDATE_BY
  FROM T_COST_GOODS
 WHERE USEFLAG = '产成品'
   AND (DELETED = 0 OR DELETED IS NULL);
COMMIT;

-- =====================================================
-- E. 插入表元数据
-- =====================================================
DECLARE
    v_goods_id NUMBER;
BEGIN
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_goods_id FROM DUAL;

    INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, CREATE_BY)
    VALUES (v_goods_id, 'CostGoods', '产品信息维护', 'T_COST_GOODS_V', 'T_COST_GOODS', 'SEQ_COST_GOODS', 'GOODSID', 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_id, 'id', 'GOODSID', '产品ID', 'number', 0, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_id, 'goodsname', 'GOODSNAME', '产品名称', 'text', 1, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_id, 'goodstype', 'GOODSTYPE', '规格', 'text', 2, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_id, 'packtype', 'PACKTYPE', '包装规格', 'text', 3, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_id, 'tranposid', 'TRANPOSID', '分销商ID', 'number', 4, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_id, 'tranposname', 'TRANPOSNAME', '分销商', 'text', 5, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_id, 'zxCustomerid', 'ZX_CUSTOMERID', '客户ID', 'number', 6, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_id, 'customname', 'CUSTOMNAME', '客户名称', 'text', 7, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, IS_VIRTUAL, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_id, 'iserp', 'ISERP', '是否ERP', 'number', 98, 1, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_id, 'createBy', 'CREATE_BY', '创建人', 'text', 99, 'system');

    COMMIT;
END;
/

-- =====================================================
-- F. 插入页面规则
-- =====================================================

-- 列配置
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'goods-manage', 'grid', 'COLUMN_OVERRIDE',
'[
  {"field":"id","visible":false,"editable":false},
  {"field":"goodsname","width":null,"editable":true,"searchable":true},
  {"field":"goodstype","width":null,"editable":true,"searchable":true},
  {"field":"packtype","width":null,"editable":true},
  {"field":"tranposid","width":null,"editable":true},
  {"field":"tranposname","width":null,"editable":false},
  {"field":"zxCustomerid","width":null,"editable":true},
  {"field":"customname","width":null,"editable":false},
  {"field":"iserp","visible":false},
  {"field":"createBy","visible":false}
]', 'system');

-- Lookup配置
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'goods-manage', 'grid', 'LOOKUP',
'[
  {"field":"customname","lookupCode":"customer","mapping":{"zxCustomerid":"customid","customname":"customname","tranposid":"tranposid","tranposname":"tranposname"}}
]', 'system');

-- 右键菜单
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'goods-manage', 'grid', 'CONTEXT_MENU',
'{"items":[
  {"action":"addRow"},
  {"action":"copyRow","requiresRow":true},
  {"action":"deleteRow","requiresRow":true},
  {"type":"separator"},
  {"action":"saveGridConfig"},
  {"type":"separator"},
  {"label":"导出","items":[
    {"action":"exportSelected","requiresSelection":true},
    {"action":"exportCurrent"},
    {"action":"exportAll"},
    {"type":"separator"},
    {"action":"resetExportConfig"},
    {"action":"openHeaderConfig"}
  ]},
  {"type":"separator"},
  {"action":"save"},
  {"type":"separator"},
  {"action":"clipboard.copy"},
  {"action":"clipboard.paste"}
]}', 'system');

-- 行样式规则
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'goods-manage', 'grid', 'ROW_CLASS',
'[{"field":"iserp","operator":"eq","value":1,"className":"row-confirmed"}]', 'system');

-- 行编辑规则
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'goods-manage', 'grid', 'ROW_EDITABLE',
'[{"field":"iserp","operator":"ne","value":1}]', 'system');

COMMIT;

-- =====================================================
-- G. 插入页面组件
-- =====================================================
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'goods-manage', 'root', 'LAYOUT', NULL, 0, '{"direction":"vertical"}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'goods-manage', 'grid', 'GRID', 'root', 1, 'CostGoods', '{"height":"100%"}', 'system');

COMMIT;

-- =====================================================
-- H. 插入菜单资源
-- =====================================================
DECLARE
    v_cost_id NUMBER;
BEGIN
    SELECT ID INTO v_cost_id FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'cost';
    INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
    VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'goods', '产品信息维护', 'PAGE', 'goods-manage', 'mdi:package-variant', '/cost/goods', v_cost_id, 2, 'system');
    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
        VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'goods', '产品信息维护', 'PAGE', 'goods-manage', 'mdi:package-variant', '/cost/goods', NULL, 2, 'system');
        COMMIT;
END;
/

-- =====================================================
-- I. 角色权限配置
-- =====================================================
INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, CREATE_BY)
VALUES (SEQ_COST_ROLE_PAGE.NEXTVAL, 
    (SELECT ID FROM T_COST_ROLE WHERE ROLE_CODE = 'ADMIN'), 
    'goods-manage', '["*"]', NULL, 'system');

COMMIT;

-- =====================================================
-- J. 数据同步存储过程
-- =====================================================
CREATE OR REPLACE PROCEDURE SP_SYNC_COST_GOODS AS
BEGIN
    -- 使用 MERGE 实现增量同步
    MERGE INTO T_COST_GOODS T
    USING (
        SELECT B.GOODSID,
               B.GOODSNAME,
               C.LASTPRICE AS PRICE,
               C.LASTSUQTY AS SUQTY,
               (CASE
                   WHEN B.ZX_WMS_GOODSCLASS IN (1, 12) AND B.GSPFLAG = 1 AND B.GOODSNO LIKE '%A%' THEN '原料'
                   WHEN B.ZX_WMS_GOODSCLASS IN (10) AND B.GSPFLAG = 1 THEN '产成品'
                   WHEN B.ZX_WMS_GOODSCLASS IN (7, 8, 9) AND B.GSPFLAG = 1 THEN '半成品'
                   WHEN B.ZX_WMS_GOODSCLASS IN (5, 13) AND B.GSPFLAG = 1 THEN '非印字包材'
                   WHEN B.ZX_WMS_GOODSCLASS IN (6) AND B.GSPFLAG = 1 THEN '印字包材'
                   WHEN B.ZX_WMS_GOODSCLASS IN (1, 2, 3, 4) AND B.GSPFLAG = 1 AND B.GOODSNO NOT LIKE '%A%' THEN '辅料'
               END) AS USEFLAG,
               B.FACTORYNAME,
               B.STANDARDTYPE,
               B.ZX_PL,
               B.ZX_MINIMUM,
               B.APPROVEDOCNO,
               E.BASEUNITQTY,
               B.ZX_CUSTOMERID,
               B.CUSTOMNAME,
               F.TARGETMARKET,
               B.HOLDERSNAME,
               B.GOODSTYPE,
               B.PACKTYPE,
               B.TRANPOSNAME,
               D.BOMID,
               C.LASTSUQTY AS LASTSUQTY2,
               B.TRANPOSID
          FROM PUB_GOODS_V@hyerp B,
               BMS_SU_SUPPLYGOODS_DOC@hyerp C,
               MPCS_PR_BOM_DOC@hyerp D,
               PUB_GOODS_UNIT_V@hyerp E,
               BMS_TR_POS_DEF@hyerp F
         WHERE B.GOODSID = C.GOODSID(+)
           AND B.GOODSID = D.PGOODSID(+)
           AND D.USESTATUS(+) = 1
           AND B.USESTATUS = 1
           AND C.ENTRYID(+) = 1
           AND B.GOODSID = E.GOODSID(+)
           AND E.GOODSDTLFLAG(+) = 1
           AND E.BASEFLAG(+) <> 1
           AND B.GOODSID < 1000000
           AND B.ZX_CUSTOMERID = F.COMPANYID(+)
           AND B.TRANPOSID = F.TRANPOSID(+)
    ) S
    ON (T.GOODSID = S.GOODSID)
    WHEN MATCHED THEN
        UPDATE SET
            T.GOODSNAME = S.GOODSNAME,
            T.PRICE = S.PRICE,
            T.SUQTY = S.SUQTY,
            T.USEFLAG = S.USEFLAG,
            T.FACTORYNAME = S.FACTORYNAME,
            T.STANDARDTYPE = S.STANDARDTYPE,
            T.ZX_PL = S.ZX_PL,
            T.ZX_MINIMUM = S.ZX_MINIMUM,
            T.APPROVEDOCNO = S.APPROVEDOCNO,
            T.BASEUNITQTY = S.BASEUNITQTY,
            T.ZX_CUSTOMERID = S.ZX_CUSTOMERID,
            T.CUSTOMNAME = S.CUSTOMNAME,
            T.TARGETMARKET = S.TARGETMARKET,
            T.HOLDERSNAME = S.HOLDERSNAME,
            T.GOODSTYPE = S.GOODSTYPE,
            T.PACKTYPE = S.PACKTYPE,
            T.TRANPOSNAME = S.TRANPOSNAME,
            T.BOMID = S.BOMID,
            T.LASTSUQTY = S.LASTSUQTY2,
            T.TRANPOSID = S.TRANPOSID,
            T.ISERP = 1,
            T.UPDATE_TIME = SYSTIMESTAMP,
            T.UPDATE_BY = 'ERP_SYNC'
    WHEN NOT MATCHED THEN
        INSERT (GOODSID, GOODSNAME, PRICE, SUQTY, USEFLAG, FACTORYNAME, STANDARDTYPE,
                ZX_PL, ZX_MINIMUM, APPROVEDOCNO, BASEUNITQTY, ZX_CUSTOMERID, CUSTOMNAME,
                TARGETMARKET, HOLDERSNAME, ISERP, GOODSTYPE, PACKTYPE, TRANPOSNAME,
                BOMID, LASTSUQTY, TRANPOSID, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
        VALUES (S.GOODSID, S.GOODSNAME, S.PRICE, S.SUQTY, S.USEFLAG, S.FACTORYNAME, S.STANDARDTYPE,
                S.ZX_PL, S.ZX_MINIMUM, S.APPROVEDOCNO, S.BASEUNITQTY, S.ZX_CUSTOMERID, S.CUSTOMNAME,
                S.TARGETMARKET, S.HOLDERSNAME, 1, S.GOODSTYPE, S.PACKTYPE, S.TRANPOSNAME,
                S.BOMID, S.LASTSUQTY2, S.TRANPOSID, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'ERP_SYNC', 'ERP_SYNC');

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('产品信息同步完成，时间: ' || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS'));
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('产品信息同步失败: ' || SQLERRM);
        RAISE;
END;
/
