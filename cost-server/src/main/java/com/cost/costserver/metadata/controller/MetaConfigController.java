package com.cost.costserver.metadata.controller;

import com.cost.costserver.auth.entity.Resource;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.common.Result;
import com.cost.costserver.common.SecurityUtils;
import com.cost.costserver.config.AppWebSocketHandler;
import com.cost.costserver.export.entity.ExportConfig;
import com.cost.costserver.export.entity.ExportConfigDetail;
import com.cost.costserver.metadata.entity.*;
import com.cost.costserver.metadata.service.MetaConfigService;
import com.cost.costserver.metadata.service.MetadataService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * 元数据配置中心控制器（硬编码页面专用）
 */
@Tag(name = "元数据配置中心")
@RestController
@RequestMapping("/meta-config")
@RequiredArgsConstructor
public class MetaConfigController {

    private static final String SUPER_ADMIN_USERNAME = "admin";

    private final MetaConfigService metaConfigService;
    private final MetadataService metadataService;
    private final AppWebSocketHandler webSocketHandler;

    @ModelAttribute
    public void requireAdminUser() {
        String username = SecurityUtils.getCurrentUsername();
        if (username == null || !SUPER_ADMIN_USERNAME.equalsIgnoreCase(username)) {
            throw new BusinessException(403, "无权限访问");
        }
    }

    // ==================== 目录管理 ====================

    @GetMapping("/resources")
    public Result<List<Resource>> listResources() {
        return Result.ok(metaConfigService.listResources());
    }

    @PostMapping("/resource")
    public Result<Resource> saveResource(@RequestBody Resource resource) {
        return Result.ok(metaConfigService.saveResource(resource));
    }

    @DeleteMapping("/resource/{id}")
    public Result<Void> deleteResource(@PathVariable Long id) {
        metaConfigService.deleteResource(id);
        return Result.ok();
    }

    // ==================== 表管理 ====================

    @GetMapping("/tables")
    public Result<List<TableMetadata>> listTables() {
        return Result.ok(metaConfigService.listTables());
    }

    @PostMapping("/table")
    public Result<TableMetadata> saveTable(@RequestBody TableMetadata table) {
        TableMetadata saved = metaConfigService.saveTable(table);
        metadataService.clearCache(saved.getTableCode());
        return Result.ok(saved);
    }

    @DeleteMapping("/table/{id}")
    public Result<Void> deleteTable(@PathVariable Long id) {
        metaConfigService.deleteTable(id);
        metadataService.clearCache(null);
        return Result.ok();
    }

    @GetMapping("/table/{tableId}/columns")
    public Result<List<ColumnMetadata>> listColumns(@PathVariable Long tableId) {
        return Result.ok(metaConfigService.listColumns(tableId));
    }

    @PostMapping("/column")
    public Result<ColumnMetadata> saveColumn(@RequestBody ColumnMetadata column) {
        ColumnMetadata saved = metaConfigService.saveColumn(column);
        metadataService.clearCache(null);
        webSocketHandler.broadcast("META_CONFIG_CHANGED", Map.of(
                "entity", "column"
        ));
        return Result.ok(saved);
    }

    @DeleteMapping("/column/{id}")
    public Result<Void> deleteColumn(@PathVariable Long id) {
        metaConfigService.deleteColumn(id);
        metadataService.clearCache(null);
        return Result.ok();
    }

    // ==================== 页面管理 ====================

    @GetMapping("/components")
    public Result<List<Map<String, Object>>> listComponents() {
        return Result.ok(metaConfigService.listComponentsWithNames());
    }

    @PostMapping("/component")
    public Result<PageComponent> saveComponent(@RequestBody PageComponent component) {
        PageComponent saved = metaConfigService.saveComponent(component);
        metadataService.clearCache(null);
        webSocketHandler.broadcast("META_CONFIG_CHANGED",
                Map.of(
                        "pageCode", component.getPageCode() != null ? component.getPageCode() : "",
                        "entity", "component"
                ));
        return Result.ok(saved);
    }

    @DeleteMapping("/component/{id}")
    public Result<Void> deleteComponent(@PathVariable Long id) {
        metaConfigService.deleteComponent(id);
        metadataService.clearCache(null);
        return Result.ok();
    }

