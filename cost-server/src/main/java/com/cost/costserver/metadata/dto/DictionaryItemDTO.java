package com.cost.costserver.metadata.dto;

import com.cost.costserver.metadata.entity.DictionaryItem;

public record DictionaryItemDTO(
    String code,
    String name,
    String value,
    Integer sortOrder,
    String extraConfig
) {
    public static DictionaryItemDTO from(DictionaryItem entity) {
        return new DictionaryItemDTO(
            entity.getItemCode(),
            entity.getItemName(),
            entity.getItemValue(),
            entity.getSortOrder(),
            entity.getExtraConfig()
        );
    }
}
