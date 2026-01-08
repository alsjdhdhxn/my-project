package com.cost.costserver.dynamic.action.executor;

import cn.hutool.core.util.StrUtil;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.dynamic.action.ActionContext;
import com.cost.costserver.dynamic.action.ActionHandler;
import com.cost.costserver.dynamic.action.ActionResult;
import com.cost.costserver.dynamic.action.ActionRule;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationContext;
import org.springframework.stereotype.Component;

import java.lang.reflect.Method;
import java.util.Arrays;
import java.util.Map;

@Component
@RequiredArgsConstructor
public class JavaActionExecutor implements ActionExecutor {

    private final Map<String, ActionHandler> actionHandlers;
    private final ApplicationContext applicationContext;

    @Override
    public String getType() {
        return "java";
    }

    @Override
    public ActionResult execute(ActionRule rule, ActionContext context) {
        if (StrUtil.isBlank(rule.getHandler())) {
            if (StrUtil.isBlank(rule.getMethod())) {
                throw new BusinessException(400, "执行器handler或method不能为空: " + rule.getCode());
            }
            return invokeMethod(rule.getMethod(), context);
        }
        ActionHandler handler = actionHandlers.get(rule.getHandler());
        if (handler == null) {
            throw new BusinessException(400, "未找到执行器handler: " + rule.getHandler());
        }
        return handler.execute(context);
    }

    private ActionResult invokeMethod(String methodRef, ActionContext context) {
        int dotIndex = methodRef.indexOf('.');
        if (dotIndex <= 0 || dotIndex == methodRef.length() - 1) {
            throw new BusinessException(400, "method格式错误，应为 beanName.methodName: " + methodRef);
        }
        String beanName = methodRef.substring(0, dotIndex);
        String methodName = methodRef.substring(dotIndex + 1);
        Object bean;
        try {
            bean = applicationContext.getBean(beanName);
        } catch (Exception e) {
            throw new BusinessException(400, "未找到Bean: " + beanName);
        }
        Method method = Arrays.stream(bean.getClass().getMethods())
            .filter(m -> m.getName().equals(methodName))
            .filter(m -> m.getParameterCount() == 1 && m.getParameterTypes()[0].isAssignableFrom(ActionContext.class))
            .findFirst()
            .orElseThrow(() -> new BusinessException(400, "未找到方法: " + methodRef));
        try {
            Object result = method.invoke(bean, context);
            if (result == null) {
                return ActionResult.empty();
            }
            if (result instanceof ActionResult actionResult) {
                return actionResult;
            }
            throw new BusinessException(400, "方法返回值类型必须是 ActionResult: " + methodRef);
        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            throw new BusinessException(500, "执行执行器方法失败: " + e.getMessage());
        }
    }
}
