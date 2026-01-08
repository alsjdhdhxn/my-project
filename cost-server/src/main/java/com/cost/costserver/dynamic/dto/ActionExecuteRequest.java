package com.cost.costserver.dynamic.dto;

import lombok.Data;

import java.util.List;
import java.util.Map;

@Data
public class ActionExecuteRequest {
    private String group;
    private List<String> actionCodes;
    private Map<String, Object> data;
    private Boolean validate;
    private String validateGroup;
}
