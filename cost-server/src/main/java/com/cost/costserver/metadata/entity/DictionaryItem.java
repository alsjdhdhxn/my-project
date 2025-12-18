package com.cost.costserver.metadata.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("T_COST_DICTIONARY_ITEM")
public class DictionaryItem {

    @TableId(type = IdType.INPUT)
    private Long id;

    private Long typeId;
    private String itemCode;
    private String itemName;
    private String itemValue;
    private Integer sortOrder;
    private String extraConfig;

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
