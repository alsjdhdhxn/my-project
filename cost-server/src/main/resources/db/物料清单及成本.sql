-- =====================================================
-- 物料清单及成本 初始化脚本
-- =====================================================
-- 数据来源：通过定时任务 JOB_SYNC_GOODS_PRICE 每5分钟从ERP同步
-- 存储过程：PROC_SYNC_GOODS_PRICE
-- =====================================================

-- =====================================================
-- A. 删除表和序列
-- =====================================================
BEGIN EXECUTE IMMEDIATE 'DROP VIEW T_COST_GOODS_PRICE_V'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE T_COST_GOODS_PRICE CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE SEQ_COST_GOODS_PRICE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- =====================================================
-- B. 删除元数据
-- =====================================================
DELETE FROM T_COST_ROLE_PAGE WHERE PAGE_CODE = 'goods-price-manage';
DELETE FROM T_COST_PAGE_RULE WHERE PAGE_CODE = 'goods-price-manage';
DELETE FROM T_COST_PAGE_COMPONENT WHERE PAGE_CODE = 'goods-price-manage';
DELETE FROM T_COST_COLUMN_METADATA WHERE TABLE_METADATA_ID IN (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostGoodsPrice');
DELETE FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostGoodsPrice';
DELETE FROM T_COST_COLUMN_METADATA WHERE TABLE_METADATA_ID IN (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostGoodsByApex');
DELETE FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostGoodsByApex';
DELETE FROM T_COST_LOOKUP_CONFIG WHERE LOOKUP_CODE = 'goodsByApex';
DELETE FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'goods-price';
COMMIT;

-- =====================================================
-- C. 创建表结构
-- =====================================================
CREATE TABLE T_COST_GOODS_PRICE (
    GOODSID      NUMBER(10) PRIMARY KEY,
    GOODSNAME    VARCHAR2(300),
    PRICE        NUMBER,
    USEFLAG      VARCHAR2(15),
    GOODSTYPE    VARCHAR2(3000),
    PACKTYPE     VARCHAR2(600),
    FACTORYNAME  VARCHAR2(300),
    DELETED      NUMBER(1) DEFAULT 0,
    CREATE_TIME  TIMESTAMP DEFAULT SYSTIMESTAMP,
    UPDATE_TIME  TIMESTAMP DEFAULT SYSTIMESTAMP,
    CREATE_BY    VARCHAR2(64),
    UPDATE_BY    VARCHAR2(64),
    ISERP        NUMBER(1) DEFAULT 0
);

CREATE SEQUENCE SEQ_COST_GOODS_PRICE START WITH 1 INCREMENT BY 1;
COMMIT;

-- =====================================================
-- D. 创建视图
-- =====================================================
CREATE OR REPLACE VIEW T_COST_GOODS_PRICE_V AS
SELECT GOODSID,
       GOODSNAME,
       PRICE,
       USEFLAG,
       GOODSTYPE,
       PACKTYPE,
       FACTORYNAME,
       DELETED,
       CREATE_TIME,
       UPDATE_TIME,
       CREATE_BY,
       UPDATE_BY,
       ISERP,
       CASE
           WHEN ISERP = 1
            AND NVL(LOWER(UPDATE_BY), '#') <> 'system'
            AND PRICE IS NULL THEN 'erp-price-null'
           WHEN ISERP = 1
            AND NVL(LOWER(UPDATE_BY), '#') <> 'system' THEN 'erp-updated'
           WHEN ISERP = 1 THEN 'erp'
           ELSE NULL
       END AS ROW_CLASS_FLAG
  FROM T_COST_GOODS_PRICE;
COMMIT;

-- =====================================================
-- E. 插入表元数据
-- =====================================================
DECLARE
    v_goods_price_id NUMBER;
BEGIN
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_goods_price_id FROM DUAL;

    INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, CREATE_BY)
    VALUES (v_goods_price_id, 'CostGoodsPrice', '物料清单及成本', 'T_COST_GOODS_PRICE_V', 'T_COST_GOODS_PRICE', 'SEQ_COST_GOODS_PRICE', 'GOODSID', 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_price_id, 'id', 'GOODSID', '产品ID', 'number', 0, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_price_id, 'goodsname', 'GOODSNAME', '产品名称', 'text', 1, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_price_id, 'price', 'PRICE', '价格', 'number', 2, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_price_id, 'useflag', 'USEFLAG', '用途', 'text', 3, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_price_id, 'goodstype', 'GOODSTYPE', '规格', 'text', 4, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_price_id, 'packtype', 'PACKTYPE', '包装规格', 'text', 5, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_price_id, 'factoryname', 'FACTORYNAME', '供应商', 'text', 6, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_price_id, 'iserp', 'ISERP', '是否ERP', 'number', 7, 'system');

    COMMIT;
END;
/

-- =====================================================
-- F. 插入页面规则
-- =====================================================

-- 列配置
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'goods-price-manage', 'grid', 'COLUMN_OVERRIDE',
'[
  {"field":"id","visible":true,"editable":false},
  {"field":"goodsname","width":null,"editable":true,"searchable":true},
  {"field":"price","width":null,"editable":true},
  {"field":"useflag","width":null,"editable":true},
  {"field":"goodstype","width":null,"editable":true},
  {"field":"packtype","width":null,"editable":true},
  {"field":"factoryname","width":null,"editable":true},
  {"field":"iserp","width":null,"editable":false}
]', 'system');

-- 表格选项
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'goods-price-manage', 'grid', 'GRID_OPTIONS',
'{"rowModelType":"infinite","cacheBlockSize":200,"maxBlocksInCache":10}', 'system');

