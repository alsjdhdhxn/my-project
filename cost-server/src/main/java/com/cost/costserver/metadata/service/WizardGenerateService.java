package com.cost.costserver.metadata.service;

import cn.hutool.core.util.StrUtil;
import com.cost.costserver.auth.entity.Resource;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.config.AppWebSocketHandler;
import com.cost.costserver.dynamic.mapper.DynamicMapper;
import com.cost.costserver.metadata.entity.*;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Service
@RequiredArgsConstructor
@Slf4j
public class WizardGenerateService {

    private final MetaConfigService metaConfigService;
    private final DynamicMapper dynamicMapper;
    private final MetadataService metadataService;
    private final AppWebSocketHandler appWebSocketHandler;
    private final ObjectMapper objectMapper;

    /**
     * 事务性生成向导页面的所有元数据实体。
     * 任何异常触发完整回滚。
     */
    @Transactional(rollbackFor = Exception.class)
    public WizardResult generate(WizardPayload payload) {
        // ============ VALIDATION PHASE (before any writes) ============

        String pageCode = payload.getPageCode();
        if (StrUtil.isBlank(pageCode)) {
            throw new BusinessException(400, "页面编码不能为空");
        }
        if (StrUtil.isBlank(payload.getResourceName())) {
            throw new BusinessException(400, "页面名称不能为空");
        }

        // Check duplicate pageCode in T_COST_RESOURCE
        String checkSql = "SELECT COUNT(1) AS CNT FROM T_COST_RESOURCE WHERE PAGE_CODE = '"
                + pageCode.replace("'", "''") + "'";
        List<Map<String, Object>> checkRows = dynamicMapper.selectList(checkSql);
        if (!checkRows.isEmpty()) {
            Object cnt = checkRows.get(0).get("CNT");
            if (cnt != null && Long.parseLong(cnt.toString()) > 0) {
                throw new BusinessException(400, "页面编码重复: " + pageCode);
            }
        }

        WizardTable masterTable = payload.getMasterTable();
        if (masterTable == null) {
            throw new BusinessException(400, "主表配置不能为空");
        }
        if (StrUtil.isBlank(masterTable.getQueryView())) {
            throw new BusinessException(400, "主表视图名不能为空");
        }
        if (StrUtil.isBlank(masterTable.getTargetTable())) {
            throw new BusinessException(400, "主表目标表名不能为空");
        }
        if (StrUtil.isBlank(masterTable.getPkColumn())) {
            throw new BusinessException(400, "主表主键列不能为空");
        }
        if (StrUtil.isBlank(masterTable.getTableCode())) {
            throw new BusinessException(400, "主表 tableCode 不能为空");
        }
        if (masterTable.getColumns() == null || masterTable.getColumns().isEmpty()) {
            throw new BusinessException(400, "主表列配置不能为空");
        }

        // Validate detail tables
        List<WizardTable> detailTables = payload.getDetailTables();
        if ("master-detail".equals(payload.getMode()) && (detailTables == null || detailTables.isEmpty())) {
            throw new BusinessException(400, "主从模式下从表不能为空");
        }
        if (detailTables != null) {
            for (int i = 0; i < detailTables.size(); i++) {
                WizardTable detail = detailTables.get(i);
                if (StrUtil.isBlank(detail.getQueryView())) {
                    throw new BusinessException(400, "从表" + (i + 1) + "视图名不能为空");
                }
                if (StrUtil.isBlank(detail.getTargetTable())) {
                    throw new BusinessException(400, "从表" + (i + 1) + "目标表名不能为空");
                }
                if (StrUtil.isBlank(detail.getPkColumn())) {
                    throw new BusinessException(400, "从表" + (i + 1) + "主键列不能为空");
                }
                if (StrUtil.isBlank(detail.getParentFkColumn())) {
                    throw new BusinessException(400, "从表" + (i + 1) + "关联字段不能为空");
                }
                if (detail.getColumns() == null || detail.getColumns().isEmpty()) {
                    throw new BusinessException(400, "从表" + (i + 1) + "列配置不能为空");
                }
            }
        }

        // Validate targetColumn exists in target table for columns marked as real via manual assignment
        validateTargetColumns(masterTable);
        validateAuditFields(masterTable);
        validateViewDeletedField(masterTable);
        if (detailTables != null) {
            for (WizardTable detail : detailTables) {
                validateTargetColumns(detail);
                validateAuditFields(detail);
                validateViewDeletedField(detail);
            }
        }

        // Ensure sequences exist (create if missing)
        ensureSequenceExists(masterTable.getSequenceName());
        if (detailTables != null) {
            for (WizardTable detail : detailTables) {
                ensureSequenceExists(detail.getSequenceName());
            }
        }

        // ============ WRITE PHASE ============
        int totalCreated = 0;

        // Step 1: Create Resource
        Resource resource = new Resource();
        resource.setResourceType("PAGE");
        resource.setParentId(payload.getParentId());
        resource.setResourceName(payload.getResourceName());
        resource.setPageCode(pageCode);
        resource.setIcon(StrUtil.blankToDefault(payload.getIcon(), "folder"));
        resource.setRoute("/dynamic/" + pageCode);
        metaConfigService.saveResource(resource);
        totalCreated++;

        // Step 2: Create TableMetadata for master table
        TableMetadata masterMeta = buildTableMetadata(masterTable, null, null);
        metaConfigService.saveTable(masterMeta);
        totalCreated++;

        // Step 3: Create TableMetadata for each detail table
        List<TableMetadata> detailMetas = new ArrayList<>();
        if (detailTables != null) {
            for (WizardTable detail : detailTables) {
                TableMetadata detailMeta = buildTableMetadata(detail, masterTable.getTableCode(), detail.getParentFkColumn());
                metaConfigService.saveTable(detailMeta);
                detailMetas.add(detailMeta);
                totalCreated++;
            }
        }

        // Step 4: Create ColumnMetadata for each table's columns
        totalCreated += createColumnsForTable(masterMeta.getId(), masterTable.getColumns());
        if (detailTables != null) {
            for (int i = 0; i < detailTables.size(); i++) {
                WizardTable detail = detailTables.get(i);
                TableMetadata detailMeta = detailMetas.get(i);
                totalCreated += createColumnsForTable(detailMeta.getId(), detail.getColumns());
            }
        }

        // Step 5: Create PageComponents
        // root LAYOUT
        PageComponent root = new PageComponent();
        root.setPageCode(pageCode);
        root.setComponentKey("root");
        root.setComponentType("LAYOUT");
        root.setComponentConfig("{\"direction\":\"vertical\",\"gap\":8}");
        root.setSortOrder(0);
        metaConfigService.saveComponent(root);
        totalCreated++;

        // master grid
        PageComponent masterGrid = new PageComponent();
        masterGrid.setPageCode(pageCode);
        masterGrid.setComponentKey(masterTable.getTableCode());
        masterGrid.setComponentType("GRID");
        masterGrid.setParentKey("root");
        masterGrid.setRefTableCode(masterTable.getTableCode());
        masterGrid.setComponentConfig(buildMasterButtonConfig());
        masterGrid.setSortOrder(1);
        metaConfigService.saveComponent(masterGrid);
        totalCreated++;

        // detail grids
        if (detailTables != null) {
            for (int i = 0; i < detailTables.size(); i++) {
                WizardTable detail = detailTables.get(i);
                PageComponent detailGrid = new PageComponent();
                detailGrid.setPageCode(pageCode);
                detailGrid.setComponentKey(detail.getTableCode());
                detailGrid.setComponentType("DETAIL_GRID");
                detailGrid.setParentKey("root");
                detailGrid.setRefTableCode(detail.getTableCode());
                detailGrid.setComponentConfig(buildDetailButtonConfig(detail.getTableName()));
                detailGrid.setSortOrder(2 + i);
                metaConfigService.saveComponent(detailGrid);
                totalCreated++;
            }
        }

        // Step 6: 列属性已直接写入 COLUMN_METADATA（visible/editable/width 等），不再生成 COLUMN_OVERRIDE 规则

        // Clear metadata cache
        metadataService.clearCache(null);

        // Step 7: Grant admin role permission for the new page
        grantAdminPagePermission(pageCode);

        return new WizardResult(pageCode, totalCreated);
    }

