-- =====================================================
-- 权限管理视图（无逻辑删除版本）
-- 权限相关表（T_COST_ROLE, T_COST_USER_ROLE, T_COST_ROLE_PAGE, T_COST_RESOURCE）
-- 均不使用审计字段和逻辑删除，采用物理删除
-- =====================================================

-- =====================================================
-- 1. 创建视图
-- =====================================================

-- 角色主表视图（简化版，无审计字段）
CREATE OR REPLACE VIEW V_COST_ROLE AS
SELECT 
    r.ID,
    r.ROLE_CODE,
    r.ROLE_NAME,
    r.DESCRIPTION
FROM T_COST_ROLE r;

-- 角色人员关联视图（显示人员ID、用户名、姓名）
-- 注意：T_COST_USER 仍保留逻辑删除
CREATE OR REPLACE VIEW V_COST_USER_ROLE AS
SELECT 
    ur.ID,
    ur.USER_ID,
    u.USERNAME,
    u.REAL_NAME,
    ur.ROLE_ID
FROM T_COST_USER_ROLE ur
LEFT JOIN T_COST_USER u ON ur.USER_ID = u.ID AND u.DELETED = 0;

-- 角色页面关联视图（显示页面CODE和页面名称）
CREATE OR REPLACE VIEW V_COST_ROLE_PAGE AS
SELECT 
    rp.ID,
    rp.ROLE_ID,
    rp.PAGE_CODE,
    res.RESOURCE_NAME AS PAGE_NAME,
    rp.BUTTON_POLICY,
    rp.COLUMN_POLICY,
    rp.ROW_POLICY
FROM T_COST_ROLE_PAGE rp
LEFT JOIN T_COST_RESOURCE res ON rp.PAGE_CODE = res.PAGE_CODE;

-- 资源权限树视图（根据角色ID查询资源树，并标记是否已授权）
-- 使用方式：SELECT * FROM V_COST_RESOURCE_PERMISSION WHERE ROLE_ID = :roleId
-- 统一使用 PAGE_CODE 作为标识
CREATE OR REPLACE VIEW V_COST_RESOURCE_PERMISSION AS
SELECT 
    res.ID,
    res.PAGE_CODE,
    res.RESOURCE_NAME,
    res.RESOURCE_TYPE,
    res.IS_HARDCODED,
    res.ICON,
    res.ROUTE,
    res.PARENT_ID,
    res.SORT_ORDER,
    r.ID AS ROLE_ID,
    r.ROLE_CODE,
    r.ROLE_NAME,
    rp.ID AS ROLE_PAGE_ID,
    rp.BUTTON_POLICY,
    rp.COLUMN_POLICY,
    rp.ROW_POLICY,
    CASE WHEN rp.ID IS NOT NULL THEN 1 ELSE 0 END AS IS_AUTHORIZED
FROM T_COST_RESOURCE res
CROSS JOIN T_COST_ROLE r
LEFT JOIN T_COST_ROLE_PAGE rp 
    ON rp.PAGE_CODE = res.PAGE_CODE
    AND rp.ROLE_ID = r.ID
ORDER BY res.SORT_ORDER;

COMMIT;
