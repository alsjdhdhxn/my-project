-- =====================================================
-- 外币汇率管理 初始化脚本
-- 执行顺序：删除表 -> 删除元数据 -> 建表 -> 插入元数据
-- =====================================================

-- =====================================================
-- A. 删除视图和表
-- =====================================================
BEGIN EXECUTE IMMEDIATE 'DROP VIEW T_COST_FORMONEY_V'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE T_COST_FORMONEY CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE SEQ_COST_FORMONEY'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- =====================================================
-- B. 删除元数据
-- =====================================================
DELETE FROM T_COST_ROLE_PAGE WHERE PAGE_CODE = 'formoney-manage';
DELETE FROM T_COST_PAGE_RULE WHERE PAGE_CODE = 'formoney-manage';
DELETE FROM T_COST_PAGE_COMPONENT WHERE PAGE_CODE = 'formoney-manage';
DELETE FROM T_COST_COLUMN_METADATA WHERE TABLE_METADATA_ID IN (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostFormoney');
DELETE FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostFormoney';
DELETE FROM T_COST_RESOURCE WHERE RESOURCE_CODE IN ('cost', 'formoney');
COMMIT;

-- =====================================================
-- C. 创建表结构
-- =====================================================
CREATE TABLE T_COST_FORMONEY (
    FMID        NUMBER(10)   NOT NULL,
    FMOPCODE    VARCHAR2(60),
    FMNAME      VARCHAR2(120),
    FMSIGN      VARCHAR2(60),
    FMUNIT      VARCHAR2(60),
    FMRATE      NUMBER(16,6),
    USESTATUS   NUMBER(2),
    DELETED     NUMBER(1) DEFAULT 0,
    CREATE_TIME TIMESTAMP DEFAULT SYSTIMESTAMP,
    UPDATE_TIME TIMESTAMP DEFAULT SYSTIMESTAMP,
    CREATE_BY   VARCHAR2(64),
    UPDATE_BY   VARCHAR2(64),
    CONSTRAINT PK_COST_FORMONEY PRIMARY KEY (FMID)
);

CREATE SEQUENCE SEQ_COST_FORMONEY START WITH 1 INCREMENT BY 1;
COMMIT;

-- =====================================================
-- D. 创建视图
-- =====================================================
CREATE OR REPLACE VIEW T_COST_FORMONEY_V AS
SELECT FMID, FMOPCODE, FMNAME, FMSIGN, FMUNIT, FMRATE, USESTATUS,
       DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY
  FROM T_COST_FORMONEY
 WHERE DELETED = 0 OR DELETED IS NULL;
COMMIT;


-- =====================================================
-- E. 插入表元数据
-- =====================================================
DECLARE
    v_formoney_id NUMBER;
BEGIN
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_formoney_id FROM DUAL;

    INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, ACTION_RULES, CREATE_BY)
    VALUES (v_formoney_id, 'CostFormoney', '外币管理', 'T_COST_FORMONEY_V', 'T_COST_FORMONEY', 'SEQ_COST_FORMONEY', 'FMID', 
    '[{"order":1,"code":"SYNC_ERP_RATE","name":"同步ERP汇率","group":"toolbar","enabled":true,"type":"sql","sql":"UPDATE T_COST_FORMONEY SET FMRATE = NULL, CREATE_TIME = NULL, UPDATE_TIME = NULL WHERE CREATE_BY = ''system''"}]',
    'system');

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
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_formoney_id, 'fmrate', 'FMRATE', '汇率', 'number', 5, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_formoney_id, 'usestatus', 'USESTATUS', '使用状态', 'number', 6, 'system');

    COMMIT;
END;
/

-- =====================================================
-- F. 插入页面规则
-- =====================================================
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'formoney-manage', 'grid', 'COLUMN_OVERRIDE',
'[{"field":"id","visible":false,"editable":false},{"field":"fmopcode","width":null,"editable":true,"searchable":true},{"field":"fmname","width":null,"editable":true,"searchable":true},{"field":"fmsign","width":null,"editable":true},{"field":"fmunit","width":null,"editable":true},{"field":"fmrate","width":null,"editable":true},{"field":"usestatus","width":null,"editable":true}]', 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'formoney-manage', 'grid', 'CONTEXT_MENU',
'{"items":[{"action":"addRow"},{"action":"copyRow","requiresRow":true},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"saveGridConfig"},{"type":"separator"},{"label":"导出","items":[{"action":"exportSelected","requiresSelection":true},{"action":"exportCurrent"},{"action":"exportAll"},{"type":"separator"},{"action":"resetExportConfig"},{"action":"openHeaderConfig"}]},{"type":"separator"},{"action":"save"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}', 'system');

COMMIT;

-- =====================================================
-- G. 插入页面组件
-- =====================================================
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'formoney-manage', 'root', 'LAYOUT', NULL, 0, '{"direction":"vertical","gap":8}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'formoney-manage', 'toolbar', 'LAYOUT', 'root', 0, '{"direction":"horizontal","gap":8}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'formoney-manage', 'syncBtn', 'BUTTON', 'toolbar', 1, 'CostFormoney', '{"label":"同步ERP汇率","type":"primary","action":"SYNC_ERP_RATE"}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'formoney-manage', 'grid', 'GRID', 'root', 1, 'CostFormoney', '{"height":"100%","selectionMode":"single"}', 'system');

COMMIT;

-- =====================================================
-- H. 插入菜单资源
-- =====================================================
INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'cost', '成本管理', 'DIRECTORY', NULL, 'mdi:currency-usd', '/cost', NULL, 1, 'system');

DECLARE
    v_cost_id NUMBER;
BEGIN
    SELECT ID INTO v_cost_id FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'cost';
    INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
    VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'formoney', '外币管理', 'PAGE', 'formoney-manage', 'mdi:currency-usd', '/cost/formoney', v_cost_id, 10, 'system');
    COMMIT;
END;
/

-- =====================================================
-- I. 角色权限配置
-- =====================================================
INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, CREATE_BY)
VALUES (SEQ_COST_ROLE_PAGE.NEXTVAL, 
    (SELECT ID FROM T_COST_ROLE WHERE ROLE_CODE = 'ADMIN'), 
    'formoney-manage', '["*"]', NULL, 'system');

COMMIT;

-- =====================================================
-- J. 导入业务数据（从ERP同步）
-- =====================================================
INSERT INTO T_COST_FORMONEY (FMID, FMOPCODE, FMNAME, FMSIGN, FMUNIT, FMRATE, USESTATUS, DELETED, CREATE_BY, CREATE_TIME)
SELECT fmid, fmopcode, fmname, fmsign, fmunit, fmrate, usestatus, 0, 'system', SYSTIMESTAMP
FROM pub_formoney_v@hyerp;

COMMIT;