    /**
     * 为 ADMIN 角色自动授权新页面（按角色编码查找，避免硬编码 ID）
     */
    private void grantAdminPagePermission(String pageCode) {
        // 查找 ADMIN 角色 ID
        String findRoleSql = "SELECT ID FROM T_COST_ROLE WHERE ROLE_CODE = 'ADMIN' AND ROWNUM = 1";
        List<Map<String, Object>> roleRows = dynamicMapper.selectList(findRoleSql);
        if (roleRows.isEmpty()) {
            log.warn("未找到 ADMIN 角色，跳过页面授权");
            return;
        }
        Object roleIdObj = roleRows.get(0).get("ID");
        if (roleIdObj == null) return;
        long roleId = Long.parseLong(roleIdObj.toString());

        String sql = "INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY) " +
                "VALUES (SEQ_COST_ROLE_PAGE.NEXTVAL, " + roleId + ", '" + pageCode.replace("'", "''") + "', '[\"*\"]', NULL, NULL)";
        dynamicMapper.insert(sql);
    }

    /**
     * 级联删除页面相关的所有元数据：
     * Resource → PageComponent → PageRule → TableMetadata → ColumnMetadata → RolePage
     */
    @Transactional(rollbackFor = Exception.class)
    public void cascadeDeleteByPageCode(String pageCode) {
        if (StrUtil.isBlank(pageCode)) {
            throw new BusinessException(400, "pageCode 不能为空");
        }
        String safe = pageCode.replace("'", "''");

        // 1. 删除页面规则
        dynamicMapper.update("DELETE FROM T_COST_PAGE_RULE WHERE PAGE_CODE = '" + safe + "'");
        // 2. 查出组件关联的 tableCode
        List<Map<String, Object>> comps = dynamicMapper.selectList(
                "SELECT REF_TABLE_CODE FROM T_COST_PAGE_COMPONENT WHERE PAGE_CODE = '" + safe + "' AND REF_TABLE_CODE IS NOT NULL AND DELETED = 0");
        // 3. 删除页面组件
        dynamicMapper.update("DELETE FROM T_COST_PAGE_COMPONENT WHERE PAGE_CODE = '" + safe + "'");
        // 4. 删除角色页面权限
        dynamicMapper.update("DELETE FROM T_COST_ROLE_PAGE WHERE PAGE_CODE = '" + safe + "'");
        // 5. 删除关联的表元数据和列元数据（仅删除未被其他页面引用的表）
        for (Map<String, Object> comp : comps) {
            Object tc = comp.get("REF_TABLE_CODE");
            if (tc == null) continue;
            String tableCode = tc.toString().replace("'", "''");
            // 检查该表是否被其他页面组件引用
            List<Map<String, Object>> otherRefs = dynamicMapper.selectList(
                    "SELECT COUNT(1) AS CNT FROM T_COST_PAGE_COMPONENT WHERE REF_TABLE_CODE = '" + tableCode +
                    "' AND PAGE_CODE != '" + safe + "' AND DELETED = 0");
            boolean sharedByOthers = !otherRefs.isEmpty() && otherRefs.get(0).get("CNT") != null
                    && Long.parseLong(otherRefs.get(0).get("CNT").toString()) > 0;
            if (sharedByOthers) {
                log.info("表 {} 被其他页面引用，跳过删除", tableCode);
                continue;
            }
            // 查 table id
            List<Map<String, Object>> tables = dynamicMapper.selectList(
                    "SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = '" + tableCode + "' AND DELETED = 0");
            for (Map<String, Object> t : tables) {
                Object tid = t.get("ID");
                if (tid != null) {
                    dynamicMapper.update("DELETE FROM T_COST_COLUMN_METADATA WHERE TABLE_METADATA_ID = " + tid);
                }
            }
            dynamicMapper.update("DELETE FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = '" + tableCode + "'");
        }
        // 6. 删除资源
        dynamicMapper.update("DELETE FROM T_COST_RESOURCE WHERE PAGE_CODE = '" + safe + "'");

        metadataService.clearCache(null);
        log.info("级联删除页面 {} 完成", pageCode);
    }

