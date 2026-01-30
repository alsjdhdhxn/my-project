package com.cost.costserver.auth.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;

@Data
@TableName("T_COST_ROLE")
public class Role {

    @TableId(type = IdType.INPUT)
    private Long id;

    private String roleCode;
    private String roleName;
    private String description;
}
