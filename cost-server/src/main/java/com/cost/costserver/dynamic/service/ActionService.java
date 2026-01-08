package com.cost.costserver.dynamic.service;

import cn.hutool.core.util.StrUtil;
import com.cost.costserver.dynamic.action.ActionContext;
import com.cost.costserver.dynamic.action.ActionExecutionReport;
import com.cost.costserver.dynamic.action.ActionResult;
import com.cost.costserver.dynamic.action.ActionRule;
import com.cost.costserver.dynamic.action.executor.ActionExecutor;
import com.cost.costserver.dynamic.action.executor.ActionExecutorRegistry;
import com.cost.costserver.dynamic.validation.ValidationReport;
import com.cost.costserver.metadata.dto.TableMetadataDTO;
import com.cost.costserver.metadata.service.MetadataService;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class ActionService {

    private final MetadataService metadataService;
    private final ObjectMapper objectMapper;
    private final ActionExecutorRegistry actionExecutorRegistry;

    public ActionExecutionReport execute(
        String tableCode,
        String group,
        List<String> actionCodes,
        Map<String, Object> data,
        ValidationReport validationReport
    ) {
        TableMetadataDTO metadata = metadataService.getTableMetadata(tableCode);
        String actionsJson = metadata.actionRules();
        ActionExecutionReport report = new ActionExecutionReport();

        if (StrUtil.isBlank(actionsJson)) {
            return report;
        }

        List<ActionRule> rules;
        try {
            rules = objectMapper.readValue(actionsJson, new TypeReference<>() {});
        } catch (Exception e) {
            log.error("解析执行器规则失败: {}", e.getMessage());
            return report;
        }

        if (rules == null || rules.isEmpty()) {
            return report;
        }

        if (data == null) {
            data = new HashMap<>();
        }

        Set<String> codeSet = actionCodes == null
            ? Collections.emptySet()
            : actionCodes.stream()
                .filter(StrUtil::isNotBlank)
                .map(String::trim)
                .collect(Collectors.toSet());
        boolean filterByCodes = !codeSet.isEmpty();

        rules = rules.stream()
            .filter(rule -> Boolean.FALSE != rule.getEnabled())
            .filter(rule -> filterByCodes ? matchesCode(rule, codeSet) : matchesGroup(rule.getGroup(), group))
            .sorted(Comparator.comparingInt(r -> r.getOrder() == null ? 0 : r.getOrder()))
            .toList();

        Map<String, Object> vars = new HashMap<>();
        ActionContext context = new ActionContext(tableCode, null, data, validationReport, vars);

        for (ActionRule rule : rules) {
            String actionCode = resolveActionCode(rule);
            context.setActionCode(actionCode);
            ActionResult result = executeRule(rule, context);
            if (result != null && result.getVars() != null && !result.getVars().isEmpty()) {
                vars.putAll(result.getVars());
            }
            report.getExecutedActions().add(actionCode);
        }

        report.setVars(vars);
        return report;
    }

    private ActionResult executeRule(ActionRule rule, ActionContext context) {
        ActionExecutor executor = actionExecutorRegistry.getExecutor(rule.getType());
        return executor.execute(rule, context);
    }

    private boolean matchesGroup(String ruleGroup, String targetGroup) {
        if (StrUtil.isBlank(targetGroup)) {
            return true;
        }
        if (StrUtil.isBlank(ruleGroup)) {
            return true;
        }
        return targetGroup.trim().equals(ruleGroup.trim());
    }

    private boolean matchesCode(ActionRule rule, Set<String> codeSet) {
        if (StrUtil.isNotBlank(rule.getCode()) && codeSet.contains(rule.getCode())) {
            return true;
        }
        return StrUtil.isNotBlank(rule.getName()) && codeSet.contains(rule.getName());
    }

    private String resolveActionCode(ActionRule rule) {
        if (StrUtil.isNotBlank(rule.getCode())) {
            return rule.getCode();
        }
        if (StrUtil.isNotBlank(rule.getName())) {
            return rule.getName();
        }
        return "action";
    }
}
