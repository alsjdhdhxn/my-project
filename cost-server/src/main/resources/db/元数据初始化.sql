-- =====================================================
-- 外币管理：建表 / 序列 / 视图
-- =====================================================

CREATE TABLE T_COST_FORMONEY
(
  FMID       NUMBER(10)   NOT NULL, -- 外币ID（主键）
  FMOPCODE   VARCHAR2(60),          -- 外币编码
  FMNAME     VARCHAR2(120),         -- 外币名称
  FMSIGN     VARCHAR2(60),          -- 外币符号
  FMUNIT     VARCHAR2(60),          -- 外币单位
  FMRATE     NUMBER(16,6),          -- 外币税率
  USESTATUS  NUMBER(2),             -- 使用状态
  DELETED    NUMBER(1) DEFAULT 0,
  CREATE_TIME TIMESTAMP DEFAULT SYSTIMESTAMP,
  UPDATE_TIME TIMESTAMP DEFAULT SYSTIMESTAMP,
  CREATE_BY  VARCHAR2(64),
  UPDATE_BY  VARCHAR2(64),
  CONSTRAINT PK_COST_FORMONEY PRIMARY KEY (FMID)
);

CREATE SEQUENCE SEQ_COST_FORMONEY START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE VIEW ERP_FORMONEY_V AS
SELECT 
       DECODE(b.fmid,     NULL, a.fmid,     b.fmid)     fmid,
       DECODE(b.fmopcode, NULL, a.fmopcode, b.fmopcode) fmopcode,
       DECODE(b.fmname,   NULL, a.fmname,   b.fmname)   fmname,
       DECODE(b.fmsign,   NULL, a.fmsign,   b.fmsign)   fmsign,
       DECODE(b.fmunit,   NULL, a.fmunit,   b.fmunit)   fmunit,
       DECODE(b.fmrate,   NULL, a.fmrate,   b.fmrate)   fmrate,
       DECODE(b.usestatus,NULL, a.usestatus,b.usestatus) usestatus,
       NVL(b.deleted, 0)  deleted,
       b.create_time,
       b.update_time,
       b.create_by,
       b.update_by
  FROM pub_formoney_v@hyerp a, T_COST_FORMONEY b
 WHERE a.fmid = b.fmid(+);

COMMIT;
-- =====================================================
-- =====================================================
-- 外币管理：元数据
-- =====================================================

DECLARE
    v_formoney_id NUMBER;
BEGIN
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_formoney_id FROM DUAL;
    INSERT INTO T_COST_TABLE_METADATA
        (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, ACTION_RULES, CREATE_BY)
    VALUES
        (v_formoney_id, 'CostFormoney', '外币管理', 'ERP_FORMONEY_V', 'T_COST_FORMONEY', 'SEQ_COST_FORMONEY', 'FMID',
        '[{"order":1,"code":"syncErpPrice","name":"同步ERP汇率","group":"manual","enabled":true,"type":"sql","sql":"UPDATE T_COST_FORMONEY SET FMOPCODE=NULL,FMNAME=NULL,FMSIGN=NULL,FMUNIT=NULL,FMRATE=NULL,USESTATUS=NULL,CREATE_TIME=NULL,UPDATE_TIME=NULL,CREATE_BY=NULL,UPDATE_BY=NULL"}]',
        'system');

    -- 列元数据（业务字段 + 主键）
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_formoney_id, 'id', 'FMID', '外币ID', 'number', 0, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_formoney_id, 'fmopcode', 'FMOPCODE', '外币编码', 'text', 1, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_formoney_id, 'fmname', 'FMNAME', '外币名称', 'text', 2, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_formoney_id, 'fmsign', 'FMSIGN', '外币符号', 'text', 3, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_formoney_id, 'fmunit', 'FMUNIT', '外币单位', 'text', 4, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_formoney_id, 'fmrate', 'FMRATE', '外币税率', 'number', 5, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_formoney_id, 'usestatus', 'USESTATUS', '使用状态', 'number', 6, 'system');

    COMMIT;
END;
/

