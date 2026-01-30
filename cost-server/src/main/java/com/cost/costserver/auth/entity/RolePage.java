package com.cost.costserver.auth.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;

@Data
@TableName("T_COST_ROLE_PAGE")
public class RolePage {

    @TableId(type = IdType.INPUT)
    private Long id;

    private Long roleId;
    private String pageCode;
    private String buttonPolicy;
    private String columnPolicy;
    private String rowPolicy;
}
