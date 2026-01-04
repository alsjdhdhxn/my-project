-- =====================================================
-- 人员管理页面配置
-- =====================================================

-- =====================================================
-- 1. 菜单资源（放在成本管理下面，新建系统管理目录）
-- =====================================================
-- 系统管理目录
INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'system', '系统管理', 'DIRECTORY', NULL, 'mdi:cog', '/system', NULL, 99, 'system');

-- 人员管理菜单
DECLARE
    v_parent_id NUMBER;
BEGIN
    SELECT ID INTO v_parent_id FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'system';
    INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
    VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'user', '人员管理', 'PAGE', 'user-manage', 'mdi:account-group', '/system/user', v_parent_id, 1, 'system');
END;
/

-- =====================================================
-- 2. 表元数据（基于 T_COST_USER）
-- =====================================================
DECLARE
    v_user_id NUMBER;
BEGIN
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_user_id FROM DUAL;
    INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, CREATE_BY)
    VALUES (v_user_id, 'CostUser', '用户', 'V_COST_USER', 'T_COST_USER', 'SEQ_COST_USER', 'ID', 'system');
    
    -- 列元数据
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, VISIBLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_user_id, 'id', 'ID', 'ID', 'number', 0, 0, 0, 80, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, SEARCHABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_user_id, 'username', 'USERNAME', '用户名', 'text', 1, 1, 1, 120, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, SEARCHABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_user_id, 'realName', 'REAL_NAME', '姓名', 'text', 2, 1, 1, 100, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_user_id, 'email', 'EMAIL', '邮箱', 'text', 3, 1, 150, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_user_id, 'phone', 'PHONE', '手机号', 'text', 4, 1, 120, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_user_id, 'deptName', 'DEPT_NAME', '部门', 'text', 5, 0, 120, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_user_id, 'status', 'STATUS', '状态', 'select', 6, 1, 80, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_user_id, 'createTime', 'CREATE_TIME', '创建时间', 'datetime', 7, 0, 160, 'system');

    COMMIT;
END;
/

-- =====================================================
-- 3. 页面组件配置（单表 GRID）
-- =====================================================
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'user-manage', 'root', 'LAYOUT', NULL, 0, '{"direction":"vertical","gap":8}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'user-manage', 'masterGrid', 'GRID', 'root', 1, 'CostUser', '{"height":"100%","selectionMode":"single"}', 'system');

COMMIT;

-- =====================================================
-- 4. 用户查询视图（关联部门名称）
-- =====================================================
CREATE OR REPLACE VIEW V_COST_USER AS
SELECT 
    u.ID,
    u.USERNAME,
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
LEFT JOIN T_COST_DEPARTMENT d ON u.DEPARTMENT_ID = d.ID AND d.DELETED = 0;

