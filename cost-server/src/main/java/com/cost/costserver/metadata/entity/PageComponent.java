package com.cost.costserver.metadata.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("T_COST_PAGE_COMPONENT")
public class PageComponent {

    @TableId(type = IdType.INPUT)
    private Long id;

    private String pageCode;
    private String componentKey;
    private String componentType;
    private String parentKey;
    private String componentConfig;
    private String refTableCode;
    private String slotName;
    private Integer sortOrder;
    private String description;

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
