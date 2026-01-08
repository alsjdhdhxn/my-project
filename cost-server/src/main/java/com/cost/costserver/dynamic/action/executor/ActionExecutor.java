package com.cost.costserver.dynamic.action.executor;

import com.cost.costserver.dynamic.action.ActionContext;
import com.cost.costserver.dynamic.action.ActionResult;
import com.cost.costserver.dynamic.action.ActionRule;

public interface ActionExecutor {
    String getType();

    ActionResult execute(ActionRule rule, ActionContext context);
}
