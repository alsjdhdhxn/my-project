package com.cost.costserver.export.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

/**
 * 自定义导出配置从表实体
 */
@Data
@TableName("T_COST_EXPORT_CONFIG_DETAIL")
public class ExportConfigDetail {

    @TableId(type = IdType.INPUT)
    private Long id;

    private Long exportConfigId;
    private String tabKey;
    private String sheetName;

    private String detailSql;
    private String masterTableAlias;
    private String detailTableAlias;
    @TableField("DETAIL_LINK_COLUMN")
    private String detailLinkColumn;

    @TableField("COLUMNS")
    private String columns;

    private Integer displayOrder;
}
