package com.cost.costserver.dynamic.action.executor;

import cn.hutool.core.util.StrUtil;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.dynamic.action.ActionContext;
import com.cost.costserver.dynamic.action.ActionResult;
import com.cost.costserver.dynamic.action.ActionRule;
import com.cost.costserver.dynamic.mapper.DynamicMapper;
import com.cost.costserver.dynamic.util.SqlTemplateUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class SqlActionExecutor implements ActionExecutor {

    private final DynamicMapper dynamicMapper;

    @Override
    public String getType() {
        return "sql";
    }

    @Override
    public ActionResult execute(ActionRule rule, ActionContext context) {
        if (StrUtil.isBlank(rule.getSql())) {
            throw new BusinessException(400, "执行器SQL不能为空: " + rule.getCode());
        }
        String sql = SqlTemplateUtils.buildSql(rule.getSql(), context.getData());
        log.info("执行执行器SQL: {}", sql);
        dynamicMapper.update(sql);
        return ActionResult.empty();
    }
}
