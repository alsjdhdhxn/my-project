package com.cost.costserver.dynamic.dto;

import lombok.Data;

import java.util.Map;

@Data
public class PageRuleActionRequest {
    private String componentKey;
    private String actionCode;
    private Map<String, Object> data;
}