-- =====================================================
-- 外币管理：页面组件（单表）
-- PAGE_CODE 建议：formoney-manage
-- =====================================================

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'formoney-manage', 'root', 'LAYOUT', NULL, 0, '{"direction":"vertical","gap":8}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'formoney-manage', 'toolbar', 'LAYOUT', 'root', 1,
'{"direction":"horizontal","gap":8,"align":"center","justify":"flex-start"}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'formoney-manage', 'syncErpPrice', 'BUTTON', 'toolbar', 1,
'{"label":"同步ERP采购价","type":"primary","action":"syncErpPrice"}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'formoney-manage', 'grid', 'GRID', 'root', 2, 'CostFormoney', '{"height":"100%","selectionMode":"single"}', 'system');

-- =====================================================
-- 外币管理：页面规则（列覆盖 + 右键菜单）
-- =====================================================

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'formoney-manage', 'grid', 'COLUMN_OVERRIDE',
'[
  {"field":"id","visible":false,"editable":false},
  {"field":"fmopcode","width":140,"editable":true,"searchable":true},
  {"field":"fmname","width":180,"editable":true,"searchable":true},
  {"field":"fmsign","width":120,"editable":true},
  {"field":"fmunit","width":120,"editable":true},
  {"field":"fmrate","width":120,"editable":true},
  {"field":"usestatus","width":120,"editable":true}
]', 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'formoney-manage', 'grid', 'CONTEXT_MENU',
'{
  "items": [
    {"action":"addRow","label":"新增"},
    {"action":"copyRow","label":"复制"},
    {"action":"deleteRow","label":"删除"},
    {"action":"save","label":"保存"},
    {"type":"separator"},
    {"action":"exportCurrent","label":"导出当前"},
    {"action":"exportAll","label":"导出全部"},
    {"action":"openHeaderConfig","label":"表头配置"},
    {"action":"resetExportConfig","label":"重置导出配置"}
  ]
}', 'system');

COMMIT;

-- =====================================================
-- 外币管理：菜单与权限（可选）
-- =====================================================
DECLARE
  v_cost_id NUMBER;
BEGIN
  SELECT ID INTO v_cost_id FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'cost';
  INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
  VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'formoney', '外币管理', 'PAGE', 'formoney-manage', 'mdi:currency-usd', '/cost/formoney', v_cost_id, 10, 'system');
END;
/
INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, CREATE_BY)
VALUES (SEQ_COST_ROLE_PAGE.NEXTVAL, 1, 'formoney-manage', '["*"]', NULL, 'system');
COMMIT;


-- =====================================================
-- A3. 业务表结构 - 部门管理
-- =====================================================
CREATE TABLE T_COST_DEPT (
    DEPTID       NUMBER(19) PRIMARY KEY,
    DEPTNAME     VARCHAR2(300),
    MANAGER      NUMBER,
    DELETED      NUMBER(1)   DEFAULT 0,
    CREATE_TIME  TIMESTAMP  DEFAULT SYSTIMESTAMP,
    UPDATE_TIME  TIMESTAMP  DEFAULT SYSTIMESTAMP,
    CREATE_BY    VARCHAR2(64),
    UPDATE_BY    VARCHAR2(64)
);
CREATE SEQUENCE SEQ_COST_DEPT START WITH 1 INCREMENT BY 1;

COMMIT;

-- =====================================================
-- D?. 部门管理元数据 (CostDept)
-- =====================================================
DECLARE
    v_dept_id NUMBER;
