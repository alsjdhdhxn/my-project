package com.cost.costserver.dynamic.action;

import com.cost.costserver.dynamic.validation.ValidationReport;
import lombok.AllArgsConstructor;
import lombok.Data;

import java.util.Map;

@Data
@AllArgsConstructor
public class ActionContext {
    private String tableCode;
    private String actionCode;
    private Map<String, Object> data;
    private ValidationReport validation;
    private Map<String, Object> vars;
}
