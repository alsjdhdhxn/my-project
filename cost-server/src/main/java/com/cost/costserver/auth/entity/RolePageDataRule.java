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
    private String ruleType;      // 规则类型
    private String ruleConfig;    // 规则配置 JSON
    private Integer priority;     // 优先级

    @TableLogic
    private Integer deleted;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createTime;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updateTime;

    private String createBy;
    private String updateBy;
}
