package com.cost.costserver.dynamic.action.executor;

import com.cost.costserver.common.BusinessException;
import com.cost.costserver.dynamic.action.ActionContext;
import com.cost.costserver.dynamic.action.ActionResult;
import com.cost.costserver.dynamic.action.ActionRule;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ActionExecutorRegistryTest {

    @Test
    void returns_executor_by_type() {
        ActionExecutor sqlExecutor = new StubExecutor("sql");
        ActionExecutorRegistry registry = new ActionExecutorRegistry(List.of(sqlExecutor));

        ActionExecutor resolved = registry.getExecutor("SQL");

        assertThat(resolved).isSameAs(sqlExecutor);
    }

    @Test
    void throws_when_type_unknown() {
        ActionExecutorRegistry registry = new ActionExecutorRegistry(List.of(new StubExecutor("sql")));

        assertThatThrownBy(() -> registry.getExecutor("unknown"))
            .isInstanceOf(BusinessException.class);
    }

    private static final class StubExecutor implements ActionExecutor {
        private final String type;

        private StubExecutor(String type) {
            this.type = type;
        }

        @Override
        public String getType() {
            return type;
        }

        @Override
        public ActionResult execute(ActionRule rule, ActionContext context) {
            return ActionResult.empty();
        }
    }
}
