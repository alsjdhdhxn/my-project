package com.cost.costserver.auth.dto;

import lombok.Data;

@Data
public class RoleVO {
    private Long id;
    private String roleCode;
    private String roleName;
    private String description;
}
