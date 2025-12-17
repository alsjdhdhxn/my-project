package com.cost.costserver.metadata.vo;

import com.cost.costserver.metadata.entity.ColumnMetadata;
import com.cost.costserver.metadata.entity.TableMetadata;
import lombok.Data;
import java.util.List;

@Data
public class TableMetadataVO {
    private Long id;
    private String tableCode;
    private String tableName;
    private String queryView;
    private String targetTable;
    private String sequenceName;
    private String pkColumn;
    private List<ColumnMetadata> columns;

    public static TableMetadataVO from(TableMetadata table, List<ColumnMetadata> columns) {
        TableMetadataVO vo = new TableMetadataVO();
        vo.setId(table.getId());
        vo.setTableCode(table.getTableCode());
        vo.setTableName(table.getTableName());
        vo.setQueryView(table.getQueryView());
        vo.setTargetTable(table.getTargetTable());
        vo.setSequenceName(table.getSequenceName());
        vo.setPkColumn(table.getPkColumn());
        vo.setColumns(columns);
        return vo;
    }
}
