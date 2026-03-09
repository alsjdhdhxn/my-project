package com.cost.costserver.grid.dto;

public record ColumnPreference(
    Long columnId,
    String columnName,
    Integer width,
    Integer order,
    Boolean hidden,
    String pinned
) {
}