    /**
     * 校验序列是否存在，不存在则自动创建
     */
    private void ensureSequenceExists(String sequenceName) {
        if (StrUtil.isBlank(sequenceName)) return;
        String checkSql = "SELECT COUNT(1) AS CNT FROM USER_SEQUENCES WHERE SEQUENCE_NAME = '"
                + sequenceName.toUpperCase().replace("'", "''") + "'";
        List<Map<String, Object>> rows = dynamicMapper.selectList(checkSql);
        boolean exists = !rows.isEmpty() && rows.get(0).get("CNT") != null
                && Long.parseLong(rows.get(0).get("CNT").toString()) > 0;
        if (!exists) {
            log.info("序列 {} 不存在，自动创建", sequenceName);
            String createSql = "CREATE SEQUENCE " + sequenceName.toUpperCase()
                    + " START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE";
            dynamicMapper.update(createSql);
        }
    }

    /**
     * 校验视图必须暴露 DELETED 字段（动态查询拼接 a.DELETED = 0 依赖该字段）
     */
    private void validateViewDeletedField(WizardTable table) {
        if (table == null || StrUtil.isBlank(table.getQueryView())) return;
        List<Map<String, Object>> cols = metaConfigService.listViewColumns("CMX", table.getQueryView());
        boolean hasDeleted = false;
        for (Map<String, Object> col : cols) {
            Object cn = col.get("COLUMN_NAME");
            if (cn != null && "DELETED".equalsIgnoreCase(cn.toString())) {
                hasDeleted = true;
                break;
            }
        }
        if (!hasDeleted) {
            throw new BusinessException(400, "视图 " + table.getQueryView() + " 未暴露 DELETED 字段，动态查询将无法正常工作");
        }
    }

