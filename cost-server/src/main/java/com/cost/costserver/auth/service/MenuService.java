package com.cost.costserver.auth.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.cost.costserver.auth.dto.MenuRoute;
import com.cost.costserver.auth.dto.UserRoute;
import com.cost.costserver.auth.entity.Resource;
import com.cost.costserver.auth.mapper.ResourceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class MenuService {

    private final ResourceMapper resourceMapper;

    /**
     * 获取用户菜单（目前不做权限过滤，后续可加）
     */
    public UserRoute getUserRoutes(Long userId) {
        // 查询所有菜单资源
        List<Resource> resources = resourceMapper.selectList(
            new LambdaQueryWrapper<Resource>()
                .orderByAsc(Resource::getSortOrder)
        );

        // 构建树形结构
        List<MenuRoute> routes = buildMenuTree(resources);

        return new UserRoute(routes, "home");
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
            // 子路由使用相对路径
            if (!isTopLevel && resource.getRoute().startsWith("/")) {
                return resource.getRoute().substring(1);
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
