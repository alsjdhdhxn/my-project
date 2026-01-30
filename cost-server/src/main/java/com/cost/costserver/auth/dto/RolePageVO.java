package com.cost.costserver.auth.dto;

import lombok.Data;

@Data
public class RolePageVO {
    private Long id;
    private Long roleId;
    private String pageCode;
    private String pageName;
    private String buttonPolicy;
    private String columnPolicy;
    private String rowPolicy;
}
