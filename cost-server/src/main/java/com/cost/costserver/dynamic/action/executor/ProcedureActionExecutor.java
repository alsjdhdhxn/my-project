package com.cost.costserver.dynamic.action.executor;

import cn.hutool.core.util.StrUtil;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.dynamic.action.ActionContext;
import com.cost.costserver.dynamic.action.ActionParam;
import com.cost.costserver.dynamic.action.ActionResult;
import com.cost.costserver.dynamic.action.ActionRule;
import lombok.RequiredArgsConstructor;
import org.apache.ibatis.type.JdbcType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.Types;
import java.util.Collections;
import java.util.List;
import java.util.Locale;

@Component
@RequiredArgsConstructor
public class ProcedureActionExecutor implements ActionExecutor {

    private final JdbcTemplate jdbcTemplate;

    @Override
    public String getType() {
        return "proc";
    }

    @Override
    public ActionResult execute(ActionRule rule, ActionContext context) {
        if (StrUtil.isBlank(rule.getProcedure())) {
            throw new BusinessException(400, "执行器procedure不能为空: " + rule.getCode());
        }
        List<ActionParam> params = rule.getParams() == null ? Collections.emptyList() : rule.getParams();
        String callSql = buildProcedureCall(rule.getProcedure(), params.size());

        return jdbcTemplate.execute((Connection connection) -> {
            CallableStatement statement = connection.prepareCall(callSql);
            int index = 1;
            for (ActionParam param : params) {
                String mode = normalizeMode(param.getMode());
                int jdbcType = resolveJdbcType(param.getJdbcType());
                if ("IN".equals(mode) || "INOUT".equals(mode)) {
                    Object value = resolveSource(param.getSource(), context);
                    statement.setObject(index, value, jdbcType);
                }
                if ("OUT".equals(mode) || "INOUT".equals(mode)) {
                    statement.registerOutParameter(index, jdbcType);
                }
                index++;
            }
            return statement;
        }, (CallableStatement statement) -> {
            statement.execute();
            ActionResult result = ActionResult.empty();
            int index = 1;
            for (ActionParam param : params) {
                String mode = normalizeMode(param.getMode());
                if ("OUT".equals(mode) || "INOUT".equals(mode)) {
                    Object value = statement.getObject(index);
                    applyTarget(param.getTarget(), value, context);
                    if (StrUtil.isNotBlank(param.getTarget())) {
                        result.getVars().put(param.getTarget(), value);
                    }
                }
                index++;
            }
            return result;
        });
    }

    private String buildProcedureCall(String procedure, int paramCount) {
        if (paramCount <= 0) {
            return "{call " + procedure + "}";
        }
        String placeholders = String.join(",", Collections.nCopies(paramCount, "?"));
        return "{call " + procedure + "(" + placeholders + ")}";
    }

    private Object resolveSource(String source, ActionContext context) {
        if (StrUtil.isBlank(source)) {
            return null;
        }
        if (source.startsWith("data.")) {
            return context.getData().get(source.substring("data.".length()));
        }
        if (source.startsWith("vars.")) {
            return context.getVars().get(source.substring("vars.".length()));
        }
        return context.getData().get(source);
    }

    private void applyTarget(String target, Object value, ActionContext context) {
        if (StrUtil.isBlank(target)) {
            return;
        }
        if (target.startsWith("data.")) {
            context.getData().put(target.substring("data.".length()), value);
            return;
        }
        if (target.startsWith("vars.")) {
            context.getVars().put(target.substring("vars.".length()), value);
            return;
        }
        context.getVars().put(target, value);
    }

    private String normalizeMode(String mode) {
        if (StrUtil.isBlank(mode)) {
            return "IN";
        }
        return mode.trim().toUpperCase(Locale.ROOT);
    }

    private int resolveJdbcType(String jdbcType) {
        if (StrUtil.isBlank(jdbcType)) {
            return Types.VARCHAR;
        }
        try {
            return JdbcType.valueOf(jdbcType.trim().toUpperCase(Locale.ROOT)).TYPE_CODE;
        } catch (IllegalArgumentException e) {
            throw new BusinessException(400, "不支持的jdbcType: " + jdbcType);
        }
    }
}
