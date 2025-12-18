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
    Long refMetadataId,
    String slotName,
    Integer sortOrder,
    String description,
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
            entity.getRefMetadataId(),
            entity.getSlotName(),
            entity.getSortOrder(),
            entity.getDescription(),
            null
        );
    }

    public PageComponentDTO withChildren(List<PageComponentDTO> children) {
        return new PageComponentDTO(
            id, pageCode, componentKey, componentType, parentKey,
            componentConfig, refMetadataId, slotName, sortOrder, description, children
        );
    }
}
