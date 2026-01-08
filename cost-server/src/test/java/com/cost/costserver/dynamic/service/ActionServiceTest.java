package com.cost.costserver.dynamic.service;

import com.cost.costserver.dynamic.action.ActionContext;
import com.cost.costserver.dynamic.action.ActionExecutionReport;
import com.cost.costserver.dynamic.action.ActionResult;
import com.cost.costserver.dynamic.action.ActionRule;
import com.cost.costserver.dynamic.action.executor.ActionExecutor;
import com.cost.costserver.dynamic.action.executor.ActionExecutorRegistry;
import com.cost.costserver.metadata.dto.TableMetadataDTO;
import com.cost.costserver.metadata.service.MetadataService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class ActionServiceTest {

    @Test
    void executes_rules_by_group() {
        MetadataService metadataService = mock(MetadataService.class);
        ActionExecutorRegistry registry = mock(ActionExecutorRegistry.class);
        ObjectMapper objectMapper = new ObjectMapper();
        ActionService actionService = new ActionService(metadataService, objectMapper, registry);

        String rulesJson = """
            [
              {"order":2,"code":"B","group":"other","type":"sql","enabled":true},
              {"order":1,"code":"A","group":"manual","type":"sql","enabled":true}
            ]
            """;
        TableMetadataDTO metadata = new TableMetadataDTO(
            1L, "T1", "T1", null, null, null, null, null, null, null, rulesJson, List.of()
        );
        when(metadataService.getTableMetadata("T1")).thenReturn(metadata);

        ActionExecutor executor = mock(ActionExecutor.class);
        when(registry.getExecutor("sql")).thenReturn(executor);
        when(executor.execute(any(ActionRule.class), any(ActionContext.class))).thenReturn(ActionResult.empty());

        ActionExecutionReport report = actionService.execute("T1", "manual", null, Map.of("id", 1), null);

        assertThat(report.getExecutedActions()).containsExactly("A");
        verify(executor, times(1)).execute(any(ActionRule.class), any(ActionContext.class));
    }

    @Test
    void action_codes_override_group_filter() {
        MetadataService metadataService = mock(MetadataService.class);
        ActionExecutorRegistry registry = mock(ActionExecutorRegistry.class);
        ObjectMapper objectMapper = new ObjectMapper();
        ActionService actionService = new ActionService(metadataService, objectMapper, registry);

        String rulesJson = """
            [
              {"order":1,"code":"A","group":"manual","type":"sql","enabled":true},
              {"order":2,"code":"B","group":"other","type":"sql","enabled":true}
            ]
            """;
        TableMetadataDTO metadata = new TableMetadataDTO(
            1L, "T1", "T1", null, null, null, null, null, null, null, rulesJson, List.of()
        );
        when(metadataService.getTableMetadata("T1")).thenReturn(metadata);

        ActionExecutor executor = mock(ActionExecutor.class);
        when(registry.getExecutor("sql")).thenReturn(executor);
        when(executor.execute(any(ActionRule.class), any(ActionContext.class))).thenReturn(ActionResult.empty());

        ActionExecutionReport report = actionService.execute("T1", "manual", List.of("B"), Map.of(), null);

        assertThat(report.getExecutedActions()).containsExactly("B");
    }

    @Test
    void merges_result_vars() {
        MetadataService metadataService = mock(MetadataService.class);
        ActionExecutorRegistry registry = mock(ActionExecutorRegistry.class);
        ObjectMapper objectMapper = new ObjectMapper();
        ActionService actionService = new ActionService(metadataService, objectMapper, registry);

        String rulesJson = """
            [
              {"order":1,"code":"A","group":"manual","type":"sql","enabled":true}
            ]
            """;
        TableMetadataDTO metadata = new TableMetadataDTO(
            1L, "T1", "T1", null, null, null, null, null, null, null, rulesJson, List.of()
        );
        when(metadataService.getTableMetadata("T1")).thenReturn(metadata);

        ActionExecutor executor = mock(ActionExecutor.class);
        when(registry.getExecutor("sql")).thenReturn(executor);
        ActionResult actionResult = new ActionResult();
        actionResult.getVars().put("token", "ok");
        when(executor.execute(any(ActionRule.class), any(ActionContext.class))).thenReturn(actionResult);

        ActionExecutionReport report = actionService.execute("T1", "manual", null, Map.of(), null);

        assertThat(report.getVars()).containsEntry("token", "ok");
        ArgumentCaptor<ActionRule> ruleCaptor = ArgumentCaptor.forClass(ActionRule.class);
        verify(executor).execute(ruleCaptor.capture(), any(ActionContext.class));
        assertThat(ruleCaptor.getValue().getCode()).isEqualTo("A");
    }
}
