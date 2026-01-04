-- =====================================================
-- V5 动态页面测试菜单
-- =====================================================

-- 在成本管理目录下添加 V5 测试入口（使用动态路由）
DECLARE
    v_parent_id NUMBER;
BEGIN
    -- 查找成本管理目录
    SELECT ID INTO v_parent_id FROM T_COST_RESOURCE 
    WHERE RESOURCE_CODE = 'cost-manage' AND ROWNUM = 1;
    
    -- 添加 V5 动态页面测试菜单（ROUTE 为空，自动生成 /dynamic/cost-eval）
    INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
    VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'cost-eval-v5', '评估单V5', 'PAGE', 'cost-eval', 'mdi:flask-outline', NULL, v_parent_id, 10, 'system');
    
    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- 如果找不到父目录，作为顶级菜单
        INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
        VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'cost-eval-v5', '评估单V5', 'PAGE', 'cost-eval', 'mdi:flask-outline', NULL, NULL, 10, 'system');
        COMMIT;
END;
/