    /**
     * 校验目标表必须包含审计字段
     */
    private void validateAuditFields(WizardTable table) {
        if (table == null || StrUtil.isBlank(table.getTargetTable())) return;
        List<Map<String, Object>> cols = metaConfigService.listViewColumns("CMX", table.getTargetTable());
        Set<String> colNames = new HashSet<>();
        for (Map<String, Object> col : cols) {
            Object cn = col.get("COLUMN_NAME");
            if (cn != null) colNames.add(cn.toString().toUpperCase());
        }
        String[] required = {"DELETED", "CREATE_TIME", "UPDATE_TIME", "CREATE_BY", "UPDATE_BY"};
        List<String> missing = new ArrayList<>();
        for (String f : required) {
            if (!colNames.contains(f)) missing.add(f);
        }
        if (!missing.isEmpty()) {
            throw new BusinessException(400, "目标表 " + table.getTargetTable() + " 缺少审计字段: " + String.join(", ", missing));
        }
    }

    /**
     * 校验列的 targetColumn 是否真实存在于目标表中。
     * 对于标记为虚拟列(isVirtual=1)但填写了 targetColumn 的情况（表示要转为真实列），
     * 必须确认该列在目标表中确实存在。
     */
    private void validateTargetColumns(WizardTable table) {
        if (table == null || table.getColumns() == null || StrUtil.isBlank(table.getTargetTable())) {
            return;
        }
        // 查询目标表所有列
        List<Map<String, Object>> targetCols = metaConfigService.listViewColumns("CMX", table.getTargetTable());
        Set<String> targetColSet = new HashSet<>();
        for (Map<String, Object> col : targetCols) {
            Object colName = col.get("COLUMN_NAME");
            if (colName != null) targetColSet.add(colName.toString().toUpperCase());
        }

        for (WizardColumn wc : table.getColumns()) {
            String tc = wc.getTargetColumn();
            if (StrUtil.isBlank(tc)) continue;
            if (!targetColSet.contains(tc.toUpperCase())) {
                throw new BusinessException(400,
                        "表 " + table.getTargetTable() + " 中不存在列 " + tc +
                        "（字段 " + wc.getColumnName() + " 的 TARGET_COLUMN 无效）");
            }
        }
    }

