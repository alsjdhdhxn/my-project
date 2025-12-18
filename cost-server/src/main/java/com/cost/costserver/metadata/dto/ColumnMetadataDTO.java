package com.cost.costserver.metadata.dto;

import com.cost.costserver.metadata.entity.ColumnMetadata;

/**
 * 列元数据 DTO - 用于 API 返回
 */
public record ColumnMetadataDTO(
    Long id,
    String fieldName,
    String columnName,
    String queryColumn,
    String targetColumn,
    String headerText,
    String dataType,
    Integer displayOrder,
    Integer width,
    Boolean visible,
    Boolean editable,
    Boolean required,
    Boolean searchable,
    Boolean sortable,
    String dictType,
    Long lookupConfigId,
    String defaultValue,
    String rulesConfig
) {
    public static ColumnMetadataDTO from(ColumnMetadata entity) {
        return new ColumnMetadataDTO(
            entity.getId(),
            entity.getFieldName(),
            entity.getColumnName(),
            entity.getQueryColumn(),
            entity.getTargetColumn(),
            entity.getHeaderText(),
            entity.getDataType(),
            entity.getDisplayOrder(),
            entity.getWidth(),
            intToBoolean(entity.getVisible()),
            intToBoolean(entity.getEditable()),
            intToBoolean(entity.getRequired()),
            intToBoolean(entity.getSearchable()),
            intToBoolean(entity.getSortable()),
            entity.getDictType(),
            entity.getLookupConfigId(),
            entity.getDefaultValue(),
            entity.getRulesConfig()
        );
    }

    private static Boolean intToBoolean(Integer value) {
        return value != null && value == 1;
    }
}
