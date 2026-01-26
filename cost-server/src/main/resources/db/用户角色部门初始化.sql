-- =====================================================
-- 用户、角色、部门 初始化脚本
-- =====================================================

-- =====================================================
-- 0. 清理旧数据
-- =====================================================

DELETE FROM T_COST_ROLE_PAGE;
DELETE FROM T_COST_USER_ROLE;
DELETE FROM T_COST_ROLE;
DELETE FROM T_COST_USER;
DELETE FROM T_COST_DEPARTMENT;
DELETE FROM T_COST_RESOURCE;
DELETE FROM T_COST_LOOKUP_CONFIG WHERE LOOKUP_CODE = 'department';
DELETE FROM T_COST_PAGE_RULE WHERE PAGE_CODE IN ('user-manage', 'dept-manage');
DELETE FROM T_COST_PAGE_COMPONENT WHERE PAGE_CODE IN ('user-manage', 'dept-manage');
DELETE FROM T_COST_COLUMN_METADATA WHERE TABLE_METADATA_ID IN (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE IN ('CostUser', 'CostDepartment'));
DELETE FROM T_COST_TABLE_METADATA WHERE TABLE_CODE IN ('CostUser', 'CostDepartment');

COMMIT;

-- =====================================================
-- 1. 菜单资源配置
-- =====================================================

-- 首页
INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'home', '首页', 'PAGE', 'home', 'mdi:monitor-dashboard', '/home', NULL, 0, 'system');

-- 系统管理目录
INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'system', '系统管理', 'DIRECTORY', NULL, 'mdi:cog', '/system', NULL, 99, 'system');

-- 系统管理子菜单
DECLARE
    v_system_id NUMBER;
BEGIN
    SELECT ID INTO v_system_id FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'system';
    
    -- 人员管理
    INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
    VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'user', '人员管理', 'PAGE', 'user-manage', 'mdi:account-group', '/system/user', v_system_id, 1, 'system');
    
    -- 部门管理
    INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
    VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'dept', '部门管理', 'PAGE', 'dept-manage', 'mdi:domain', '/system/dept', v_system_id, 3, 'system');
END;
/

COMMIT;

-- =====================================================
-- 2. 视图定义
-- =====================================================

-- 用户视图（包含部门名称）
CREATE OR REPLACE VIEW V_COST_USER AS
SELECT 
    u.ID,
    u.USERNAME,
    u.PASSWORD,
    u.REAL_NAME,
    u.EMAIL,
    u.PHONE,
    u.DEPARTMENT_ID,
    d.DEPT_NAME,
    u.STATUS,
    u.DELETED,
    u.CREATE_BY,
    u.CREATE_TIME,
    u.UPDATE_BY,
    u.UPDATE_TIME
FROM T_COST_USER u
LEFT JOIN T_COST_DEPARTMENT d ON u.DEPARTMENT_ID = d.ID
WHERE u.DELETED = 0;

-- =====================================================
-- 3. 初始化管理员用户
-- =====================================================

INSERT INTO T_COST_USER (ID, USERNAME, PASSWORD, REAL_NAME, DEPARTMENT_ID, CREATE_BY)
VALUES (SEQ_COST_USER.NEXTVAL, 'admin', '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iKt6Z5EH', '系统管理员', 1, 'system');

COMMIT;

-- =====================================================
-- 4. 数据同步（从 ERP 同步）
-- =====================================================

-- 同步部门数据
MERGE INTO T_COST_DEPARTMENT t
USING (
    SELECT deptid AS ID, deptname AS DEPT_NAME FROM hy.t_dept
) s
ON (t.ID = s.ID)
WHEN MATCHED THEN
    UPDATE SET t.DEPT_NAME = s.DEPT_NAME, t.UPDATE_TIME = SYSTIMESTAMP
WHEN NOT MATCHED THEN
    INSERT (ID, DEPT_CODE, DEPT_NAME, CREATE_BY, CREATE_TIME)
    VALUES (s.ID, 'DEPT_' || s.ID, s.DEPT_NAME, 'sync', SYSTIMESTAMP);

