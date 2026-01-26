-- =====================================================
-- 外币汇率管理 初始化脚本
-- =====================================================

-- =====================================================
-- 0. 清理旧数据
-- =====================================================

DELETE FROM T_COST_ROLE_PAGE WHERE PAGE_CODE = 'formoney-manage';
DELETE FROM T_COST_PAGE_RULE WHERE PAGE_CODE = 'formoney-manage';
DELETE FROM T_COST_PAGE_COMPONENT WHERE PAGE_CODE = 'formoney-manage';
DELETE FROM T_COST_COLUMN_METADATA WHERE TABLE_METADATA_ID IN (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostFormoney');
DELETE FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostFormoney';
DELETE FROM T_COST_RESOURCE WHERE RESOURCE_CODE IN ('cost', 'formoney');

COMMIT;

-- =====================================================
-- 1. 表结构
-- =====================================================

CREATE TABLE T_COST_FORMONEY
(
  FMID        NUMBER(10)   NOT NULL, -- 外币ID（主键）
  FMOPCODE    VARCHAR2(60),          -- 外币编码
  FMNAME      VARCHAR2(120),         -- 外币名称
  FMSIGN      VARCHAR2(60),          -- 外币符号
  FMUNIT      VARCHAR2(60),          -- 外币单位
  FMRATE      NUMBER(16,6),          -- 外币税率
  USESTATUS   NUMBER(2),             -- 使用状态
  DELETED     NUMBER(1) DEFAULT 0,
  CREATE_TIME TIMESTAMP DEFAULT SYSTIMESTAMP,
  UPDATE_TIME TIMESTAMP DEFAULT SYSTIMESTAMP,
  CREATE_BY   VARCHAR2(64),
  UPDATE_BY   VARCHAR2(64),
  CONSTRAINT PK_COST_FORMONEY PRIMARY KEY (FMID)
);

CREATE SEQUENCE SEQ_COST_FORMONEY START WITH 1 INCREMENT BY 1;

-- =====================================================
-- 1.1 初始化数据（从ERP同步）
-- =====================================================

MERGE INTO T_COST_FORMONEY t
USING (
    SELECT fmid, fmopcode, fmname, fmsign, fmunit, fmrate, usestatus 
    FROM pub_formoney_v@hyerp
) s
ON (t.FMID = s.fmid)
WHEN MATCHED THEN
    UPDATE SET t.FMOPCODE = s.fmopcode, t.FMNAME = s.fmname, t.FMSIGN = s.fmsign,
               t.FMUNIT = s.fmunit, t.FMRATE = s.fmrate, t.USESTATUS = s.usestatus,
               t.UPDATE_TIME = SYSTIMESTAMP, t.DELETED = 0
WHEN NOT MATCHED THEN
    INSERT (FMID, FMOPCODE, FMNAME, FMSIGN, FMUNIT, FMRATE, USESTATUS, DELETED, CREATE_BY, CREATE_TIME)
    VALUES (s.fmid, s.fmopcode, s.fmname, s.fmsign, s.fmunit, s.fmrate, s.usestatus, 0, 'sync', SYSTIMESTAMP);

COMMIT;

-- =====================================================
-- 2. 菜单资源配置
-- =====================================================

-- 成本管理目录
INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'cost', '成本管理', 'DIRECTORY', NULL, 'mdi:currency-usd', '/cost', NULL, 1, 'system');

-- 外币管理页面
DECLARE
    v_cost_id NUMBER;
BEGIN
    SELECT ID INTO v_cost_id FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'cost';
    
    INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
    VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'formoney', '外币管理', 'PAGE', 'formoney-manage', 'mdi:currency-usd', '/cost/formoney', v_cost_id, 10, 'system');
END;
/

COMMIT;

-- =====================================================
-- 3. 视图定义
-- =====================================================

-- 外币管理视图（关联ERP数据）
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

-- =====================================================
-- 4. 表元数据配置
-- =====================================================

DECLARE
    v_formoney_id NUMBER;
BEGIN
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_formoney_id FROM DUAL;

    INSERT INTO T_COST_TABLE_METADATA
        (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, ACTION_RULES, CREATE_BY)
    VALUES
        (v_formoney_id, 'CostFormoney', '外币管理', 'ERP_FORMONEY_V', 'T_COST_FORMONEY', 'SEQ_COST_FORMONEY', 'FMID',
         '[{"order":1,"code":"syncErpPrice","name":"同步ERP采购价","group":"manual","enabled":true,"type":"sql","sql":"UPDATE T_COST_FORMONEY SET FMOPCODE=NULL,FMNAME=NULL,FMSIGN=NULL,FMUNIT=NULL,FMRATE=NULL,USESTATUS=NULL,CREATE_TIME=NULL,UPDATE_TIME=NULL,CREATE_BY=NULL,UPDATE_BY=NULL"}]',
         'system');

    -- 列元数据
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
-- 5. 页面组件配置
-- =====================================================

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'formoney-manage', 'root', 'LAYOUT', NULL, 0, '{"direction":"vertical","gap":8}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'formoney-manage', 'toolbar', 'LAYOUT', 'root', 1,
'{"direction":"horizontal","gap":8,"align":"center","justify":"flex-start"}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'formoney-manage', 'syncErpPrice', 'BUTTON', 'toolbar', 1,
'{"label":"同步ERP采购价","type":"primary","action":"syncErpPrice","requiresRow":false,"refreshMode":"all"}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'formoney-manage', 'grid', 'GRID', 'root', 2, 'CostFormoney', '{"height":"100%","selectionMode":"single"}', 'system');

COMMIT;

-- =====================================================
-- 6. 页面规则配置
-- =====================================================

-- 列配置
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'formoney-manage', 'grid', 'COLUMN_OVERRIDE',
'[
  {"field":"id","visible":false,"editable":false},
  {"field":"fmopcode","width":null,"editable":true,"searchable":true},
  {"field":"fmname","width":null,"editable":true,"searchable":true},
  {"field":"fmsign","width":null,"editable":true},
  {"field":"fmunit","width":null,"editable":true},
  {"field":"fmrate","width":null,"editable":true},
  {"field":"usestatus","width":null,"editable":true}
]', 'system');

-- 右键菜单
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'formoney-manage', 'grid', 'CONTEXT_MENU',
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
-- 7. 角色权限配置
-- =====================================================

-- ADMIN角色的外币管理页面权限
INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, CREATE_BY)
VALUES (SEQ_COST_ROLE_PAGE.NEXTVAL, 
    (SELECT ID FROM T_COST_ROLE WHERE ROLE_CODE = 'ADMIN'), 
    'formoney-manage', '["*"]', NULL, 'system');

COMMIT;
