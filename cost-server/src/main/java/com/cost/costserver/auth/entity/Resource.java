package com.cost.costserver.auth.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;

@Data
@TableName("T_COST_RESOURCE")
public class Resource {

    @TableId(type = IdType.INPUT)
    private Long id;

    private String pageCode;
    private String resourceName;
    private String resourceType;  // DIRECTORY, PAGE
    private Integer isHardcoded;  // 1=硬编码页面, 0=元数据驱动
    private String icon;
    private String route;
    private Long parentId;
    private Integer sortOrder;
}