-- 同步用户数据
MERGE INTO T_COST_USER t
USING (
    SELECT opcode AS USERNAME, username AS REAL_NAME, deptid AS DEPARTMENT_ID FROM hy.t_user
) s
ON (t.USERNAME = s.USERNAME)
WHEN MATCHED THEN
    UPDATE SET t.REAL_NAME = s.REAL_NAME, t.DEPARTMENT_ID = s.DEPARTMENT_ID, t.UPDATE_TIME = SYSTIMESTAMP
WHEN NOT MATCHED THEN
    INSERT (ID, USERNAME, PASSWORD, REAL_NAME, DEPARTMENT_ID, STATUS, CREATE_BY, CREATE_TIME)
    VALUES (SEQ_COST_USER.NEXTVAL, s.USERNAME, 'default', s.REAL_NAME, s.DEPARTMENT_ID, 'ACTIVE', 'sync', SYSTIMESTAMP);

COMMIT;

-- =====================================================
-- 5. 表元数据配置
-- =====================================================

-- 用户表元数据
INSERT INTO T_COST_TABLE_METADATA (
    ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, 
    SEQUENCE_NAME, PK_COLUMN, CREATE_BY
) VALUES (
    SEQ_COST_TABLE_METADATA.NEXTVAL,
    'CostUser', '用户管理',
    'V_COST_USER', 'T_COST_USER',
    'SEQ_COST_USER', 'ID', 'system'
);

-- 部门表元数据
INSERT INTO T_COST_TABLE_METADATA (
    ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, 
    SEQUENCE_NAME, PK_COLUMN, CREATE_BY
) VALUES (
    SEQ_COST_TABLE_METADATA.NEXTVAL,
    'CostDepartment', '部门管理',
    'T_COST_DEPARTMENT', 'T_COST_DEPARTMENT',
    'SEQ_COST_DEPARTMENT', 'ID', 'system'
);

COMMIT;

-- =====================================================
-- 6. 列元数据配置
-- =====================================================

-- 用户表列元数据
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostUser'), 'id', 'ID', 'ID', 'number', 1, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostUser'), 'username', 'USERNAME', '用户名', 'text', 2, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostUser'), 'realName', 'REAL_NAME', '姓名', 'text', 3, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostUser'), 'email', 'EMAIL', '邮箱', 'text', 4, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostUser'), 'phone', 'PHONE', '电话', 'text', 5, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostUser'), 'departmentId', 'DEPARTMENT_ID', '部门ID', 'number', 6, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, IS_VIRTUAL, CREATE_BY)
VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostUser'), 'deptName', 'DEPT_NAME', '部门名称', 'text', 7, 1, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, IS_VIRTUAL, CREATE_BY)
VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostUser'), 'status', 'STATUS', '状态', 'text', 8, 0, 'system');

-- 部门表列元数据
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostDepartment'), 'id', 'ID', 'ID', 'number', 1, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostDepartment'), 'deptCode', 'DEPT_CODE', '部门编码', 'text', 2, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostDepartment'), 'deptName', 'DEPT_NAME', '部门名称', 'text', 3, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostDepartment'), 'parentId', 'PARENT_ID', '上级部门ID', 'number', 4, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY)
VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostDepartment'), 'sortOrder', 'SORT_ORDER', '排序', 'number', 5, 'system');

COMMIT;

-- =====================================================
-- 7. 页面组件配置
-- =====================================================

-- 用户管理页面
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, REF_TABLE_CODE, SORT_ORDER, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'user-manage', 'masterGrid', 'GRID', 'CostUser', 0, 'system');

-- 部门管理页面
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, REF_TABLE_CODE, SORT_ORDER, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'dept-manage', 'masterGrid', 'GRID', 'CostDepartment', 0, 'system');

COMMIT;

-- =====================================================
-- 8. 页面规则配置
-- =====================================================

-- 用户管理：列配置
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (
    SEQ_COST_PAGE_RULE.NEXTVAL,
    'user-manage',
    'masterGrid',
    'COLUMN_OVERRIDE',
    '[
        {"field":"id","visible":false,"editable":false},
        {"field":"username","editable":true},
        {"field":"realName","editable":true},
        {"field":"email","editable":true},
        {"field":"phone","editable":true},
        {"field":"departmentId","visible":false,"editable":false},
        {"field":"deptName","editable":false},
        {"field":"status","editable":true}
    ]',
    'system'
);

