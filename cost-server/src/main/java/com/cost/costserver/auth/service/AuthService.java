package com.cost.costserver.auth.service;

import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.cost.costserver.auth.dto.LoginToken;
import com.cost.costserver.auth.dto.UserInfo;
import com.cost.costserver.auth.entity.Role;
import com.cost.costserver.auth.entity.User;
import com.cost.costserver.auth.mapper.RoleMapper;
import com.cost.costserver.auth.mapper.UserMapper;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.common.JwtUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserMapper userMapper;
    private final RoleMapper roleMapper;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;

    /**
     * 登录
     */
    public LoginToken login(String username, String password) {
        User user = userMapper.selectOne(
            new LambdaQueryWrapper<User>()
                .eq(User::getUsername, username)
        );

        if (user == null) {
            throw new BusinessException(400, "用户名或密码错误");
        }

        if (!passwordEncoder.matches(password, user.getPassword())) {
            throw new BusinessException(400, "用户名或密码错误");
        }

        if (!"ACTIVE".equals(user.getStatus())) {
            throw new BusinessException(400, "用户已被禁用");
        }

        String accessToken = jwtUtil.generateAccessToken(user.getId(), user.getUsername());
        String refreshToken = jwtUtil.generateRefreshToken(user.getId(), user.getUsername());

        return new LoginToken(accessToken, refreshToken);
    }

    /**
     * 获取用户信息
     */
    public UserInfo getUserInfo(String token) {
        if (!jwtUtil.validateToken(token)) {
            throw new BusinessException(401, "Token无效");
        }

        Long userId = jwtUtil.getUserId(token);
        String username = jwtUtil.getUsername(token);

        // 查询用户角色
        List<Role> roles = roleMapper.selectByUserId(userId);
        List<String> roleCodes = roles.stream().map(Role::getRoleCode).toList();

        return new UserInfo(userId.toString(), username, roleCodes);
    }

    /**
     * 刷新 Token
     */
    public LoginToken refreshToken(String refreshToken) {
        if (!jwtUtil.validateToken(refreshToken)) {
            throw new BusinessException(401, "RefreshToken无效");
        }

        if (!jwtUtil.isRefreshToken(refreshToken)) {
            throw new BusinessException(401, "不是有效的RefreshToken");
        }

        Long userId = jwtUtil.getUserId(refreshToken);
        String username = jwtUtil.getUsername(refreshToken);

        String newAccessToken = jwtUtil.generateAccessToken(userId, username);
        String newRefreshToken = jwtUtil.generateRefreshToken(userId, username);

        return new LoginToken(newAccessToken, newRefreshToken);
    }

    /**
     * 修改当前登录用户密码
     */
    public void changePassword(String token, String newPassword) {
        if (!jwtUtil.validateToken(token)) {
            throw new BusinessException(401, "Token无效");
        }

        Long userId = jwtUtil.getUserId(token);
        String username = jwtUtil.getUsername(token);

        User user = userMapper.selectById(userId);
        if (user == null) {
            throw new BusinessException(404, "用户不存在");
        }

        int updated = userMapper.update(
                null,
                new LambdaUpdateWrapper<User>()
                    .set(User::getPassword, passwordEncoder.encode(newPassword))
                    .set(User::getUpdateBy, username)
                    .set(User::getUpdateTime, LocalDateTime.now())
                    .eq(User::getId, userId)
                    .eq(User::getDeleted, 0)
            );

        if (updated == 0) {
            throw new BusinessException(400, "密码修改失败");
        }
    }
}
