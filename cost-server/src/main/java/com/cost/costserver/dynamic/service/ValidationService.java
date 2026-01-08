package com.cost.costserver.dynamic.service;

import cn.hutool.core.util.StrUtil;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.dynamic.mapper.DynamicMapper;
import com.cost.costserver.dynamic.util.SqlTemplateUtils;
import com.cost.costserver.dynamic.validation.RuleResult;
import com.cost.costserver.dynamic.validation.ValidationReport;
import com.cost.costserver.metadata.dto.TableMetadataDTO;
import com.cost.costserver.metadata.service.MetadataService;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.*;

/**
 * 后端验证服务
 * 流程：按 order 顺序执行验证器
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ValidationService {

    private final DynamicMapper dynamicMapper;
    private final MetadataService metadataService;
    private final ObjectMapper objectMapper;

    @Data
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class ValidationRule {
        private Integer order;
        private String code;
        private String name;
        private String group;
        private String sql;
        private String condition;
        private String message;
    }

    /**
     * 执行后端验证
     * @param tableCode 表编码
     * @param data 待验证数据
     * @return 验证结果
     */
    public ValidationReport validate(String tableCode, Map<String, Object> data) {
        return validate(tableCode, null, data);
    }

    /**
     * 执行后端验证
     * @param tableCode 表编码
     * @param group 验证分组（为空则执行全部）
     * @param data 待验证数据
     * @return 验证结果
     */
    public ValidationReport validate(String tableCode, String group, Map<String, Object> data) {
        TableMetadataDTO metadata = metadataService.getTableMetadata(tableCode);
        String rulesJson = metadata.validationRules();

        if (StrUtil.isBlank(rulesJson)) {
            return ValidationReport.success();
        }

        List<ValidationRule> rules;
        try {
            rules = objectMapper.readValue(rulesJson, new TypeReference<>() {});
        } catch (Exception e) {
            log.error("解析验证规则失败: {}", e.getMessage());
            return ValidationReport.success();
        }

        if (rules == null || rules.isEmpty()) {
            return ValidationReport.success();
        }

        rules = rules.stream()
            .filter(rule -> matchesGroup(rule.getGroup(), group))
            .toList();

        // 按 order 排序
        rules.sort(Comparator.comparingInt(r -> r.getOrder() == null ? 0 : r.getOrder()));

        ValidationReport report = ValidationReport.success();
        if (data == null) {
            data = new HashMap<>();
        }

        for (ValidationRule rule : rules) {
            // 1. 执行验证 SQL
            RuleResult ruleResult = executeValidation(rule, data);
            report.getResults().add(ruleResult);
            if (!ruleResult.isPassed()) {
                report.setPassed(false);
                report.setMessage(ruleResult.getMessage());
                return report;
            }
        }

        return report;
    }

    /**
     * 执行验证 SQL
     */
    private RuleResult executeValidation(ValidationRule rule, Map<String, Object> data) {
        RuleResult ruleResult = new RuleResult();
        ruleResult.setCode(rule.getCode());
        ruleResult.setName(rule.getName());

        if (StrUtil.isBlank(rule.getSql()) || StrUtil.isBlank(rule.getCondition())) {
            ruleResult.setPassed(true);
            return ruleResult;
        }

        try {
            String sql = SqlTemplateUtils.buildSql(rule.getSql(), data);
            log.debug("执行验证SQL: {}", sql);

            Long result = dynamicMapper.selectCount(sql);
            log.debug("验证结果: {}, 条件: {}", result, rule.getCondition());

            boolean passed = evaluateCondition(result, rule.getCondition());
            ruleResult.setResult(result);
            ruleResult.setPassed(passed);
            if (!passed) {
                ruleResult.setMessage(rule.getMessage());
            }
            return ruleResult;
        } catch (Exception e) {
            log.error("执行验证SQL失败: {}", e.getMessage());
            throw new BusinessException(500, "验证执行失败: " + e.getMessage());
        }
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