    /**
     * 查询目标表的主键列名（通过 ALL_CONSTRAINTS + ALL_CONS_COLUMNS）
     */
    public String getPkColumn(String owner, String tableName) {
        String sql = "SELECT cc.COLUMN_NAME FROM ALL_CONSTRAINTS c " +
                "JOIN ALL_CONS_COLUMNS cc ON c.OWNER = cc.OWNER " +
                "AND c.CONSTRAINT_NAME = cc.CONSTRAINT_NAME " +
                "WHERE c.OWNER = '" + owner.toUpperCase().replace("'", "''") +
                "' AND c.TABLE_NAME = '" + tableName.toUpperCase().replace("'", "''") +
                "' AND c.CONSTRAINT_TYPE = 'P' ORDER BY cc.POSITION";
        List<Map<String, Object>> rows = dynamicMapper.selectList(sql);
        if (rows.isEmpty()) return null;
        return (String) rows.get(0).get("COLUMN_NAME");
    }

    // ==================== Private Helpers ====================

    private TableMetadata buildTableMetadata(WizardTable wizardTable, String parentTableCode, String parentFkColumn) {
        TableMetadata meta = new TableMetadata();
        meta.setTableCode(wizardTable.getTableCode());
        meta.setTableName(wizardTable.getTableName());
        meta.setQueryView(wizardTable.getQueryView());
        meta.setTargetTable(wizardTable.getTargetTable());
        meta.setSequenceName(wizardTable.getSequenceName());
        meta.setPkColumn(wizardTable.getPkColumn());
        if (StrUtil.isNotBlank(parentTableCode)) {
            meta.setParentTableCode(parentTableCode);
        }
        if (StrUtil.isNotBlank(parentFkColumn)) {
            meta.setParentFkColumn(parentFkColumn);
        }
        return meta;
    }

    private int createColumnsForTable(Long tableMetadataId, List<WizardColumn> columns) {
        if (columns == null || columns.isEmpty()) return 0;
        int count = 0;
        for (WizardColumn wc : columns) {
            ColumnMetadata col = new ColumnMetadata();
            col.setTableMetadataId(tableMetadataId);
            col.setColumnName(wc.getColumnName());
            col.setTargetColumn(wc.getTargetColumn());
            col.setHeaderText(wc.getHeaderText());
            col.setDataType(StrUtil.blankToDefault(wc.getDataType(), "text"));
            col.setDisplayOrder(wc.getDisplayOrder());
            col.setIsVirtual(wc.getIsVirtual() != null ? wc.getIsVirtual() : 0);
            col.setSortable(1);
            col.setFilterable(wc.getFilterable() != null && wc.getFilterable() ? 1 : 0);
            // 列属性直接写入（不再生成 COLUMN_OVERRIDE）
            boolean isVirtual = wc.getIsVirtual() != null && wc.getIsVirtual() == 1
                    && StrUtil.isBlank(wc.getTargetColumn());
            col.setVisible(wc.getVisible() != null && wc.getVisible() ? 1 : 0);
            col.setEditable(isVirtual ? 0 : (wc.getEditable() != null && wc.getEditable() ? 1 : 0));
            col.setSearchable(wc.getFilterable() != null && wc.getFilterable() ? 1 : 0);
            col.setWidth(computeWidth(wc));
            col.setCellEditor(mapCellEditor(wc.getWidgetType()));
            metaConfigService.saveColumn(col);
            count++;
        }
        return count;
    }

