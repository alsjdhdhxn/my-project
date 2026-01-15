package com.cost.costserver.metadata.controller;

import com.cost.costserver.auth.dto.PagePermission;
import com.cost.costserver.auth.service.PermissionService;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.common.Result;
import com.cost.costserver.common.SecurityUtils;
import com.cost.costserver.metadata.dto.DictionaryItemDTO;
import com.cost.costserver.metadata.dto.LookupConfigDTO;
import com.cost.costserver.metadata.dto.PageComponentDTO;
import com.cost.costserver.metadata.dto.TableMetadataDTO;
import com.cost.costserver.metadata.service.MetadataService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "元数据接口")
@RestController
@RequestMapping("/api/metadata")
@RequiredArgsConstructor
public class MetadataController {

    private final MetadataService metadataService;
    private final PermissionService permissionService;

    @Operation(summary = "获取表元数据（原始，不含权限）")
    @GetMapping("/table/{tableCode}")
    public Result<TableMetadataDTO> getTableMetadata(@PathVariable String tableCode) {
        return Result.ok(metadataService.getTableMetadata(tableCode));
    }

    @Operation(summary = "获取表元数据（合并权限）")
    @GetMapping("/table/{tableCode}/page/{pageCode}")
    public Result<TableMetadataDTO> getTableMetadataWithPermission(
            @PathVariable String tableCode,
            @PathVariable String pageCode,
            @RequestParam(required = false) String gridKey) {
        Long userId = SecurityUtils.getCurrentUserId();
        if (userId == null) {
            throw new BusinessException(403, "无权限访问");
        }
        PagePermission permission = permissionService.getPagePermission(userId, pageCode);
        if (permission == null) {
            throw new BusinessException(403, "无权限访问");
        }
        return Result.ok(metadataService.getTableMetadataWithPermission(tableCode, pageCode, gridKey, permission, userId));
    }

    @Operation(summary = "获取页面组件树")
    @GetMapping("/page/{pageCode}")
    public Result<List<PageComponentDTO>> getPageComponents(@PathVariable String pageCode) {
        return Result.ok(metadataService.getPageComponents(pageCode));
    }

    @Operation(summary = "获取字典项")
    @GetMapping("/dict/{dictType}")
    public Result<List<DictionaryItemDTO>> getDictItems(@PathVariable String dictType) {
        return Result.ok(metadataService.getDictItems(dictType));
    }

    @Operation(summary = "获取弹窗选择器配置")
    @GetMapping("/lookup/{lookupCode}")
    public Result<LookupConfigDTO> getLookupConfig(@PathVariable String lookupCode) {
        return Result.ok(metadataService.getLookupConfig(lookupCode));
    }

    @Operation(summary = "清除元数据缓存")
    @PostMapping("/cache/clear")
    public Result<Void> clearCache(@RequestParam(required = false) String tableCode) {
        metadataService.clearCache(tableCode);
        return Result.ok();
    }
}
