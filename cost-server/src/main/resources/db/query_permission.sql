-- =====================================================
-- 权限查询脚本
-- =====================================================

-- =====================================================
-- 1. 查询 Admin 权限（全部权限）
-- =====================================================
SELECT 
    r.ROLE_CODE,
    r.ROLE_NAME,
    rp.PAGE_CODE,
    rp.BUTTON_POLICY,
    rp.COLUMN_POLICY
FROM T_COST_ROLE r
JOIN T_COST_ROLE_PAGE rp ON r.ID = rp.ROLE_ID
WHERE r.ROLE_CODE = 'ADMIN' 
  AND r.DELETED = 0 
  AND rp.DELETED = 0;

-- 结果说明：
-- BUTTON_POLICY = ["*"] 表示拥有所有按钮权限
-- COLUMN_POLICY = NULL 表示不限制任何列

-- =====================================================
-- 2. 查询个人用户权限（根据用户名）
-- =====================================================
SELECT 
    u.USERNAME,
    u.REAL_NAME,
    r.ROLE_CODE,
    r.ROLE_NAME,
    rp.PAGE_CODE,
    rp.BUTTON_POLICY,
    rp.COLUMN_POLICY
FROM T_COST_USER u
JOIN T_COST_USER_ROLE ur ON u.ID = ur.USER_ID
JOIN T_COST_ROLE r ON ur.ROLE_ID = r.ID
JOIN T_COST_ROLE_PAGE rp ON r.ID = rp.ROLE_ID
WHERE u.USERNAME = 'lisi'
  AND u.DELETED = 0 
  AND ur.DELETED = 0 
  AND r.DELETED = 0 
  AND rp.DELETED = 0;

-- 结果说明（lisi 用户）：
-- BUTTON_POLICY = ["EXPORT"] 表示只有导出权限
-- COLUMN_POLICY = {"amount":{"visible":false}} 表示金额列不可见

-- =====================================================
-- 3. 查询用户的数据权限规则
-- =====================================================
SELECT 
    u.USERNAME,
    rp.PAGE_CODE,
    dr.RULE_TYPE,
    dr.RULE_CONFIG,
    dr.PRIORITY
FROM T_COST_USER u
JOIN T_COST_USER_ROLE ur ON u.ID = ur.USER_ID
JOIN T_COST_ROLE_PAGE rp ON ur.ROLE_ID = rp.ROLE_ID
JOIN T_COST_ROLE_PAGE_DATA_RULE dr ON rp.ID = dr.ROLE_PAGE_ID
WHERE u.USERNAME = 'lisi'
  AND u.DELETED = 0 
  AND ur.DELETED = 0 
  AND rp.DELETED = 0 
  AND dr.DELETED = 0
ORDER BY dr.PRIORITY;

-- 结果说明：
-- RULE_TYPE = USER, RULE_CONFIG = {"field":"CREATE_BY","operator":"eq","value":"${currentUser}"}
-- 表示只能看自己创建的数据

-- =====================================================
-- 4. 查询用户的个人偏好配置
-- =====================================================
SELECT 
    u.USERNAME,
    ug.PAGE_CODE,
    ug.GRID_KEY,
    ug.CONFIG_DATA
FROM T_COST_USER u
JOIN T_COST_USER_GRID_CONFIG ug ON u.ID = ug.USER_ID
WHERE u.USERNAME = 'zhangsan'
  AND u.DELETED = 0 
  AND ug.DELETED = 0;

-- =====================================================
-- 5. 权限合并查询（完整视图）
-- 合并规则：基础层(COLUMN_METADATA) → 限制层(ROLE_PAGE) → 偏好层(USER_GRID_CONFIG)
-- =====================================================
SELECT 
    u.USERNAME,
    u.REAL_NAME,
    cm.FIELD_NAME,
    cm.HEADER_TEXT,
    cm.VISIBLE AS BASE_VISIBLE,
    cm.EDITABLE AS BASE_EDITABLE,
    rp.COLUMN_POLICY,
    ug.CONFIG_DATA AS USER_PREFERENCE
FROM T_COST_USER u
JOIN T_COST_USER_ROLE ur ON u.ID = ur.USER_ID
JOIN T_COST_ROLE_PAGE rp ON ur.ROLE_ID = rp.ROLE_ID
JOIN T_COST_TABLE_METADATA tm ON tm.TABLE_CODE = 'CostDemo'
JOIN T_COST_COLUMN_METADATA cm ON cm.TABLE_METADATA_ID = tm.ID
LEFT JOIN T_COST_USER_GRID_CONFIG ug ON u.ID = ug.USER_ID AND ug.PAGE_CODE = rp.PAGE_CODE
WHERE u.USERNAME = 'lisi'
  AND rp.PAGE_CODE = 'cost-demo'
  AND u.DELETED = 0 
  AND ur.DELETED = 0 
  AND rp.DELETED = 0 
  AND cm.DELETED = 0
ORDER BY cm.DISPLAY_ORDER;

-- =====================================================
-- 6. 权限合并逻辑说明（Java 伪代码）
-- =====================================================
/*
public ColumnConfig mergePermission(String pageCode, String fieldName, Long userId) {
    // 1. 基础层：从元数据获取默认配置
    ColumnMetadata base = getColumnMetadata(pageCode, fieldName);
    ColumnConfig result = new ColumnConfig();
    result.setVisible(base.getVisible());
    result.setEditable(base.getEditable());
    
    // 2. 限制层：角色权限只能收紧，不能放宽
    List<RolePage> rolePages = getUserRolePages(userId, pageCode);
    for (RolePage rp : rolePages) {
        Map<String, Object> columnPolicy = parseJson(rp.getColumnPolicy());
        if (columnPolicy != null && columnPolicy.containsKey(fieldName)) {
            Map<String, Object> policy = (Map) columnPolicy.get(fieldName);
            // 只能收紧：如果角色说不可见，就不可见
            if (Boolean.FALSE.equals(policy.get("visible"))) {
                result.setVisible(false);
            }
            if (Boolean.FALSE.equals(policy.get("editable"))) {
                result.setEditable(false);
            }
        }
    }
    
    // 3. 偏好层：用户个人设置（不能突破角色限制）
    UserGridConfig userConfig = getUserGridConfig(userId, pageCode);
    if (userConfig != null) {
        Map<String, Object> config = parseJson(userConfig.getConfigData());
        List<String> hiddenColumns = (List) config.get("hiddenColumns");
        // 用户可以隐藏列，但不能显示被角色禁止的列
        if (hiddenColumns != null && hiddenColumns.contains(fieldName)) {
            result.setVisible(false);
        }
    }
    
    return result;
}
*/
