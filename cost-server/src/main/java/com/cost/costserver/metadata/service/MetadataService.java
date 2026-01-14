package com.cost.costserver.metadata.service;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.cost.costserver.auth.dto.ColumnPermission;
import com.cost.costserver.auth.dto.PagePermission;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.metadata.dto.*;
import com.cost.costserver.metadata.entity.*;
import com.cost.costserver.metadata.mapper.*;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
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

    private final Map<String, TableMetadataDTO> cache = new ConcurrentHashMap<>();

    public TableMetadataDTO getTableMetadata(String tableCode) {
        TableMetadataDTO cached = cache.get(tableCode);
        if (cached != null) {
            return cached;
        }

        TableMetadata table = tableMetadataMapper.selectOne(
            new LambdaQueryWrapper<TableMetadata>()
                .eq(TableMetadata::getTableCode, tableCode)
        );
        if (table == null) {
            throw new BusinessException(400, "表元数据不存在: " + tableCode);
        }

        List<ColumnMetadata> columns = columnMetadataMapper.selectList(
            new LambdaQueryWrapper<ColumnMetadata>()
                .eq(ColumnMetadata::getTableMetadataId, table.getId())
                .orderByAsc(ColumnMetadata::getDisplayOrder)
        );

        TableMetadataDTO dto = TableMetadataDTO.from(table, columns);
        cache.put(tableCode, dto);
        return dto;
    }

    /**
     * 获取表元数据（合并权限）
     * 将角色的列权限合并到列元数据中返回
     */
    public TableMetadataDTO getTableMetadataWithPermission(String tableCode, PagePermission permission) {
        TableMetadataDTO base = getTableMetadata(tableCode);
        
        if (permission == null || permission.columns() == null || permission.columns().isEmpty()) {
            return base;
        }
        
        // 合并列权限到列元数据
        List<ColumnMetadataDTO> mergedColumns = base.columns().stream()
            .map(col -> {
                ColumnPermission colPerm = permission.getColumnPermission(col.fieldName());
                // 权限只能收紧，不能放宽
                boolean visible = col.visible() && colPerm.visible();
                boolean editable = col.editable() && colPerm.editable();
                return col.withPermission(visible, editable);
            })
            .filter(col -> col.visible()) // 过滤掉不可见的列
            .toList();
        
        return base.withColumns(mergedColumns);
    }

    public void clearCache(String tableCode) {
        if (tableCode == null) {
            cache.clear();
        } else {
            cache.remove(tableCode);
        }
    }

    public boolean isValidTable(String tableCode) {
        return cache.containsKey(tableCode) || tableMetadataMapper.selectCount(
            new LambdaQueryWrapper<TableMetadata>()
                .eq(TableMetadata::getTableCode, tableCode)
        ) > 0;
    }

    /**
     * 查找所有以指定表为父表的子表
     */
    public List<TableMetadataDTO> findChildTables(String parentTableCode) {
        List<TableMetadata> childTables = tableMetadataMapper.selectList(
            new LambdaQueryWrapper<TableMetadata>()
                .eq(TableMetadata::getParentTableCode, parentTableCode)
        );
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
                .orderByAsc(PageComponent::getSortOrder)
        );

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
                .orderByAsc(PageRule::getSortOrder)
        );
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

    private List<PageRuleDTO> resolveComponentRules(PageComponent component, Map<String, List<PageRuleDTO>> rulesByComponent) {
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
                .eq(DictionaryType::getTypeCode, dictType)
        );
        if (type == null) {
            return Collections.emptyList();
        }

        List<DictionaryItem> items = dictionaryItemMapper.selectList(
            new LambdaQueryWrapper<DictionaryItem>()
                .eq(DictionaryItem::getTypeId, type.getId())
                .orderByAsc(DictionaryItem::getSortOrder)
        );

        return items.stream().map(DictionaryItemDTO::from).toList();
    }

    private String camelToKebab(String camel) {
        StringBuilder sb = new StringBuilder();
        for (char c : camel.toCharArray()) {
            if (Character.isUpperCase(c)) {
                if (!sb.isEmpty()) sb.append('-');
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
                .eq(LookupConfig::getLookupCode, lookupCode)
        );
        if (config == null) {
            throw new BusinessException(400, "弹窗选择器配置不存在: " + lookupCode);
        }
        return LookupConfigDTO.from(config);
    }
}
