-- =====================================================
-- 客户信息管理 初始化脚本
-- =====================================================
-- 数据来源：通过定时任务从ERP同步（PUB_CUSTOMER、BMS_TR_POS_DEF）
-- =====================================================

-- =====================================================
-- 0. 清理旧数据
-- =====================================================

DELETE FROM T_COST_ROLE_PAGE WHERE PAGE_CODE = 'customer-manage';
DELETE FROM T_COST_PAGE_RULE WHERE PAGE_CODE = 'customer-manage';
DELETE FROM T_COST_PAGE_COMPONENT WHERE PAGE_CODE = 'customer-manage';
DELETE FROM T_COST_COLUMN_METADATA WHERE TABLE_METADATA_ID IN (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE IN ('CostCustomer', 'CostTranposer'));
DELETE FROM T_COST_TABLE_METADATA WHERE TABLE_CODE IN ('CostCustomer', 'CostTranposer');
DELETE FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'customer';

COMMIT;

-- =====================================================
-- 1. 表结构
-- =====================================================

-- 客户信息
CREATE TABLE T_COST_CUSTOMER (
    CUSTOMID    NUMBER(19) PRIMARY KEY,
    ZONE        VARCHAR2(500),
    CUSTOMNAME  VARCHAR2(500),
    ISERP       NUMBER(1)   DEFAULT 0,
    DELETED     NUMBER(1)   DEFAULT 0,
    CREATE_TIME TIMESTAMP  DEFAULT SYSTIMESTAMP,
    UPDATE_TIME TIMESTAMP  DEFAULT SYSTIMESTAMP,
    CREATE_BY   VARCHAR2(64),
    UPDATE_BY   VARCHAR2(64)
);

CREATE SEQUENCE SEQ_COST_CUSTOMER START WITH 1 INCREMENT BY 1;

-- 分销商信息
CREATE TABLE T_COST_TRANPOSER (
    TRANPOSID    NUMBER(19) PRIMARY KEY,
    CUSTOMID     NUMBER(19),
    TRANPOSNAME  VARCHAR2(500),
    ISERP        NUMBER(1)   DEFAULT 0,
    DELETED      NUMBER(1)   DEFAULT 0,
    CREATE_TIME  TIMESTAMP  DEFAULT SYSTIMESTAMP,
    UPDATE_TIME  TIMESTAMP  DEFAULT SYSTIMESTAMP,
    CREATE_BY    VARCHAR2(64),
    UPDATE_BY    VARCHAR2(64)
);

CREATE SEQUENCE SEQ_COST_TRANPOSER START WITH 1 INCREMENT BY 1;

-- =====================================================
-- 1.1 初始化数据（从ERP同步）
-- =====================================================

-- 同步客户数据
MERGE INTO T_COST_CUSTOMER t
USING (
    SELECT CUSTOMID, CUSTOMNAME, ZONE FROM PUB_CUSTOMER@hyerp
) s
ON (t.CUSTOMID = s.CUSTOMID)
WHEN MATCHED THEN
    UPDATE SET t.CUSTOMNAME = s.CUSTOMNAME, t.ZONE = s.ZONE, 
               t.UPDATE_TIME = SYSTIMESTAMP, t.ISERP = 1, t.DELETED = 0
WHEN NOT MATCHED THEN
    INSERT (CUSTOMID, CUSTOMNAME, ZONE, ISERP, DELETED, CREATE_BY, CREATE_TIME)
    VALUES (s.CUSTOMID, s.CUSTOMNAME, s.ZONE, 1, 0, 'sync', SYSTIMESTAMP);

-- 同步分销商数据
MERGE INTO T_COST_TRANPOSER t
USING (
    SELECT TRANPOSID, COMPANYID AS CUSTOMID, TRANPOSNAME FROM BMS_TR_POS_DEF@hyerp
) s
ON (t.TRANPOSID = s.TRANPOSID)
WHEN MATCHED THEN
    UPDATE SET t.CUSTOMID = s.CUSTOMID, t.TRANPOSNAME = s.TRANPOSNAME,
               t.UPDATE_TIME = SYSTIMESTAMP, t.ISERP = 1, t.DELETED = 0
