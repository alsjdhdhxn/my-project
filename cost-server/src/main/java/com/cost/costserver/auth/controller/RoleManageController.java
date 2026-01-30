package com.cost.costserver.auth.controller;

import com.cost.costserver.auth.dto.*;
import com.cost.costserver.auth.service.RoleManageService;
import com.cost.costserver.common.Result;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 权限管理控制器（硬编码页面专用）
 */
@RestController
@RequestMapping("/role-manage")
@RequiredArgsConstructor
public class RoleManageController {

    private final RoleManageService roleManageService;

    // ==================== 角色管理 ====================

    @GetMapping("/roles")
    public Result<List<RoleVO>> listRoles() {
        return Result.ok(roleManageService.listRoles());
    }

    @PostMapping("/role")
    public Result<RoleVO> createRole(@RequestBody RoleVO role) {
        return Result.ok(roleManageService.createRole(role));
    }

    @PutMapping("/role/{id}")
    public Result<RoleVO> updateRole(@PathVariable Long id, @RequestBody RoleVO role) {
        role.setId(id);
        return Result.ok(roleManageService.updateRole(role));
    }

    @DeleteMapping("/role/{id}")
    public Result<Void> deleteRole(@PathVariable Long id) {
        roleManageService.deleteRole(id);
        return Result.ok();
    }

    // ==================== 角色人员管理 ====================

    @GetMapping("/role/{roleId}/users")
    public Result<List<UserRoleVO>> listUsersByRole(@PathVariable Long roleId) {
        return Result.ok(roleManageService.listUsersByRole(roleId));
    }

    @PostMapping("/role/{roleId}/user")
    public Result<UserRoleVO> addUserToRole(@PathVariable Long roleId, @RequestBody UserRoleVO userRole) {
        userRole.setRoleId(roleId);
        return Result.ok(roleManageService.addUserToRole(userRole));
    }

    @DeleteMapping("/user-role/{id}")
    public Result<Void> removeUserFromRole(@PathVariable Long id) {
        roleManageService.removeUserFromRole(id);
        return Result.ok();
    }

    // ==================== 角色页面管理 ====================

    @GetMapping("/role/{roleId}/pages")
    public Result<List<RolePageVO>> listPagesByRole(@PathVariable Long roleId) {
        return Result.ok(roleManageService.listPagesByRole(roleId));
    }

    @PostMapping("/role/{roleId}/page")
    public Result<RolePageVO> addPageToRole(@PathVariable Long roleId, @RequestBody RolePageVO rolePage) {
        rolePage.setRoleId(roleId);
        return Result.ok(roleManageService.addPageToRole(rolePage));
    }

    @PutMapping("/role-page/{id}")
    public Result<RolePageVO> updateRolePage(@PathVariable Long id, @RequestBody RolePageVO rolePage) {
        rolePage.setId(id);
        return Result.ok(roleManageService.updateRolePage(rolePage));
    }

    @DeleteMapping("/role-page/{id}")
    public Result<Void> removePageFromRole(@PathVariable Long id) {
        roleManageService.removePageFromRole(id);
        return Result.ok();
    }

    // ==================== 辅助查询 ====================

    @GetMapping("/users")
    public Result<List<UserSimpleVO>> listAllUsers() {
        return Result.ok(roleManageService.listAllUsers());
    }

    @GetMapping("/pages")
    public Result<List<PageSimpleVO>> listAllPages() {
        return Result.ok(roleManageService.listAllPages());
    }

    @GetMapping("/page/{pageCode}/buttons")
    public Result<List<PageButtonVO>> listPageButtons(@PathVariable String pageCode) {
        return Result.ok(roleManageService.listPageButtons(pageCode));
    }

    // ==================== 高级查询 ====================

    @PostMapping("/roles/search")
    public Result<List<RoleVO>> searchRoles(@RequestBody List<SearchConditionDTO> conditions) {
        return Result.ok(roleManageService.searchRoles(conditions));
    }
}
