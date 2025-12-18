package com.cost.costserver.auth.controller;

import com.cost.costserver.auth.dto.LoginRequest;
import com.cost.costserver.auth.dto.LoginToken;
import com.cost.costserver.auth.dto.RefreshTokenRequest;
import com.cost.costserver.auth.dto.UserInfo;
import com.cost.costserver.auth.service.AuthService;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.common.Result;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

@Tag(name = "认证接口")
@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @Operation(summary = "登录")
    @PostMapping("/login")
    public Result<LoginToken> login(@Valid @RequestBody LoginRequest request) {
        return Result.ok(authService.login(request.getUserName(), request.getPassword()));
    }

    @Operation(summary = "获取用户信息")
    @GetMapping("/getUserInfo")
    public Result<UserInfo> getUserInfo(@RequestHeader(value = "Authorization", required = false) String authorization) {
        if (!StringUtils.hasText(authorization) || !authorization.startsWith("Bearer ")) {
            throw new BusinessException(401, "未提供有效的Token");
        }
        String token = authorization.substring(7);
        return Result.ok(authService.getUserInfo(token));
    }

    @Operation(summary = "刷新Token")
    @PostMapping("/refreshToken")
    public Result<LoginToken> refreshToken(@Valid @RequestBody RefreshTokenRequest request) {
        return Result.ok(authService.refreshToken(request.getRefreshToken()));
    }
}
