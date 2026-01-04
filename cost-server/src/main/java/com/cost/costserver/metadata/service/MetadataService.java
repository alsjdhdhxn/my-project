package com.cost.costserver.metadata.service;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.metadata.dto.*;
import com.cost.costserver.metadata.entity.*;
import com.cost.costserver.metadata.mapper.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class MetadataService {

    private final TableMetadataMapper tableMetadataMapper;
    private final ColumnMetadataMapper columnMetadataMapper;
    private final PageComponentMapper pageComponentMapper;
    private final DictionaryTypeMapper dictionaryTypeMapper;
    private final DictionaryItemMapper dictionaryItemMapper;
    private final LookupConfigMapper lookupConfigMapper;

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

        // 构建树形结构
        Map<String, List<PageComponentDTO>> childrenMap = components.stream()
            .filter(c -> StrUtil.isNotBlank(c.getParentKey()))
            .map(PageComponentDTO::from)
            .collect(Collectors.groupingBy(PageComponentDTO::parentKey));

        return components.stream()
            .filter(c -> StrUtil.isBlank(c.getParentKey()))
            .map(PageComponentDTO::from)
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
