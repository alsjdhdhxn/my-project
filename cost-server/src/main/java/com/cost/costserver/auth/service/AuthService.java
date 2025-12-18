package com.cost.costserver.auth.service;

import cn.hutool.json.JSONArray;
import cn.hutool.json.JSONUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.cost.costserver.auth.dto.LoginToken;
import com.cost.costserver.auth.dto.UserInfo;
import com.cost.costserver.auth.entity.Role;
import com.cost.costserver.auth.entity.RolePage;
import com.cost.costserver.auth.entity.User;
import com.cost.costserver.auth.mapper.RoleMapper;
import com.cost.costserver.auth.mapper.RolePageMapper;
import com.cost.costserver.auth.mapper.UserMapper;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.common.JwtUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserMapper userMapper;
    private final RoleMapper roleMapper;
    private final RolePageMapper rolePageMapper;
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

        // 查询用户按钮权限
        List<RolePage> rolePages = rolePageMapper.selectByUserId(userId);
        Set<String> buttons = new HashSet<>();
        for (RolePage rp : rolePages) {
            if (rp.getButtonPolicy() != null) {
                JSONArray arr = JSONUtil.parseArray(rp.getButtonPolicy());
                for (Object item : arr) {
                    buttons.add(item.toString());
                }
            }
        }

        return new UserInfo(userId.toString(), username, roleCodes, buttons);
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
}
