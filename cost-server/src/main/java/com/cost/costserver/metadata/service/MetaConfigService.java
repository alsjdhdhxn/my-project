package com.cost.costserver.metadata.service;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.cost.costserver.auth.entity.Resource;
import com.cost.costserver.auth.entity.RolePage;
import com.cost.costserver.auth.mapper.ResourceMapper;
import com.cost.costserver.auth.mapper.RolePageMapper;
import com.cost.costserver.dynamic.mapper.DynamicMapper;
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

        String previousFieldName = StrUtil.blankToDefault(existing.getFieldName(), current.getFieldName());
        String currentFieldName = StrUtil.blankToDefault(current.getFieldName(), existing.getFieldName());

        migrateColumnOverrideRules(bindings, current.getId(), previousFieldName, currentFieldName);
        migrateRoleColumnPolicies(bindings, current.getId(), previousFieldName, currentFieldName);
        migrateUserGridConfigs(bindings, current.getId(), previousFieldName, currentFieldName);
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
            String oldFieldName,
            String newFieldName) {
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
            String migrated = migrateColumnOverrideJson(rule.getRules(), columnId, oldFieldName, newFieldName);
            if (migrated != null) {
                rule.setRules(migrated);
                pageRuleMapper.updateById(rule);
            }
        }
    }

    private void migrateRoleColumnPolicies(
            List<GridBinding> bindings,
            Long columnId,
            String oldFieldName,
            String newFieldName) {
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
                oldFieldName,
                newFieldName
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
            String oldFieldName,
            String newFieldName) {
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
            String migrated = migrateUserGridConfigJson(config.getConfigData(), columnId, oldFieldName, newFieldName);
            if (migrated != null) {
                config.setConfigData(migrated);
                userGridConfigMapper.updateById(config);
            }
        }
    }

    private String migrateColumnOverrideJson(String raw, Long columnId, String oldFieldName, String newFieldName) {
        try {
            JsonNode root = objectMapper.readTree(raw);
            if (!(root instanceof ArrayNode arrayNode)) {
                return null;
            }
            boolean changed = false;
            for (JsonNode item : arrayNode) {
                if (!(item instanceof ObjectNode objectNode) || !matchesColumnReference(objectNode, columnId, oldFieldName, newFieldName)) {
                    continue;
                }
                objectNode.put("columnId", columnId);
                objectNode.put("field", newFieldName);
                objectNode.put("fieldName", newFieldName);
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
            String oldFieldName,
            String newFieldName) {
        try {
            JsonNode root = objectMapper.readTree(raw);
            if (!(root instanceof ObjectNode rootObject)) {
                return null;
            }
            boolean changed = migratePermissionContainer(rootObject, columnId, oldFieldName, newFieldName);
            for (String tableKey : tableKeys) {
                JsonNode tableNode = rootObject.get(tableKey);
                if (tableNode instanceof ObjectNode tableObject) {
                    changed = migratePermissionContainer(tableObject, columnId, oldFieldName, newFieldName) || changed;
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
            String oldFieldName,
            String newFieldName) {
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
            if (!matchesPolicyReference(entry.getKey(), permissionNode, columnId, oldFieldName, newFieldName)) {
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
        matchedNode.put("fieldName", newFieldName);
        matchedKeys.forEach(container::remove);
        container.set(canonicalKey, matchedNode);
        return true;
    }

    private String migrateUserGridConfigJson(String raw, Long columnId, String oldFieldName, String newFieldName) {
        try {
            JsonNode root = objectMapper.readTree(raw);
            boolean changed = false;
            if (root instanceof ArrayNode arrayNode) {
                changed = migratePreferenceArray(arrayNode, columnId, oldFieldName, newFieldName);
            } else if (root instanceof ObjectNode objectNode) {
                JsonNode columnsNode = objectNode.get("columns");
                if (columnsNode instanceof ArrayNode columnsArray) {
                    changed = migratePreferenceArray(columnsArray, columnId, oldFieldName, newFieldName);
                }
                JsonNode stateNode = objectNode.get("columnState");
                if (stateNode instanceof ArrayNode stateArray) {
                    changed = migratePreferenceArray(stateArray, columnId, oldFieldName, newFieldName) || changed;
                }
            }
            return changed ? objectMapper.writeValueAsString(root) : null;
        } catch (Exception ignored) {
            return null;
        }
    }

    private boolean migratePreferenceArray(ArrayNode arrayNode, Long columnId, String oldFieldName, String newFieldName) {
        boolean changed = false;
        for (JsonNode node : arrayNode) {
            if (!(node instanceof ObjectNode objectNode) || !matchesPreferenceReference(objectNode, columnId, oldFieldName, newFieldName)) {
                continue;
            }
            objectNode.put("columnId", columnId);
            objectNode.put("field", newFieldName);
            if (objectNode.has("fieldName")) {
                objectNode.put("fieldName", newFieldName);
            }
            if (objectNode.has("colId")) {
                objectNode.put("colId", newFieldName);
            }
            changed = true;
        }
        return changed;
    }

    private boolean matchesColumnReference(ObjectNode node, Long columnId, String oldFieldName, String newFieldName) {
        Long existingColumnId = longValue(node.get("columnId"));
        if (columnId != null && columnId.equals(existingColumnId)) {
            return true;
        }
        String field = text(node.get("field"));
        if (StrUtil.isBlank(field)) {
            field = text(node.get("fieldName"));
        }
        return StrUtil.isNotBlank(field) && (StrUtil.equals(field, oldFieldName) || StrUtil.equals(field, newFieldName));
    }

    private boolean matchesPolicyReference(String key, ObjectNode node, Long columnId, String oldFieldName, String newFieldName) {
        Long existingColumnId = longValue(node.get("columnId"));
        if (columnId != null && columnId.equals(existingColumnId)) {
            return true;
        }
        if (columnId != null && StrUtil.equals(key, String.valueOf(columnId))) {
            return true;
        }
        String fieldName = text(node.get("fieldName"));
        if (StrUtil.isBlank(fieldName)) {
            fieldName = key;
        }
        return StrUtil.isNotBlank(fieldName)
            && (StrUtil.equals(fieldName, oldFieldName) || StrUtil.equals(fieldName, newFieldName));
    }

    private boolean matchesPreferenceReference(ObjectNode node, Long columnId, String oldFieldName, String newFieldName) {
        Long existingColumnId = longValue(node.get("columnId"));
        if (columnId != null && columnId.equals(existingColumnId)) {
            return true;
        }
        String field = text(node.get("field"));
        if (StrUtil.isBlank(field)) {
            field = text(node.get("fieldName"));
        }
        if (StrUtil.isBlank(field)) {
            field = text(node.get("colId"));
        }
        return StrUtil.isNotBlank(field) && (StrUtil.equals(field, oldFieldName) || StrUtil.equals(field, newFieldName));
    }

    private boolean looksLikePermissionNode(ObjectNode node) {
        return node.has("visible") || node.has("editable") || node.has("columnId") || node.has("fieldName");
    }

    private String text(JsonNode node) {
        return node != null && !node.isNull() && node.isTextual() ? node.asText() : null;
    }

    private String text(JsonNode node, String fieldName) {
        if (node == null || StrUtil.isBlank(fieldName)) {
            return null;
        }
        return text(node.get(fieldName));
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
        String sql = "SELECT COLUMN_NAME, DATA_TYPE, DATA_LENGTH, DATA_PRECISION, DATA_SCALE, COLUMN_ID " +
                     "FROM DBA_TAB_COLUMNS WHERE OWNER = '" + safeOwner + "' AND TABLE_NAME = '" + safeName + "' " +
                     "ORDER BY COLUMN_ID";
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
