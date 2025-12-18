package com.cost.costserver.auth.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("T_COST_RESOURCE")
public class Resource {

    @TableId(type = IdType.INPUT)
    private Long id;

    private String resourceCode;
    private String resourceName;
    private String resourceType;  // DIRECTORY, PAGE
    private String pageCode;
    private String icon;
    private String route;
    private Long parentId;
    private Integer sortOrder;

    @TableLogic
    private Integer deleted;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createTime;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updateTime;

    private String createBy;
    private String updateBy;
}
