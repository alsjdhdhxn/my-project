package com.cost.costserver.dynamic.action.executor;

import com.cost.costserver.dynamic.action.ActionContext;
import com.cost.costserver.dynamic.action.ActionResult;
import com.cost.costserver.dynamic.action.ActionRule;
import com.cost.costserver.dynamic.mapper.DynamicMapper;
import org.junit.jupiter.api.Test;

import java.util.HashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

class SqlActionExecutorTest {

    @Test
    void executes_sql_with_template_values() {
        DynamicMapper dynamicMapper = mock(DynamicMapper.class);
        SqlActionExecutor executor = new SqlActionExecutor(dynamicMapper);

        ActionRule rule = new ActionRule();
        rule.setCode("update");
        rule.setSql("UPDATE T_TEST SET NAME = :name WHERE ID = :id");

        Map<String, Object> data = new HashMap<>();
        data.put("name", "Alice");
        data.put("id", 10);
        ActionContext context = new ActionContext("T_TEST", "update", data, null, new HashMap<>());

        ActionResult result = executor.execute(rule, context);

        verify(dynamicMapper).update("UPDATE T_TEST SET NAME = 'Alice' WHERE ID = 10");
        assertThat(result).isNotNull();
    }
}
