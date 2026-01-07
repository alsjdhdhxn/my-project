package com.cost.costserver.auth.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.cost.costserver.auth.dto.MenuRoute;
import com.cost.costserver.auth.dto.UserPermissionContext;
import com.cost.costserver.auth.dto.UserRoute;
import com.cost.costserver.auth.entity.Role;
import com.cost.costserver.auth.entity.Resource;
import com.cost.costserver.auth.mapper.ResourceMapper;
import com.cost.costserver.auth.mapper.RoleMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class MenuService {

    private final ResourceMapper resourceMapper;
    private final PermissionService permissionService;
    private final RoleMapper roleMapper;
    private static final String SUPER_ADMIN_ROLE = "ADMIN";

    /**
     * 获取用户菜单（根据权限过滤）
     */
    public UserRoute getUserRoutes(Long userId) {
        if (userId == null) {
            return new UserRoute(List.of(), "home");
        }
        // 查询所有菜单资源
        List<Resource> resources = resourceMapper.selectList(
            new LambdaQueryWrapper<Resource>()
                .orderByAsc(Resource::getSortOrder)
        );

        List<Role> roles = roleMapper.selectByUserId(userId);
        List<String> roleCodes = roles.stream().map(Role::getRoleCode).toList();
        boolean isSuperAdmin = roleCodes.stream()
            .anyMatch(code -> SUPER_ADMIN_ROLE.equalsIgnoreCase(code));

        if (isSuperAdmin) {
            List<MenuRoute> routes = buildMenuTree(resources);
            return new UserRoute(routes, "home");
        }

        // 获取用户有权限的 pageCode 集合
        UserPermissionContext permContext = permissionService.buildUserPermissionContext(userId, null, roleCodes);
        Set<String> allowedPageCodes = permContext.pageCodes();

        // 过滤菜单：PAGE 类型必须有权限，DIRECTORY 类型保留（后续根据子菜单决定）
        List<Resource> filteredResources = filterResourcesByPermission(resources, allowedPageCodes);

        // 构建树形结构
        List<MenuRoute> routes = buildMenuTree(filteredResources);

        return new UserRoute(routes, "home");
    }

    /**
     * 根据权限过滤菜单资源
     * - PAGE 类型：pageCode 必须在允许列表中
     * - DIRECTORY 类型：保留，后续在构建树时根据是否有子菜单决定
     */
    private List<Resource> filterResourcesByPermission(List<Resource> resources, Set<String> allowedPageCodes) {
        if (allowedPageCodes == null || allowedPageCodes.isEmpty()) {
            return List.of();
        }
        
        // 先收集有权限的 PAGE 资源 ID
        Set<Long> allowedPageIds = resources.stream()
            .filter(r -> "PAGE".equals(r.getResourceType()))
            .filter(r -> r.getPageCode() != null && allowedPageCodes.contains(r.getPageCode()))
            .map(Resource::getId)
            .collect(Collectors.toSet());
        
        // 收集这些 PAGE 的所有祖先目录 ID
        Set<Long> ancestorIds = collectAncestorIds(resources, allowedPageIds);
        
        // 过滤：PAGE 必须有权限，DIRECTORY 必须是祖先
        return resources.stream()
            .filter(r -> {
                if ("PAGE".equals(r.getResourceType())) {
                    return allowedPageIds.contains(r.getId());
                } else if ("DIRECTORY".equals(r.getResourceType())) {
                    return ancestorIds.contains(r.getId());
                }
                return false;
            })
            .toList();
    }

    /**
     * 收集指定资源的所有祖先 ID
     */
    private Set<Long> collectAncestorIds(List<Resource> resources, Set<Long> targetIds) {
        Map<Long, Resource> resourceMap = resources.stream()
            .collect(Collectors.toMap(Resource::getId, r -> r));
        
        Set<Long> ancestorIds = new java.util.HashSet<>();
        for (Long id : targetIds) {
            Resource current = resourceMap.get(id);
            while (current != null && current.getParentId() != null) {
                ancestorIds.add(current.getParentId());
                current = resourceMap.get(current.getParentId());
            }
        }
        return ancestorIds;
    }

    private List<MenuRoute> buildMenuTree(List<Resource> resources) {
        // 按 parentId 分组
        Map<Long, List<Resource>> childrenMap = resources.stream()
            .filter(r -> r.getParentId() != null)
            .collect(Collectors.groupingBy(Resource::getParentId));

        // 获取顶级菜单
        List<Resource> topLevel = resources.stream()
            .filter(r -> r.getParentId() == null)
            .toList();

        // 递归构建（顶级菜单 isTopLevel=true，无父级）
        return topLevel.stream()
            .map(r -> buildMenuRoute(r, childrenMap, true, null))
            .toList();
    }

    private MenuRoute buildMenuRoute(Resource resource, Map<Long, List<Resource>> childrenMap, 
                                       boolean isTopLevel, String parentName) {
        MenuRoute route = new MenuRoute();
        route.setId(resource.getId().toString());
        // 子路由 name 格式：parent_child（elegant-router 要求）
        String routeName = parentName != null 
            ? parentName + "_" + resource.getResourceCode() 
            : resource.getResourceCode();
        route.setName(routeName);
        route.setPath(buildPath(resource, isTopLevel));
        route.setComponent(buildComponent(resource, isTopLevel));

        MenuRoute.MenuMeta meta = new MenuRoute.MenuMeta();
        meta.setTitle(resource.getResourceName());
        // 不设置 i18nKey，直接使用 title 显示中文
        meta.setIcon(resource.getIcon());
        meta.setOrder(resource.getSortOrder());
        meta.setPageCode(resource.getPageCode());
        route.setMeta(meta);

        // 处理子菜单（子菜单不是顶级，传递父级 name）
        List<Resource> children = childrenMap.get(resource.getId());
        if (children != null && !children.isEmpty()) {
            route.setChildren(children.stream()
                .map(c -> buildMenuRoute(c, childrenMap, false, routeName))
                .toList());
        }

        return route;
    }

    private String buildPath(Resource resource, boolean isTopLevel) {
        if (resource.getRoute() != null) {
            // 子路由使用相对路径（只取最后一段）
            if (!isTopLevel) {
                String route = resource.getRoute();
                int lastSlash = route.lastIndexOf('/');
                return lastSlash >= 0 ? route.substring(lastSlash + 1) : route;
            }
            return resource.getRoute();
        }
        // 目录类型，路径为 /resourceCode
        return "/" + resource.getResourceCode();
    }

    private String buildComponent(Resource resource, boolean isTopLevel) {
        if ("DIRECTORY".equals(resource.getResourceType())) {
            return "layout.base";
        }
        // 顶级 PAGE 需要布局，子级 PAGE 只需要视图
        if (isTopLevel) {
            if ("home".equals(resource.getPageCode())) {
                return "layout.base$view.home";
            }
            return "layout.base$view.dynamic";
        }
        // 子级页面只返回视图组件
        return "view.dynamic";
    }
}
