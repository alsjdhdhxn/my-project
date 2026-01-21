package com.cost.costserver.export.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 自定义导出配置实体
 */
@Data
@TableName("T_COST_EXPORT_CONFIG")
public class ExportConfig {

    @TableId(type = IdType.INPUT)
    private Long id;

    private String exportCode;
    private String exportName;
    private String pageCode;

    private String masterSql;
    private String masterTableAlias;
    private String pkColumn;
    private String pageViewAlias;
    private String pageFkColumn;
    @TableField("MASTER_LINK_COLUMN")
    private String masterLinkColumn;

    @TableField("COLUMNS")
    private String columns;

    private String masterSheetName;
    private Integer displayOrder;
    private Integer deleted;
    private String createBy;
    private LocalDateTime createTime;
    private String updateBy;
    private LocalDateTime updateTime;
}
