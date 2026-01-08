package com.cost.costserver.dynamic.dto;

import lombok.Data;

import java.util.Map;

@Data
public class ValidationRequest {
    private String group;
    private Map<String, Object> data;
}
