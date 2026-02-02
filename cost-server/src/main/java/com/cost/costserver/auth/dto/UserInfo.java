package com.cost.costserver.auth.dto;

import java.util.List;

public record UserInfo(
    String userId,
    String userName,
    List<String> roles
) {}
