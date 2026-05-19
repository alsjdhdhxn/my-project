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
    Boolean isVirtual,
    Integer migrated
) {
    public static ColumnMetadataDTO from(ColumnMetadata entity) {
        // 如果已迁移(MIGRATED=1)，从实体新字段读取；否则用默认值（兼容旧数据）
        boolean isMigrated = entity.getMigrated() != null && entity.getMigrated() == 1;

        // 合并 cellEditor 到 rulesConfig（前端从 rulesConfig.cellEditor 读取编辑器配置）
        String rulesConfig = isMigrated ? mergeEditorIntoRulesConfig(entity.getRulesConfig(), entity.getCellEditor()) : null;

        return new ColumnMetadataDTO(
            entity.getId(),
            entity.getColumnName(),
            entity.getQueryColumn(),
            entity.getTargetColumn(),
            entity.getHeaderText(),
            entity.getDataType(),
            entity.getDisplayOrder(),
            isMigrated ? entity.getWidth() : null,
            isMigrated ? intToBoolean(entity.getVisible(), true) : true,
            isMigrated ? intToBoolean(entity.getEditable(), true) : true,
            isMigrated ? intToBoolean(entity.getRequired(), false) : false,
            isMigrated ? intToBoolean(entity.getSearchable(), false) : intToBoolean(entity.getFilterable()),
            intToBoolean(entity.getSortable()),
            isMigrated ? entity.getPinned() : null,
            entity.getDictType(),
            null,
            isMigrated ? entity.getDefaultValue() : null,
            rulesConfig,
            intToBoolean(entity.getIsVirtual()),
            entity.getMigrated()
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
            this.defaultValue, this.rulesConfig, this.isVirtual, this.migrated
        );
    }
}
