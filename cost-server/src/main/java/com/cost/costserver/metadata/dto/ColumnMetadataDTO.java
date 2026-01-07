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
    String rulesConfig,
    Boolean isVirtual
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
            entity.getRulesConfig(),
            intToBoolean(entity.getIsVirtual())
        );
    }

    private static Boolean intToBoolean(Integer value) {
        return value != null && value == 1;
    }

    /**
     * 合并权限后返回新实例
     */
    public ColumnMetadataDTO withPermission(boolean visible, boolean editable) {
        return new ColumnMetadataDTO(
            this.id, this.fieldName, this.columnName, this.queryColumn, this.targetColumn,
            this.headerText, this.dataType, this.displayOrder, this.width,
            visible, editable,
            this.required, this.searchable, this.sortable, this.dictType, this.lookupConfigId,
            this.defaultValue, this.rulesConfig, this.isVirtual
        );
    }
}
