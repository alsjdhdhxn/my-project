package com.cost.costserver.auth.dto;

import lombok.Data;
import java.time.LocalDateTime;

@Data
public class RolePageVO {
    private Long id;
    private Long roleId;
    private String pageCode;
    private String pageName;
    private String buttonPolicy;
    private String columnPolicy;
    private LocalDateTime createTime;
    private LocalDateTime updateTime;
    private String createBy;
    private String updateBy;
}
