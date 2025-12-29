package com.cost.costserver.dynamic.service;

import cn.hutool.core.util.StrUtil;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.dynamic.mapper.DynamicMapper;
import com.cost.costserver.metadata.dto.TableMetadataDTO;
import com.cost.costserver.metadata.service.MetadataService;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 后端验证服务
 * 流程：按 order 顺序执行验证器，每个验证器通过后执行其关联的执行器（如果有）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ValidationService {

    private final DynamicMapper dynamicMapper;
    private final MetadataService metadataService;
    private final ObjectMapper objectMapper;

    private static final Pattern PARAM_PATTERN = Pattern.compile(":([a-zA-Z][a-zA-Z0-9]*)");

    @Data
    public static class ValidationRule {
        private Integer order;
        private String name;
        private String sql;
        private String condition;
        private String message;
        private ActionConfig action;
    }

    @Data
    public static class ActionConfig {
        private Boolean enabled;
        private String sql;
        private String description;
    }

    @Data
    public static class ValidationResult {
        private boolean valid;
        private String ruleName;
        private String message;
        private List<String> executedActions = new ArrayList<>();

        public static ValidationResult success() {
            ValidationResult r = new ValidationResult();
            r.setValid(true);
            return r;
        }

        public static ValidationResult fail(String ruleName, String message) {
            ValidationResult r = new ValidationResult();
            r.setValid(false);
            r.setRuleName(ruleName);
            r.setMessage(message);
            return r;
        }
    }

    /**
     * 执行后端验证
     * @param tableCode 表编码
     * @param data 待验证数据
     * @return 验证结果
     */
    public ValidationResult validate(String tableCode, Map<String, Object> data) {
        TableMetadataDTO metadata = metadataService.getTableMetadata(tableCode);
        String rulesJson = metadata.validationRules();

        if (StrUtil.isBlank(rulesJson)) {
            return ValidationResult.success();
        }

        List<ValidationRule> rules;
        try {
            rules = objectMapper.readValue(rulesJson, new TypeReference<>() {});
        } catch (Exception e) {
            log.error("解析验证规则失败: {}", e.getMessage());
            return ValidationResult.success();
        }

        // 按 order 排序
        rules.sort(Comparator.comparingInt(r -> r.getOrder() == null ? 0 : r.getOrder()));

        ValidationResult result = ValidationResult.success();

        for (ValidationRule rule : rules) {
            // 1. 执行验证 SQL
            boolean passed = executeValidation(rule, data);

            if (!passed) {
                return ValidationResult.fail(rule.getName(), rule.getMessage());
            }

            // 2. 验证通过，执行关联的执行器（如果有且启用）
            if (rule.getAction() != null && Boolean.TRUE.equals(rule.getAction().getEnabled())) {
                executeAction(rule.getAction(), data);
                result.getExecutedActions().add(rule.getName() + ":" + rule.getAction().getDescription());
            }
        }

        return result;
    }

    /**
     * 执行验证 SQL
     */
    private boolean executeValidation(ValidationRule rule, Map<String, Object> data) {
        if (StrUtil.isBlank(rule.getSql()) || StrUtil.isBlank(rule.getCondition())) {
            return true;
        }

        try {
            String sql = buildSql(rule.getSql(), data);
            log.debug("执行验证SQL: {}", sql);

            Long result = dynamicMapper.selectCount(sql);
            log.debug("验证结果: {}, 条件: {}", result, rule.getCondition());

            return evaluateCondition(result, rule.getCondition());
        } catch (Exception e) {
            log.error("执行验证SQL失败: {}", e.getMessage());
            throw new BusinessException(500, "验证执行失败: " + e.getMessage());
        }
    }

    /**
     * 执行执行器 SQL
     */
    private void executeAction(ActionConfig action, Map<String, Object> data) {
        if (StrUtil.isBlank(action.getSql())) {
            return;
        }

        try {
            String sql = buildSql(action.getSql(), data);
            log.info("执行执行器SQL: {}", sql);
            dynamicMapper.insert(sql);
        } catch (Exception e) {
            log.error("执行执行器SQL失败: {}", e.getMessage());
            throw new BusinessException(500, "执行器执行失败: " + e.getMessage());
        }
    }

    /**
     * 构建 SQL，替换参数占位符
     * :paramName -> 实际值
     */
    private String buildSql(String sqlTemplate, Map<String, Object> data) {
        Matcher matcher = PARAM_PATTERN.matcher(sqlTemplate);
        StringBuffer sb = new StringBuffer();

        while (matcher.find()) {
            String paramName = matcher.group(1);
            Object value = data.get(paramName);
            String replacement = formatValue(value);
            matcher.appendReplacement(sb, Matcher.quoteReplacement(replacement));
        }
        matcher.appendTail(sb);

        return sb.toString();
    }

    /**
     * 格式化值为 SQL 字面量
     */
    private String formatValue(Object value) {
        if (value == null) {
            return "NULL";
        }
        if (value instanceof Number) {
            return value.toString();
        }
        // 字符串需要转义单引号
        String strValue = value.toString().replace("'", "''");
        return "'" + strValue + "'";
    }

    /**
     * 评估条件表达式
     * 支持: result == 0, result == 1, result > 0, result < 10
     */
    private boolean evaluateCondition(Long result, String condition) {
        if (result == null) result = 0L;

        // 简单解析条件
        condition = condition.trim();

        if (condition.contains("==")) {
            String[] parts = condition.split("==");
            long expected = Long.parseLong(parts[1].trim());
            return result.equals(expected);
        }
        if (condition.contains("!=")) {
            String[] parts = condition.split("!=");
            long expected = Long.parseLong(parts[1].trim());
            return !result.equals(expected);
        }
        if (condition.contains(">=")) {
            String[] parts = condition.split(">=");
            long expected = Long.parseLong(parts[1].trim());
            return result >= expected;
        }
        if (condition.contains("<=")) {
            String[] parts = condition.split("<=");
            long expected = Long.parseLong(parts[1].trim());
            return result <= expected;
        }
        if (condition.contains(">")) {
            String[] parts = condition.split(">");
            long expected = Long.parseLong(parts[1].trim());
            return result > expected;
        }
        if (condition.contains("<")) {
            String[] parts = condition.split("<");
            long expected = Long.parseLong(parts[1].trim());
            return result < expected;
        }

        log.warn("无法解析条件: {}", condition);
        return true;
    }
}
