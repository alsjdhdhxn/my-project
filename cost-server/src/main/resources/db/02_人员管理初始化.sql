-- =====================================================
-- 人员管理初始化脚本
-- 用途：初始化人员管理页面的元数据和业务数据（先删后插）
-- 页面编码：user-manage
-- 表编码：CostUser
-- 导出时间: 2026-02-05
-- 注意：密码为BCrypt加密后的值，默认密码为admin
-- =====================================================

-- =====================================================
-- 1. 表元数据 (T_COST_TABLE_METADATA)
-- =====================================================
DELETE FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostUser';

INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, PARENT_TABLE_CODE, PARENT_FK_COLUMN, AUDIT_ENABLED, VALIDATION_RULES, ACTION_RULES, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) 
VALUES (5, 'CostUser', '用户管理', 'V_COST_USER', 'T_COST_USER', 'SEQ_COST_USER', 'ID', NULL, NULL, 0, NULL, NULL, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);

-- =====================================================
-- 2. 列元数据 (T_COST_COLUMN_METADATA)
-- =====================================================
DELETE FROM T_COST_COLUMN_METADATA WHERE TABLE_METADATA_ID = 5;

INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DICT_TYPE, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) 
VALUES (27, 5, 'id', 'ID', NULL, NULL, 'ID', 'number', 1, 1, 1, 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);

INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DICT_TYPE, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) 
VALUES (28, 5, 'username', 'USERNAME', NULL, NULL, '用户名', 'text', 2, 1, 1, 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);

INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DICT_TYPE, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) 
VALUES (29, 5, 'realName', 'REAL_NAME', NULL, NULL, '姓名', 'text', 3, 1, 1, 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);

INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DICT_TYPE, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) 
VALUES (30, 5, 'email', 'EMAIL', NULL, NULL, '邮箱', 'text', 4, 1, 1, 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);

INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DICT_TYPE, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) 
VALUES (31, 5, 'phone', 'PHONE', NULL, NULL, '电话', 'text', 5, 1, 1, 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);

INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DICT_TYPE, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) 
VALUES (32, 5, 'departmentId', 'DEPARTMENT_ID', NULL, NULL, '部门ID', 'number', 6, 1, 1, 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);

INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DICT_TYPE, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) 
VALUES (33, 5, 'deptName', 'DEPT_NAME', NULL, NULL, '部门名称', 'text', 7, 1, 1, 1, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);

INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DICT_TYPE, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) 
VALUES (34, 5, 'status', 'STATUS', NULL, NULL, '状态', 'text', 8, 1, 1, 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);


-- =====================================================
-- 3. 页面组件 (T_COST_PAGE_COMPONENT)
-- =====================================================
DELETE FROM T_COST_PAGE_COMPONENT WHERE PAGE_CODE = 'user-manage';

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SLOT_NAME, SORT_ORDER, DELETED, DESCRIPTION, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) 
VALUES (5, 'user-manage', 'masterGrid', 'GRID', NULL, '{"buttons":[{"action":"addRow","label":"新增"},{"action":"deleteRow","label":"删除","requiresRow":true},{"action":"resetPassword","label":"初始化密码","position":"toolbar","requiresRow":true,"method":"userService.resetPassword"},{"action":"save","label":"保存"}]}', 'CostUser', NULL, 0, 0, NULL, SYSDATE, SYSDATE, 'system', NULL);

-- =====================================================
-- 4. 页面规则 (T_COST_PAGE_RULE)
-- =====================================================
DELETE FROM T_COST_PAGE_RULE WHERE PAGE_CODE = 'user-manage';

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) 
VALUES (11, 'user-manage', 'masterGrid', 'COLUMN_OVERRIDE', '[
        {"field":"id","visible":false,"editable":false},
        {"field":"username","editable":true},
        {"field":"realName","editable":true},
        {"field":"email","editable":true},
        {"field":"phone","editable":true},
        {"field":"departmentId","visible":false,"editable":false},
        {"field":"deptName","editable":false},
        {"field":"status","editable":true}
    ]', 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) 
VALUES (12, 'user-manage', 'masterGrid', 'LOOKUP', '[
        {"field":"deptName","lookupCode":"department","mapping":{"departmentId":"id","deptName":"deptName"}}
    ]', 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);
