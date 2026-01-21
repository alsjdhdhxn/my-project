package com.cost.costserver.export.dto;

import lombok.Data;
import java.util.List;

/**
 * 导出配置 DTO（包含主表配置和从表配置）
 */
@Data
public class CustomExportConfigDTO {

    private Long id;
    private String exportCode;
    private String exportName;
    private String pageCode;
    private String masterSheetName;
    private Integer displayOrder;

    // 主表 SQL 配置
    private String masterSql;
    private String masterTableAlias;
    private String pkColumn;
    private String pageViewAlias;
    private String pageFkColumn;

    // 主表列配置
    private List<ColumnConfig> columns;

    // 从表配置列表
    private List<DetailConfig> details;

    @Data
    public static class ColumnConfig {
        private String field;
        private String header;
        private Integer order;
        private Boolean visible;
    }

    @Data
    public static class DetailConfig {
        private Long id;
        private String tabKey;
        private String sheetName;
        private String detailSql;
        private String masterTableAlias;
        private String detailTableAlias;
        private List<ColumnConfig> columns;
        private Integer displayOrder;
    }
}
