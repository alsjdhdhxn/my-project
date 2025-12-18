package com.cost.costserver.auth.dto;

public record LoginToken(
    String token,
    String refreshToken
) {}