    @GetMapping("/rules")
    public Result<List<PageRule>> listRules(
            @RequestParam String pageCode,
            @RequestParam String componentKey) {
        return Result.ok(metaConfigService.listRules(pageCode, componentKey));
    }

    @PostMapping("/rule")
    public Result<PageRule> saveRule(@RequestBody PageRule rule) {
        PageRule saved = metaConfigService.saveRule(rule);
        metadataService.clearCache(null);
        webSocketHandler.broadcast("META_CONFIG_CHANGED",
                Map.of(
                        "pageCode", rule.getPageCode() != null ? rule.getPageCode() : "",
                        "entity", "rule",
                        "ruleType", rule.getRuleType() != null ? rule.getRuleType() : "",
                        "componentKey", rule.getComponentKey() != null ? rule.getComponentKey() : ""
                ));
        return Result.ok(saved);
    }

    @DeleteMapping("/rule/{id}")
    public Result<Void> deleteRule(@PathVariable Long id) {
        metaConfigService.deleteRule(id);
        metadataService.clearCache(null);
        webSocketHandler.broadcast("META_CONFIG_CHANGED", Map.of(
                "entity", "rule"
        ));
        return Result.ok();
    }

    // ==================== Lookup管理 ====================

    @GetMapping("/lookups")
    public Result<List<LookupConfig>> listLookups() {
        return Result.ok(metaConfigService.listLookups());
    }

    @PostMapping("/lookup")
    public Result<LookupConfig> saveLookup(@RequestBody LookupConfig lookup) {
        LookupConfig saved = metaConfigService.saveLookup(lookup);
        metadataService.clearCache(null);
        return Result.ok(saved);
    }

    @DeleteMapping("/lookup/{id}")
    public Result<Void> deleteLookup(@PathVariable Long id) {
        metaConfigService.deleteLookup(id);
        metadataService.clearCache(null);
        return Result.ok();
    }

    // ==================== 视图列查询 ====================

    @Operation(summary = "根据pageCode查询关联的表元数据")
    @GetMapping("/tables-by-page")
    public Result<List<TableMetadata>> listTablesByPageCode(@RequestParam String pageCode) {
        return Result.ok(metaConfigService.listTablesByPageCode(pageCode));
    }

    @Operation(summary = "根据pageCode查询关联的lookupCode列表")
    @GetMapping("/lookup-codes-by-page")
    public Result<List<String>> listLookupCodesByPageCode(@RequestParam String pageCode) {
        return Result.ok(metaConfigService.listLookupCodesByPageCode(pageCode));
    }

    @Operation(summary = "查询视图/表的物理列")
    @GetMapping("/export-configs")
    public Result<List<ExportConfig>> listExportConfigs() {
        return Result.ok(metaConfigService.listExportConfigs());
    }

    @PostMapping("/export-config")
    public Result<ExportConfig> saveExportConfig(@RequestBody ExportConfig config) {
        return Result.ok(metaConfigService.saveExportConfig(config));
    }

    @DeleteMapping("/export-config/{id}")
    public Result<Void> deleteExportConfig(@PathVariable Long id) {
        metaConfigService.deleteExportConfig(id);
        return Result.ok();
    }

    @GetMapping("/export-config/{configId}/details")
    public Result<List<ExportConfigDetail>> listExportConfigDetails(@PathVariable Long configId) {
        return Result.ok(metaConfigService.listExportConfigDetails(configId));
    }

    @PostMapping("/export-config-detail")
    public Result<ExportConfigDetail> saveExportConfigDetail(@RequestBody ExportConfigDetail detail) {
        return Result.ok(metaConfigService.saveExportConfigDetail(detail));
    }

    @DeleteMapping("/export-config-detail/{id}")
    public Result<Void> deleteExportConfigDetail(@PathVariable Long id) {
        metaConfigService.deleteExportConfigDetail(id);
        return Result.ok();
    }

    @Operation(summary = "查询视图/表的物理列")
    @GetMapping("/view-columns")
    public Result<List<Map<String, Object>>> listViewColumns(
            @RequestParam(defaultValue = "CMX") String owner,
            @RequestParam String viewName) {
        return Result.ok(metaConfigService.listViewColumns(owner, viewName));
    }
}
