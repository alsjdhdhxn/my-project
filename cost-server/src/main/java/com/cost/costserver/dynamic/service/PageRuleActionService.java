package com.cost.costserver.dynamic.service;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.dynamic.action.ActionContext;
import com.cost.costserver.dynamic.action.ActionExecutionReport;
import com.cost.costserver.dynamic.action.ActionResult;
import com.cost.costserver.dynamic.action.ActionRule;
import com.cost.costserver.dynamic.action.executor.ActionExecutor;
import com.cost.costserver.dynamic.action.executor.ActionExecutorRegistry;
import com.cost.costserver.metadata.entity.PageRule;
import com.cost.costserver.metadata.mapper.PageRuleMapper;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class PageRuleActionService {

    private final PageRuleMapper pageRuleMapper;
    private final ObjectMapper objectMapper;
    private final ActionExecutorRegistry actionExecutorRegistry;

    @Transactional(rollbackFor = Exception.class)
    public ActionExecutionReport execute(String pageCode, String componentKey, String actionCode, Map<String, Object> data) {
        if (StrUtil.isBlank(pageCode)) {
            throw new BusinessException(400, "pageCode不能为空");
        }
        if (StrUtil.isBlank(actionCode)) {
            throw new BusinessException(400, "actionCode不能为空");
        }

        // 查询 TOOLBAR 和 CONTEXT_MENU 规则
        List<PageRule> rules = pageRuleMapper.selectList(
            new LambdaQueryWrapper<PageRule>()
                .eq(PageRule::getPageCode, pageCode)
                .eq(StrUtil.isNotBlank(componentKey), PageRule::getComponentKey, componentKey)
                .in(PageRule::getRuleType, "TOOLBAR", "CONTEXT_MENU")
                .eq(PageRule::getDeleted, 0)
        );

        if (rules.isEmpty()) {
            throw new BusinessException(404, "未找到页面规则: " + pageCode);
        }

        // 从规则中查找匹配的 action
        ActionRule actionRule = findActionRule(rules, actionCode);
        if (actionRule == null) {
            throw new BusinessException(404, "未找到执行器: " + actionCode);
        }

        // 执行
        ActionExecutionReport report = new ActionExecutionReport();
        Map<String, Object> vars = new HashMap<>();
        ActionContext context = new ActionContext(pageCode, actionCode, data != null ? data : new HashMap<>(), null, vars);

        ActionResult result = executeRule(actionRule, context);
        if (result != null && result.getVars() != null) {
            vars.putAll(result.getVars());
        }
        report.getExecutedActions().add(actionCode);
        report.setVars(vars);

        return report;
    }

    private ActionRule findActionRule(List<PageRule> rules, String actionCode) {
        for (PageRule rule : rules) {
            if (StrUtil.isBlank(rule.getRules())) continue;
            try {
                Map<String, Object> ruleConfig = objectMapper.readValue(rule.getRules(), new TypeReference<>() {});
                List<Map<String, Object>> items = extractItems(ruleConfig);
                ActionRule found = findInItems(items, actionCode);
                if (found != null) return found;
            } catch (Exception e) {
                log.warn("解析规则失败: {}", e.getMessage());
            }
        }
        return null;
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> extractItems(Map<String, Object> config) {
        Object items = config.get("items");
        if (items instanceof List) {
            return (List<Map<String, Object>>) items;
        }
        return Collections.emptyList();
    }

    private ActionRule findInItems(List<Map<String, Object>> items, String actionCode) {
        for (Map<String, Object> item : items) {
            String action = (String) item.get("action");
            if (actionCode.equals(action)) {
                return toActionRule(item, actionCode);
            }
            // 递归查找子菜单
            @SuppressWarnings("unchecked")
            List<Map<String, Object>> subItems = (List<Map<String, Object>>) item.get("items");
            if (subItems != null) {
                ActionRule found = findInItems(subItems, actionCode);
                if (found != null) return found;
            }
        }
        return null;
    }

    private ActionRule toActionRule(Map<String, Object> item, String actionCode) {
        ActionRule rule = new ActionRule();
        rule.setCode(actionCode);
        rule.setName((String) item.get("label"));
        rule.setEnabled(true);

        // 确定类型和内容
        String sql = (String) item.get("sql");
        String handler = (String) item.get("handler");
        String procedure = (String) item.get("procedure");

        if (StrUtil.isNotBlank(sql)) {
            rule.setType("sql");
            rule.setSql(sql);
        } else if (StrUtil.isNotBlank(handler)) {
            rule.setType("java");
            rule.setHandler(handler);
        } else if (StrUtil.isNotBlank(procedure)) {
            rule.setType("proc");
            rule.setProcedure(procedure);
        } else {
            // 没有配置执行内容，可能是前端 JS 处理的
            return null;
        }

        return rule;
    }

    private ActionResult executeRule(ActionRule rule, ActionContext context) {
        ActionExecutor executor = actionExecutorRegistry.getExecutor(rule.getType());
        return executor.execute(rule, context);
    }
}
