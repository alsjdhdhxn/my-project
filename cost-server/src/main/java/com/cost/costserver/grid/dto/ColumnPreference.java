package com.cost.costserver.grid.dto;

public record ColumnPreference(
    String field,
    Integer width,
    Integer order,
    Boolean hidden,
    String pinned
) {
}