-- 用户管理：Lookup 配置（部门选择弹窗）
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (
    SEQ_COST_PAGE_RULE.NEXTVAL,
    'user-manage',
    'masterGrid',
    'LOOKUP',
    '[
        {"field":"deptName","lookupCode":"department","mapping":{"departmentId":"id","deptName":"deptName"}}
    ]',
    'system'
);

-- 用户管理：右键菜单
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (
    SEQ_COST_PAGE_RULE.NEXTVAL,
    'user-manage',
    'masterGrid',
    'CONTEXT_MENU',
    '{"items":[{"action":"addRow"},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"save"}]}',
    'system'
);

-- 部门管理：列配置
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (
    SEQ_COST_PAGE_RULE.NEXTVAL,
    'dept-manage',
    'masterGrid',
    'COLUMN_OVERRIDE',
    '[
        {"field":"id","visible":false,"editable":false},
        {"field":"deptCode","editable":true},
        {"field":"deptName","editable":true},
        {"field":"parentId","editable":true},
        {"field":"sortOrder","editable":true}
    ]',
    'system'
);

-- 部门管理：右键菜单
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (
    SEQ_COST_PAGE_RULE.NEXTVAL,
    'dept-manage',
    'masterGrid',
    'CONTEXT_MENU',
    '{"items":[{"action":"addRow"},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"save"}]}',
    'system'
);

COMMIT;

-- =====================================================
-- 9. Lookup 配置（部门选择弹窗）
-- =====================================================

INSERT INTO T_COST_LOOKUP_CONFIG (
    ID, LOOKUP_CODE, LOOKUP_NAME, DATA_SOURCE, 
    DISPLAY_COLUMNS, SEARCH_COLUMNS, VALUE_FIELD, LABEL_FIELD, CREATE_BY
) VALUES (
    SEQ_COST_LOOKUP_CONFIG.NEXTVAL,
    'department',
    '部门选择',
    'CostDepartment',
    '[{"field":"deptCode","header":"部门编码","width":120},{"field":"deptName","header":"部门名称","width":200}]',
    '["deptCode","deptName"]',
    'id',
    'deptName',
    'system'
);

COMMIT;

-- =====================================================
-- 10. 角色和权限配置
-- =====================================================

-- 创建管理员角色
INSERT INTO T_COST_ROLE (ID, ROLE_CODE, ROLE_NAME, DESCRIPTION, CREATE_BY)
VALUES (SEQ_COST_ROLE.NEXTVAL, 'ADMIN', '系统管理员', '拥有所有权限', 'system');

-- 关联 admin 用户到管理员角色
INSERT INTO T_COST_USER_ROLE (ID, USER_ID, ROLE_ID, CREATE_BY) 
VALUES (SEQ_COST_USER_ROLE.NEXTVAL, 
    (SELECT ID FROM T_COST_USER WHERE USERNAME = 'admin'), 
    (SELECT ID FROM T_COST_ROLE WHERE ROLE_CODE = 'ADMIN'), 
    'system');

-- 管理员角色的页面权限
INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, CREATE_BY)
VALUES (SEQ_COST_ROLE_PAGE.NEXTVAL, 
    (SELECT ID FROM T_COST_ROLE WHERE ROLE_CODE = 'ADMIN'), 
    'home', '["*"]', NULL, 'system');

INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, CREATE_BY)
VALUES (SEQ_COST_ROLE_PAGE.NEXTVAL, 
    (SELECT ID FROM T_COST_ROLE WHERE ROLE_CODE = 'ADMIN'), 
    'user-manage', '["*"]', NULL, 'system');

INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, CREATE_BY)
VALUES (SEQ_COST_ROLE_PAGE.NEXTVAL, 
    (SELECT ID FROM T_COST_ROLE WHERE ROLE_CODE = 'ADMIN'), 
    'dept-manage', '["*"]', NULL, 'system');

COMMIT;
