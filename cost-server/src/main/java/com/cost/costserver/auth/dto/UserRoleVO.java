package com.cost.costserver.auth.dto;

import lombok.Data;

@Data
public class UserRoleVO {
    private Long id;
    private Long userId;
    private String username;
    private String realName;
    private Long roleId;
}
