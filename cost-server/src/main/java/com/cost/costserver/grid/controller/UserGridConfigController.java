package com.cost.costserver.grid.controller;

import com.cost.costserver.common.BusinessException;
import com.cost.costserver.common.Result;
import com.cost.costserver.common.SecurityUtils;
import com.cost.costserver.grid.dto.SaveGridConfigRequest;
import com.cost.costserver.grid.service.UserGridConfigService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@Tag(name = "Grid config")
@RestController
@RequestMapping("/api/grid-config")
@RequiredArgsConstructor
public class UserGridConfigController {

    private final UserGridConfigService userGridConfigService;

    @Operation(summary = "Get user grid config")
    @GetMapping("/{pageCode}/{gridKey}")
    public Result<Object> getConfig(@PathVariable String pageCode, @PathVariable String gridKey) {
        Long userId = SecurityUtils.getCurrentUserId();
        if (userId == null) {
            throw new BusinessException(403, "no permission");
        }
        return Result.ok(userGridConfigService.getConfig(userId, pageCode, gridKey));
    }

    @Operation(summary = "Save user grid config")
    @PostMapping("/{pageCode}/{gridKey}")
    public Result<Void> saveConfig(
        @PathVariable String pageCode,
        @PathVariable String gridKey,
        @RequestBody SaveGridConfigRequest request
    ) {
        Long userId = SecurityUtils.getCurrentUserId();
        if (userId == null) {
            throw new BusinessException(403, "no permission");
        }
        if (request == null || request.getConfigData() == null) {
            throw new BusinessException(400, "configData is required");
        }
        userGridConfigService.saveConfig(userId, pageCode, gridKey, request.getConfigData());
        return Result.ok();
    }
}
