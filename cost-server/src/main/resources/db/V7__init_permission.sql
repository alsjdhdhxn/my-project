-- =====================================================
-- 用户/角色/菜单初始化
-- =====================================================

-- =====================================================
-- 1. 部门
-- =====================================================
INSERT INTO T_COST_DEPARTMENT (ID, DEPT_CODE, DEPT_NAME, PARENT_ID, SORT_ORDER, CREATE_BY)
VALUES (SEQ_COST_DEPARTMENT.NEXTVAL, 'ROOT', '总公司', NULL, 0, 'system');
INSERT INTO T_COST_DEPARTMENT (ID, DEPT_CODE, DEPT_NAME, PARENT_ID, SORT_ORDER, CREATE_BY)
VALUES (SEQ_COST_DEPARTMENT.NEXTVAL, 'FINANCE', '财务部', 1, 1, 'system');
INSERT INTO T_COST_DEPARTMENT (ID, DEPT_CODE, DEPT_NAME, PARENT_ID, SORT_ORDER, CREATE_BY)
VALUES (SEQ_COST_DEPARTMENT.NEXTVAL, 'PURCHASE', '采购部', 1, 2, 'system');

-- =====================================================
-- 2. 角色
-- =====================================================
INSERT INTO T_COST_ROLE (ID, ROLE_CODE, ROLE_NAME, DESCRIPTION, CREATE_BY)
VALUES (SEQ_COST_ROLE.NEXTVAL, 'ADMIN', '系统管理员', '拥有所有权限', 'system');
INSERT INTO T_COST_ROLE (ID, ROLE_CODE, ROLE_NAME, DESCRIPTION, CREATE_BY)
VALUES (SEQ_COST_ROLE.NEXTVAL, 'FINANCE_MANAGER', '财务经理', '财务部门管理权限', 'system');
INSERT INTO T_COST_ROLE (ID, ROLE_CODE, ROLE_NAME, DESCRIPTION, CREATE_BY)
VALUES (SEQ_COST_ROLE.NEXTVAL, 'FINANCE_STAFF', '财务专员', '财务部门普通权限', 'system');

-- =====================================================
-- 3. 用户 (密码: 123456)
-- =====================================================
INSERT INTO T_COST_USER (ID, USERNAME, PASSWORD, REAL_NAME, DEPARTMENT_ID, CREATE_BY)
VALUES (SEQ_COST_USER.NEXTVAL, 'admin', '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iKt6Z5EH', '系统管理员', 1, 'system');
INSERT INTO T_COST_USER (ID, USERNAME, PASSWORD, REAL_NAME, DEPARTMENT_ID, CREATE_BY)
VALUES (SEQ_COST_USER.NEXTVAL, 'zhangsan', '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iKt6Z5EH', '张三', 2, 'system');
INSERT INTO T_COST_USER (ID, USERNAME, PASSWORD, REAL_NAME, DEPARTMENT_ID, CREATE_BY)
VALUES (SEQ_COST_USER.NEXTVAL, 'lisi', '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iKt6Z5EH', '李四', 2, 'system');

-- =====================================================
-- 4. 用户角色关联
-- =====================================================
INSERT INTO T_COST_USER_ROLE (ID, USER_ID, ROLE_ID, CREATE_BY) VALUES (SEQ_COST_USER_ROLE.NEXTVAL, 1, 1, 'system');
INSERT INTO T_COST_USER_ROLE (ID, USER_ID, ROLE_ID, CREATE_BY) VALUES (SEQ_COST_USER_ROLE.NEXTVAL, 2, 2, 'system');
INSERT INTO T_COST_USER_ROLE (ID, USER_ID, ROLE_ID, CREATE_BY) VALUES (SEQ_COST_USER_ROLE.NEXTVAL, 3, 3, 'system');

-- =====================================================
-- 5. 角色页面权限
-- =====================================================
-- ADMIN: 所有权限
INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, CREATE_BY)
VALUES (SEQ_COST_ROLE_PAGE.NEXTVAL, 1, 'cost-eval', '["*"]', NULL, 'system');

-- FINANCE_MANAGER: 有增删改权限
INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, CREATE_BY)
VALUES (SEQ_COST_ROLE_PAGE.NEXTVAL, 2, 'cost-eval', '["CREATE","EDIT","DELETE","EXPORT"]', NULL, 'system');

-- FINANCE_STAFF: 只有查看和导出权限
INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, CREATE_BY)
VALUES (SEQ_COST_ROLE_PAGE.NEXTVAL, 3, 'cost-eval', '["EXPORT"]', NULL, 'system');

-- =====================================================
-- 6. 菜单资源
-- =====================================================
-- 首页
INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'home', '首页', 'PAGE', 'home', 'mdi:monitor-dashboard', '/home', NULL, 0, 'system');

-- 成本管理模块
INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'cost-management', '成本管理', 'DIRECTORY', NULL, 'mdi:currency-usd', NULL, NULL, 1, 'system');

-- 评估单V4
DECLARE
    v_parent_id NUMBER;
BEGIN
    SELECT ID INTO v_parent_id FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'cost-management';
    INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
    VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'cost-eval-v4', '评估单', 'PAGE', 'cost-eval', 'mdi:calculator', '/cost/eval-v4', v_parent_id, 1, 'system');
END;
/

COMMIT;
