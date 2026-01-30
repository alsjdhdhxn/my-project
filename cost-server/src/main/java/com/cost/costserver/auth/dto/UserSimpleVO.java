package com.cost.costserver.auth.dto;

import lombok.Data;

@Data
public class UserSimpleVO {
    private Long id;
    private String username;
    private String realName;
}
