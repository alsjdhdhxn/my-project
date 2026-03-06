package com.cost.costserver.metadata.service;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.cost.costserver.auth.dto.ColumnPermission;
import com.cost.costserver.auth.dto.PagePermission;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.grid.dto.ColumnPreference;
import com.cost.costserver.grid.service.UserGridConfigService;
import com.cost.costserver.metadata.dto.*;
import com.cost.costserver.metadata.entity.*;
import com.cost.costserver.metadata.mapper.*;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class MetadataService {

    private final TableMetadataMapper tableMetadataMapper;
    private final ColumnMetadataMapper columnMetadataMapper;
    private final PageComponentMapper pageComponentMapper;
    private final PageRuleMapper pageRuleMapper;
    private final DictionaryTypeMapper dictionaryTypeMapper;
    private final DictionaryItemMapper dictionaryItemMapper;
    private final LookupConfigMapper lookupConfigMapper;
    private final ObjectMapper objectMapper;
    private final UserGridConfigService userGridConfigService;

    private final Map<String, TableMetadataDTO> cache = new ConcurrentHashMap<>();

    public TableMetadataDTO getTableMetadata(String tableCode) {
        TableMetadataDTO cached = cache.get(tableCode);
        if (cached != null) {
            return cached;
        }

        TableMetadata table = tableMetadataMapper.selectOne(
                new LambdaQueryWrapper<TableMetadata>()
                        .eq(TableMetadata::getTableCode, tableCode));
        if (table == null) {
            throw new BusinessException(400, "表元数据不存在: " + tableCode);
        }

        List<ColumnMetadata> columns = columnMetadataMapper.selectList(
                new LambdaQueryWrapper<ColumnMetadata>()
                        .eq(ColumnMetadata::getTableMetadataId, table.getId())
                        .orderByAsc(ColumnMetadata::getDisplayOrder));

        TableMetadataDTO dto = TableMetadataDTO.from(table, columns);
        cache.put(tableCode, dto);
        return dto;
    }

    /**
     * 获取表元数据（合并权限）
     * 将角色的列权限合并到列元数据中返回
     */
    public TableMetadataDTO getTableMetadataWithPermission(
            String tableCode,
            String pageCode,
            String gridKey,
            PagePermission permission,
            Long userId) {
        return getTableMetadataWithPermission(tableCode, pageCode, gridKey, permission, userId, true);
    }

    public TableMetadataDTO getTableMetadataWithPermission(
            String tableCode,
            String pageCode,
            String gridKey,
            PagePermission permission,
            Long userId,
            boolean applyUserPreferences) {
        TableMetadataDTO base = getTableMetadata(tableCode);
        // COLUMN_OVERRIDE now merged on backend for metadata/table endpoint.
        List<ColumnMetadataDTO> columns = base.columns();
        // 1) 列配置（表元数据）基线
        // 2) 列覆盖（仅收紧，不放开）
        columns = applyColumnOverrides(columns, loadColumnOverrides(pageCode, gridKey));
        // 3) 页面权限（仅收紧，不放开）
        columns = applyPermission(columns, permission, gridKey);
        if (applyUserPreferences) {
            columns = applyUserPreferences(columns, userId, pageCode, gridKey);
        }
        return base.withColumns(columns);
    }

    public void clearCache(String tableCode) {
        if (tableCode == null) {
            cache.clear();
        } else {
            cache.remove(tableCode);
        }
    }

    private List<ColumnMetadataDTO> applyPermission(
            List<ColumnMetadataDTO> columns,
            PagePermission permission,
            String gridKey) {
        if (permission == null) {
            return columns;
        }
        List<ColumnMetadataDTO> result = new ArrayList<>();
        for (ColumnMetadataDTO col : columns) {
            ColumnPermission colPerm = permission.getColumnPermission(gridKey, col.fieldName());
            if (colPerm != null && !colPerm.visible()) {
                continue;
            }
            boolean editable = col.editable() != null ? col.editable() : true;
            if (colPerm != null && !colPerm.editable()) {
                editable = false;
            }
            boolean visible = col.visible() == null || col.visible();
            if (!visible) {
                editable = false;
            }
            String rulesConfig = applyVisibilityLock(col.rulesConfig(), !visible);
            result.add(copyColumn(col, col.displayOrder(), col.width(), visible, editable,
                    col.required(), col.searchable(), col.sortable(), col.pinned(), rulesConfig));
        }
        return result;
    }

    private List<ColumnMetadataDTO> applyUserPreferences(
            List<ColumnMetadataDTO> columns,
            Long userId,
            String pageCode,
            String gridKey) {
        if (userId == null || StrUtil.isBlank(pageCode) || StrUtil.isBlank(gridKey)) {
            return columns;
        }
        Map<String, ColumnPreference> preferences = userGridConfigService.getColumnPreferences(userId, pageCode,
                gridKey);
        if (preferences.isEmpty()) {
            return columns;
        }
        int maxOrder = preferences.values().stream()
                .map(ColumnPreference::order)
                .filter(Objects::nonNull)
                .max(Integer::compareTo)
                .orElse(0);

        List<ColumnMetadataDTO> result = new ArrayList<>();
        int index = 0;
        for (ColumnMetadataDTO col : columns) {
            ColumnPreference pref = preferences.get(col.fieldName());
            Integer displayOrder = col.displayOrder();
            if (pref != null && pref.order() != null) {
                displayOrder = pref.order();
            } else if (!preferences.isEmpty()) {
                int baseOrder = displayOrder != null ? displayOrder : index;
                displayOrder = maxOrder + 1 + baseOrder;
            }

            Integer width = col.width();
            String pinned = col.pinned();
            Boolean visible = col.visible();
            Boolean editable = col.editable();

            if (pref != null) {
                if (pref.width() != null) {
                    width = pref.width();
                }
                if (pref.hidden() != null) {
                    // 用户个性化只允许收紧：可隐藏，不可放开上层已隐藏列
                    if (pref.hidden()) {
                        visible = false;
                    }
                }
                pinned = pref.pinned();
            }

            if (visible != null && !visible) {
                editable = false;
            }

            result.add(copyColumn(col, displayOrder, width, visible, editable,
                    col.required(), col.searchable(), col.sortable(), pinned, col.rulesConfig()));
            index++;
        }
        return result;
    }

    private List<ColumnMetadataDTO> applyColumnOverrides(
            List<ColumnMetadataDTO> columns,
            Map<String, ColumnOverride> overrides) {
        if (overrides == null || overrides.isEmpty()) {
            return columns;
        }

        List<ColumnMetadataDTO> result = new ArrayList<>();
        for (ColumnMetadataDTO col : columns) {
            ColumnOverride override = overrides.get(col.fieldName());
            if (override == null) {
                result.add(col);
                continue;
            }

            Boolean visible = tightenBoolean(col.visible(), override.visible());
            Boolean editable = tightenBoolean(col.editable(), override.editable());
            Boolean required = tightenBoolean(col.required(), override.required());
            Boolean searchable = tightenBoolean(col.searchable(), override.searchable());
            Boolean sortable = tightenBoolean(col.sortable(), override.sortable());

            if (visible != null && !visible) {
                editable = false;
            }

            Integer width = override.width() != null ? override.width() : col.width();
            String pinned = override.pinned() != null ? override.pinned() : col.pinned();
            Integer displayOrder = override.order() != null ? override.order() : col.displayOrder();
            String mergedRulesConfig = mergeRulesConfig(col.rulesConfig(), override);

            result.add(copyColumn(
                    col,
                    displayOrder,
                    width,
                    visible,
                    editable,
                    required,
                    searchable,
                    sortable,
                    pinned,
                    mergedRulesConfig));
        }
        return result;
    }

    private Boolean tightenBoolean(Boolean base, Boolean tightenWith) {
        boolean baseAllowed = base == null || base;
        if (tightenWith == null) {
            return baseAllowed;
        }
        return baseAllowed && tightenWith;
    }

    private Map<String, ColumnOverride> loadColumnOverrides(String pageCode, String gridKey) {
        if (StrUtil.isBlank(pageCode) || StrUtil.isBlank(gridKey)) {
            return Collections.emptyMap();
        }
        List<String> componentKeys = new ArrayList<>();
        componentKeys.add(gridKey);
        if ("masterGrid".equals(gridKey)) {
            componentKeys.add("master");
        }
        if ("master".equals(gridKey)) {
            componentKeys.add("masterGrid");
        }

        List<PageRule> rules = pageRuleMapper.selectList(
                new LambdaQueryWrapper<PageRule>()
                        .eq(PageRule::getPageCode, pageCode)
                        .eq(PageRule::getRuleType, "COLUMN_OVERRIDE")
                        .eq(PageRule::getDeleted, 0)
                        .in(PageRule::getComponentKey, componentKeys)
                        .orderByAsc(PageRule::getSortOrder));

        if (rules.isEmpty()) {
            return Collections.emptyMap();
        }

        PageRule selected = null;
        for (String key : componentKeys) {
            for (PageRule rule : rules) {
                if (key.equals(rule.getComponentKey())) {
                    selected = rule;
                    break;
                }
            }
            if (selected != null)
                break;
        }

        if (selected == null || StrUtil.isBlank(selected.getRules())) {
            return Collections.emptyMap();
        }
        return parseColumnOverrides(selected.getRules());
    }

    private Map<String, ColumnOverride> parseColumnOverrides(String rules) {
        try {
            JsonNode root = objectMapper.readTree(rules);
            if (!root.isArray()) {
                log.warn("COLUMN_OVERRIDE rules is not an array");
                return Collections.emptyMap();
            }
            Map<String, ColumnOverride> result = new HashMap<>();
            for (JsonNode node : root) {
                String field = text(node, "field");
                if (StrUtil.isBlank(field)) {
                    field = text(node, "fieldName");
                }
                if (StrUtil.isBlank(field))
                    continue;
                ColumnOverride override = new ColumnOverride(
                        number(node, "width"),
                        bool(node, "visible"),
                        bool(node, "editable"),
                        bool(node, "required"),
                        bool(node, "searchable"),
                        bool(node, "sortable"),
                        normalizePinned(text(node, "pinned")),
                        number(node, "order", "displayOrder"),
                        parseOverrideConfig(node.get("format"), "format"),
                        number(node, "precision"),
                        bool(node, "trimZeros"),
                        text(node, "roundMode"),
                        text(node, "cellEditor"),
                        parseOverrideConfig(node.get("cellEditorParams"), "cellEditorParams"),
                        text(node, "aggFunc"),
                        parseOverrideConfig(node.get("rulesConfig"), "rulesConfig"));
                result.put(field, override);
            }
            return result;
        } catch (Exception e) {
            log.warn("Failed to parse COLUMN_OVERRIDE rules: {}", e.getMessage());
            return Collections.emptyMap();
        }
    }

    private String normalizePinned(String value) {
        if (value == null)
            return null;
        if ("left".equalsIgnoreCase(value))
            return "left";
        if ("right".equalsIgnoreCase(value))
            return "right";
        return null;
    }

    private Integer number(JsonNode node, String... keys) {
        for (String key : keys) {
            JsonNode value = node.get(key);
            if (value == null || value.isNull())
                continue;
            if (value.isNumber())
                return value.intValue();
            if (value.isTextual()) {
                try {
                    return Integer.parseInt(value.asText());
                } catch (NumberFormatException ignored) {
                    return null;
                }
            }
        }
        return null;
    }

    private Boolean bool(JsonNode node, String key) {
        JsonNode value = node.get(key);
        if (value == null || value.isNull())
            return null;
        if (value.isBoolean())
            return value.asBoolean();
        if (value.isNumber()) {
            int intValue = value.asInt();
            if (intValue == 1) return true;
            if (intValue == 0) return false;
            return null;
        }
        if (value.isTextual()) {
            String text = value.asText().trim();
            if ("1".equals(text)) return true;
            if ("0".equals(text)) return false;
            return Boolean.parseBoolean(text);
        }
        return null;
    }

    private String text(JsonNode node, String key) {
        JsonNode value = node.get(key);
        return value != null && value.isTextual() ? value.asText() : null;
    }

    private JsonNode parseOverrideConfig(JsonNode node, String label) {
        if (node == null || node.isNull())
            return null;
        if (node.isObject())
            return node;
        if (node.isTextual()) {
            try {
                return objectMapper.readTree(node.asText());
            } catch (Exception e) {
                log.warn("Failed to parse {} JSON: {}", label, e.getMessage());
            }
        }
        return null;
    }

    private String mergeRulesConfig(String baseRulesConfig, ColumnOverride override) {
        if (!hasRulesConfigOverride(override)) {
            return baseRulesConfig;
        }

        ObjectNode merged = parseRulesConfigObject(baseRulesConfig);

        if (override.rulesConfig() != null) {
            deepMergeObject(merged, override.rulesConfig());
        }
        if (override.format() != null) {
            merged.set("format", override.format().deepCopy());
        }
        if (override.precision() != null) {
            merged.put("precision", override.precision());
        }
        if (override.trimZeros() != null) {
            merged.put("trimZeros", override.trimZeros());
        }
        if (StrUtil.isNotBlank(override.roundMode())) {
            merged.put("roundMode", override.roundMode());
            ObjectNode formatNode = ensureObjectNode(merged, "format");
            formatNode.put("roundMode", override.roundMode());
        }
        if (StrUtil.isNotBlank(override.aggFunc())) {
            merged.put("aggFunc", override.aggFunc());
        }
        if (override.cellEditorParams() != null) {
            merged.set("cellEditorParams", override.cellEditorParams().deepCopy());
        }
        if (StrUtil.isNotBlank(override.cellEditor())) {
            merged.put("cellEditor", override.cellEditor());
            applyEditorConfig(merged, override);
        }

        if (merged.isEmpty()) {
            return null;
        }
        try {
            return objectMapper.writeValueAsString(merged);
        } catch (Exception e) {
            log.warn("Failed to serialize merged rulesConfig: {}", e.getMessage());
            return baseRulesConfig;
        }
    }

    private String applyVisibilityLock(String baseRulesConfig, boolean lockVisible) {
        if (!lockVisible) {
            return baseRulesConfig;
        }
        ObjectNode merged = parseRulesConfigObject(baseRulesConfig);
        ObjectNode columnControl = ensureObjectNode(merged, "columnControl");
        columnControl.put("lockVisible", true);
        try {
            return objectMapper.writeValueAsString(merged);
        } catch (Exception e) {
            log.warn("Failed to serialize visibility lock rulesConfig: {}", e.getMessage());
            return baseRulesConfig;
        }
    }

    private boolean hasRulesConfigOverride(ColumnOverride override) {
        if (override == null) {
            return false;
        }
        return override.rulesConfig() != null
                || override.format() != null
                || override.precision() != null
                || override.trimZeros() != null
                || StrUtil.isNotBlank(override.roundMode())
                || StrUtil.isNotBlank(override.aggFunc())
                || StrUtil.isNotBlank(override.cellEditor())
                || override.cellEditorParams() != null;
    }

    private ObjectNode parseRulesConfigObject(String rawRulesConfig) {
        if (StrUtil.isBlank(rawRulesConfig)) {
            return objectMapper.createObjectNode();
        }
        try {
            JsonNode node = objectMapper.readTree(rawRulesConfig);
            if (node != null && node.isObject()) {
                return (ObjectNode) node.deepCopy();
            }
        } catch (Exception e) {
            log.warn("Failed to parse base rulesConfig JSON: {}", e.getMessage());
        }
        return objectMapper.createObjectNode();
    }

    private void deepMergeObject(ObjectNode target, JsonNode patch) {
        if (target == null || patch == null || patch.isNull() || !patch.isObject()) {
            return;
        }
        patch.fields().forEachRemaining(entry -> {
            String key = entry.getKey();
            JsonNode patchValue = entry.getValue();
            JsonNode currentValue = target.get(key);
            if (currentValue != null && currentValue.isObject() && patchValue != null && patchValue.isObject()) {
                deepMergeObject((ObjectNode) currentValue, patchValue);
            } else if (patchValue != null) {
                target.set(key, patchValue.deepCopy());
            }
        });
    }

    private ObjectNode ensureObjectNode(ObjectNode parent, String key) {
        JsonNode node = parent.get(key);
        if (node != null && node.isObject()) {
            return (ObjectNode) node;
        }
        ObjectNode created = objectMapper.createObjectNode();
        parent.set(key, created);
        return created;
    }

    private void applyEditorConfig(ObjectNode merged, ColumnOverride override) {
        String cellEditor = override.cellEditor();
        if (StrUtil.isBlank(cellEditor)) {
            return;
        }

        ObjectNode editorNode = ensureObjectNode(merged, "editor");
        editorNode.put("type", cellEditor);

        JsonNode params = override.cellEditorParams();
        if (params != null) {
            editorNode.set("params", params.deepCopy());
        }

        if (!"lookup".equalsIgnoreCase(cellEditor) || params == null || !params.isObject()) {
            return;
        }

        String lookupCode = text(params, "lookupCode");
        JsonNode mapping = params.get("mapping");
        if (StrUtil.isBlank(lookupCode) || mapping == null || !mapping.isObject()) {
            return;
        }

        ObjectNode lookupNode = ensureObjectNode(merged, "lookup");
        lookupNode.put("code", lookupCode);
        lookupNode.set("mapping", mapping.deepCopy());

        Boolean noFillback = bool(params, "noFillback");
        if (noFillback != null) {
            lookupNode.put("noFillback", noFillback);
        }
        String filterField = text(params, "filterField");
        if (StrUtil.isNotBlank(filterField)) {
            lookupNode.put("filterField", filterField);
        }
        String filterColumn = text(params, "filterColumn");
        if (StrUtil.isNotBlank(filterColumn)) {
            lookupNode.put("filterColumn", filterColumn);
        }
        String filterValueFrom = text(params, "filterValueFrom");
        if (StrUtil.isNotBlank(filterValueFrom)) {
            lookupNode.put("filterValueFrom", filterValueFrom);
        }
    }

    private ColumnMetadataDTO copyColumn(
            ColumnMetadataDTO col,
            Integer displayOrder,
            Integer width,
            Boolean visible,
            Boolean editable,
            Boolean required,
            Boolean searchable,
            Boolean sortable,
            String pinned,
            String rulesConfig) {
        return new ColumnMetadataDTO(
                col.id(),
                col.fieldName(),
                col.columnName(),
                col.queryColumn(),
                col.targetColumn(),
                col.headerText(),
                col.dataType(),
                displayOrder,
                width,
                visible,
                editable,
                required,
                searchable,
                sortable,
                pinned,
                col.dictType(),
                col.lookupConfigId(),
                col.defaultValue(),
                rulesConfig,
                col.isVirtual());
    }

    private record ColumnOverride(
            Integer width,
            Boolean visible,
            Boolean editable,
            Boolean required,
            Boolean searchable,
            Boolean sortable,
            String pinned,
            Integer order,
            JsonNode format,
            Integer precision,
            Boolean trimZeros,
            String roundMode,
            String cellEditor,
            JsonNode cellEditorParams,
            String aggFunc,
            JsonNode rulesConfig) {
    }

    public boolean isValidTable(String tableCode) {
        return cache.containsKey(tableCode) || tableMetadataMapper.selectCount(
                new LambdaQueryWrapper<TableMetadata>()
                        .eq(TableMetadata::getTableCode, tableCode)) > 0;
    }

    /**
     * 查找所有以指定表为父表的子表
     */
    public List<TableMetadataDTO> findChildTables(String parentTableCode) {
        List<TableMetadata> childTables = tableMetadataMapper.selectList(
                new LambdaQueryWrapper<TableMetadata>()
                        .eq(TableMetadata::getParentTableCode, parentTableCode));
        return childTables.stream()
                .map(t -> getTableMetadata(t.getTableCode()))
                .toList();
    }

    /**
     * 获取页面组件树
     */
    public List<PageComponentDTO> getPageComponents(String pageCode) {
        return getPageComponents(pageCode, null);
    }
    
    /**
     * 获取页面组件树（带权限过滤）
     */
    public List<PageComponentDTO> getPageComponents(String pageCode, Set<String> allowedButtons) {
        List<PageComponent> components = pageComponentMapper.selectList(
                new LambdaQueryWrapper<PageComponent>()
                        .eq(PageComponent::getPageCode, pageCode)
                        .orderByAsc(PageComponent::getSortOrder));

        Map<String, List<PageRuleDTO>> rulesByComponent = getPageRules(pageCode).stream()
                .filter(rule -> StrUtil.isNotBlank(rule.componentKey()))
                .collect(Collectors.groupingBy(PageRuleDTO::componentKey));
        
        // 构建 tableCode -> tableName 映射
        Map<String, String> tableNameMap = buildTableNameMap(components);

        // 构建树形结构
        Map<String, List<PageComponentDTO>> childrenMap = components.stream()
                .filter(c -> StrUtil.isNotBlank(c.getParentKey()))
                .map(component -> toDTOWithRules(component, rulesByComponent))
                .map(dto -> filterButtonsInComponent(dto, allowedButtons, tableNameMap))
                .collect(Collectors.groupingBy(PageComponentDTO::parentKey));

        return components.stream()
                .filter(c -> StrUtil.isBlank(c.getParentKey()))
                .map(component -> toDTOWithRules(component, rulesByComponent))
                .map(dto -> filterButtonsInComponent(dto, allowedButtons, tableNameMap))
                .map(dto -> buildTree(dto, childrenMap))
                .toList();
    }
    
    /**
     * 构建 tableCode -> tableName 映射
     */
    private Map<String, String> buildTableNameMap(List<PageComponent> components) {
        Set<String> tableCodes = new HashSet<>();
        for (PageComponent c : components) {
            if (StrUtil.isNotBlank(c.getRefTableCode())) {
                tableCodes.add(c.getRefTableCode());
            }
            // 从 TABS 组件的 config 中提取 tableCode
            if ("TABS".equalsIgnoreCase(c.getComponentType()) && StrUtil.isNotBlank(c.getComponentConfig())) {
                try {
                    cn.hutool.json.JSONObject config = cn.hutool.json.JSONUtil.parseObj(c.getComponentConfig());
                    cn.hutool.json.JSONArray tabs = config.getJSONArray("tabs");
                    if (tabs != null) {
                        for (int i = 0; i < tabs.size(); i++) {
                            String tableCode = tabs.getJSONObject(i).getStr("tableCode");
                            if (StrUtil.isNotBlank(tableCode)) {
                                tableCodes.add(tableCode);
                            }
                        }
                    }
                } catch (Exception ignored) {}
            }
        }
        
        if (tableCodes.isEmpty()) {
            return Collections.emptyMap();
        }
        
        List<TableMetadata> tables = tableMetadataMapper.selectList(
                new LambdaQueryWrapper<TableMetadata>()
                        .in(TableMetadata::getTableCode, tableCodes));
        
        Map<String, String> map = new HashMap<>();
        for (TableMetadata t : tables) {
            map.put(t.getTableCode(), t.getTableName());
        }
        return map;
    }
    
    /**
     * 过滤组件中的按钮（根据用户权限）
     */
    private PageComponentDTO filterButtonsInComponent(PageComponentDTO dto, Set<String> allowedButtons, Map<String, String> tableNameMap) {
        // null 表示不过滤（如 admin 用户或未传入权限）
        // 包含 "*" 表示全部权限
        if (allowedButtons == null || allowedButtons.contains("*")) {
            return dto;
        }
        // 空集合表示没有任何按钮权限，需要过滤掉所有按钮
        
        String config = dto.componentConfig();
        if (StrUtil.isBlank(config)) {
            return dto;
        }
        
        try {
            cn.hutool.json.JSONObject configJson = cn.hutool.json.JSONUtil.parseObj(config);
            boolean modified = false;
            
            // 处理 GRID 组件的 buttons - 使用表的中文名作为 groupName
            if (configJson.containsKey("buttons")) {
                String tableName = tableNameMap.get(dto.refTableCode());
                cn.hutool.json.JSONArray buttons = configJson.getJSONArray("buttons");
                cn.hutool.json.JSONArray filteredButtons = filterButtons(buttons, allowedButtons, tableName);
                configJson.set("buttons", filteredButtons);
                modified = true;
            }
            
            // 处理 TABS 组件的 tabs[].buttons - 使用 tab 的 title 作为 groupName
            if (configJson.containsKey("tabs")) {
                cn.hutool.json.JSONArray tabs = configJson.getJSONArray("tabs");
                for (int i = 0; i < tabs.size(); i++) {
                    cn.hutool.json.JSONObject tab = tabs.getJSONObject(i);
                    String tabTitle = tab.getStr("title");
                    if (tab.containsKey("buttons")) {
                        cn.hutool.json.JSONArray buttons = tab.getJSONArray("buttons");
                        cn.hutool.json.JSONArray filteredButtons = filterButtons(buttons, allowedButtons, tabTitle);
                        tab.set("buttons", filteredButtons);
                        modified = true;
                    }
                }
            }
            
            if (modified) {
                return dto.withComponentConfig(configJson.toString());
            }
        } catch (Exception e) {
            log.warn("过滤按钮失败, componentKey={}, error={}", dto.componentKey(), e.getMessage());
        }
        
        return dto;
    }
    
    /**
     * 过滤按钮数组
     */
    private cn.hutool.json.JSONArray filterButtons(cn.hutool.json.JSONArray buttons, Set<String> allowedButtons, String groupName) {
        cn.hutool.json.JSONArray result = new cn.hutool.json.JSONArray();
        for (int i = 0; i < buttons.size(); i++) {
            cn.hutool.json.JSONObject btn = buttons.getJSONObject(i);
            String action = btn.getStr("action");
            String type = btn.getStr("type");
            
            // 保留分隔符
            if ("separator".equals(type)) {
                result.add(btn);
                continue;
            }
            
            // 处理子菜单
            if (btn.containsKey("items")) {
                cn.hutool.json.JSONArray subItems = btn.getJSONArray("items");
                cn.hutool.json.JSONArray filteredSubItems = filterButtons(subItems, allowedButtons, groupName);
                if (!filteredSubItems.isEmpty()) {
                    cn.hutool.json.JSONObject newBtn = new cn.hutool.json.JSONObject(btn);
                    newBtn.set("items", filteredSubItems);
                    result.add(newBtn);
                }
                continue;
            }
            
            // 检查权限
            if (action != null) {
                String fullKey = groupName != null ? groupName + ":" + action : action;
                if (allowedButtons.contains(fullKey) || allowedButtons.contains(action)) {
                    result.add(btn);
                }
            }
        }
        return result;
    }

    private PageComponentDTO buildTree(PageComponentDTO node, Map<String, List<PageComponentDTO>> childrenMap) {
        List<PageComponentDTO> children = childrenMap.get(node.componentKey());
        if (children == null || children.isEmpty()) {
            return node;
        }
        List<PageComponentDTO> builtChildren = children.stream()
                .map(child -> buildTree(child, childrenMap))
                .toList();
        return node.withChildren(builtChildren);
    }

    public List<PageRuleDTO> getPageRules(String pageCode) {
        List<PageRule> rules = pageRuleMapper.selectList(
                new LambdaQueryWrapper<PageRule>()
                        .eq(PageRule::getPageCode, pageCode)
                        .orderByAsc(PageRule::getSortOrder));
        return rules.stream().map(PageRuleDTO::from).toList();
    }

    private PageComponentDTO toDTOWithRules(PageComponent component, Map<String, List<PageRuleDTO>> rulesByComponent) {
        PageComponentDTO dto = PageComponentDTO.from(component);
        List<PageRuleDTO> rules = resolveComponentRules(component, rulesByComponent);
        if (rules.isEmpty()) {
            return dto;
        }
        return dto.withRules(rules);
    }

    private List<PageRuleDTO> resolveComponentRules(PageComponent component,
            Map<String, List<PageRuleDTO>> rulesByComponent) {
        List<PageRuleDTO> rules = new ArrayList<>();
        addRules(rules, rulesByComponent.get(component.getComponentKey()));
        if ("masterGrid".equals(component.getComponentKey())) {
            addRules(rules, rulesByComponent.get("master"));
        }
        if ("TABS".equalsIgnoreCase(component.getComponentType())) {
            for (String tabKey : extractTabKeys(component)) {
                addRules(rules, rulesByComponent.get(tabKey));
            }
        }
        rules.sort(Comparator.comparingInt(rule -> rule.sortOrder() == null ? 0 : rule.sortOrder()));
        return rules;
    }

    private void addRules(List<PageRuleDTO> target, List<PageRuleDTO> source) {
        if (source == null || source.isEmpty()) {
            return;
        }
        target.addAll(source);
    }

    private List<String> extractTabKeys(PageComponent component) {
        String config = component.getComponentConfig();
        if (StrUtil.isBlank(config)) {
            return Collections.emptyList();
        }
        try {
            JsonNode root = objectMapper.readTree(config);
            JsonNode tabs = root.get("tabs");
            if (tabs == null || !tabs.isArray()) {
                return Collections.emptyList();
            }
            List<String> keys = new ArrayList<>();
            for (JsonNode tab : tabs) {
                JsonNode key = tab.get("key");
                if (key != null && key.isTextual()) {
                    keys.add(key.asText());
                }
            }
            return keys;
        } catch (Exception e) {
            log.warn("Failed to parse tabs config for component {}: {}", component.getComponentKey(), e.getMessage());
            return Collections.emptyList();
        }
    }

    /**
     * 获取字典项
     */
    public List<DictionaryItemDTO> getDictItems(String dictType) {
        DictionaryType type = dictionaryTypeMapper.selectOne(
                new LambdaQueryWrapper<DictionaryType>()
                        .eq(DictionaryType::getTypeCode, dictType));
        if (type == null) {
            return Collections.emptyList();
        }

        List<DictionaryItem> items = dictionaryItemMapper.selectList(
                new LambdaQueryWrapper<DictionaryItem>()
                        .eq(DictionaryItem::getTypeId, type.getId())
                        .orderByAsc(DictionaryItem::getSortOrder));

        return items.stream().map(DictionaryItemDTO::from).toList();
    }

    private String camelToKebab(String camel) {
        StringBuilder sb = new StringBuilder();
        for (char c : camel.toCharArray()) {
            if (Character.isUpperCase(c)) {
                if (!sb.isEmpty())
                    sb.append('-');
                sb.append(Character.toLowerCase(c));
            } else {
                sb.append(c);
            }
        }
        return sb.toString();
    }

    /**
     * 获取弹窗选择器配置
     */
    public LookupConfigDTO getLookupConfig(String lookupCode) {
        LookupConfig config = lookupConfigMapper.selectOne(
                new LambdaQueryWrapper<LookupConfig>()
                        .eq(LookupConfig::getLookupCode, lookupCode));
        if (config == null) {
            throw new BusinessException(400, "弹窗选择器配置不存在: " + lookupCode);
        }
        return LookupConfigDTO.from(config);
    }

    /**
     * 通过页面编码获取关联的主表元数据
     * 查找页面组件中 componentType=GRID 且 componentKey=masterGrid 的组件，获取其 refTableCode
     */
    public TableMetadataDTO getTableMetadataByPageCode(String pageCode) {
        if (StrUtil.isBlank(pageCode)) {
            return null;
        }
        List<PageComponent> components = pageComponentMapper.selectList(
                new LambdaQueryWrapper<PageComponent>()
                        .eq(PageComponent::getPageCode, pageCode)
                        .eq(PageComponent::getComponentType, "GRID"));

        // 优先找 masterGrid，其次找 grid
        PageComponent masterGrid = null;
        for (PageComponent c : components) {
            if ("masterGrid".equals(c.getComponentKey()) || "master".equals(c.getComponentKey())) {
                masterGrid = c;
                break;
            }
            if ("grid".equals(c.getComponentKey()) && masterGrid == null) {
                masterGrid = c;
            }
        }
        if (masterGrid == null && !components.isEmpty()) {
            masterGrid = components.get(0);
        }

        if (masterGrid == null || StrUtil.isBlank(masterGrid.getRefTableCode())) {
            return null;
        }

        try {
            return getTableMetadata(masterGrid.getRefTableCode());
        } catch (Exception e) {
            log.warn("Failed to get table metadata for page {}: {}", pageCode, e.getMessage());
            return null;
        }
    }
}