BEGIN
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_dept_id FROM DUAL;
    INSERT INTO T_COST_TABLE_METADATA
        (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, CREATE_BY)
    VALUES
        (v_dept_id, 'CostDept', '部门管理', 'T_COST_DEPT', 'T_COST_DEPT', 'SEQ_COST_DEPT', 'DEPTID', 'system');

    INSERT INTO T_COST_COLUMN_METADATA
        (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES
        (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_dept_id, 'id', 'DEPTID', '部门ID', 'number', 0, 'system');

    INSERT INTO T_COST_COLUMN_METADATA
        (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES
        (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_dept_id, 'deptName', 'DEPTNAME', '部门名称', 'text', 1, 'system');

    INSERT INTO T_COST_COLUMN_METADATA
        (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES
        (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_dept_id, 'manager', 'MANAGER', '负责人ID', 'number', 2, 'system');
    COMMIT;
END;
/

-- =====================================================
-- E?. 部门管理页面组件
-- pageCode 建议：dept-manage（与 user-manage/role-manage 风格一致）
-- =====================================================
INSERT INTO T_COST_PAGE_COMPONENT
    (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES
    (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'dept-manage', 'root', 'LAYOUT', NULL, 0, '{"direction":"vertical"}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT
    (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG, CREATE_BY)
VALUES
    (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'dept-manage', 'grid', 'GRID', 'root', 1, 'CostDept', '{"height":"100%"}', 'system');

COMMIT;

-- =====================================================
-- D?. 默认右键菜单（与 user-manage 一致）
-- =====================================================
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES
(SEQ_COST_PAGE_RULE.NEXTVAL, 'dept-manage', 'grid', 'CONTEXT_MENU',
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
-- C?. 资源菜单（如需菜单）
-- =====================================================
DECLARE
    v_system_id NUMBER;
BEGIN
    SELECT ID INTO v_system_id FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'system';

    INSERT INTO T_COST_RESOURCE
        (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
    VALUES
        (SEQ_COST_RESOURCE.NEXTVAL, 'dept', '部门管理', 'PAGE', 'dept-manage', 'mdi:domain', '/system/dept', v_system_id, 3, 'system');
END;
/
COMMIT;

-- =====================================================
-- G?. 页面权限（管理员默认放开）
-- =====================================================
INSERT INTO T_COST_ROLE_PAGE
    (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, CREATE_BY)
VALUES
    (SEQ_COST_ROLE_PAGE.NEXTVAL, 1, 'dept-manage', '["*"]', NULL, 'system');

COMMIT;

-- =====================================================
-- 用户管理: department lookup (fill DEPARTMENT_ID)
-- =====================================================

-- 1) Add CostUser column metadata for DEPARTMENT_ID
DECLARE
    v_user_id NUMBER;
BEGIN
    SELECT ID INTO v_user_id FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostUser';

    INSERT INTO T_COST_COLUMN_METADATA
        (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES
        (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_user_id, 'departmentId', 'DEPARTMENT_ID', 'Department ID', 'number', 6, 'system');
    COMMIT;
END;
/

-- 2) Lookup config for department
INSERT INTO T_COST_LOOKUP_CONFIG
    (ID, LOOKUP_CODE, LOOKUP_NAME, DATA_SOURCE, DISPLAY_COLUMNS, SEARCH_COLUMNS, VALUE_FIELD, LABEL_FIELD, CREATE_BY)
VALUES
    (SEQ_COST_LOOKUP_CONFIG.NEXTVAL, 'dept', 'Department', 'CostDept',
     '[{"field":"deptName","header":"Department","width":200},{"field":"id","header":"Dept ID","width":80},{"field":"manager","header":"Manager ID","width":100}]',
     '["deptName"]', 'id', 'deptName', 'system');

-- 3) User manage lookup rule
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES
(SEQ_COST_PAGE_RULE.NEXTVAL, 'user-manage', 'grid', 'LOOKUP',
'[
  {"field":"departmentId","lookupCode":"dept","mapping":{"departmentId":"id"}}
]', 'system');

COMMIT;

-- =====================================================
-- 产品信息维护：建表 / 序列 / 视图
-- =====================================================

CREATE TABLE T_COST_GOODS (
    GOODSID        NUMBER(19) PRIMARY KEY,
    GOODSNAME      VARCHAR2(200),
    GOODSTYPE      VARCHAR2(100),
    PACKTYPE       VARCHAR2(100),
    TRANPOSID      NUMBER(19),
    ZX_CUSTOMERID  NUMBER(19),
    ISERP          NUMBER(1) DEFAULT 0,
    DELETED        NUMBER(1) DEFAULT 0,
    CREATE_TIME    TIMESTAMP DEFAULT SYSTIMESTAMP,
    UPDATE_TIME    TIMESTAMP DEFAULT SYSTIMESTAMP,
    CREATE_BY      VARCHAR2(64),
    UPDATE_BY      VARCHAR2(64)
);
CREATE SEQUENCE SEQ_COST_GOODS START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE VIEW T_COST_GOODS_V AS
SELECT B.GOODSID,
       B.GOODSNAME,
       B.GOODSTYPE,
       B.PACKTYPE,
       B.TRANPOSID,
       B.ZX_CUSTOMERID,
       B.CUSTOMNAME,
       B.TRANPOSNAME,
       1 AS ISERP,
       0 AS DELETED,
       NULL AS CREATE_TIME,
       NULL AS UPDATE_TIME,
       NULL AS CREATE_BY,
       NULL AS UPDATE_BY
  FROM PUB_GOODS_V@hyerp B
 WHERE B.ZX_WMS_GOODSCLASS IN (10)
   AND B.GSPFLAG = 1
UNION ALL
SELECT A.GOODSID,
       A.GOODSNAME,
       A.GOODSTYPE,
       A.PACKTYPE,
       A.TRANPOSID,
       A.ZX_CUSTOMERID,
       B.CUSTOMNAME,
       C.TRANPOSNAME,
       NVL(A.ISERP, 0) AS ISERP,
       A.DELETED,
       A.CREATE_TIME,
       A.UPDATE_TIME,
       A.CREATE_BY,
       A.UPDATE_BY
  FROM T_COST_GOODS A, PUB_CUSTOMER@hyerp B, BMS_TR_POS_DEF@hyerp C
 WHERE A.ZX_CUSTOMERID = B.CUSTOMID(+)
   AND A.TRANPOSID = C.TRANPOSID(+);

COMMIT;

-- =====================================================
-- 产品信息维护：元数据
-- =====================================================

DECLARE
    v_goods_id NUMBER;
BEGIN
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_goods_id FROM DUAL;
    INSERT INTO T_COST_TABLE_METADATA
        (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, CREATE_BY)
    VALUES
        (v_goods_id, 'CostGoods', '产品信息', 'T_COST_GOODS_V', 'T_COST_GOODS', 'SEQ_COST_GOODS', 'GOODSID', 'system');

    -- 列元数据
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

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_id, 'iserp', 'ISERP', '是否ERP', 'number', 98, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_goods_id, 'createBy', 'CREATE_BY', '创建人', 'text', 99, 'system');

    COMMIT;
END;
/

-- =====================================================
-- 产品信息维护：页面组件
-- PAGE_CODE: goods-manage
-- =====================================================

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'goods-manage', 'root', 'LAYOUT', NULL, 0, '{"direction":"vertical"}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'goods-manage', 'grid', 'GRID', 'root', 1, 'CostGoods', '{"height":"100%"}', 'system');

COMMIT;

-- =====================================================
-- 产品信息维护：页面规则
-- =====================================================

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'goods-manage', 'grid', 'COLUMN_OVERRIDE',
'[
  {"field":"id","visible":false,"editable":false},
  {"field":"goodsname","width":200,"editable":true,"searchable":true},
  {"field":"goodstype","width":150,"editable":true,"searchable":true},
  {"field":"packtype","width":150,"editable":true},
  {"field":"tranposid","width":100,"editable":true},
  {"field":"tranposname","width":150,"editable":false},
  {"field":"zxCustomerid","width":100,"editable":true},
  {"field":"customname","width":150,"editable":false},
  {"field":"iserp","visible":false},
  {"field":"createBy","visible":false}
]', 'system');

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

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'goods-manage', 'grid', 'ROW_CLASS',
'[{"field":"iserp","operator":"eq","value":1,"className":"row-confirmed"}]', 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'goods-manage', 'grid', 'ROW_EDITABLE',
'[{"field":"iserp","operator":"ne","value":1}]', 'system');

COMMIT;

-- =====================================================
-- 产品信息维护：菜单与权限
-- =====================================================

DECLARE
    v_cost_id NUMBER;
BEGIN
    SELECT ID INTO v_cost_id FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'cost';
    INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
    VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'goods', '产品信息', 'PAGE', 'goods-manage', 'mdi:package-variant', '/cost/goods', v_cost_id, 2, 'system');
END;
/

INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, CREATE_BY)
VALUES (SEQ_COST_ROLE_PAGE.NEXTVAL, 1, 'goods-manage', '["*"]', NULL, 'system');

COMMIT;
