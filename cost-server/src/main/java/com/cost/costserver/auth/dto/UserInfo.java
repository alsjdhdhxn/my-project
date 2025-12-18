package com.cost.costserver.auth.dto;

import java.util.List;
import java.util.Set;

public record UserInfo(
    String userId,
    String userName,
    List<String> roles,
    Set<String> buttons
) {}
