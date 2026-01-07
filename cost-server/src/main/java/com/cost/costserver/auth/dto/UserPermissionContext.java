package com.cost.costserver.auth.dto;

import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 用户权限上下文（登录时组装）
 */
public record UserPermissionContext(
    Long userId,
    String username,
    List<String> roles,                           // 角色编码列表
    Set<String> pageCodes,                        // 有权限的 pageCode 集合
    Map<String, PagePermission> pagePermissions   // pageCode -> 页面权限详情
) {
    /**
     * 是否有某个页面权限
     */
    public boolean hasPagePermission(String pageCode) {
        return pageCodes != null && pageCodes.contains(pageCode);
    }
    
    /**
     * 获取页面权限
     */
    public PagePermission getPagePermission(String pageCode) {
        return pagePermissions != null ? pagePermissions.get(pageCode) : null;
    }
}