WHEN NOT MATCHED THEN
    INSERT (TRANPOSID, CUSTOMID, TRANPOSNAME, ISERP, DELETED, CREATE_BY, CREATE_TIME)
    VALUES (s.TRANPOSID, s.CUSTOMID, s.TRANPOSNAME, 1, 0, 'sync', SYSTIMESTAMP);

COMMIT;

-- =====================================================
-- 1.2 同步存储过程和定时任务
-- =====================================================

-- 同步客户和分销商数据的存储过程
CREATE OR REPLACE PROCEDURE PROC_SYNC_CUSTOMER AS
BEGIN
    -- 同步客户数据
    MERGE INTO T_COST_CUSTOMER t
    USING (
        SELECT CUSTOMID, CUSTOMNAME, ZONE FROM PUB_CUSTOMER@hyerp
    ) s
    ON (t.CUSTOMID = s.CUSTOMID)
    WHEN MATCHED THEN
        UPDATE SET t.CUSTOMNAME = s.CUSTOMNAME, t.ZONE = s.ZONE, 
                   t.UPDATE_TIME = SYSTIMESTAMP, t.ISERP = 1, t.DELETED = 0
    WHEN NOT MATCHED THEN
        INSERT (CUSTOMID, CUSTOMNAME, ZONE, ISERP, DELETED, CREATE_BY, CREATE_TIME)
        VALUES (s.CUSTOMID, s.CUSTOMNAME, s.ZONE, 1, 0, 'sync', SYSTIMESTAMP);

    -- 同步分销商数据
    MERGE INTO T_COST_TRANPOSER t
    USING (
        SELECT TRANPOSID, COMPANYID AS CUSTOMID, TRANPOSNAME FROM BMS_TR_POS_DEF@hyerp
    ) s
    ON (t.TRANPOSID = s.TRANPOSID)
    WHEN MATCHED THEN
        UPDATE SET t.CUSTOMID = s.CUSTOMID, t.TRANPOSNAME = s.TRANPOSNAME,
                   t.UPDATE_TIME = SYSTIMESTAMP, t.ISERP = 1, t.DELETED = 0
    WHEN NOT MATCHED THEN
        INSERT (TRANPOSID, CUSTOMID, TRANPOSNAME, ISERP, DELETED, CREATE_BY, CREATE_TIME)
        VALUES (s.TRANPOSID, s.CUSTOMID, s.TRANPOSNAME, 1, 0, 'sync', SYSTIMESTAMP);

    COMMIT;
END;
/

-- 创建定时任务（每5分钟执行一次）
BEGIN
    -- 先删除已存在的任务
    BEGIN
        DBMS_SCHEDULER.DROP_JOB(job_name => 'JOB_SYNC_CUSTOMER', force => TRUE);
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;
    
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_SYNC_CUSTOMER',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'PROC_SYNC_CUSTOMER',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=MINUTELY;INTERVAL=5',
        enabled         => TRUE,
        auto_drop       => FALSE,
        comments        => '每5分钟同步客户和分销商数据'
    );
END;
/

-- =====================================================
-- 2. 视图定义
-- =====================================================

-- 客户视图（直接查本地表）
CREATE OR REPLACE VIEW T_COST_CUSTOMER_V AS
SELECT CUSTOMID,
       CUSTOMNAME,
       ZONE,
       ISERP,
       DELETED,
       CREATE_TIME,
       UPDATE_TIME,
       CREATE_BY,
       UPDATE_BY
  FROM T_COST_CUSTOMER
 WHERE DELETED = 0;

-- 分销商视图（直接查本地表）
CREATE OR REPLACE VIEW T_COST_TRANPOSER_V AS
SELECT CUSTOMID,
       TRANPOSID,
       TRANPOSNAME,
       ISERP,
       DELETED,
       CREATE_TIME,
       UPDATE_TIME,
       CREATE_BY,
       UPDATE_BY
  FROM T_COST_TRANPOSER 
 WHERE DELETED = 0;

-- =====================================================
-- 3. 菜单资源配置
-- =====================================================

DECLARE
    v_cost_id NUMBER;
BEGIN
    SELECT ID INTO v_cost_id FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'cost';
    
    INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
    VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'customer', '客户信息', 'PAGE', 'customer-manage', 'mdi:account-box', '/cost/customer', v_cost_id, 3, 'system');
END;
/

COMMIT;

-- =====================================================
-- 4. 表元数据配置
-- =====================================================

-- 客户主表元数据
DECLARE
    v_customer_main_id NUMBER;
