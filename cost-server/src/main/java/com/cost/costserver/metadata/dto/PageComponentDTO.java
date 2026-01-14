package com.cost.costserver.metadata.dto;

import com.cost.costserver.metadata.entity.PageComponent;

import java.util.List;

public record PageComponentDTO(
    Long id,
    String pageCode,
    String componentKey,
    String componentType,
    String parentKey,
    String componentConfig,
    String refTableCode,
    String slotName,
    Integer sortOrder,
    String description,
    List<PageRuleDTO> rules,
    List<PageComponentDTO> children
) {
    public static PageComponentDTO from(PageComponent entity) {
        return new PageComponentDTO(
            entity.getId(),
            entity.getPageCode(),
            entity.getComponentKey(),
            entity.getComponentType(),
            entity.getParentKey(),
            entity.getComponentConfig(),
            entity.getRefTableCode(),
            entity.getSlotName(),
            entity.getSortOrder(),
            entity.getDescription(),
            null,
            null
        );
    }

    public PageComponentDTO withChildren(List<PageComponentDTO> children) {
        return new PageComponentDTO(
            id, pageCode, componentKey, componentType, parentKey,
            componentConfig, refTableCode, slotName, sortOrder, description, rules, children
        );
    }

    public PageComponentDTO withRules(List<PageRuleDTO> rules) {
        return new PageComponentDTO(
            id, pageCode, componentKey, componentType, parentKey,
            componentConfig, refTableCode, slotName, sortOrder, description, rules, children
        );
    }
}
