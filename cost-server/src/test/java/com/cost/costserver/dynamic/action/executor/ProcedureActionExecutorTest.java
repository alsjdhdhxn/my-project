package com.cost.costserver.dynamic.action.executor;

import com.cost.costserver.common.BusinessException;
import com.cost.costserver.dynamic.action.ActionContext;
import com.cost.costserver.dynamic.action.ActionResult;
import com.cost.costserver.dynamic.action.ActionRule;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.CallableStatementCallback;
import org.springframework.jdbc.core.CallableStatementCreator;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.HashMap;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class ProcedureActionExecutorTest {

    @Test
    void throws_when_procedure_missing() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        ProcedureActionExecutor executor = new ProcedureActionExecutor(jdbcTemplate);

        ActionRule rule = new ActionRule();
        ActionContext context = new ActionContext("T1", "proc", new HashMap<>(), null, new HashMap<>());

        assertThatThrownBy(() -> executor.execute(rule, context))
            .isInstanceOf(BusinessException.class);
    }

    @Test
    void returns_result_from_jdbc_template() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        ProcedureActionExecutor executor = new ProcedureActionExecutor(jdbcTemplate);

        ActionRule rule = new ActionRule();
        rule.setProcedure("P_TEST");
        rule.setParams(List.of());
        ActionContext context = new ActionContext("T1", "proc", new HashMap<>(), null, new HashMap<>());

        ActionResult expected = new ActionResult();
        expected.setMessage("ok");
        when(jdbcTemplate.execute(any(CallableStatementCreator.class), any(CallableStatementCallback.class)))
            .thenReturn(expected);

        ActionResult result = executor.execute(rule, context);

        assertThat(result.getMessage()).isEqualTo("ok");
    }
}
