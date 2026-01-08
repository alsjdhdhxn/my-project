package com.cost.costserver.dynamic.validation;

import lombok.Data;

@Data
public class RuleResult {
    private String code;
    private String name;
    private boolean passed;
    private String message;
    private Long result;
}
