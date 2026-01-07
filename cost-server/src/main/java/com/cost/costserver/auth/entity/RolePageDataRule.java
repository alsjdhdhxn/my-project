package com.cost.costserver.auth.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("T_COST_ROLE_PAGE_DATA_RULE")
public class RolePageDataRule {

    @TableId(type = IdType.INPUT)
    private Long id;

    private Long rolePageId;      // 关联 T_COST_ROLE_PAGE.ID
    private String fieldName;     // 字段名（驼峰）
    private String operator;      // 操作符：eq/ne/in/like/between
    private String value;         // 值，支持占位符如 ${userId}、${deptId}
    private String valueType;     // 值类型：literal/placeholder

    @TableLogic
    private Integer deleted;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createTime;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updateTime;

    private String createBy;
    private String updateBy;
}