    private String buildMasterButtonConfig() {
        return "{\"buttons\":[" +
                "{\"action\":\"query\",\"label\":\"查询\"}," +
                "{\"action\":\"addRow\",\"label\":\"新增\"}," +
                "{\"action\":\"deleteRow\",\"label\":\"删除\",\"requiresRow\":true}," +
                "{\"action\":\"save\",\"label\":\"保存\"}," +
                "{\"action\":\"saveGridConfig\",\"label\":\"保存列配置\"}" +
                "]}";
    }

    private String buildDetailButtonConfig(String tableName) {
        String title = StrUtil.blankToDefault(tableName, "明细");
        return "{\"title\":\"" + escapeJson(title) + "\",\"buttons\":[" +
                "{\"action\":\"addRow\",\"label\":\"明细新增\",\"position\":\"both\"}," +
                "{\"action\":\"deleteRow\",\"label\":\"明细删除\",\"requiresRow\":true,\"position\":\"both\"}," +
                "{\"action\":\"saveGridConfig\",\"label\":\"保存列配置\",\"position\":\"context\"}" +
                "]}";
    }

    private String buildColumnOverrideJson(List<WizardColumn> columns) {
        if (columns == null || columns.isEmpty()) return "[]";

        ArrayNode array = objectMapper.createArrayNode();
        for (WizardColumn wc : columns) {
            ObjectNode node = objectMapper.createObjectNode();
            node.put("columnName", wc.getColumnName());

            // visible
            boolean visible = wc.getVisible() == null || wc.getVisible();
            node.put("visible", visible);

            // editable: virtual columns (still virtual at submission) MUST be non-editable
            // If isVirtual=1 but targetColumn is specified, it has been promoted to real
            boolean isVirtual = wc.getIsVirtual() != null && wc.getIsVirtual() == 1
                    && StrUtil.isBlank(wc.getTargetColumn());
            boolean editable;
            if (isVirtual) {
                editable = false;
            } else {
                editable = wc.getEditable() == null || wc.getEditable();
            }
            node.put("editable", editable);

            // width by widgetType
            node.put("width", computeWidth(wc));

            // cellEditor by widgetType
            String cellEditor = mapCellEditor(wc.getWidgetType());
            if (cellEditor != null) {
                node.put("cellEditor", cellEditor);
            }

            array.add(node);
        }

        try {
            return objectMapper.writeValueAsString(array);
        } catch (JsonProcessingException e) {
            log.error("Failed to serialize COLUMN_OVERRIDE JSON", e);
            return "[]";
        }
    }

    private int computeWidth(WizardColumn wc) {
        String widgetType = StrUtil.blankToDefault(wc.getWidgetType(), "text");
        switch (widgetType) {
            case "number":
                return 100;
            case "date":
                return 120;
            case "select":
                return 130;
            case "checkbox":
                return 80;
            default: // text
                String header = StrUtil.blankToDefault(wc.getHeaderText(), "");
                return header.length() > 10 ? 160 : 120;
        }
    }

    private String mapCellEditor(String widgetType) {
        if (StrUtil.isBlank(widgetType) || "text".equals(widgetType)) {
            return null; // omit, use default editor
        }
        switch (widgetType) {
            case "number":
                return "agNumberCellEditor";
            case "date":
                return "datePicker";
            case "select":
                return "agSelectCellEditor";
            case "checkbox":
                return "agCheckboxCellEditor";
            default:
                return null;
        }
    }

    private String escapeJson(String value) {
        if (value == null) return "";
        return value.replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "\\r")
                .replace("\t", "\\t");
    }
}
