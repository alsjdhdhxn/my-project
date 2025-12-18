package com.cost.costserver.auth.dto;

import java.util.List;

public record UserRoute(
    List<MenuRoute> routes,
    String home
) {}
