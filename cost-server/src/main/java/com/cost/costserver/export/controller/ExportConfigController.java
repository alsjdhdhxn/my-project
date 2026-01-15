package com.cost.costserver.export.controller;

import com.cost.costserver.auth.entity.Role;
import com.cost.costserver.auth.mapper.RoleMapper;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.common.Result;
import com.cost.costserver.common.SecurityUtils;
import com.cost.costserver.export.dto.ExportHeaderConfigDTO;
import com.cost.costserver.export.dto.ExportUserPrefDTO;
import com.cost.costserver.export.dto.SaveExportHeaderConfigRequest;
import com.cost.costserver.export.dto.SaveExportUserPrefRequest;
import com.cost.costserver.export.service.ExportConfigService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/export-config")
@RequiredArgsConstructor
public class ExportConfigController {

    private static final String ADMIN_ROLE = "ADMIN";

    private final ExportConfigService exportConfigService;
    private final RoleMapper roleMapper;

    @GetMapping("/prefs/{pageCode}")
    public Result<ExportUserPrefDTO> getUserPref(@PathVariable String pageCode) {
        Long userId = SecurityUtils.getCurrentUserId();
        if (userId == null) {
            throw new BusinessException(403, "no permission");
        }
        return Result.ok(exportConfigService.getUserPref(userId, pageCode));
    }

    @PostMapping("/prefs/{pageCode}")
    public Result<Void> saveUserPref(
        @PathVariable String pageCode,
        @RequestBody SaveExportUserPrefRequest request
    ) {
        Long userId = SecurityUtils.getCurrentUserId();
        if (userId == null) {
            throw new BusinessException(403, "no permission");
        }
        exportConfigService.saveUserPref(userId, pageCode, request);
        return Result.ok();
    }

    @DeleteMapping("/prefs/{pageCode}")
    public Result<Void> resetUserPref(@PathVariable String pageCode) {
        Long userId = SecurityUtils.getCurrentUserId();
        if (userId == null) {
            throw new BusinessException(403, "no permission");
        }
        exportConfigService.resetUserPref(userId, pageCode);
        return Result.ok();
    }

    @GetMapping("/headers/{pageCode}/{gridKey}")
    public Result<List<ExportHeaderConfigDTO>> getHeaderConfig(
        @PathVariable String pageCode,
        @PathVariable String gridKey
    ) {
        Long userId = SecurityUtils.getCurrentUserId();
        if (userId == null) {
            throw new BusinessException(403, "no permission");
        }
        return Result.ok(exportConfigService.getHeaderConfig(pageCode, gridKey));
    }

    @PostMapping("/headers/{pageCode}/{gridKey}")
    public Result<Void> saveHeaderConfig(
        @PathVariable String pageCode,
        @PathVariable String gridKey,
        @RequestBody SaveExportHeaderConfigRequest request
    ) {
        Long userId = SecurityUtils.getCurrentUserId();
        if (userId == null) {
            throw new BusinessException(403, "no permission");
        }
        if (!isAdmin(userId)) {
            throw new BusinessException(403, "no permission");
        }
        if (request == null || request.getHeaders() == null) {
            throw new BusinessException(400, "headers is required");
        }
        exportConfigService.saveHeaderConfig(pageCode, gridKey, request.getHeaders());
        return Result.ok();
    }

    private boolean isAdmin(Long userId) {
        List<Role> roles = roleMapper.selectByUserId(userId);
        return roles.stream().anyMatch(role -> ADMIN_ROLE.equalsIgnoreCase(role.getRoleCode()));
    }
}
