package com.cost.costserver.metadata.dto;

import com.cost.costserver.metadata.entity.PageRule;

public record PageRuleDTO(
    Long id,
    String pageCode,
    String componentKey,
    String ruleType,
    String rules,
    Integer sortOrder,
    String description
) {
    public static PageRuleDTO from(PageRule entity) {
        return new PageRuleDTO(
            entity.getId(),
            entity.getPageCode(),
            entity.getComponentKey(),
            entity.getRuleType(),
            entity.getRules(),
            entity.getSortOrder(),
            entity.getDescription()
        );
    }
}
