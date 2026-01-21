package com.cost.costserver.export.controller;

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

@RestController
@RequestMapping("/api/export-config")
@RequiredArgsConstructor
public class ExportConfigController {

    private final CustomExportService customExportService;

    @GetMapping("/custom/{pageCode}")
    public Result<List<CustomExportConfigDTO>> getCustomExportConfigs(@PathVariable String pageCode) {
        Long userId = SecurityUtils.getCurrentUserId();
        if (userId == null) {
            throw new BusinessException(403, "no permission");
        }
        return Result.ok(customExportService.getExportConfigs(pageCode));
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
        customExportService.export(exportCode, request, response);
    }
}
