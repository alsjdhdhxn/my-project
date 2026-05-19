package com.cost.costserver.metadata.service;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.cost.costserver.dynamic.mapper.DynamicMapper;
import com.cost.costserver.metadata.entity.*;
import com.cost.costserver.metadata.mapper.*;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.stream.Collectors;

/**
 * COLUMN_OVERRIDE → COLUMN_METADATA 迁移服务
 *
 * 执行顺序：
 * 1. splitSharedTables() — 拆分共享表为页面独有副本
 * 2. migrateColumnOverrides() — 将 COLUMN_OVERRIDE 规则写入对应列
 * 3. markUnmigratedTables() — 无 COLUMN_OVERRIDE 的表补默认值
 * 4. verify() — 验证无共享表残留
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ColumnOverrideMigrationService {

    private final TableMetadataMapper tableMetadataMapper;
    private final ColumnMetadataMapper columnMetadataMapper;
    private final PageComponentMapper pageComponentMapper;
    private final PageRuleMapper pageRuleMapper;
    private final DynamicMapper dynamicMapper;
    private final ObjectMapper objectMapper;

    // ==================== 步骤 3-4：拆分共享表 ====================

    /**
     * 拆分共享表为页面独有副本。
     * 所有共享页面都复制独立副本，原始表标记为 SOURCE 不被引用。
     */
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> splitSharedTables() {
        // 1. 找出所有共享表（被多个 pageCode 引用的 tableCode）
        Map<String, List<PageComponent>> sharedTableUsage = findSharedTables();

        int splitCount = 0;
        int copiedColumns = 0;
        List<String> splitDetails = new ArrayList<>();

        for (Map.Entry<String, List<PageComponent>> entry : sharedTableUsage.entrySet()) {
            String originalTableCode = entry.getKey();
            List<PageComponent> users = entry.getValue();

            if (users.size() <= 1) continue; // 不共享

            TableMetadata originalTable = tableMetadataMapper.selectOne(
                new LambdaQueryWrapper<TableMetadata>()
                    .eq(TableMetadata::getTableCode, originalTableCode)
                    .eq(TableMetadata::getDeleted, 0));
            if (originalTable == null) continue;

            // 所有页面都复制独立副本
            for (PageComponent comp : users) {
                String newTableCode = generateUniqueTableCode(originalTableCode, comp.getPageCode());

                // 复制 TABLE_METADATA
                TableMetadata copy = new TableMetadata();
                copy.setTableCode(newTableCode);
                copy.setTableName(originalTable.getTableName());
                copy.setQueryView(originalTable.getQueryView());
                copy.setTargetTable(originalTable.getTargetTable());
                copy.setSequenceName(originalTable.getSequenceName());
                copy.setPkColumn(originalTable.getPkColumn());
                copy.setParentTableCode(originalTable.getParentTableCode());
                copy.setParentFkColumn(originalTable.getParentFkColumn());
                copy.setPageCode(comp.getPageCode());
                copy.setComponentKey(comp.getComponentKey());
                copy.setSourceTableCode(originalTableCode);
                // ID 由 save 方法生成
                Long newId = getNextId("SEQ_COST_TABLE_METADATA");
                copy.setId(newId);
                tableMetadataMapper.insert(copy);

                // 复制所有列
                List<ColumnMetadata> columns = columnMetadataMapper.selectList(
                    new LambdaQueryWrapper<ColumnMetadata>()
                        .eq(ColumnMetadata::getTableMetadataId, originalTable.getId())
                        .eq(ColumnMetadata::getDeleted, 0));

                for (ColumnMetadata col : columns) {
                    ColumnMetadata colCopy = new ColumnMetadata();
                    colCopy.setId(getNextId("SEQ_COST_COLUMN_METADATA"));
                    colCopy.setTableMetadataId(newId);
                    colCopy.setColumnName(col.getColumnName());
                    colCopy.setQueryColumn(col.getQueryColumn());
                    colCopy.setTargetColumn(col.getTargetColumn());
                    colCopy.setHeaderText(col.getHeaderText());
                    colCopy.setDataType(col.getDataType());
                    colCopy.setDisplayOrder(col.getDisplayOrder());
                    colCopy.setSortable(col.getSortable());
                    colCopy.setFilterable(col.getFilterable());
                    colCopy.setIsVirtual(col.getIsVirtual());
                    colCopy.setDictType(col.getDictType());
                    colCopy.setDeleted(0);
                    columnMetadataMapper.insert(colCopy);
                    copiedColumns++;
                }

                // 更新 PAGE_COMPONENT 引用
                comp.setRefTableCode(newTableCode);
                pageComponentMapper.updateById(comp);

                splitDetails.add(originalTableCode + " → " + newTableCode + " (page:" + comp.getPageCode() + ")");
                splitCount++;
            }

            // 标记原始表为 SOURCE（不再被引用）
            originalTable.setSourceTableCode("ORIGINAL");
            tableMetadataMapper.updateById(originalTable);
        }

        // 2. 不共享的表直接标记归属
        markSingleUseTables();

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("splitCount", splitCount);
        result.put("copiedColumns", copiedColumns);
        result.put("details", splitDetails);
        return result;
    }

    // ==================== 步骤 6：迁移 COLUMN_OVERRIDE ====================

    /**
     * 将每个页面的 COLUMN_OVERRIDE 规则写入对应的独立列元数据
     */
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> migrateColumnOverrides() {
        List<PageRule> rules = pageRuleMapper.selectList(
            new LambdaQueryWrapper<PageRule>()
                .eq(PageRule::getRuleType, "COLUMN_OVERRIDE")
                .eq(PageRule::getDeleted, 0));

        int migratedRules = 0;
        int migratedColumns = 0;
        List<String> errors = new ArrayList<>();

        for (PageRule rule : rules) {
            try {
                int cols = migrateOneRule(rule);
                migratedColumns += cols;
                migratedRules++;

                // 标记规则为已迁移
                rule.setDescription("[已迁移] " + StrUtil.blankToDefault(rule.getDescription(), ""));
                pageRuleMapper.updateById(rule);
            } catch (Exception e) {
                errors.add("Rule " + rule.getId() + " (" + rule.getPageCode() + "/" + rule.getComponentKey() + "): " + e.getMessage());
                log.error("迁移规则失败: ruleId={}", rule.getId(), e);
            }
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("migratedRules", migratedRules);
        result.put("migratedColumns", migratedColumns);
        result.put("errors", errors);
        return result;
    }

    // ==================== 步骤补充：无 COLUMN_OVERRIDE 的表补默认值 ====================

    /**
     * 对没有 COLUMN_OVERRIDE 的页面表，设默认值并标记 MIGRATED=1
     */
    @Transactional(rollbackFor = Exception.class)
    public int markUnmigratedTables() {
        String sql = "UPDATE T_COST_COLUMN_METADATA SET " +
            "VISIBLE = 1, EDITABLE = 1, REQUIRED = 0, SEARCHABLE = 0, MIGRATED = 1 " +
            "WHERE (MIGRATED = 0 OR MIGRATED IS NULL) AND DELETED = 0";
        return dynamicMapper.update(sql);
    }

    // ==================== 验证 ====================

    /**
     * 验证：所有 tableCode 只被 1 个 pageCode 引用
     */
    public Map<String, List<String>> verify() {
        Map<String, List<PageComponent>> usage = findSharedTables();
        Map<String, List<String>> shared = new LinkedHashMap<>();
        for (Map.Entry<String, List<PageComponent>> entry : usage.entrySet()) {
            if (entry.getValue().size() > 1) {
                shared.put(entry.getKey(), entry.getValue().stream()
                    .map(c -> c.getPageCode() + "/" + c.getComponentKey())
                    .collect(Collectors.toList()));
            }
        }
        return shared; // 期望为空
    }

    // ==================== Private Helpers ====================

    /**
     * 找出所有共享表——复用 listTablesByPageCode 的完整解析逻辑
     * 包括 REF_TABLE_CODE 和 componentConfig JSON 中的 tabs[].tableCode
     */
    private Map<String, List<PageComponent>> findSharedTables() {
        List<PageComponent> allComps = pageComponentMapper.selectList(
            new LambdaQueryWrapper<PageComponent>().eq(PageComponent::getDeleted, 0));

        Map<String, List<PageComponent>> tableToComps = new LinkedHashMap<>();

        for (PageComponent comp : allComps) {
            // 1. REF_TABLE_CODE
            if (StrUtil.isNotBlank(comp.getRefTableCode())) {
                tableToComps.computeIfAbsent(comp.getRefTableCode(), k -> new ArrayList<>()).add(comp);
            }
            // 2. componentConfig JSON 中的 tabs[].tableCode
            if (StrUtil.isNotBlank(comp.getComponentConfig())) {
                try {
                    JsonNode config = objectMapper.readTree(comp.getComponentConfig());
                    JsonNode tabs = config.get("tabs");
                    if (tabs != null && tabs.isArray()) {
                        for (JsonNode tab : tabs) {
                            String tc = tab.has("tableCode") ? tab.get("tableCode").asText() : null;
                            if (StrUtil.isNotBlank(tc)) {
                                tableToComps.computeIfAbsent(tc, k -> new ArrayList<>()).add(comp);
                            }
                        }
                    }
                } catch (Exception ignored) {}
            }
        }

        // 只返回被多个不同 pageCode 引用的
        Map<String, List<PageComponent>> shared = new LinkedHashMap<>();
        for (Map.Entry<String, List<PageComponent>> entry : tableToComps.entrySet()) {
            Set<String> pageCodes = entry.getValue().stream()
                .map(PageComponent::getPageCode)
                .collect(Collectors.toSet());
            if (pageCodes.size() > 1) {
                shared.put(entry.getKey(), entry.getValue());
            }
        }
        return shared;
    }

    /**
     * 不共享的表直接标记归属
     */
    private void markSingleUseTables() {
        List<PageComponent> allComps = pageComponentMapper.selectList(
            new LambdaQueryWrapper<PageComponent>()
                .eq(PageComponent::getDeleted, 0)
                .isNotNull(PageComponent::getRefTableCode));

        for (PageComponent comp : allComps) {
            if (StrUtil.isBlank(comp.getRefTableCode())) continue;
            TableMetadata table = tableMetadataMapper.selectOne(
                new LambdaQueryWrapper<TableMetadata>()
                    .eq(TableMetadata::getTableCode, comp.getRefTableCode())
                    .eq(TableMetadata::getDeleted, 0));
            if (table != null && StrUtil.isBlank(table.getPageCode())) {
                table.setPageCode(comp.getPageCode());
                table.setComponentKey(comp.getComponentKey());
                tableMetadataMapper.updateById(table);
            }
        }
    }

    private int migrateOneRule(PageRule rule) throws Exception {
        if (StrUtil.isBlank(rule.getRules())) return 0;

        // 找到该组件当前引用的表
        PageComponent comp = pageComponentMapper.selectOne(
            new LambdaQueryWrapper<PageComponent>()
                .eq(PageComponent::getPageCode, rule.getPageCode())
                .eq(PageComponent::getComponentKey, rule.getComponentKey())
                .eq(PageComponent::getDeleted, 0));
        if (comp == null) return 0;

        String tableCode = comp.getRefTableCode();
        if (StrUtil.isBlank(tableCode)) return 0;

        TableMetadata table = tableMetadataMapper.selectOne(
            new LambdaQueryWrapper<TableMetadata>()
                .eq(TableMetadata::getTableCode, tableCode)
                .eq(TableMetadata::getDeleted, 0));
        if (table == null) return 0;

        JsonNode items = objectMapper.readTree(rule.getRules());
        if (!items.isArray()) return 0;

        int count = 0;
        for (JsonNode item : items) {
            String columnName = item.has("columnName") ? item.get("columnName").asText() : null;
            Long columnId = item.has("columnId") && !item.get("columnId").isNull() ? item.get("columnId").asLong() : null;

            if (StrUtil.isBlank(columnName) && columnId == null) continue;

            // 找列
            ColumnMetadata col = findColumn(table.getId(), columnId, columnName);
            if (col == null) continue;

            // 写入基础属性
            if (item.has("visible")) col.setVisible(item.get("visible").asBoolean() ? 1 : 0);
            if (item.has("editable")) col.setEditable(item.get("editable").asBoolean() ? 1 : 0);
            if (item.has("required")) col.setRequired(item.get("required").asBoolean() ? 1 : 0);
            if (item.has("searchable")) col.setSearchable(item.get("searchable").asBoolean() ? 1 : 0);
            if (item.has("width")) col.setWidth(item.get("width").asInt());
            if (item.has("pinned") && !item.get("pinned").isNull()) col.setPinned(item.get("pinned").asText());
            if (item.has("cellEditor") && !item.get("cellEditor").isNull()) col.setCellEditor(item.get("cellEditor").asText());

            // defaultValue 处理（超长放 RULES_CONFIG）
            if (item.has("defaultValue") && !item.get("defaultValue").isNull()) {
                String dv = item.get("defaultValue").isTextual()
                    ? item.get("defaultValue").asText()
                    : item.get("defaultValue").toString();
                if (dv.length() <= 1000) {
                    col.setDefaultValue(dv);
                } else {
                    // 超长放 RULES_CONFIG
                    ObjectNode rc = getOrCreateRulesConfig(col);
                    rc.set("defaultValue", item.get("defaultValue"));
                    col.setRulesConfig(objectMapper.writeValueAsString(rc));
                }
            }

            // 复杂配置合并到 RULES_CONFIG
            ObjectNode rulesConfig = getOrCreateRulesConfig(col);
            boolean rcChanged = false;
            if (item.has("format") && !item.get("format").isNull()) { rulesConfig.set("format", item.get("format")); rcChanged = true; }
            if (item.has("precision") && !item.get("precision").isNull()) { rulesConfig.put("precision", item.get("precision").asInt()); rcChanged = true; }
            if (item.has("trimZeros") && !item.get("trimZeros").isNull()) { rulesConfig.put("trimZeros", item.get("trimZeros").asBoolean()); rcChanged = true; }
            if (item.has("roundMode") && !item.get("roundMode").isNull()) { rulesConfig.put("roundMode", item.get("roundMode").asText()); rcChanged = true; }
            if (item.has("cellEditorParams") && !item.get("cellEditorParams").isNull()) { rulesConfig.set("cellEditorParams", item.get("cellEditorParams")); rcChanged = true; }
            if (item.has("aggFunc") && !item.get("aggFunc").isNull()) { rulesConfig.put("aggFunc", item.get("aggFunc").asText()); rcChanged = true; }
            if (item.has("rulesConfig") && !item.get("rulesConfig").isNull()) {
                // 深度合并
                JsonNode overrideRc = item.get("rulesConfig");
                if (overrideRc.isObject()) {
                    overrideRc.fields().forEachRemaining(field -> rulesConfig.set(field.getKey(), field.getValue()));
                    rcChanged = true;
                }
            }

            if (rcChanged) {
                col.setRulesConfig(objectMapper.writeValueAsString(rulesConfig));
            }

            // 标记已迁移
            col.setMigrated(1);
            columnMetadataMapper.updateById(col);
            count++;
        }

        // 该表所有列标记为已迁移
        String markSql = "UPDATE T_COST_COLUMN_METADATA SET MIGRATED = 1 " +
            "WHERE TABLE_METADATA_ID = " + table.getId() + " AND (MIGRATED = 0 OR MIGRATED IS NULL)";
        dynamicMapper.update(markSql);

        return count;
    }

    private ColumnMetadata findColumn(Long tableMetadataId, Long columnId, String columnName) {
        if (columnId != null) {
            ColumnMetadata col = columnMetadataMapper.selectById(columnId);
            if (col != null && col.getTableMetadataId().equals(tableMetadataId)) return col;
        }
        if (StrUtil.isNotBlank(columnName)) {
            return columnMetadataMapper.selectOne(
                new LambdaQueryWrapper<ColumnMetadata>()
                    .eq(ColumnMetadata::getTableMetadataId, tableMetadataId)
                    .eq(ColumnMetadata::getColumnName, columnName)
                    .eq(ColumnMetadata::getDeleted, 0));
        }
        return null;
    }

    private ObjectNode getOrCreateRulesConfig(ColumnMetadata col) {
        if (StrUtil.isNotBlank(col.getRulesConfig())) {
            try {
                JsonNode node = objectMapper.readTree(col.getRulesConfig());
                if (node.isObject()) return (ObjectNode) node;
            } catch (Exception ignored) {}
        }
        return objectMapper.createObjectNode();
    }

    private String generateUniqueTableCode(String originalCode, String pageCode) {
        // 用 pageCode 的 hashCode 取 4 位 hex
        String hash = Integer.toHexString(Math.abs(pageCode.hashCode())).substring(0, 4).toUpperCase();
        String candidate = originalCode + "_P" + hash;
        // 截断到 64 字符
        if (candidate.length() > 64) {
            candidate = candidate.substring(0, 64);
        }
        // 防重
        int suffix = 0;
        String finalCode = candidate;
        while (tableMetadataMapper.selectCount(
            new LambdaQueryWrapper<TableMetadata>().eq(TableMetadata::getTableCode, finalCode)) > 0) {
            suffix++;
            finalCode = candidate.substring(0, Math.min(candidate.length(), 61)) + "_" + suffix;
        }
        return finalCode;
    }

    private Long getNextId(String seqName) {
        return dynamicMapper.getNextSequenceValue(seqName);
    }
}
