package com.cost.costserver.metadata.service;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.cost.costserver.auth.entity.Resource;
import com.cost.costserver.auth.entity.RolePage;
import com.cost.costserver.auth.mapper.ResourceMapper;
import com.cost.costserver.auth.mapper.RolePageMapper;
import com.cost.costserver.dynamic.mapper.DynamicMapper;
import com.cost.costserver.export.entity.ExportConfig;
import com.cost.costserver.export.entity.ExportConfigDetail;
import com.cost.costserver.export.mapper.ExportConfigDetailMapper;
import com.cost.costserver.export.mapper.ExportConfigMapper;
import com.cost.costserver.grid.entity.UserGridConfig;
import com.cost.costserver.grid.mapper.UserGridConfigMapper;
import com.cost.costserver.metadata.entity.*;
import com.cost.costserver.metadata.mapper.*;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class MetaConfigService {

    private final ResourceMapper resourceMapper;
    private final RolePageMapper rolePageMapper;
    private final TableMetadataMapper tableMetadataMapper;
    private final ColumnMetadataMapper columnMetadataMapper;
    private final PageComponentMapper pageComponentMapper;
    private final PageRuleMapper pageRuleMapper;
    private final LookupConfigMapper lookupConfigMapper;
    private final ExportConfigMapper exportConfigMapper;
    private final ExportConfigDetailMapper exportConfigDetailMapper;
    private final UserGridConfigMapper userGridConfigMapper;
    private final DynamicMapper dynamicMapper;
    private final ObjectMapper objectMapper;

    private Long nextId(String seq) {
        return dynamicMapper.getNextSequenceValue(seq);
    }

    // ==================== 目录管理 ====================

    public List<Resource> listResources() {
        return resourceMapper.selectList(
            new LambdaQueryWrapper<Resource>().orderByAsc(Resource::getSortOrder)
        );
    }

    @Transactional
    public Resource saveResource(Resource r) {
        if (r.getId() == null) {
            r.setId(nextId("SEQ_COST_RESOURCE"));
            resourceMapper.insert(r);
        } else {
            resourceMapper.updateById(r);
        }
        return r;
    }

    @Transactional
    public void deleteResource(Long id) {
        resourceMapper.deleteById(id);
    }

    // ==================== 表管理 ====================

    public List<TableMetadata> listTables() {
        return tableMetadataMapper.selectList(
            new LambdaQueryWrapper<TableMetadata>().orderByAsc(TableMetadata::getId)
        );
    }

    @Transactional
    public TableMetadata saveTable(TableMetadata t) {
        if (t.getId() == null) {
            t.setId(nextId("SEQ_COST_TABLE_METADATA"));
            tableMetadataMapper.insert(t);
        } else {
            tableMetadataMapper.updateById(t);
        }
        return t;
    }

    @Transactional
    public void deleteTable(Long id) {
        tableMetadataMapper.deleteById(id);
    }

    public List<ColumnMetadata> listColumns(Long tableMetadataId) {
        return columnMetadataMapper.selectList(
            new LambdaQueryWrapper<ColumnMetadata>()
                .eq(ColumnMetadata::getTableMetadataId, tableMetadataId)
                .orderByAsc(ColumnMetadata::getDisplayOrder)
        );
    }

    @Transactional
    public ColumnMetadata saveColumn(ColumnMetadata c) {
        if (c.getId() == null) {
            c.setId(nextId("SEQ_COST_COLUMN_METADATA"));
            columnMetadataMapper.insert(c);
        } else {
            ColumnMetadata existing = columnMetadataMapper.selectById(c.getId());
            columnMetadataMapper.updateById(c);
            if (existing != null) {
                migrateColumnLinkedConfigs(existing, c);
            }
        }
        return c;
    }

    @Transactional
    public void deleteColumn(Long id) {
        columnMetadataMapper.deleteById(id);
    }

    private void migrateColumnLinkedConfigs(ColumnMetadata existing, ColumnMetadata current) {
        if (existing == null || current == null || current.getId() == null) {
            return;
        }
        Long tableMetadataId = current.getTableMetadataId() != null ? current.getTableMetadataId() : existing.getTableMetadataId();
        if (tableMetadataId == null) {
            return;
        }
        TableMetadata table = tableMetadataMapper.selectById(tableMetadataId);
        if (table == null || StrUtil.isBlank(table.getTableCode())) {
            return;
        }
        List<GridBinding> bindings = findGridBindingsByTableCode(table.getTableCode());
        if (bindings.isEmpty()) {
            return;
        }

        String previousColumnName = StrUtil.blankToDefault(existing.getColumnName(), current.getColumnName());
        String currentColumnName = StrUtil.blankToDefault(current.getColumnName(), existing.getColumnName());

        migrateColumnOverrideRules(bindings, current.getId(), previousColumnName, currentColumnName);
        migrateRoleColumnPolicies(bindings, current.getId(), previousColumnName, currentColumnName);
        migrateUserGridConfigs(bindings, current.getId(), previousColumnName, currentColumnName);
    }

    private List<GridBinding> findGridBindingsByTableCode(String tableCode) {
        if (StrUtil.isBlank(tableCode)) {
            return Collections.emptyList();
        }
        List<PageComponent> components = pageComponentMapper.selectList(
            new LambdaQueryWrapper<PageComponent>().eq(PageComponent::getDeleted, 0)
        );
        Map<String, GridBinding> bindings = new LinkedHashMap<>();
        for (PageComponent component : components) {
            if (component == null || StrUtil.isBlank(component.getPageCode())) {
                continue;
            }
            String componentType = component.getComponentType();
            if (("GRID".equals(componentType) || "DETAIL_GRID".equals(componentType))
                    && StrUtil.equals(tableCode, component.getRefTableCode())
                    && StrUtil.isNotBlank(component.getComponentKey())) {
                GridBinding binding = new GridBinding(component.getPageCode(), component.getComponentKey());
                bindings.put(binding.pageCode() + "#" + binding.gridKey(), binding);
                continue;
            }
            if (!"TABS".equals(componentType) || StrUtil.isBlank(component.getComponentConfig())) {
                continue;
            }
            try {
                JsonNode tabs = objectMapper.readTree(component.getComponentConfig()).path("tabs");
                if (!tabs.isArray()) {
                    continue;
                }
                for (JsonNode tab : tabs) {
                    if (!StrUtil.equals(tableCode, text(tab, "tableCode"))) {
                        continue;
                    }
                    String tabKey = text(tab, "key");
                    if (StrUtil.isBlank(tabKey)) {
                        continue;
                    }
                    GridBinding binding = new GridBinding(component.getPageCode(), tabKey);
                    bindings.put(binding.pageCode() + "#" + binding.gridKey(), binding);
                }
            } catch (Exception ignored) {
            }
        }
        return new ArrayList<>(bindings.values());
    }

    private void migrateColumnOverrideRules(
            List<GridBinding> bindings,
            Long columnId,
            String oldColumnName,
            String newColumnName) {
        if (bindings == null || bindings.isEmpty()) {
            return;
        }
        Set<String> pageCodes = new LinkedHashSet<>();
        Set<String> componentKeys = new LinkedHashSet<>();
        for (GridBinding binding : bindings) {
            pageCodes.add(binding.pageCode());
            componentKeys.addAll(binding.candidateGridKeys());
        }

        List<PageRule> rules = pageRuleMapper.selectList(
            new LambdaQueryWrapper<PageRule>()
                .eq(PageRule::getRuleType, "COLUMN_OVERRIDE")
                .eq(PageRule::getDeleted, 0)
                .in(PageRule::getPageCode, pageCodes)
                .in(PageRule::getComponentKey, componentKeys)
        );
        for (PageRule rule : rules) {
            if (rule == null || StrUtil.isBlank(rule.getRules())) {
                continue;
            }
            GridBinding matched = bindings.stream()
                .filter(binding -> StrUtil.equals(binding.pageCode(), rule.getPageCode())
                    && binding.candidateGridKeys().contains(rule.getComponentKey()))
                .findFirst()
                .orElse(null);
            if (matched == null) {
                continue;
            }
            String migrated = migrateColumnOverrideJson(rule.getRules(), columnId, oldColumnName, newColumnName);
            if (migrated != null) {
                rule.setRules(migrated);
                pageRuleMapper.updateById(rule);
            }
        }
    }

    private void migrateRoleColumnPolicies(
            List<GridBinding> bindings,
            Long columnId,
            String oldColumnName,
            String newColumnName) {
        if (bindings == null || bindings.isEmpty()) {
            return;
        }
        Set<String> pageCodes = bindings.stream().map(GridBinding::pageCode).collect(java.util.stream.Collectors.toCollection(LinkedHashSet::new));
        List<RolePage> rolePages = rolePageMapper.selectList(
            new LambdaQueryWrapper<RolePage>().in(RolePage::getPageCode, pageCodes)
        );
        Map<String, Set<String>> tableKeysByPage = new LinkedHashMap<>();
        for (GridBinding binding : bindings) {
            tableKeysByPage.computeIfAbsent(binding.pageCode(), ignored -> new LinkedHashSet<>())
                .addAll(binding.candidateGridKeys());
        }

        for (RolePage rolePage : rolePages) {
            if (rolePage == null || StrUtil.isBlank(rolePage.getColumnPolicy())) {
                continue;
            }
            String migrated = migrateColumnPolicyJson(
                rolePage.getColumnPolicy(),
                tableKeysByPage.getOrDefault(rolePage.getPageCode(), Collections.emptySet()),
                columnId,
                oldColumnName,
                newColumnName
            );
            if (migrated != null) {
                rolePage.setColumnPolicy(migrated);
                rolePageMapper.updateById(rolePage);
            }
        }
    }

    private void migrateUserGridConfigs(
            List<GridBinding> bindings,
            Long columnId,
            String oldColumnName,
            String newColumnName) {
        if (bindings == null || bindings.isEmpty()) {
            return;
        }
        Set<String> pageCodes = bindings.stream().map(GridBinding::pageCode).collect(java.util.stream.Collectors.toCollection(LinkedHashSet::new));
        Set<String> gridKeys = new LinkedHashSet<>();
        for (GridBinding binding : bindings) {
            gridKeys.addAll(binding.candidateGridKeys());
        }
        List<UserGridConfig> configs = userGridConfigMapper.selectList(
            new LambdaQueryWrapper<UserGridConfig>()
                .eq(UserGridConfig::getDeleted, 0)
                .in(UserGridConfig::getPageCode, pageCodes)
                .in(UserGridConfig::getGridKey, gridKeys)
        );

        for (UserGridConfig config : configs) {
            if (config == null || StrUtil.isBlank(config.getConfigData())) {
                continue;
            }
            GridBinding matched = bindings.stream()
                .filter(binding -> StrUtil.equals(binding.pageCode(), config.getPageCode())
                    && binding.candidateGridKeys().contains(config.getGridKey()))
                .findFirst()
                .orElse(null);
            if (matched == null) {
                continue;
            }
            String migrated = migrateUserGridConfigJson(config.getConfigData(), columnId, oldColumnName, newColumnName);
            if (migrated != null) {
                config.setConfigData(migrated);
                userGridConfigMapper.updateById(config);
            }
        }
    }

    private String migrateColumnOverrideJson(String raw, Long columnId, String oldColumnName, String newColumnName) {
        try {
            JsonNode root = objectMapper.readTree(raw);
            if (!(root instanceof ArrayNode arrayNode)) {
                return null;
            }
            boolean changed = false;
            for (JsonNode item : arrayNode) {
                if (!(item instanceof ObjectNode objectNode) || !matchesColumnReference(objectNode, columnId, oldColumnName, newColumnName)) {
                    continue;
                }
                objectNode.put("columnId", columnId);
                objectNode.put("columnName", newColumnName);
                changed = true;
            }
            return changed ? objectMapper.writeValueAsString(arrayNode) : null;
        } catch (Exception ignored) {
            return null;
        }
    }

    private String migrateColumnPolicyJson(
            String raw,
            Set<String> tableKeys,
            Long columnId,
            String oldColumnName,
            String newColumnName) {
        try {
            JsonNode root = objectMapper.readTree(raw);
            if (!(root instanceof ObjectNode rootObject)) {
                return null;
            }
            boolean changed = migratePermissionContainer(rootObject, columnId, oldColumnName, newColumnName);
            for (String tableKey : tableKeys) {
                JsonNode tableNode = rootObject.get(tableKey);
                if (tableNode instanceof ObjectNode tableObject) {
                    changed = migratePermissionContainer(tableObject, columnId, oldColumnName, newColumnName) || changed;
                }
            }
            return changed ? objectMapper.writeValueAsString(rootObject) : null;
        } catch (Exception ignored) {
            return null;
        }
    }

    private boolean migratePermissionContainer(
            ObjectNode container,
            Long columnId,
            String oldColumnName,
            String newColumnName) {
        if (container == null) {
            return false;
        }
        List<String> matchedKeys = new ArrayList<>();
        ObjectNode matchedNode = null;
        java.util.Iterator<Map.Entry<String, JsonNode>> fields = container.fields();
        while (fields.hasNext()) {
            Map.Entry<String, JsonNode> entry = fields.next();
            if (!(entry.getValue() instanceof ObjectNode permissionNode) || !looksLikePermissionNode(permissionNode)) {
                continue;
            }
            if (!matchesPolicyReference(entry.getKey(), permissionNode, columnId, oldColumnName, newColumnName)) {
                continue;
            }
            matchedKeys.add(entry.getKey());
            if (matchedNode == null) {
                matchedNode = permissionNode.deepCopy();
            }
        }
        if (matchedNode == null) {
            return false;
        }
        String canonicalKey = String.valueOf(columnId);
        matchedNode.put("columnId", columnId);
        matchedNode.put("columnName", newColumnName);
        matchedKeys.forEach(container::remove);
        container.set(canonicalKey, matchedNode);
        return true;
    }

    private String migrateUserGridConfigJson(String raw, Long columnId, String oldColumnName, String newColumnName) {
        try {
            JsonNode root = objectMapper.readTree(raw);
            boolean changed = false;
            if (root instanceof ArrayNode arrayNode) {
                changed = migratePreferenceArray(arrayNode, columnId, oldColumnName, newColumnName);
            } else if (root instanceof ObjectNode objectNode) {
                JsonNode columnsNode = objectNode.get("columns");
                if (columnsNode instanceof ArrayNode columnsArray) {
                    changed = migratePreferenceArray(columnsArray, columnId, oldColumnName, newColumnName);
                }
                JsonNode stateNode = objectNode.get("columnState");
                if (stateNode instanceof ArrayNode stateArray) {
                    changed = migratePreferenceArray(stateArray, columnId, oldColumnName, newColumnName) || changed;
                }
            }
            return changed ? objectMapper.writeValueAsString(root) : null;
        } catch (Exception ignored) {
            return null;
        }
    }

    private boolean migratePreferenceArray(ArrayNode arrayNode, Long columnId, String oldColumnName, String newColumnName) {
        boolean changed = false;
        for (JsonNode node : arrayNode) {
            if (!(node instanceof ObjectNode objectNode) || !matchesPreferenceReference(objectNode, columnId, oldColumnName, newColumnName)) {
                continue;
            }
            objectNode.put("columnId", columnId);
            objectNode.put("columnName", newColumnName);
            if (objectNode.has("colId")) {
                objectNode.put("colId", newColumnName);
            }
            changed = true;
        }
        return changed;
    }

    private boolean matchesColumnReference(ObjectNode node, Long columnId, String oldColumnName, String newColumnName) {
        Long existingColumnId = longValue(node.get("columnId"));
        if (columnId != null && columnId.equals(existingColumnId)) {
            return true;
        }
        String columnName = text(node.get("columnName"));
        return StrUtil.isNotBlank(columnName) && (StrUtil.equals(columnName, oldColumnName) || StrUtil.equals(columnName, newColumnName));
    }

    private boolean matchesPolicyReference(String key, ObjectNode node, Long columnId, String oldColumnName, String newColumnName) {
        Long existingColumnId = longValue(node.get("columnId"));
        if (columnId != null && columnId.equals(existingColumnId)) {
            return true;
        }
        if (columnId != null && StrUtil.equals(key, String.valueOf(columnId))) {
            return true;
        }
        String columnName = text(node.get("columnName"));
        if (StrUtil.isBlank(columnName)) {
            columnName = key;
        }
        return StrUtil.isNotBlank(columnName)
            && (StrUtil.equals(columnName, oldColumnName) || StrUtil.equals(columnName, newColumnName));
    }

    private boolean matchesPreferenceReference(ObjectNode node, Long columnId, String oldColumnName, String newColumnName) {
        Long existingColumnId = longValue(node.get("columnId"));
        if (columnId != null && columnId.equals(existingColumnId)) {
            return true;
        }
        String columnName = text(node.get("columnName"));
        if (StrUtil.isBlank(columnName)) {
            columnName = text(node.get("colId"));
        }
        return StrUtil.isNotBlank(columnName) && (StrUtil.equals(columnName, oldColumnName) || StrUtil.equals(columnName, newColumnName));
    }

    private boolean looksLikePermissionNode(ObjectNode node) {
        return node.has("visible") || node.has("editable") || node.has("columnId") || node.has("columnName");
    }

    private String text(JsonNode node) {
        return node != null && !node.isNull() && node.isTextual() ? node.asText() : null;
    }

    private String text(JsonNode node, String key) {
        if (node == null || StrUtil.isBlank(key)) {
            return null;
        }
        return text(node.get(key));
    }

    private Long longValue(JsonNode node) {
        if (node == null || node.isNull()) {
            return null;
        }
        if (node.isNumber()) {
            return node.longValue();
        }
        if (node.isTextual()) {
            try {
                return Long.parseLong(node.asText());
            } catch (NumberFormatException ignored) {
                return null;
            }
        }
        return null;
    }

    private record GridBinding(String pageCode, String gridKey) {
        Set<String> candidateGridKeys() {
            Set<String> keys = new LinkedHashSet<>();
            keys.add(gridKey);
            if ("master".equals(gridKey)) {
                keys.add("masterGrid");
            } else if ("masterGrid".equals(gridKey)) {
                keys.add("master");
            }
            return keys;
        }
    }

    // ==================== 页面管理 ====================

    public List<PageComponent> listComponents() {
        return pageComponentMapper.selectList(
            new LambdaQueryWrapper<PageComponent>().orderByAsc(PageComponent::getSortOrder)
        );
    }

    public List<Map<String, Object>> listComponentsWithNames() {
        String sql = "SELECT c.ID as \"id\", c.PAGE_CODE as \"pageCode\", c.COMPONENT_KEY as \"componentKey\", " +
                     "c.COMPONENT_TYPE as \"componentType\", c.PARENT_KEY as \"parentKey\", " +
                     "c.COMPONENT_CONFIG as \"componentConfig\", c.REF_TABLE_CODE as \"refTableCode\", " +
                     "c.SLOT_NAME as \"slotName\", c.SORT_ORDER as \"sortOrder\", c.DESCRIPTION as \"description\", " +
                     "r.RESOURCE_NAME as \"pageName\", t.TABLE_NAME as \"refTableName\" " +
                     "FROM T_COST_PAGE_COMPONENT c " +
                     "LEFT JOIN T_COST_RESOURCE r ON c.PAGE_CODE = r.PAGE_CODE " +
                     "LEFT JOIN T_COST_TABLE_METADATA t ON c.REF_TABLE_CODE = t.TABLE_CODE AND t.DELETED = 0 " +
                     "WHERE c.DELETED = 0 ORDER BY c.SORT_ORDER";
        List<Map<String, Object>> rows = dynamicMapper.selectList(sql);
        // CLOB 字段转 String（Oracle 的 CLOB 列返回 ClobProxyImpl，Jackson 无法序列化）
        for (Map<String, Object> row : rows) {
            for (Map.Entry<String, Object> entry : row.entrySet()) {
                if (entry.getValue() instanceof java.sql.Clob clob) {
                    try { entry.setValue(clob.getSubString(1, (int) clob.length())); }
                    catch (Exception ignored) { entry.setValue(null); }
                }
            }
        }
        return rows;
    }

    @Transactional
    public PageComponent saveComponent(PageComponent c) {
        if (c.getId() == null) {
            c.setId(nextId("SEQ_COST_PAGE_COMPONENT"));
            pageComponentMapper.insert(c);
        } else {
            pageComponentMapper.updateById(c);
        }
        return c;
    }

    @Transactional
    public void deleteComponent(Long id) {
        pageComponentMapper.deleteById(id);
    }

    public List<PageRule> listRules(String pageCode, String componentKey) {
        return pageRuleMapper.selectList(
            new LambdaQueryWrapper<PageRule>()
                .eq(PageRule::getPageCode, pageCode)
                .eq(PageRule::getComponentKey, componentKey)
                .orderByAsc(PageRule::getSortOrder)
        );
    }

    @Transactional
    public PageRule saveRule(PageRule r) {
        if (r.getId() == null) {
            r.setId(nextId("SEQ_COST_PAGE_RULE"));
            pageRuleMapper.insert(r);
        } else {
            pageRuleMapper.updateById(r);
        }
        return r;
    }

    @Transactional
    public void deleteRule(Long id) {
        pageRuleMapper.deleteById(id);
    }

    // ==================== Lookup管理 ====================

    public List<LookupConfig> listLookups() {
        return lookupConfigMapper.selectList(
            new LambdaQueryWrapper<LookupConfig>().orderByAsc(LookupConfig::getId)
        );
    }

    @Transactional
    public LookupConfig saveLookup(LookupConfig l) {
        if (l.getId() == null) {
            l.setId(nextId("SEQ_COST_LOOKUP_CONFIG"));
            lookupConfigMapper.insert(l);
        } else {
            lookupConfigMapper.updateById(l);
        }
        return l;
    }

    @Transactional
    public void deleteLookup(Long id) {
        lookupConfigMapper.deleteById(id);
    }

    // ==================== 视图列查询 ====================

    /**
     * 查询视图/表的物理列结构（从 DBA_TAB_COLUMNS）
     */
    public List<Map<String, Object>> listViewColumns(String owner, String viewName) {
        String safeOwner = owner.toUpperCase().replace("'", "''");
        String safeName = viewName.toUpperCase().replace("'", "''");
        String sql = "SELECT c.COLUMN_NAME, c.DATA_TYPE, c.DATA_LENGTH, c.DATA_PRECISION, c.DATA_SCALE, c.COLUMN_ID, " +
                     "cc.COMMENTS AS COLUMN_COMMENT " +
                     "FROM DBA_TAB_COLUMNS c " +
                     "LEFT JOIN DBA_COL_COMMENTS cc ON cc.OWNER = c.OWNER " +
                     "AND cc.TABLE_NAME = c.TABLE_NAME AND cc.COLUMN_NAME = c.COLUMN_NAME " +
                     "WHERE c.OWNER = '" + safeOwner + "' AND c.TABLE_NAME = '" + safeName + "' " +
                     "ORDER BY c.COLUMN_ID";
        return dynamicMapper.selectList(sql);
    }

    /**
     * 根据 pageCode 查询关联的表元数据
     */
    public List<TableMetadata> listTablesByPageCode(String pageCode) {
        String safeCode = pageCode.replace("'", "''");
        // 1. 查出该 pageCode 下所有组件
        String compSql = "SELECT COMPONENT_TYPE, REF_TABLE_CODE, COMPONENT_CONFIG " +
                         "FROM T_COST_PAGE_COMPONENT WHERE PAGE_CODE = '" + safeCode + "' AND DELETED = 0";
        List<Map<String, Object>> comps = dynamicMapper.selectList(compSql);

        // 2. 提取所有关联的 tableCode
        java.util.Set<String> tableCodes = new java.util.LinkedHashSet<>();
        for (Map<String, Object> comp : comps) {
            String type = (String) comp.get("COMPONENT_TYPE");
            String refTableCode = (String) comp.get("REF_TABLE_CODE");
            // COMPONENT_CONFIG 可能是 CLOB 类型（Druid 返回 ClobProxyImpl）
            Object configObj = comp.get("COMPONENT_CONFIG");
            String config = null;
            if (configObj instanceof String s) {
                config = s;
            } else if (configObj instanceof java.sql.Clob clob) {
                try { config = clob.getSubString(1, (int) clob.length()); } catch (Exception ignored) {}
            }
            // GRID / DETAIL_GRID 的 refTableCode
            if (("GRID".equals(type) || "DETAIL_GRID".equals(type)) && refTableCode != null && !refTableCode.isEmpty()) {
                tableCodes.add(refTableCode);
            }
            // TABS 的 componentConfig -> tabs[].tableCode
            if ("TABS".equals(type) && config != null && !config.isEmpty()) {
                try {
                    cn.hutool.json.JSONObject json = cn.hutool.json.JSONUtil.parseObj(config);
                    cn.hutool.json.JSONArray tabs = json.getJSONArray("tabs");
                    if (tabs != null) {
                        for (int i = 0; i < tabs.size(); i++) {
                            String tc = tabs.getJSONObject(i).getStr("tableCode");
                            if (tc != null && !tc.isEmpty()) tableCodes.add(tc);
                        }
                    }
                } catch (Exception ignored) {}
            }
        }
        if (tableCodes.isEmpty()) return java.util.Collections.emptyList();

        // 3. 用 tableCode IN (...) 查表元数据
        String inClause = tableCodes.stream().map(c -> "'" + c.replace("'", "''") + "'")
                          .collect(java.util.stream.Collectors.joining(","));
        String sql = "SELECT * FROM T_COST_TABLE_METADATA WHERE DELETED = 0 AND TABLE_CODE IN (" + inClause + ") ORDER BY ID";
        List<Map<String, Object>> rows = dynamicMapper.selectList(sql);
        return rows.stream().map(this::mapToTableMetadata).collect(java.util.stream.Collectors.toList());
    }

    /**
     * 根据 pageCode 查询关联的 lookupCode 列表
     * 从 t_cost_page_rule 中 rule_type='LOOKUP' 的 rules JSON 提取
     */
    public List<String> listLookupCodesByPageCode(String pageCode) {
        String safeCode = pageCode.replace("'", "''");
        String sql = "SELECT RULES FROM T_COST_PAGE_RULE WHERE PAGE_CODE = '" + safeCode + "' AND RULE_TYPE = 'LOOKUP' AND DELETED = 0";
        List<Map<String, Object>> rows = dynamicMapper.selectList(sql);

        java.util.Set<String> codes = new java.util.LinkedHashSet<>();
        for (Map<String, Object> row : rows) {
            Object rulesObj = row.get("RULES");
            String rulesStr = null;
            if (rulesObj instanceof String s) {
                rulesStr = s;
            } else if (rulesObj instanceof java.sql.Clob clob) {
                try { rulesStr = clob.getSubString(1, (int) clob.length()); } catch (Exception ignored) {}
            }
            if (rulesStr == null || rulesStr.isBlank()) continue;
            try {
                cn.hutool.json.JSONArray arr = cn.hutool.json.JSONUtil.parseArray(rulesStr);
                for (int i = 0; i < arr.size(); i++) {
                    String lc = arr.getJSONObject(i).getStr("lookupCode");
                    if (lc != null && !lc.isEmpty()) codes.add(lc);
                }
            } catch (Exception ignored) {}
        }
        return new java.util.ArrayList<>(codes);
    }

    public List<ExportConfig> listExportConfigs() {
        return exportConfigMapper.selectList(
            new LambdaQueryWrapper<ExportConfig>()
                .eq(ExportConfig::getDeleted, 0)
                .orderByAsc(ExportConfig::getPageCode)
                .orderByAsc(ExportConfig::getDisplayOrder)
                .orderByAsc(ExportConfig::getId)
        );
    }

    @Transactional
    public ExportConfig saveExportConfig(ExportConfig config) {
        if (config.getId() == null) {
            config.setId(nextId("SEQ_COST_EXPORT_CONFIG"));
            if (config.getDeleted() == null) {
                config.setDeleted(0);
            }
            exportConfigMapper.insert(config);
        } else {
            exportConfigMapper.updateById(config);
        }
        return config;
    }

    @Transactional
    public void deleteExportConfig(Long id) {
        exportConfigDetailMapper.delete(
            new LambdaQueryWrapper<ExportConfigDetail>()
                .eq(ExportConfigDetail::getExportConfigId, id)
        );
        exportConfigMapper.deleteById(id);
    }

    public List<ExportConfigDetail> listExportConfigDetails(Long exportConfigId) {
        return exportConfigDetailMapper.selectList(
            new LambdaQueryWrapper<ExportConfigDetail>()
                .eq(ExportConfigDetail::getExportConfigId, exportConfigId)
                .orderByAsc(ExportConfigDetail::getDisplayOrder)
                .orderByAsc(ExportConfigDetail::getId)
        );
    }

    @Transactional
    public ExportConfigDetail saveExportConfigDetail(ExportConfigDetail detail) {
        if (detail.getId() == null) {
            detail.setId(nextId("SEQ_COST_EXPORT_CONFIG_DTL"));
            exportConfigDetailMapper.insert(detail);
        } else {
            exportConfigDetailMapper.updateById(detail);
        }
        return detail;
    }

    @Transactional
    public void deleteExportConfigDetail(Long id) {
        exportConfigDetailMapper.deleteById(id);
    }

    // ==================== 审批流配置 ====================

    public List<Map<String, Object>> listApprovalFlows() {
        String sql = "SELECT f.FLOW_ID as \"flowId\", f.PAGE_CODE as \"pageCode\", r.RESOURCE_NAME as \"pageName\", " +
                     "f.FLOW_NAME as \"flowName\", f.FLOW_VERSION as \"flowVersion\", f.FLOW_PRIORITY as \"flowPriority\", " +
                     "f.IS_ENABLED as \"isEnabled\", f.REMARK as \"remark\", f.CREATE_BY as \"createBy\", " +
                     "f.CREATE_TIME as \"createTime\", f.UPDATE_BY as \"updateBy\", f.UPDATE_TIME as \"updateTime\" " +
                     "FROM WF_FLOW_DEF f " +
                     "LEFT JOIN T_COST_RESOURCE r ON r.PAGE_CODE = f.PAGE_CODE " +
                     "ORDER BY f.PAGE_CODE, f.FLOW_PRIORITY, f.FLOW_VERSION DESC, f.FLOW_ID";
        return dynamicMapper.selectList(sql);
    }

    @Transactional
    public Map<String, Object> saveApprovalFlow(Map<String, Object> flow) {
        Long id = longValue(flow.get("flowId"));
        if (id == null) {
            id = nextId("SEQ_WF_FLOW_DEF");
            String sql = "INSERT INTO WF_FLOW_DEF (FLOW_ID, PAGE_CODE, FLOW_NAME, FLOW_VERSION, FLOW_PRIORITY, IS_ENABLED, REMARK, CREATE_BY, CREATE_TIME) VALUES (" +
                    id + ", " + sqlString(str(flow.get("pageCode"))) + ", " + sqlString(str(flow.get("flowName"))) + ", " +
                    intValue(flow.get("flowVersion"), 1) + ", " + intValue(flow.get("flowPriority"), 100) + ", " +
                    intValue(flow.get("isEnabled"), 1) + ", " + sqlString(str(flow.get("remark"))) + ", 'admin', SYSTIMESTAMP)";
            dynamicMapper.insert(sql);
        } else {
            String sql = "UPDATE WF_FLOW_DEF SET PAGE_CODE=" + sqlString(str(flow.get("pageCode"))) +
                    ", FLOW_NAME=" + sqlString(str(flow.get("flowName"))) +
                    ", FLOW_VERSION=" + intValue(flow.get("flowVersion"), 1) +
                    ", FLOW_PRIORITY=" + intValue(flow.get("flowPriority"), 100) +
                    ", IS_ENABLED=" + intValue(flow.get("isEnabled"), 1) +
                    ", REMARK=" + sqlString(str(flow.get("remark"))) +
                    ", UPDATE_BY='admin', UPDATE_TIME=SYSTIMESTAMP WHERE FLOW_ID=" + id;
            dynamicMapper.update(sql);
        }
        return one("SELECT f.FLOW_ID as \"flowId\", f.PAGE_CODE as \"pageCode\", f.FLOW_NAME as \"flowName\", f.FLOW_VERSION as \"flowVersion\", f.FLOW_PRIORITY as \"flowPriority\", f.IS_ENABLED as \"isEnabled\", f.REMARK as \"remark\" FROM WF_FLOW_DEF f WHERE f.FLOW_ID=" + id);
    }

    @Transactional
    public void deleteApprovalFlow(Long flowId) {
        dynamicMapper.delete("DELETE FROM WF_APPROVAL_LOG WHERE APPROVAL_ID IN (SELECT APPROVAL_ID FROM WF_APPROVAL_MAIN WHERE FLOW_ID=" + flowId + ")");
        dynamicMapper.delete("DELETE FROM WF_APPROVAL_DETAIL WHERE APPROVAL_ID IN (SELECT APPROVAL_ID FROM WF_APPROVAL_MAIN WHERE FLOW_ID=" + flowId + ")");
        dynamicMapper.delete("DELETE FROM WF_APPROVAL_MAIN WHERE FLOW_ID=" + flowId);
        dynamicMapper.delete("DELETE FROM WF_FLOW_APPROVER WHERE NODE_ID IN (SELECT NODE_ID FROM WF_FLOW_NODE WHERE FLOW_ID=" + flowId + ")");
        dynamicMapper.delete("DELETE FROM WF_FLOW_NODE WHERE FLOW_ID=" + flowId);
        dynamicMapper.delete("DELETE FROM WF_FLOW_CONDITION WHERE FLOW_ID=" + flowId);
        dynamicMapper.delete("DELETE FROM WF_FLOW_DEF WHERE FLOW_ID=" + flowId);
    }

    @Transactional
    public void deleteApprovalPage(String pageCode) {
        List<Map<String, Object>> rows = dynamicMapper.selectList(
            "SELECT FLOW_ID as \"flowId\" FROM WF_FLOW_DEF WHERE PAGE_CODE=" + sqlString(pageCode)
        );
        for (Map<String, Object> row : rows) {
            Long flowId = longValue(row.get("flowId"));
            if (flowId != null) {
                deleteApprovalFlow(flowId);
            }
        }
    }

    public List<Map<String, Object>> listApprovalConditions(Long flowId) {
        String sql = "SELECT CONDITION_ID as \"conditionId\", FLOW_ID as \"flowId\", CONDITION_NAME as \"conditionName\", " +
                     "CONDITION_MODE as \"conditionMode\", LOGIC_TREE as \"logicTree\", SQL_EXPR as \"sqlExpr\", " +
                     "ON_ERROR as \"onError\", IS_ENABLED as \"isEnabled\", CREATE_BY as \"createBy\", CREATE_TIME as \"createTime\", " +
                     "UPDATE_BY as \"updateBy\", UPDATE_TIME as \"updateTime\" FROM WF_FLOW_CONDITION " +
                     "WHERE FLOW_ID=" + flowId + " ORDER BY CONDITION_ID";
        return clobToString(dynamicMapper.selectList(sql));
    }

    @Transactional
    public Map<String, Object> saveApprovalCondition(Map<String, Object> condition) {
        Long id = longValue(condition.get("conditionId"));
        Long flowId = longValue(condition.get("flowId"));
        if (id == null) {
            id = nextId("SEQ_WF_FLOW_CONDITION");
            String sql = "INSERT INTO WF_FLOW_CONDITION (CONDITION_ID, FLOW_ID, CONDITION_NAME, CONDITION_MODE, LOGIC_TREE, SQL_EXPR, ON_ERROR, IS_ENABLED, CREATE_BY, CREATE_TIME) VALUES (" +
                    id + ", " + flowId + ", " + sqlString(str(condition.get("conditionName"))) + ", " +
                    sqlString(defaultStr(condition.get("conditionMode"), "ALWAYS")) + ", " + sqlClob(str(condition.get("logicTree"))) + ", " +
                    sqlClob(str(condition.get("sqlExpr"))) + ", " + sqlString(defaultStr(condition.get("onError"), "REQUIRE_APPROVAL")) + ", " +
                    intValue(condition.get("isEnabled"), 1) + ", 'admin', SYSTIMESTAMP)";
            dynamicMapper.insert(sql);
        } else {
            String sql = "UPDATE WF_FLOW_CONDITION SET CONDITION_NAME=" + sqlString(str(condition.get("conditionName"))) +
                    ", CONDITION_MODE=" + sqlString(defaultStr(condition.get("conditionMode"), "ALWAYS")) +
                    ", LOGIC_TREE=" + sqlClob(str(condition.get("logicTree"))) +
                    ", SQL_EXPR=" + sqlClob(str(condition.get("sqlExpr"))) +
                    ", ON_ERROR=" + sqlString(defaultStr(condition.get("onError"), "REQUIRE_APPROVAL")) +
                    ", IS_ENABLED=" + intValue(condition.get("isEnabled"), 1) +
                    ", UPDATE_BY='admin', UPDATE_TIME=SYSTIMESTAMP WHERE CONDITION_ID=" + id;
            dynamicMapper.update(sql);
        }
        return one("SELECT CONDITION_ID as \"conditionId\", FLOW_ID as \"flowId\", CONDITION_NAME as \"conditionName\", CONDITION_MODE as \"conditionMode\", LOGIC_TREE as \"logicTree\", SQL_EXPR as \"sqlExpr\", ON_ERROR as \"onError\", IS_ENABLED as \"isEnabled\" FROM WF_FLOW_CONDITION WHERE CONDITION_ID=" + id);
    }

    @Transactional
    public void deleteApprovalCondition(Long conditionId) {
        dynamicMapper.delete("DELETE FROM WF_FLOW_CONDITION WHERE CONDITION_ID=" + conditionId);
    }

    public List<Map<String, Object>> listApprovalNodes(Long flowId) {
        String sql = "SELECT NODE_ID as \"nodeId\", FLOW_ID as \"flowId\", APPROVAL_LEVEL as \"approvalLevel\", NODE_NAME as \"nodeName\", " +
                     "APPROVAL_MODE as \"approvalMode\", CONDITION_MODE as \"conditionMode\", LOGIC_TREE as \"logicTree\", SQL_EXPR as \"sqlExpr\", " +
                     "ON_ERROR as \"onError\", IS_ENABLED as \"isEnabled\", CREATE_BY as \"createBy\", CREATE_TIME as \"createTime\", " +
                     "UPDATE_BY as \"updateBy\", UPDATE_TIME as \"updateTime\" FROM WF_FLOW_NODE " +
                     "WHERE FLOW_ID=" + flowId + " ORDER BY APPROVAL_LEVEL, NODE_ID";
        return clobToString(dynamicMapper.selectList(sql));
    }

    @Transactional
    public Map<String, Object> saveApprovalNode(Map<String, Object> node) {
        Long id = longValue(node.get("nodeId"));
        Long flowId = longValue(node.get("flowId"));
        if (id == null) {
            id = nextId("SEQ_WF_FLOW_NODE");
            String sql = "INSERT INTO WF_FLOW_NODE (NODE_ID, FLOW_ID, APPROVAL_LEVEL, NODE_NAME, APPROVAL_MODE, CONDITION_MODE, LOGIC_TREE, SQL_EXPR, ON_ERROR, IS_ENABLED, CREATE_BY, CREATE_TIME) VALUES (" +
                    id + ", " + flowId + ", " + intValue(node.get("approvalLevel"), 1) + ", " + sqlString(str(node.get("nodeName"))) + ", " +
                    sqlString(defaultStr(node.get("approvalMode"), "OR")) + ", " + sqlString(defaultStr(node.get("conditionMode"), "ALWAYS")) + ", " +
                    sqlClob(str(node.get("logicTree"))) + ", " + sqlClob(str(node.get("sqlExpr"))) + ", " +
                    sqlString(defaultStr(node.get("onError"), "REQUIRE_APPROVAL")) + ", " + intValue(node.get("isEnabled"), 1) + ", 'admin', SYSTIMESTAMP)";
            dynamicMapper.insert(sql);
        } else {
            String sql = "UPDATE WF_FLOW_NODE SET APPROVAL_LEVEL=" + intValue(node.get("approvalLevel"), 1) +
                    ", NODE_NAME=" + sqlString(str(node.get("nodeName"))) +
                    ", APPROVAL_MODE=" + sqlString(defaultStr(node.get("approvalMode"), "OR")) +
                    ", CONDITION_MODE=" + sqlString(defaultStr(node.get("conditionMode"), "ALWAYS")) +
                    ", LOGIC_TREE=" + sqlClob(str(node.get("logicTree"))) +
                    ", SQL_EXPR=" + sqlClob(str(node.get("sqlExpr"))) +
                    ", ON_ERROR=" + sqlString(defaultStr(node.get("onError"), "REQUIRE_APPROVAL")) +
                    ", IS_ENABLED=" + intValue(node.get("isEnabled"), 1) +
                    ", UPDATE_BY='admin', UPDATE_TIME=SYSTIMESTAMP WHERE NODE_ID=" + id;
            dynamicMapper.update(sql);
        }
        return one("SELECT NODE_ID as \"nodeId\", FLOW_ID as \"flowId\", APPROVAL_LEVEL as \"approvalLevel\", NODE_NAME as \"nodeName\", APPROVAL_MODE as \"approvalMode\", CONDITION_MODE as \"conditionMode\", LOGIC_TREE as \"logicTree\", SQL_EXPR as \"sqlExpr\", ON_ERROR as \"onError\", IS_ENABLED as \"isEnabled\" FROM WF_FLOW_NODE WHERE NODE_ID=" + id);
    }

    @Transactional
    public void deleteApprovalNode(Long nodeId) {
        dynamicMapper.delete("DELETE FROM WF_APPROVAL_LOG WHERE DETAIL_ID IN (SELECT DETAIL_ID FROM WF_APPROVAL_DETAIL WHERE NODE_ID=" + nodeId + ")");
        dynamicMapper.delete("DELETE FROM WF_APPROVAL_DETAIL WHERE NODE_ID=" + nodeId);
        dynamicMapper.delete("DELETE FROM WF_FLOW_APPROVER WHERE NODE_ID=" + nodeId);
        dynamicMapper.delete("DELETE FROM WF_FLOW_NODE WHERE NODE_ID=" + nodeId);
    }

    public List<Map<String, Object>> listApprovalApprovers(Long nodeId) {
        String sql = "SELECT ID as \"id\", NODE_ID as \"nodeId\", APPLY_DEPT_ID as \"applyDeptId\", APPLY_DEPT_NAME as \"applyDeptName\", " +
                     "TARGET_TYPE as \"targetType\", TARGET_USER_ID as \"targetUserId\", TARGET_USER_NAME as \"targetUserName\", " +
                     "TARGET_ROLE_ID as \"targetRoleId\", TARGET_ROLE_CODE as \"targetRoleCode\", TARGET_ROLE_NAME as \"targetRoleName\", " +
                     "CONDITION_MODE as \"conditionMode\", LOGIC_TREE as \"logicTree\", SQL_EXPR as \"sqlExpr\", ON_ERROR as \"onError\", " +
                     "SORT_ORDER as \"sortOrder\", IS_ENABLED as \"isEnabled\", CREATE_BY as \"createBy\", CREATE_TIME as \"createTime\", " +
                     "UPDATE_BY as \"updateBy\", UPDATE_TIME as \"updateTime\" FROM WF_FLOW_APPROVER " +
                     "WHERE NODE_ID=" + nodeId + " ORDER BY SORT_ORDER, ID";
        return clobToString(dynamicMapper.selectList(sql));
    }

    @Transactional
    public Map<String, Object> saveApprovalApprover(Map<String, Object> approver) {
        Long id = longValue(approver.get("id"));
        Long nodeId = longValue(approver.get("nodeId"));
        Long applyDeptId = longValue(approver.get("applyDeptId"));
        Long targetUserId = longValue(approver.get("targetUserId"));
        Long targetRoleId = longValue(approver.get("targetRoleId"));
        if (id == null) {
            id = nextId("SEQ_WF_FLOW_APPROVER");
            String sql = "INSERT INTO WF_FLOW_APPROVER (ID, NODE_ID, APPLY_DEPT_ID, APPLY_DEPT_NAME, TARGET_TYPE, TARGET_USER_ID, TARGET_USER_NAME, TARGET_ROLE_ID, TARGET_ROLE_CODE, TARGET_ROLE_NAME, CONDITION_MODE, LOGIC_TREE, SQL_EXPR, ON_ERROR, SORT_ORDER, IS_ENABLED, CREATE_BY, CREATE_TIME) VALUES (" +
                    id + ", " + nodeId + ", " + sqlNumber(applyDeptId) + ", " + sqlString(str(approver.get("applyDeptName"))) + ", " +
                    sqlString(defaultStr(approver.get("targetType"), "USER")) + ", " + sqlNumber(targetUserId) + ", " + sqlString(str(approver.get("targetUserName"))) + ", " +
                    sqlNumber(targetRoleId) + ", " + sqlString(str(approver.get("targetRoleCode"))) + ", " + sqlString(str(approver.get("targetRoleName"))) + ", " +
                    sqlString(defaultStr(approver.get("conditionMode"), "ALWAYS")) + ", " + sqlClob(str(approver.get("logicTree"))) + ", " + sqlClob(str(approver.get("sqlExpr"))) + ", " +
                    sqlString(defaultStr(approver.get("onError"), "REQUIRE_APPROVAL")) + ", " + intValue(approver.get("sortOrder"), 1) + ", " + intValue(approver.get("isEnabled"), 1) + ", 'admin', SYSTIMESTAMP)";
            dynamicMapper.insert(sql);
        } else {
            String sql = "UPDATE WF_FLOW_APPROVER SET APPLY_DEPT_ID=" + sqlNumber(applyDeptId) +
                    ", APPLY_DEPT_NAME=" + sqlString(str(approver.get("applyDeptName"))) +
                    ", TARGET_TYPE=" + sqlString(defaultStr(approver.get("targetType"), "USER")) +
                    ", TARGET_USER_ID=" + sqlNumber(targetUserId) +
                    ", TARGET_USER_NAME=" + sqlString(str(approver.get("targetUserName"))) +
                    ", TARGET_ROLE_ID=" + sqlNumber(targetRoleId) +
                    ", TARGET_ROLE_CODE=" + sqlString(str(approver.get("targetRoleCode"))) +
                    ", TARGET_ROLE_NAME=" + sqlString(str(approver.get("targetRoleName"))) +
                    ", CONDITION_MODE=" + sqlString(defaultStr(approver.get("conditionMode"), "ALWAYS")) +
                    ", LOGIC_TREE=" + sqlClob(str(approver.get("logicTree"))) +
                    ", SQL_EXPR=" + sqlClob(str(approver.get("sqlExpr"))) +
                    ", ON_ERROR=" + sqlString(defaultStr(approver.get("onError"), "REQUIRE_APPROVAL")) +
                    ", SORT_ORDER=" + intValue(approver.get("sortOrder"), 1) +
                    ", IS_ENABLED=" + intValue(approver.get("isEnabled"), 1) +
                    ", UPDATE_BY='admin', UPDATE_TIME=SYSTIMESTAMP WHERE ID=" + id;
            dynamicMapper.update(sql);
        }
        return one("SELECT ID as \"id\", NODE_ID as \"nodeId\", APPLY_DEPT_ID as \"applyDeptId\", APPLY_DEPT_NAME as \"applyDeptName\", TARGET_TYPE as \"targetType\", TARGET_USER_ID as \"targetUserId\", TARGET_USER_NAME as \"targetUserName\", TARGET_ROLE_ID as \"targetRoleId\", TARGET_ROLE_CODE as \"targetRoleCode\", TARGET_ROLE_NAME as \"targetRoleName\", CONDITION_MODE as \"conditionMode\", LOGIC_TREE as \"logicTree\", SQL_EXPR as \"sqlExpr\", ON_ERROR as \"onError\", SORT_ORDER as \"sortOrder\", IS_ENABLED as \"isEnabled\" FROM WF_FLOW_APPROVER WHERE ID=" + id);
    }

    @Transactional
    public void deleteApprovalApprover(Long id) {
        dynamicMapper.delete("DELETE FROM WF_FLOW_APPROVER WHERE ID=" + id);
    }

    public Map<String, Object> getApprovalReferenceData() {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("pages", dynamicMapper.selectList("SELECT ID as \"id\", RESOURCE_NAME as \"resourceName\", PAGE_CODE as \"pageCode\", ROUTE as \"route\" FROM T_COST_RESOURCE WHERE RESOURCE_TYPE='PAGE' AND PAGE_CODE IS NOT NULL ORDER BY SORT_ORDER, ID"));
        result.put("users", dynamicMapper.selectList("SELECT ID as \"id\", USERNAME as \"username\", REAL_NAME as \"realName\", DEPARTMENT_ID as \"departmentId\" FROM T_COST_USER WHERE DELETED=0 AND STATUS='ACTIVE' ORDER BY ID"));
        result.put("roles", dynamicMapper.selectList("SELECT ID as \"id\", ROLE_CODE as \"roleCode\", ROLE_NAME as \"roleName\" FROM T_COST_ROLE ORDER BY ID"));
        result.put("departments", dynamicMapper.selectList("SELECT ID as \"id\", DEPT_CODE as \"deptCode\", DEPT_NAME as \"deptName\" FROM T_COST_DEPARTMENT WHERE DELETED=0 ORDER BY SORT_ORDER, ID"));
        return result;
    }

    private Map<String, Object> one(String sql) {
        List<Map<String, Object>> rows = clobToString(dynamicMapper.selectList(sql));
        return rows.isEmpty() ? Collections.emptyMap() : rows.get(0);
    }

    private List<Map<String, Object>> clobToString(List<Map<String, Object>> rows) {
        for (Map<String, Object> row : rows) {
            for (Map.Entry<String, Object> entry : row.entrySet()) {
                if (entry.getValue() instanceof java.sql.Clob clob) {
                    try {
                        entry.setValue(clob.getSubString(1, (int) clob.length()));
                    } catch (Exception ignored) {
                        entry.setValue(null);
                    }
                }
            }
        }
        return rows;
    }

    private String str(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private String defaultStr(Object value, String defaultValue) {
        String text = str(value);
        return StrUtil.isBlank(text) ? defaultValue : text;
    }

    private Long longValue(Object value) {
        if (value instanceof Number number) {
            return number.longValue();
        }
        if (value instanceof String text && StrUtil.isNotBlank(text)) {
            return Long.parseLong(text);
        }
        return null;
    }

    private int intValue(Object value, int defaultValue) {
        Long parsed = longValue(value);
        return parsed == null ? defaultValue : parsed.intValue();
    }

    private String sqlNumber(Long value) {
        return value == null ? "NULL" : String.valueOf(value);
    }

    private String sqlString(String value) {
        if (StrUtil.isBlank(value)) {
            return "NULL";
        }
        return "'" + value.replace("'", "''") + "'";
    }

    private String sqlClob(String value) {
        if (StrUtil.isBlank(value)) {
            return "NULL";
        }
        String escaped = value.replace("'", "''");
        List<String> chunks = new ArrayList<>();
        for (int i = 0; i < escaped.length(); i += 3000) {
            chunks.add("TO_CLOB('" + escaped.substring(i, Math.min(i + 3000, escaped.length())) + "')");
        }
        return String.join(" || ", chunks);
    }

    private TableMetadata mapToTableMetadata(Map<String, Object> row) {
        TableMetadata t = new TableMetadata();
        t.setId(row.get("ID") != null ? ((Number) row.get("ID")).longValue() : null);
        t.setTableCode((String) row.get("TABLE_CODE"));
        t.setTableName((String) row.get("TABLE_NAME"));
        t.setQueryView((String) row.get("QUERY_VIEW"));
        t.setTargetTable((String) row.get("TARGET_TABLE"));
        t.setSequenceName((String) row.get("SEQUENCE_NAME"));
        t.setPkColumn((String) row.get("PK_COLUMN"));
        t.setParentTableCode((String) row.get("PARENT_TABLE_CODE"));
        t.setParentFkColumn((String) row.get("PARENT_FK_COLUMN"));
        return t;
    }
}
