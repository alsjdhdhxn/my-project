package com.cost.costserver.metadata.dto;

import com.cost.costserver.metadata.entity.ColumnMetadata;
import com.cost.costserver.metadata.entity.TableMetadata;
import java.util.List;

/**
 * 表元数据 DTO - 用于 API 返回
 */
public record TableMetadataDTO(
    Long id,
    String tableCode,
    String tableName,
    String queryView,
    String targetTable,
    String sequenceName,
    String pkColumn,
    String parentTableCode,
    String parentFkColumn,
    String validationRules,
    String actionRules,
    List<ColumnMetadataDTO> columns
) {
    public static TableMetadataDTO from(TableMetadata table, List<ColumnMetadata> columns) {
        List<ColumnMetadataDTO> columnDTOs = columns.stream()
            .map(ColumnMetadataDTO::from)
            .toList();
        
        return new TableMetadataDTO(
            table.getId(),
            table.getTableCode(),
            table.getTableName(),
            table.getQueryView(),
            table.getTargetTable(),
            table.getSequenceName(),
            table.getPkColumn(),
            table.getParentTableCode(),
            table.getParentFkColumn(),
            table.getValidationRules(),
            table.getActionRules(),
            columnDTOs
        );
    }

    /**
     * 替换列列表后返回新实例
     */
    public TableMetadataDTO withColumns(List<ColumnMetadataDTO> newColumns) {
        return new TableMetadataDTO(
            this.id, this.tableCode, this.tableName, this.queryView, this.targetTable,
            this.sequenceName, this.pkColumn, this.parentTableCode, this.parentFkColumn,
            this.validationRules, this.actionRules, newColumns
        );
    }
}
