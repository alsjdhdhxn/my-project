package com.cost.costserver.auth.controller;

import com.cost.costserver.auth.dto.UserRoute;
import com.cost.costserver.auth.service.MenuService;
import com.cost.costserver.common.Result;
import com.cost.costserver.common.SecurityUtils;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Collections;

@Tag(name = "路由接口")
@RestController
@RequestMapping("/route")
@RequiredArgsConstructor
public class RouteController {

    private final MenuService menuService;

    @Operation(summary = "获取常量路由")
    @GetMapping("/getConstantRoutes")
    public Result<?> getConstantRoutes() {
        // 常量路由由前端静态定义，后端返回空
        return Result.ok(Collections.emptyList());
    }

    @Operation(summary = "获取用户路由")
    @GetMapping("/getUserRoutes")
    public Result<UserRoute> getUserRoutes() {
        Long userId = SecurityUtils.getCurrentUserId();
        return Result.ok(menuService.getUserRoutes(userId));
    }

    @Operation(summary = "判断路由是否存在")
    @GetMapping("/isRouteExist")
    public Result<Boolean> isRouteExist(@RequestParam String routeName) {
        // 简单实现，后续可完善
        return Result.ok(true);
    }
}
