package com.cost.costserver.metadata.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("T_COST_COLUMN_METADATA")
public class ColumnMetadata {

    @TableId(type = IdType.INPUT)
    private Long id;

    private Long tableMetadataId;
    private String fieldName;
    private String columnName;
    private String queryColumn;
    private String targetColumn;
    private String headerText;
    private String dataType;
    private Integer displayOrder;
    private Integer width;
    private Integer visible;
    private Integer editable;
    private Integer required;
    private Integer searchable;
    private Integer sortable;
    private String dictType;
    private Long lookupConfigId;
    private String defaultValue;
    private String rulesConfig;
    
    /** 是否虚拟列：0-物理列 1-虚拟列（不存不取，只有公式） */
    private Integer isVirtual;

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
