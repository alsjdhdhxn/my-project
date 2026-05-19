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
import com.cost.costserver.metadata.service.WizardGenerateService;
import com.cost.costserver.metadata.service.ColumnOverrideMigrationService;
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
    private final WizardGenerateService wizardGenerateService;
    private final ColumnOverrideMigrationService columnOverrideMigrationService;

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

    // ==================== 审批流配置 ====================

    @GetMapping("/approval/flows")
    public Result<List<Map<String, Object>>> listApprovalFlows() {
        return Result.ok(metaConfigService.listApprovalFlows());
    }

    @PostMapping("/approval/flow")
    public Result<Map<String, Object>> saveApprovalFlow(@RequestBody Map<String, Object> flow) {
        return Result.ok(metaConfigService.saveApprovalFlow(flow));
    }

    @DeleteMapping("/approval/flow/{flowId}")
    public Result<Void> deleteApprovalFlow(@PathVariable Long flowId) {
        metaConfigService.deleteApprovalFlow(flowId);
        return Result.ok();
    }

    @DeleteMapping("/approval/page/{pageCode}")
    public Result<Void> deleteApprovalPage(@PathVariable String pageCode) {
        metaConfigService.deleteApprovalPage(pageCode);
        return Result.ok();
    }

    @GetMapping("/approval/flow/{flowId}/conditions")
    public Result<List<Map<String, Object>>> listApprovalConditions(@PathVariable Long flowId) {
        return Result.ok(metaConfigService.listApprovalConditions(flowId));
    }

    @PostMapping("/approval/condition")
    public Result<Map<String, Object>> saveApprovalCondition(@RequestBody Map<String, Object> condition) {
        return Result.ok(metaConfigService.saveApprovalCondition(condition));
    }

    @DeleteMapping("/approval/condition/{conditionId}")
    public Result<Void> deleteApprovalCondition(@PathVariable Long conditionId) {
        metaConfigService.deleteApprovalCondition(conditionId);
        return Result.ok();
    }

    @GetMapping("/approval/flow/{flowId}/nodes")
    public Result<List<Map<String, Object>>> listApprovalNodes(@PathVariable Long flowId) {
        return Result.ok(metaConfigService.listApprovalNodes(flowId));
    }

    @PostMapping("/approval/node")
    public Result<Map<String, Object>> saveApprovalNode(@RequestBody Map<String, Object> node) {
        return Result.ok(metaConfigService.saveApprovalNode(node));
    }

    @DeleteMapping("/approval/node/{nodeId}")
    public Result<Void> deleteApprovalNode(@PathVariable Long nodeId) {
        metaConfigService.deleteApprovalNode(nodeId);
        return Result.ok();
    }

    @GetMapping("/approval/node/{nodeId}/approvers")
    public Result<List<Map<String, Object>>> listApprovalApprovers(@PathVariable Long nodeId) {
        return Result.ok(metaConfigService.listApprovalApprovers(nodeId));
    }

    @PostMapping("/approval/approver")
    public Result<Map<String, Object>> saveApprovalApprover(@RequestBody Map<String, Object> approver) {
        return Result.ok(metaConfigService.saveApprovalApprover(approver));
    }

    @DeleteMapping("/approval/approver/{id}")
    public Result<Void> deleteApprovalApprover(@PathVariable Long id) {
        metaConfigService.deleteApprovalApprover(id);
        return Result.ok();
    }

    @GetMapping("/approval/reference-data")
    public Result<Map<String, Object>> getApprovalReferenceData() {
        return Result.ok(metaConfigService.getApprovalReferenceData());
    }

    @Operation(summary = "查询视图/表的物理列")
    @GetMapping("/view-columns")
    public Result<List<Map<String, Object>>> listViewColumns(
            @RequestParam(defaultValue = "CMX") String owner,
            @RequestParam String viewName) {
        return Result.ok(metaConfigService.listViewColumns(owner, viewName));
    }

    // ==================== 向导 ====================

    @Operation(summary = "向导：一键生成页面")
    @PostMapping("/wizard/generate")
    public Result<Object> wizardGenerate(@RequestBody WizardPayload payload) {
        try {
            WizardResult result = wizardGenerateService.generate(payload);
            webSocketHandler.broadcast("META_CONFIG_CHANGED", Map.of(
                    "entity", "wizard",
                    "pageCode", result.getPageCode() != null ? result.getPageCode() : ""
            ));
            return Result.ok(result);
        } catch (BusinessException e) {
            throw e; // 业务异常由全局处理器处理
        } catch (Exception e) {
            // 提取数据库错误详情
            Map<String, Object> detail = new java.util.LinkedHashMap<>();
            detail.put("message", e.getMessage());

            // 遍历整个异常链提取 ORA 错误码和 SQL
            String oraCode = null;
            String sql = null;
            Throwable cursor = e;
            while (cursor != null) {
                String msg = cursor.getMessage();
                if (msg != null) {
                    // 提取 ORA 错误码
                    if (oraCode == null && msg.contains("ORA-")) {
                        java.util.regex.Matcher m = java.util.regex.Pattern.compile("ORA-\\d+").matcher(msg);
                        if (m.find()) oraCode = m.group();
                    }
                    // 提取 SQL（MyBatis BadSqlGrammarException / StatementCallback 等通常包含 SQL）
                    if (sql == null) {
                        // 匹配常见格式: "### SQL: ..." 或 "; SQL [...]" 或 "bad SQL grammar [...]"
                        java.util.regex.Matcher sqlMatcher = java.util.regex.Pattern
                                .compile("(?:### SQL:|SQL \\[|bad SQL grammar \\[)\\s*(.+?)(?:\\]|###|$)", java.util.regex.Pattern.DOTALL)
                                .matcher(msg);
                        if (sqlMatcher.find()) {
                            sql = sqlMatcher.group(1).trim();
                            if (sql.length() > 1000) sql = sql.substring(0, 1000);
                        }
                    }
                }
                // 如果是 SQLException，可以直接取
                if (cursor instanceof java.sql.SQLException sqlEx && sql == null) {
                    sql = sqlEx.getMessage();
                }
                cursor = cursor.getCause();
            }

            if (oraCode != null) detail.put("oraCode", oraCode);
            if (sql != null) detail.put("sql", sql);

            Throwable root = e;
            while (root.getCause() != null) root = root.getCause();
            String rootMsg = root.getMessage();
            if (rootMsg != null && rootMsg.length() > 500) rootMsg = rootMsg.substring(0, 500);
            detail.put("rootCause", rootMsg);

            String summary = oraCode != null ? oraCode + ": " : "生成失败: ";
            String causeMsg = e.getCause() != null ? e.getCause().getMessage() : e.getMessage();
            summary += causeMsg != null && causeMsg.length() > 100 ? causeMsg.substring(0, 100) : causeMsg;
            return Result.fail(500, summary, detail);
        }
    }

    @Operation(summary = "向导：查询表主键列")
    @GetMapping("/wizard/pk-column")
    public Result<String> wizardPkColumn(
            @RequestParam(defaultValue = "CMX") String owner,
            @RequestParam String tableName) {
        String pkColumn = wizardGenerateService.getPkColumn(owner, tableName);
        if (pkColumn == null) {
            throw new BusinessException(400, "目标表缺少主键定义: " + tableName);
        }
        return Result.ok(pkColumn);
    }

    @Operation(summary = "查询数据库中的表/视图列表（支持模糊搜索）")
    @GetMapping("/db-objects")
    public Result<List<Map<String, Object>>> listDbObjects(
            @RequestParam(defaultValue = "CMX") String owner,
            @RequestParam(required = false) String keyword,
            @RequestParam(defaultValue = "TABLE,VIEW") String types) {
        return Result.ok(metaConfigService.listDbObjects(owner, keyword, types));
    }

    @Operation(summary = "向导：级联删除页面及相关元数据")
    @DeleteMapping("/wizard/cascade/{pageCode}")
    public Result<Void> wizardCascadeDelete(@PathVariable String pageCode) {
        wizardGenerateService.cascadeDeleteByPageCode(pageCode);
        webSocketHandler.broadcast("META_CONFIG_CHANGED", Map.of(
                "entity", "wizard",
                "pageCode", pageCode
        ));
        return Result.ok();
    }

    // ==================== 迁移工具 ====================

    @Operation(summary = "迁移：拆分共享表为页面独有")
    @GetMapping("/migration/split-tables")
    public Result<Map<String, Object>> migrationSplitTables() {
        return Result.ok(columnOverrideMigrationService.splitSharedTables());
    }

    @Operation(summary = "迁移：COLUMN_OVERRIDE 写入列元数据")
    @GetMapping("/migration/migrate-overrides")
    public Result<Map<String, Object>> migrationMigrateOverrides() {
        return Result.ok(columnOverrideMigrationService.migrateColumnOverrides());
    }

    @Operation(summary = "迁移：无 COLUMN_OVERRIDE 的表补默认值")
    @GetMapping("/migration/mark-unmigrated")
    public Result<Integer> migrationMarkUnmigrated() {
        return Result.ok(columnOverrideMigrationService.markUnmigratedTables());
    }

    @Operation(summary = "迁移：验证无共享表残留")
    @GetMapping("/migration/verify")
    public Result<Map<String, List<String>>> migrationVerify() {
        return Result.ok(columnOverrideMigrationService.verify());
    }
}
