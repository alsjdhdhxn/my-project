package com.cost.costserver.auth.service;

import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.cost.costserver.auth.entity.User;
import com.cost.costserver.auth.mapper.UserMapper;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.dynamic.action.ActionContext;
import com.cost.costserver.dynamic.action.ActionResult;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.lang.reflect.Array;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class UserService {

    private static final String DEFAULT_PASSWORD = "Abc123..";

    private final UserMapper userMapper;
    private final PasswordEncoder passwordEncoder;

    public ActionResult resetPassword(ActionContext context) {
        Map<String, Object> data = context == null ? null : context.getData();
        List<Long> ids = resolveIds(data);
        if (ids.isEmpty()) {
            throw new BusinessException(400, "user id is required");
        }

        int updated = 0;
        for (Long userId : ids) {
            String encoded = passwordEncoder.encode(DEFAULT_PASSWORD);
            int rows = userMapper.update(
                null,
                new LambdaUpdateWrapper<User>()
                    .set(User::getPassword, encoded)
                    .eq(User::getId, userId)
                    .eq(User::getDeleted, 0)
            );
            updated += rows;
        }

        if (updated == 0) {
            throw new BusinessException(400, "no user updated");
        }

        ActionResult result = ActionResult.empty();
        result.setMessage("password reset");
        result.getVars().put("resetCount", updated);
        return result;
    }

    private List<Long> resolveIds(Map<String, Object> data) {
        List<Long> ids = new ArrayList<>();
        if (data == null) {
            return ids;
        }
        appendIds(ids, data.get("id"));
        appendIds(ids, data.get("ids"));
        return ids.stream().distinct().toList();
    }

    private void appendIds(List<Long> ids, Object value) {
        if (value == null) {
            return;
        }
        if (value instanceof Collection<?> collection) {
            for (Object item : collection) {
                appendIds(ids, item);
            }
            return;
        }
        if (value.getClass().isArray()) {
            int length = Array.getLength(value);
            for (int i = 0; i < length; i++) {
                appendIds(ids, Array.get(value, i));
            }
            return;
        }
        if (value instanceof String text && text.contains(",")) {
            String[] parts = text.split(",");
            for (String part : parts) {
                appendIds(ids, part);
            }
            return;
        }
        Long parsed = parseId(value);
        if (parsed != null) {
            ids.add(parsed);
        }
    }

    private Long parseId(Object value) {
        if (value instanceof Number number) {
            return number.longValue();
        }
        String text = value.toString().trim();
        if (text.isEmpty()) {
            return null;
        }
        try {
            return Long.parseLong(text);
        } catch (NumberFormatException e) {
            throw new BusinessException(400, "invalid user id: " + text);
        }
    }
}
