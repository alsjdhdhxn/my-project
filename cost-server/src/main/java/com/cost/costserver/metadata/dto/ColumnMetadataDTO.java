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
     * 同时将 cellEditorParams 中的 lookup 配置转换为 rulesConfig.lookup 格式
     */
    private static String mergeEditorIntoRulesConfig(String rulesConfig, String cellEditor) {
        try {
            com.fasterxml.jackson.databind.ObjectMapper om = new com.fasterxml.jackson.databind.ObjectMapper();
            com.fasterxml.jackson.databind.node.ObjectNode node;
            if (rulesConfig != null && !rulesConfig.isBlank()) {
                node = (com.fasterxml.jackson.databind.node.ObjectNode) om.readTree(rulesConfig);
            } else {
                node = om.createObjectNode();
            }

            // 合并 cellEditor
            if (cellEditor != null && !cellEditor.isBlank() && !node.has("cellEditor")) {
                node.put("cellEditor", cellEditor);
            }

            // 将 cellEditorParams.lookupCode + mapping 转为 lookup.code + mapping 格式
            // 前端 extractLookupRules 读的是 config.lookup.code / config.lookup.mapping
            if (node.has("cellEditorParams")) {
                var params = node.get("cellEditorParams");
                if (params.isObject() && params.has("lookupCode") && !node.has("lookup")) {
                    var lookupNode = om.createObjectNode();
                    lookupNode.put("code", params.get("lookupCode").asText());
                    if (params.has("mapping")) lookupNode.set("mapping", params.get("mapping"));
                    if (params.has("noFillback")) lookupNode.set("noFillback", params.get("noFillback"));
                    if (params.has("filterField")) lookupNode.set("filterField", params.get("filterField"));
                    if (params.has("filterColumn")) lookupNode.set("filterColumn", params.get("filterColumn"));
                    if (params.has("filterValueFrom")) lookupNode.set("filterValueFrom", params.get("filterValueFrom"));
                    node.set("lookup", lookupNode);
                }
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
