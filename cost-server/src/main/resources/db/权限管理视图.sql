-- =====================================================
-- 权限管理视图及表结构增量更新
-- =====================================================

-- =====================================================
-- 1. 表结构增量更新（添加缺失的审计字段）
-- 注意：如果字段已存在会报错，可忽略
-- =====================================================

-- T_COST_USER_ROLE 添加 UPDATE_BY, UPDATE_TIME（如果不存在）
ALTER TABLE T_COST_USER_ROLE ADD (UPDATE_BY VARCHAR2(64), UPDATE_TIME TIMESTAMP DEFAULT SYSTIMESTAMP);
-- T_COST_ROLE_PAGE_DATA_RULE 添加 UPDATE_BY, UPDATE_TIME（如果不存在）
ALTER TABLE T_COST_ROLE_PAGE_DATA_RULE ADD (UPDATE_BY VARCHAR2(64), UPDATE_TIME TIMESTAMP DEFAULT SYSTIMESTAMP);


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

-- 资源权限树视图（根据角色ID查询资源树，并标记是否已授权）
-- 使用方式：SELECT * FROM V_COST_RESOURCE_PERMISSION WHERE ROLE_ID = :roleId
-- 注意：T_COST_ROLE_PAGE.PAGE_CODE 存的是 RESOURCE_CODE
CREATE OR REPLACE VIEW V_COST_RESOURCE_PERMISSION AS
SELECT 
    res.ID,
    res.RESOURCE_CODE,
    res.RESOURCE_NAME,
    res.RESOURCE_TYPE,
    res.PAGE_CODE,
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
    CASE WHEN rp.ID IS NOT NULL THEN 1 ELSE 0 END AS IS_AUTHORIZED
FROM T_COST_RESOURCE res
CROSS JOIN T_COST_ROLE r
LEFT JOIN T_COST_ROLE_PAGE rp 
    ON rp.PAGE_CODE = res.RESOURCE_CODE  -- 用 RESOURCE_CODE 关联
    AND rp.ROLE_ID = r.ID 
    AND rp.DELETED = 0
WHERE res.DELETED = 0 
  AND r.DELETED = 0
ORDER BY res.SORT_ORDER;

COMMIT;

-- =====================================================
-- 3. 菜单资源配置（权限管理页面）
-- =====================================================

-- 删除旧的权限管理菜单（如果存在）
DELETE FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'permission';
COMMIT;

-- 创建系统管理菜单（如果不存在）和权限管理页面
DECLARE
    v_system_id NUMBER;
BEGIN
    -- 查找系统管理菜单ID，如果不存在则创建
    BEGIN
        SELECT ID INTO v_system_id FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'system';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
            VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'system', '系统管理', 'MENU', 'mdi:cog', '/system', NULL, 99, 'system')
            RETURNING ID INTO v_system_id;
    END;
    
    -- 创建权限管理菜单（硬编码页面，PAGE_CODE为空）
    INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
    VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'permission', '权限管理', 'PAGE', NULL, 'mdi:shield-account', '/system/permission', v_system_id, 1, 'system');
END;
/

COMMIT;
