package com.cost.costserver.metadata.dto;

import com.cost.costserver.metadata.entity.ColumnMetadata;

/**
 * 列元数据 DTO - 用于 API 返回
 */
public record ColumnMetadataDTO(
    Long id,
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
    String pinned,
    String dictType,
    Long lookupConfigId,
    String defaultValue,
    String rulesConfig,
    Boolean isVirtual
) {
    public static ColumnMetadataDTO from(ColumnMetadata entity) {
        return new ColumnMetadataDTO(
            entity.getId(),
            entity.getColumnName(),
            entity.getQueryColumn(),
            entity.getTargetColumn(),
            entity.getHeaderText(),
            entity.getDataType(),
            entity.getDisplayOrder(),
            entity.getWidth(),
            intToBoolean(entity.getVisible(), true),
            intToBoolean(entity.getEditable(), true),
            intToBoolean(entity.getRequired(), false),
            intToBoolean(entity.getSearchable(), false),
            intToBoolean(entity.getSortable()),
            entity.getPinned(),
            entity.getDictType(),
            null,
            entity.getDefaultValue(),
            mergeEditorIntoRulesConfig(entity.getRulesConfig(), entity.getCellEditor()),
            intToBoolean(entity.getIsVirtual())
        );
    }

    /**
     * 将独立的 cellEditor 字段合并到 rulesConfig JSON 中（前端从此读取编辑器配置）
     */
    private static String mergeEditorIntoRulesConfig(String rulesConfig, String cellEditor) {
        if (cellEditor == null || cellEditor.isBlank()) return rulesConfig;
        try {
            com.fasterxml.jackson.databind.ObjectMapper om = new com.fasterxml.jackson.databind.ObjectMapper();
            com.fasterxml.jackson.databind.node.ObjectNode node;
            if (rulesConfig != null && !rulesConfig.isBlank()) {
                node = (com.fasterxml.jackson.databind.node.ObjectNode) om.readTree(rulesConfig);
            } else {
                node = om.createObjectNode();
            }
            // 只在 rulesConfig 中没有 cellEditor 时补入
            if (!node.has("cellEditor")) {
                node.put("cellEditor", cellEditor);
            }
            return om.writeValueAsString(node);
        } catch (Exception e) {
            return rulesConfig;
        }
    }

    private static Boolean intToBoolean(Integer value) {
        return value != null && value == 1;
    }

    private static Boolean intToBoolean(Integer value, boolean defaultValue) {
        if (value == null) return defaultValue;
        return value == 1;
    }

    /**
     * 合并权限后返回新实例
     */
    public ColumnMetadataDTO withPermission(boolean visible, boolean editable) {
        return new ColumnMetadataDTO(
            this.id, this.columnName, this.queryColumn, this.targetColumn,
            this.headerText, this.dataType, this.displayOrder, this.width,
            visible, editable,
            this.required, this.searchable, this.sortable, this.pinned, this.dictType, this.lookupConfigId,
            this.defaultValue, this.rulesConfig, this.isVirtual
        );
    }
}
