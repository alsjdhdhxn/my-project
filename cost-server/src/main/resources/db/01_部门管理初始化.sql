-- =====================================================
-- 部门管理初始化脚本
-- 用途：初始化部门管理页面的元数据和业务数据（先删后插）
-- 页面编码：dept-manage
-- 表编码：CostDepartment
-- 导出时间: 2026-02-05
-- =====================================================

-- =====================================================
-- 1. 表元数据 (T_COST_TABLE_METADATA)
-- =====================================================
DELETE FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostDepartment';

INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, PARENT_TABLE_CODE, PARENT_FK_COLUMN, AUDIT_ENABLED, VALIDATION_RULES, ACTION_RULES, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) 
VALUES (6, 'CostDepartment', '部门管理', 'T_COST_DEPARTMENT', 'T_COST_DEPARTMENT', 'SEQ_COST_DEPARTMENT', 'ID', NULL, NULL, 0, NULL, NULL, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);

-- =====================================================
-- 2. 列元数据 (T_COST_COLUMN_METADATA)
-- =====================================================
DELETE FROM T_COST_COLUMN_METADATA WHERE TABLE_METADATA_ID = 6;

INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DICT_TYPE, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) 
VALUES (35, 6, 'id', 'ID', NULL, NULL, 'ID', 'number', 1, 1, 1, 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);

INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DICT_TYPE, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) 
VALUES (36, 6, 'deptCode', 'DEPT_CODE', NULL, NULL, '部门编码', 'text', 2, 1, 1, 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);

INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DICT_TYPE, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) 
VALUES (37, 6, 'deptName', 'DEPT_NAME', NULL, NULL, '部门名称', 'text', 3, 1, 1, 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);

INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DICT_TYPE, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) 
VALUES (38, 6, 'parentId', 'PARENT_ID', NULL, NULL, '上级部门ID', 'number', 4, 1, 1, 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);

INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DICT_TYPE, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) 
VALUES (39, 6, 'sortOrder', 'SORT_ORDER', NULL, NULL, '排序', 'number', 5, 1, 1, 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);

-- =====================================================
-- 3. 页面组件 (T_COST_PAGE_COMPONENT)
-- =====================================================
DELETE FROM T_COST_PAGE_COMPONENT WHERE PAGE_CODE = 'dept-manage';

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SLOT_NAME, SORT_ORDER, DELETED, DESCRIPTION, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) 
VALUES (6, 'dept-manage', 'masterGrid', 'GRID', NULL, '{"buttons":[{"action":"addRow","label":"新增"},{"action":"deleteRow","label":"删除","requiresRow":true},{"action":"save","label":"保存"}]}', 'CostDepartment', NULL, 0, 0, NULL, SYSDATE, SYSDATE, 'system', NULL);

-- =====================================================
-- 4. 页面规则 (T_COST_PAGE_RULE)
-- =====================================================
DELETE FROM T_COST_PAGE_RULE WHERE PAGE_CODE = 'dept-manage';

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) 
VALUES (14, 'dept-manage', 'masterGrid', 'COLUMN_OVERRIDE', '[
        {"field":"id","visible":false,"editable":false},
        {"field":"deptCode","editable":true},
        {"field":"deptName","editable":true},
        {"field":"parentId","editable":true},
        {"field":"sortOrder","editable":true}
    ]', 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);

-- =====================================================
-- 5. Lookup配置 (T_COST_LOOKUP_CONFIG)
-- 注意：department Lookup 被 user-manage 页面引用
-- =====================================================
DELETE FROM T_COST_LOOKUP_CONFIG WHERE LOOKUP_CODE = 'department';

INSERT INTO T_COST_LOOKUP_CONFIG (ID, LOOKUP_CODE, LOOKUP_NAME, DATA_SOURCE, DISPLAY_COLUMNS, VALUE_FIELD, LABEL_FIELD, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) 
VALUES (3, 'department', '部门选择', 'T_COST_DEPARTMENT', '[{"field":"deptCode","header":"部门编码","width":120},{"field":"deptName","header":"部门名称","width":200}]', 'id', 'deptName', 0, SYSDATE, SYSDATE, 'system', NULL);
