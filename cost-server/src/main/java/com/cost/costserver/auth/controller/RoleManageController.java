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
        return Result.success(roleManageService.listRoles());
    }

    @PostMapping("/role")
    public Result<RoleVO> createRole(@RequestBody RoleVO role) {
        return Result.success(roleManageService.createRole(role));
    }

    @PutMapping("/role/{id}")
    public Result<RoleVO> updateRole(@PathVariable Long id, @RequestBody RoleVO role) {
        role.setId(id);
        return Result.success(roleManageService.updateRole(role));
    }

    @DeleteMapping("/role/{id}")
    public Result<Void> deleteRole(@PathVariable Long id) {
        roleManageService.deleteRole(id);
        return Result.success(null);
    }

    // ==================== 角色人员管理 ====================

    @GetMapping("/role/{roleId}/users")
    public Result<List<UserRoleVO>> listUsersByRole(@PathVariable Long roleId) {
        return Result.success(roleManageService.listUsersByRole(roleId));
    }

    @PostMapping("/role/{roleId}/user")
    public Result<UserRoleVO> addUserToRole(@PathVariable Long roleId, @RequestBody UserRoleVO userRole) {
        userRole.setRoleId(roleId);
        return Result.success(roleManageService.addUserToRole(userRole));
    }

    @DeleteMapping("/user-role/{id}")
    public Result<Void> removeUserFromRole(@PathVariable Long id) {
        roleManageService.removeUserFromRole(id);
        return Result.success(null);
    }

    // ==================== 角色页面管理 ====================

    @GetMapping("/role/{roleId}/pages")
    public Result<List<RolePageVO>> listPagesByRole(@PathVariable Long roleId) {
        return Result.success(roleManageService.listPagesByRole(roleId));
    }

    @PostMapping("/role/{roleId}/page")
    public Result<RolePageVO> addPageToRole(@PathVariable Long roleId, @RequestBody RolePageVO rolePage) {
        rolePage.setRoleId(roleId);
        return Result.success(roleManageService.addPageToRole(rolePage));
    }

    @PutMapping("/role-page/{id}")
    public Result<RolePageVO> updateRolePage(@PathVariable Long id, @RequestBody RolePageVO rolePage) {
        rolePage.setId(id);
        return Result.success(roleManageService.updateRolePage(rolePage));
    }

    @DeleteMapping("/role-page/{id}")
    public Result<Void> removePageFromRole(@PathVariable Long id) {
        roleManageService.removePageFromRole(id);
        return Result.success(null);
    }

    // ==================== 辅助查询 ====================

    @GetMapping("/users")
    public Result<List<UserSimpleVO>> listAllUsers() {
        return Result.success(roleManageService.listAllUsers());
    }

    @GetMapping("/pages")
    public Result<List<PageSimpleVO>> listAllPages() {
        return Result.success(roleManageService.listAllPages());
    }
}
