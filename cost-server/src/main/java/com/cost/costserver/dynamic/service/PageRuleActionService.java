package com.cost.costserver.dynamic.service;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.dynamic.action.ActionContext;
import com.cost.costserver.dynamic.action.ActionExecutionReport;
import com.cost.costserver.dynamic.action.ActionParam;
import com.cost.costserver.dynamic.action.ActionResult;
import com.cost.costserver.dynamic.action.ActionRule;
import com.cost.costserver.dynamic.action.executor.ActionExecutor;
import com.cost.costserver.dynamic.action.executor.ActionExecutorRegistry;
import com.cost.costserver.metadata.entity.PageComponent;
import com.cost.costserver.metadata.mapper.PageComponentMapper;
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

    private final PageComponentMapper pageComponentMapper;
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

        // 从页面组件表查询按钮配置（按钮现在存在 COMPONENT_CONFIG.buttons 中）
        List<PageComponent> components = pageComponentMapper.selectList(
            new LambdaQueryWrapper<PageComponent>()
                .eq(PageComponent::getPageCode, pageCode)
                .eq(PageComponent::getDeleted, 0)
        );

        if (components.isEmpty()) {
            throw new BusinessException(404, "未找到页面组件: " + pageCode);
        }

        // 从组件配置中查找匹配的 action
        ActionRule actionRule = findActionRule(components, componentKey, actionCode);
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

    private ActionRule findActionRule(List<PageComponent> components, String componentKey, String actionCode) {
        for (PageComponent component : components) {
            // 如果指定了 componentKey，只在该组件中查找
            if (StrUtil.isNotBlank(componentKey) && !componentKey.equals(component.getComponentKey())) {
                continue;
            }
            
            String configJson = component.getComponentConfig();
            if (StrUtil.isBlank(configJson)) continue;
            
            try {
                Map<String, Object> config = objectMapper.readValue(configJson, new TypeReference<>() {});
                
                // TABS 组件：从每个 tab 的 buttons 中查找
                if ("TABS".equals(component.getComponentType())) {
                    @SuppressWarnings("unchecked")
                    List<Map<String, Object>> tabs = (List<Map<String, Object>>) config.get("tabs");
                    if (tabs != null) {
                        for (Map<String, Object> tab : tabs) {
                            @SuppressWarnings("unchecked")
                            List<Map<String, Object>> buttons = (List<Map<String, Object>>) tab.get("buttons");
                            if (buttons != null) {
                                ActionRule found = findInItems(buttons, actionCode);
                                if (found != null) return found;
                            }
                        }
                    }
                } else {
                    // 其他组件：从 buttons 中查找
                    @SuppressWarnings("unchecked")
                    List<Map<String, Object>> buttons = (List<Map<String, Object>>) config.get("buttons");
                    if (buttons != null) {
                        ActionRule found = findInItems(buttons, actionCode);
                        if (found != null) return found;
                    }
                }
            } catch (Exception e) {
                log.warn("解析组件配置失败: {}", e.getMessage());
            }
        }
        return null;
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

    @SuppressWarnings("unchecked")
    private ActionRule toActionRule(Map<String, Object> item, String actionCode) {
        ActionRule rule = new ActionRule();
        rule.setCode(actionCode);
        rule.setName((String) item.get("label"));
        rule.setEnabled(true);

        // 确定类型和内容
        String sql = (String) item.get("sql");
        String handler = (String) item.get("handler");
        String method = (String) item.get("method");
        String procedure = (String) item.get("procedure");

        if (StrUtil.isNotBlank(sql)) {
            rule.setType("sql");
            rule.setSql(sql);
        } else if (StrUtil.isNotBlank(handler)) {
            rule.setType("java");
            rule.setHandler(handler);
        } else if (StrUtil.isNotBlank(method)) {
            rule.setType("java");
            rule.setMethod(method);
        } else if (StrUtil.isNotBlank(procedure)) {
            rule.setType("proc");
            rule.setProcedure(procedure);
            // 解析 params
            Object paramsObj = item.get("params");
            if (paramsObj instanceof List) {
                List<Map<String, Object>> paramsList = (List<Map<String, Object>>) paramsObj;
                List<ActionParam> actionParams = new ArrayList<>();
                for (Map<String, Object> p : paramsList) {
                    ActionParam ap = new ActionParam();
                    ap.setSource((String) p.get("source"));
                    ap.setTarget((String) p.get("target"));
                    ap.setMode((String) p.get("mode"));
                    ap.setJdbcType((String) p.get("jdbcType"));
                    actionParams.add(ap);
                }
                rule.setParams(actionParams);
            }
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
