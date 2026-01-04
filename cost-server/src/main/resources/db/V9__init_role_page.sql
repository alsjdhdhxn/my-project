-- =====================================================
-- 角色管理页面配置（主从：角色-用户）
-- =====================================================

-- =====================================================
-- 1. 菜单资源
-- =====================================================
DECLARE
    v_parent_id NUMBER;
BEGIN
    SELECT ID INTO v_parent_id FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'system';
    INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
    VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'role', '角色管理', 'PAGE', 'role-manage', 'mdi:shield-account', '/system/role', v_parent_id, 2, 'system');
END;
/

-- =====================================================
-- 2. 主表元数据（角色）
-- =====================================================
DECLARE
    v_role_id NUMBER;
BEGIN
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_role_id FROM DUAL;
    INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, CREATE_BY)
    VALUES (v_role_id, 'CostRole', '角色', 'T_COST_ROLE', 'T_COST_ROLE', 'SEQ_COST_ROLE', 'ID', 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, VISIBLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_role_id, 'id', 'ID', 'ID', 'number', 0, 0, 0, 80, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, SEARCHABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_role_id, 'roleCode', 'ROLE_CODE', '角色编码', 'text', 1, 1, 1, 120, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, SEARCHABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_role_id, 'roleName', 'ROLE_NAME', '角色名称', 'text', 2, 1, 1, 150, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_role_id, 'description', 'DESCRIPTION', '描述', 'text', 3, 1, 250, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_role_id, 'createTime', 'CREATE_TIME', '创建时间', 'datetime', 4, 0, 160, 'system');

    COMMIT;
END;
/

-- =====================================================
-- 3. 从表元数据（角色用户关联，关联用户信息）
-- =====================================================
DECLARE
    v_user_role_id NUMBER;
BEGIN
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_user_role_id FROM DUAL;
    INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, PARENT_TABLE_CODE, PARENT_FK_COLUMN, CREATE_BY)
    VALUES (v_user_role_id, 'CostUserRole', '角色用户', 'V_COST_USER_ROLE', 'T_COST_USER_ROLE', 'SEQ_COST_USER_ROLE', 'ID', 'CostRole', 'ROLE_ID', 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, VISIBLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_user_role_id, 'id', 'ID', 'ID', 'number', 0, 0, 0, 80, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, VISIBLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_user_role_id, 'roleId', 'ROLE_ID', '角色ID', 'number', 1, 0, 0, 80, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, VISIBLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_user_role_id, 'userId', 'USER_ID', '用户ID', 'number', 2, 0, 0, 80, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, SEARCHABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_user_role_id, 'username', 'USERNAME', '用户名', 'text', 3, 0, 1, 120, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, SEARCHABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_user_role_id, 'realName', 'REAL_NAME', '姓名', 'text', 4, 0, 1, 100, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_user_role_id, 'deptName', 'DEPT_NAME', '部门', 'text', 5, 0, 120, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_user_role_id, 'createTime', 'CREATE_TIME', '分配时间', 'datetime', 6, 0, 160, 'system');

    COMMIT;
END;
/

-- =====================================================
-- 4. 页面组件配置（主从布局）
-- =====================================================
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'role-manage', 'root', 'LAYOUT', NULL, 0, '{"direction":"vertical","gap":8}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'role-manage', 'masterGrid', 'GRID', 'root', 1, 'CostRole', '{"height":"50%","selectionMode":"single"}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'role-manage', 'detailTabs', 'TABS', 'root', 2, 'CostUserRole', 
'{
  "mode": "group",
  "tabs": [
    {"key": "users", "title": "角色用户", "columns": ["username", "realName", "deptName", "createTime"]}
  ]
}', 'system');

COMMIT;

-- =====================================================
-- 5. 角色用户视图（关联用户信息）
-- =====================================================
CREATE OR REPLACE VIEW V_COST_USER_ROLE AS
SELECT 
    ur.ID,
    ur.USER_ID,
    ur.ROLE_ID,
    u.USERNAME,
    u.REAL_NAME,
    d.DEPT_NAME,
    ur.DELETED,
    ur.CREATE_BY,
    ur.CREATE_TIME
FROM T_COST_USER_ROLE ur
LEFT JOIN T_COST_USER u ON ur.USER_ID = u.ID AND u.DELETED = 0
LEFT JOIN T_COST_DEPARTMENT d ON u.DEPARTMENT_ID = d.ID AND d.DELETED = 0;
