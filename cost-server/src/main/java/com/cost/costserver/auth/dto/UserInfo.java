package com.cost.costserver.auth.dto;

import java.util.List;

public record UserInfo(
    String userId,
    String userName,
    String realName,
    String departmentId,
    String departmentName,
    List<String> roles
) {}
