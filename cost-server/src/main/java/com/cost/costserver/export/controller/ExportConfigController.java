package com.cost.costserver.export.controller;

import com.cost.costserver.auth.dto.PagePermission;
import com.cost.costserver.auth.service.PermissionService;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.common.Result;
import com.cost.costserver.common.SecurityUtils;
import com.cost.costserver.export.dto.CustomExportConfigDTO;
import com.cost.costserver.export.dto.CustomExportRequest;
import com.cost.costserver.export.service.CustomExportService;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Set;

@RestController
@RequestMapping("/api/export-config")
@RequiredArgsConstructor
public class ExportConfigController {

    private final CustomExportService customExportService;
    private final PermissionService permissionService;

    @GetMapping("/custom/{pageCode}")
    public Result<List<CustomExportConfigDTO>> getCustomExportConfigs(@PathVariable String pageCode) {
        Long userId = SecurityUtils.getCurrentUserId();
        if (userId == null) {
            throw new BusinessException(403, "no permission");
        }
        
        List<CustomExportConfigDTO> configs = customExportService.getExportConfigs(pageCode);
        
        // 获取用户的页面权限，过滤导出配置
        PagePermission permission = permissionService.getPagePermission(userId, pageCode);
        if (permission == null) {
            return Result.ok(List.of()); // 无页面权限，返回空列表
        }
        
        Set<String> allowedButtons = permission.buttons();
        if (allowedButtons.contains("*")) {
            return Result.ok(configs); // 全部权限
        }
        
        // 过滤：只返回用户有权限的导出配置
        // 权限格式：自定义导出:{exportCode}
        List<CustomExportConfigDTO> filtered = configs.stream()
                .filter(config -> allowedButtons.contains("自定义导出:" + config.getExportCode()))
                .toList();
        
        return Result.ok(filtered);
    }

    @PostMapping("/custom/{exportCode}/export")
    public void customExport(
            @PathVariable String exportCode,
            @RequestBody(required = false) CustomExportRequest request,
            HttpServletResponse response) {
        Long userId = SecurityUtils.getCurrentUserId();
        if (userId == null) {
            throw new BusinessException(403, "no permission");
        }
        
        // 获取导出配置以确定 pageCode
        CustomExportConfigDTO config = customExportService.getExportConfigByCode(exportCode);
        if (config == null) {
            throw new BusinessException(400, "导出配置不存在: " + exportCode);
        }
        
        // 检查导出权限
        PagePermission permission = permissionService.getPagePermission(userId, config.getPageCode());
        if (permission == null) {
            throw new BusinessException(403, "无导出权限");
        }
        
        Set<String> allowedButtons = permission.buttons();
        if (!allowedButtons.contains("*") && !allowedButtons.contains("自定义导出:" + exportCode)) {
            throw new BusinessException(403, "无导出权限");
        }
        
        customExportService.export(exportCode, request, response);
    }
}
