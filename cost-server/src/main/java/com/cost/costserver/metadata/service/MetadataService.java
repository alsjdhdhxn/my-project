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
        List<ColumnMetadataDTO> columns = applyColumnOverrides(base.columns(), pageCode, gridKey);
        columns = applyPermission(columns, permission);
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

    private List<ColumnMetadataDTO> applyPermission(List<ColumnMetadataDTO> columns, PagePermission permission) {
        if (permission == null) {
            return columns;
        }
        List<ColumnMetadataDTO> result = new ArrayList<>();
        for (ColumnMetadataDTO col : columns) {
            ColumnPermission colPerm = permission.getColumnPermission(col.fieldName());
            if (colPerm != null && !colPerm.visible()) {
                continue;
            }
            boolean editable = col.editable() != null ? col.editable() : true;
            if (colPerm != null && !colPerm.editable()) {
                editable = false;
            }
            result.add(copyColumn(col, col.displayOrder(), col.width(), col.visible(), editable,
                    col.required(), col.searchable(), col.sortable(), col.pinned(), col.rulesConfig()));
        }
        return result;
    }

    private List<ColumnMetadataDTO> applyColumnOverrides(List<ColumnMetadataDTO> columns, String pageCode,
            String gridKey) {
        Map<String, ColumnOverride> overrides = loadColumnOverrides(pageCode, gridKey);
        if (overrides.isEmpty()) {
            return columns;
        }
        List<ColumnMetadataDTO> result = new ArrayList<>();
        for (ColumnMetadataDTO col : columns) {
            ColumnOverride override = overrides.get(col.fieldName());
            if (override == null) {
                result.add(col);
                continue;
            }
            Integer displayOrder = override.order() != null ? override.order() : col.displayOrder();
            Integer width = override.width() != null ? override.width() : col.width();
            Boolean visible = override.visible() != null ? override.visible() : col.visible();
            Boolean editable = override.editable() != null ? override.editable() : col.editable();
            Boolean required = override.required() != null ? override.required() : col.required();
            Boolean searchable = override.searchable() != null ? override.searchable() : col.searchable();
            Boolean sortable = override.sortable() != null ? override.sortable() : col.sortable();
            String pinned = override.pinned() != null ? override.pinned() : col.pinned();
            String rulesConfig = mergeRulesConfig(col.rulesConfig(), override, col.fieldName());
            result.add(copyColumn(col, displayOrder, width, visible, editable, required, searchable, sortable, pinned,
                    rulesConfig));
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

            if (pref != null) {
                if (pref.width() != null) {
                    width = pref.width();
                }
                if (pref.hidden() != null) {
                    visible = !pref.hidden();
                }
                pinned = pref.pinned();
            }

            result.add(copyColumn(col, displayOrder, width, visible, col.editable(),
                    col.required(), col.searchable(), col.sortable(), pinned, col.rulesConfig()));
            index++;
        }
        return result;
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
        if (value.isTextual()) {
            return Boolean.parseBoolean(value.asText());
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

    private String mergeRulesConfig(String baseConfig, ColumnOverride override, String fieldName) {
        if (override == null)
            return baseConfig;
        if (override.format() == null && override.precision() == null && override.trimZeros() == null
                && override.rulesConfig() == null) {
            return baseConfig;
        }

        ObjectNode root = parseRulesConfig(baseConfig, fieldName);
        if (override.rulesConfig() instanceof ObjectNode overrideNode) {
            mergeObjectNode(root, overrideNode);
        }

        if (override.format() instanceof ObjectNode formatNode) {
            root.set("format", formatNode);
        }

        if (override.precision() != null || override.trimZeros() != null) {
            ObjectNode format = root.with("format");
            if (override.precision() != null) {
                format.put("precision", override.precision());
            }
            if (override.trimZeros() != null) {
                format.put("trimZeros", override.trimZeros());
            }
        }

        return root.toString();
    }

    private ObjectNode parseRulesConfig(String raw, String fieldName) {
        if (StrUtil.isBlank(raw)) {
            return objectMapper.createObjectNode();
        }
        try {
            JsonNode parsed = objectMapper.readTree(raw);
            if (parsed instanceof ObjectNode objectNode) {
                return objectNode;
            }
            log.warn("rulesConfig is not an object: {}", fieldName);
        } catch (Exception e) {
            log.warn("Failed to parse rulesConfig for {}: {}", fieldName, e.getMessage());
        }
        return objectMapper.createObjectNode();
    }

    private void mergeObjectNode(ObjectNode target, ObjectNode override) {
        Iterator<Map.Entry<String, JsonNode>> fields = override.fields();
        while (fields.hasNext()) {
            Map.Entry<String, JsonNode> entry = fields.next();
            target.set(entry.getKey(), entry.getValue());
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
        List<PageComponent> components = pageComponentMapper.selectList(
                new LambdaQueryWrapper<PageComponent>()
                        .eq(PageComponent::getPageCode, pageCode)
                        .orderByAsc(PageComponent::getSortOrder));

        Map<String, List<PageRuleDTO>> rulesByComponent = getPageRules(pageCode).stream()
                .filter(rule -> StrUtil.isNotBlank(rule.componentKey()))
                .collect(Collectors.groupingBy(PageRuleDTO::componentKey));

        // 构建树形结构
        Map<String, List<PageComponentDTO>> childrenMap = components.stream()
                .filter(c -> StrUtil.isNotBlank(c.getParentKey()))
                .map(component -> toDTOWithRules(component, rulesByComponent))
                .collect(Collectors.groupingBy(PageComponentDTO::parentKey));

        return components.stream()
                .filter(c -> StrUtil.isBlank(c.getParentKey()))
                .map(component -> toDTOWithRules(component, rulesByComponent))
                .map(dto -> buildTree(dto, childrenMap))
                .toList();
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
                        .eq(PageRule::getDeleted, 0)
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
