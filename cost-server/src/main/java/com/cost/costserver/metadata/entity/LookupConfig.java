package com.cost.costserver.metadata.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("T_COST_LOOKUP_CONFIG")
public class LookupConfig {

    @TableId(type = IdType.INPUT)
    private Long id;

    private String lookupCode;
    private String lookupName;
    private String dataSource;
    private String displayColumns;
    private String searchColumns;
    private String valueField;
    private String labelField;

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
