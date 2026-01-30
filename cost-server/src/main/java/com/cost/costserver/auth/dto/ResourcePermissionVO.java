package com.cost.costserver.auth.dto;

import lombok.Data;
import java.util.List;

/**
 * 资源权限树VO（包含授权状态）
 */
@Data
public class ResourcePermissionVO {
    private Long id;
    private String pageCode;
    private String resourceName;
    private String resourceType;  // DIRECTORY, PAGE
    private Integer isHardcoded;  // 1=硬编码页面, 0=元数据驱动
    private String icon;
    private String route;
    private Long parentId;
    private Integer sortOrder;
    
    // 权限相关
    private Long rolePageId;      // T_COST_ROLE_PAGE.ID，有值表示已授权
    private String buttonPolicy;
    private String columnPolicy;
    private String rowPolicy;
    private Integer isAuthorized; // 1=已授权, 0=未授权
    
    // 树形结构
    private List<ResourcePermissionVO> children;
}