-- 行样式规则
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'goods-price-manage', 'grid', 'ROW_CLASS',
'[
  {"field":"rowClassFlag","operator":"eq","value":"erp","className":"row-iserp"},
  {"field":"rowClassFlag","operator":"eq","value":"erp-updated","className":"row-iserp-updated"},
  {"field":"rowClassFlag","operator":"eq","value":"erp-price-null","className":"row-iserp-price-null"}
]', 'system');

-- 单元格编辑规则：ISERP=1时只允许编辑price字段
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'goods-price-manage', 'grid', 'CELL_EDITABLE',
'[{"condition":{"field":"iserp","operator":"eq","value":1},"editableFields":["price"]}]', 'system');

-- 右键菜单
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'goods-price-manage', 'grid', 'CONTEXT_MENU',
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

COMMIT;

-- =====================================================
-- G. 插入页面组件
-- =====================================================
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'goods-price-manage', 'root', 'LAYOUT', NULL, 0, '{"direction":"vertical"}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'goods-price-manage', 'grid', 'GRID', 'root', 1, 'CostGoodsPrice', '{"height":"100%"}', 'system');

COMMIT;

-- =====================================================
-- H. 插入菜单资源
-- =====================================================
DECLARE
    v_cost_id NUMBER;
BEGIN
    SELECT ID INTO v_cost_id FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'cost';
    INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
    VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'goods-price', '物料清单及成本', 'PAGE', 'goods-price-manage', 'mdi:tag-outline', '/cost/goods-price', v_cost_id, 4, 'system');
    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
        VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'goods-price', '物料清单及成本', 'PAGE', 'goods-price-manage', 'mdi:tag-outline', '/cost/goods-price', NULL, 4, 'system');
        COMMIT;
END;
/

-- =====================================================
-- I. 角色权限配置
-- =====================================================
INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, CREATE_BY)
VALUES (SEQ_COST_ROLE_PAGE.NEXTVAL, 
    (SELECT ID FROM T_COST_ROLE WHERE ROLE_CODE = 'ADMIN'), 
    'goods-price-manage', '["*"]', NULL, 'system');

COMMIT;

-- =====================================================
-- J. 产品弹窗配置（按物料）
-- =====================================================

-- 1. 创建产品弹窗视图
CREATE OR REPLACE VIEW V_COST_GOODS_BY_APEX AS
SELECT c.GOODSID AS P_GOODSID,
       c.GOODSNAME,
       c.GOODSTYPE,
       c.PACKTYPE,
       c.TRANPOSID,
       c.TRANPOSNAME,
       c.ZX_CUSTOMERID,
       c.CUSTOMNAME,
       c.ZONE,
       a.APEX_GOODSID AS GOODSID,
       0 AS DELETED
  FROM T_COST_PINGGU_DTL a, T_COST_PINGGU b, T_COST_GOODS_V c
 WHERE a.DOCID = b.DOCID
   AND b.GOODSID = c.GOODSID;

-- 2. 创建lookup配置（使用DATA_SOURCE指向表元数据的TABLE_CODE）
INSERT INTO T_COST_LOOKUP_CONFIG (ID, LOOKUP_CODE, LOOKUP_NAME, DATA_SOURCE, DISPLAY_COLUMNS, SEARCH_COLUMNS, VALUE_FIELD, LABEL_FIELD, CREATE_BY)
VALUES (SEQ_COST_LOOKUP_CONFIG.NEXTVAL, 'goodsByApex', '产品选择(按物料)', 'V_COST_GOODS_BY_APEX',
'[{"field":"pGoodsid","header":"产品ID","width":80},{"field":"goodsname","header":"产品名称","width":200},{"field":"goodstype","header":"规格","width":150},{"field":"packtype","header":"包装规格","width":120},{"field":"tranposname","header":"分销商","width":150},{"field":"customname","header":"客户名称","width":150},{"field":"zone","header":"国家","width":100}]',
'["goodsname","customname"]', 'goodsid', 'goodsname', 'system');

-- 3. 创建视图的表元数据（供lookup使用）
DECLARE
    v_goods_apex_id NUMBER;
BEGIN
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_goods_apex_id FROM DUAL;

    INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, PK_COLUMN, CREATE_BY)
    VALUES (v_goods_apex_id, 'CostGoodsByApex', '产品选择(按物料)', 'V_COST_GOODS_BY_APEX', 'V_COST_GOODS_BY_APEX', 'GOODSID', 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_apex_id, 'pGoodsid', 'P_GOODSID', '产品ID', 'number', 0, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_apex_id, 'goodsname', 'GOODSNAME', '产品名称', 'text', 1, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_apex_id, 'goodstype', 'GOODSTYPE', '规格', 'text', 2, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_apex_id, 'packtype', 'PACKTYPE', '包装规格', 'text', 3, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_apex_id, 'tranposid', 'TRANPOSID', '分销商ID', 'number', 4, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_apex_id, 'tranposname', 'TRANPOSNAME', '分销商', 'text', 5, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_apex_id, 'zxCustomerid', 'ZX_CUSTOMERID', '客户ID', 'number', 6, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_apex_id, 'customname', 'CUSTOMNAME', '客户名称', 'text', 7, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_apex_id, 'zone', 'ZONE', '国家', 'text', 8, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_apex_id, 'goodsid', 'GOODSID', '物料ID', 'number', 9, 'system');

    COMMIT;
END;
/

-- 4. 给物料清单及成本页面添加LOOKUP规则（无回填）
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'goods-price-manage', 'grid', 'LOOKUP',
'[{"field":"id","lookupCode":"goodsByApex","noFillback":true}]', 'system');

COMMIT;
