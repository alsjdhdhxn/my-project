package com.cost.costserver.dynamic.action.executor;

import cn.hutool.core.util.StrUtil;
import com.cost.costserver.common.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Locale;

@Component
@RequiredArgsConstructor
public class ActionExecutorRegistry {

    private final List<ActionExecutor> executors;

    public ActionExecutor getExecutor(String type) {
        if (StrUtil.isBlank(type)) {
            throw new BusinessException(400, "执行器类型不能为空");
        }
        String normalized = type.trim().toLowerCase(Locale.ROOT);
        for (ActionExecutor executor : executors) {
            if (normalized.equals(executor.getType())) {
                return executor;
            }
        }
        throw new BusinessException(400, "未知执行器类型: " + type);
    }
}
