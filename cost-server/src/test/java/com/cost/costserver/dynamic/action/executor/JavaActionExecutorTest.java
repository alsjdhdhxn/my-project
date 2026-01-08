package com.cost.costserver.dynamic.action.executor;

import com.cost.costserver.dynamic.action.ActionContext;
import com.cost.costserver.dynamic.action.ActionHandler;
import com.cost.costserver.dynamic.action.ActionResult;
import com.cost.costserver.dynamic.action.ActionRule;
import org.junit.jupiter.api.Test;
import org.springframework.context.ApplicationContext;

import java.util.HashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class JavaActionExecutorTest {

    @Test
    void executes_handler_when_present() {
        ActionHandler handler = mock(ActionHandler.class);
        Map<String, ActionHandler> handlers = Map.of("demoHandler", handler);
        ApplicationContext applicationContext = mock(ApplicationContext.class);
        JavaActionExecutor executor = new JavaActionExecutor(handlers, applicationContext);

        ActionRule rule = new ActionRule();
        rule.setCode("demo");
        rule.setHandler("demoHandler");

        ActionResult expected = new ActionResult();
        expected.getVars().put("status", "ok");
        when(handler.execute(any(ActionContext.class))).thenReturn(expected);

        ActionContext context = new ActionContext("T1", "demo", new HashMap<>(), null, new HashMap<>());
        ActionResult result = executor.execute(rule, context);

        assertThat(result).isSameAs(expected);
        verify(handler).execute(any(ActionContext.class));
        verifyNoInteractions(applicationContext);
    }

    @Test
    void executes_method_when_handler_missing() {
        Map<String, ActionHandler> handlers = Map.of();
        ApplicationContext applicationContext = mock(ApplicationContext.class);
        JavaActionExecutor executor = new JavaActionExecutor(handlers, applicationContext);

        TestBean bean = new TestBean();
        when(applicationContext.getBean("testBean")).thenReturn(bean);

        ActionRule rule = new ActionRule();
        rule.setCode("demo");
        rule.setMethod("testBean.handle");

        ActionContext context = new ActionContext("T1", "demo", new HashMap<>(), null, new HashMap<>());
        ActionResult result = executor.execute(rule, context);

        assertThat(result.getMessage()).isEqualTo("ok");
    }

    private static final class TestBean {
        public ActionResult handle(ActionContext context) {
            ActionResult result = new ActionResult();
            result.setMessage("ok");
            return result;
        }
    }
}