BEGIN
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_customer_main_id FROM DUAL;

    INSERT INTO T_COST_TABLE_METADATA
        (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, CREATE_BY)
    VALUES
        (v_customer_main_id, 'CostCustomer', '客户信息', 'T_COST_CUSTOMER_V', 'T_COST_CUSTOMER', 'SEQ_COST_CUSTOMER', 'CUSTOMID', 'system');

    -- 列元数据
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_customer_main_id, 'id', 'CUSTOMID', '客户ID', 'number', 0, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_customer_main_id, 'customname', 'CUSTOMNAME', '客户名称', 'text', 1, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_customer_main_id, 'zone', 'ZONE', '区域', 'text', 2, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, IS_VIRTUAL, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_customer_main_id, 'iserp', 'ISERP', '是否ERP', 'number', 99, 1, 'system');

    COMMIT;
END;
/

-- 分销商从表元数据
DECLARE
    v_tranposer_id NUMBER;
BEGIN
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_tranposer_id FROM DUAL;

    INSERT INTO T_COST_TABLE_METADATA
        (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, PARENT_TABLE_CODE, PARENT_FK_COLUMN, CREATE_BY)
    VALUES
        (v_tranposer_id, 'CostTranposer', '分销商信息', 'T_COST_TRANPOSER_V', 'T_COST_TRANPOSER', 'SEQ_COST_TRANPOSER', 'TRANPOSID', 'CostCustomer', 'CUSTOMID', 'system');

    -- 列元数据
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_tranposer_id, 'id', 'TRANPOSID', '分销商ID', 'number', 0, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_tranposer_id, 'customid', 'CUSTOMID', '客户ID', 'number', 1, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_tranposer_id, 'tranposname', 'TRANPOSNAME', '分销商名称', 'text', 2, 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, IS_VIRTUAL, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_tranposer_id, 'iserp', 'ISERP', '是否ERP', 'number', 99, 1, 'system');

    COMMIT;
END;
/

-- =====================================================
-- 5. 页面组件配置
-- =====================================================

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'customer-manage', 'root', 'LAYOUT', NULL, 0, '{"direction":"vertical","gap":8}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'customer-manage', 'masterGrid', 'GRID', 'root', 1, 'CostCustomer', '{"height":"50%","selectionMode":"single"}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'customer-manage', 'detailTabs', 'TABS', 'root', 2,
'{"mode":"single","tabs":[{"key":"tranposer","title":"分销商","tableCode":"CostTranposer"}]}', 'system');

COMMIT;

-- =====================================================
-- 6. 页面规则配置
-- =====================================================

-- 主从关系
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'customer-manage', 'detailTabs', 'RELATION',
'{"masterKey":"masterGrid","detailKey":"detailTabs"}', 'system');

-- 主表列配置
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'customer-manage', 'masterGrid', 'COLUMN_OVERRIDE',
'[
  {"field":"id","width":null,"editable":true},
  {"field":"customname","width":null,"editable":true,"searchable":true},
  {"field":"zone","width":null,"editable":true},
  {"field":"iserp","visible":false}
]', 'system');

-- 从表列配置
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'customer-manage', 'tranposer', 'COLUMN_OVERRIDE',
'[
  {"field":"id","width":null,"editable":true},
  {"field":"customid","visible":false,"editable":false},
  {"field":"tranposname","width":null,"editable":true},
  {"field":"iserp","visible":false}
]', 'system');

-- 主表行样式
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'customer-manage', 'masterGrid', 'ROW_CLASS',
'[{"field":"iserp","operator":"eq","value":1,"className":"row-confirmed"}]', 'system');

-- 从表行样式
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'customer-manage', 'tranposer', 'ROW_CLASS',
'[{"field":"iserp","operator":"eq","value":1,"className":"row-confirmed"}]', 'system');

-- 主表右键菜单
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'customer-manage', 'masterGrid', 'CONTEXT_MENU',
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

-- 从表右键菜单
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'customer-manage', 'tranposer', 'CONTEXT_MENU',
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

INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, CREATE_BY)
VALUES (SEQ_COST_ROLE_PAGE.NEXTVAL, 
    (SELECT ID FROM T_COST_ROLE WHERE ROLE_CODE = 'ADMIN'), 
    'customer-manage', '["*"]', NULL, 'system');

COMMIT;
