package com.cost.costserver.export.controller;

import com.cost.costserver.export.dto.ExportExcelRequest;
import com.cost.costserver.export.service.ExcelExportService;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/export")
@RequiredArgsConstructor
public class ExcelExportController {

    private final ExcelExportService excelExportService;

    @PostMapping("/page/{pageCode}")
    public void exportPage(
            @PathVariable String pageCode,
            @RequestBody ExportExcelRequest request,
            HttpServletResponse response
    ) {
        excelExportService.exportPage(pageCode, request, response);
    }
}
