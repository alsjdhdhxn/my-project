package com.cost.costserver.metadata.controller;

import com.cost.costserver.common.Result;
import com.cost.costserver.metadata.service.MetadataService;
import com.cost.costserver.metadata.vo.TableMetadataVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@Tag(name = "元数据接口")
@RestController
@RequestMapping("/api/metadata")
@RequiredArgsConstructor
public class MetadataController {

    private final MetadataService metadataService;

    @Operation(summary = "获取表元数据")
    @GetMapping("/table/{tableCode}")
    public Result<TableMetadataVO> getTableMetadata(@PathVariable String tableCode) {
        return Result.ok(metadataService.getTableMetadata(tableCode));
    }

    @Operation(summary = "清除元数据缓存")
    @PostMapping("/cache/clear")
    public Result<Void> clearCache(@RequestParam(required = false) String tableCode) {
        metadataService.clearCache(tableCode);
        return Result.ok();
    }
}
