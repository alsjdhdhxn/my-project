-- =====================================================
-- 权限管理视图及表结构增量更新
-- =====================================================

-- =====================================================
-- 1. 表结构增量更新（添加缺失的审计字段）
-- 注意：如果字段已存在会报错，可忽略
-- =====================================================

-- T_COST_USER_ROLE 添加 UPDATE_BY, UPDATE_TIME（如果不存在）
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE T_COST_USER_ROLE ADD (UPDATE_BY VARCHAR2(64), UPDATE_TIME TIMESTAMP DEFAULT SYSTIMESTAMP)';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

-- T_COST_ROLE_PAGE_DATA_RULE 添加 UPDATE_BY, UPDATE_TIME（如果不存在）
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE T_COST_ROLE_PAGE_DATA_RULE ADD (UPDATE_BY VARCHAR2(64), UPDATE_TIME TIMESTAMP DEFAULT SYSTIMESTAMP)';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

COMMIT;

-- =====================================================
-- 2. 创建视图
-- =====================================================

-- 角色主表视图
CREATE OR REPLACE VIEW V_COST_ROLE AS
SELECT 
    r.ID,
    r.ROLE_CODE,
    r.ROLE_NAME,
    r.DESCRIPTION,
    r.DELETED,
    r.CREATE_BY,
    r.CREATE_TIME,
    r.UPDATE_BY,
    r.UPDATE_TIME
FROM T_COST_ROLE r
WHERE r.DELETED = 0;

-- 角色人员关联视图（显示人员ID、用户名、姓名）
CREATE OR REPLACE VIEW V_COST_USER_ROLE AS
SELECT 
    ur.ID,
    ur.USER_ID,
    u.USERNAME,
    u.REAL_NAME,
    ur.ROLE_ID,
    ur.DELETED,
    ur.CREATE_BY,
    ur.CREATE_TIME,
    ur.UPDATE_BY,
    ur.UPDATE_TIME
FROM T_COST_USER_ROLE ur
LEFT JOIN T_COST_USER u ON ur.USER_ID = u.ID AND u.DELETED = 0
WHERE ur.DELETED = 0;

-- 角色页面关联视图（显示页面CODE和页面名称）
CREATE OR REPLACE VIEW V_COST_ROLE_PAGE AS
SELECT 
    rp.ID,
    rp.ROLE_ID,
    rp.PAGE_CODE,
    res.RESOURCE_NAME AS PAGE_NAME,
    rp.BUTTON_POLICY,
    rp.COLUMN_POLICY,
    rp.DELETED,
    rp.CREATE_BY,
    rp.CREATE_TIME,
    rp.UPDATE_BY,
    rp.UPDATE_TIME
FROM T_COST_ROLE_PAGE rp
LEFT JOIN T_COST_RESOURCE res ON rp.PAGE_CODE = res.PAGE_CODE AND res.DELETED = 0
WHERE rp.DELETED = 0;

COMMIT;
