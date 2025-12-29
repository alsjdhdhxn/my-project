package com.cost.costserver.metadata.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("T_COST_TABLE_METADATA")
public class TableMetadata {

    @TableId(type = IdType.INPUT)
    private Long id;

    private String tableCode;
    private String tableName;
    private String queryView;
    private String targetTable;
    private String sequenceName;
    private String pkColumn;

    /** 父表编码（从表才有） */
    private String parentTableCode;

    /** 关联父表的外键列名 */
    private String parentFkColumn;

    /** 后端验证规则 JSON */
    private String validationRules;

    @TableLogic
    private Integer deleted;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createTime;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updateTime;

    @TableField(fill = FieldFill.INSERT)
    private String createBy;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private String updateBy;
}
