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
            table.getParentFkColumn(), // 保持原样，是数据库列名
            table.getValidationRules(),
            columnDTOs
        );
    }
}
