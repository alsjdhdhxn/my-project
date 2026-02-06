-- ============================================================
-- Admin用户初始化
-- 包含: admin用户及其角色关联
-- 注意: 密码由应用程序启动时通过AdminPasswordInitializer初始化
-- ============================================================

-- ============================================================
-- 1. 创建admin用户
-- ============================================================
INSERT INTO T_COST_USER (ID, USERNAME, REAL_NAME, EMAIL, PHONE, DEPARTMENT_ID, STATUS, DELETED, CREATE_TIME, UPDATE_TIME)
VALUES (111, 'admin', '系统管理员', 'admin@example.com', NULL, NULL, 'ACTIVE', 0, SYSTIMESTAMP, SYSTIMESTAMP);

-- ============================================================
-- 2. 关联admin用户与ADMIN角色
-- ============================================================
INSERT INTO T_COST_USER_ROLE (ID, USER_ID, ROLE_ID, USERNAME, ROLE_CODE)
VALUES (3, 111, 3, 'admin', 'ADMIN');
