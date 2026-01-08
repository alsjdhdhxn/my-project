package com.cost.costserver.dynamic.action;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.Data;

import java.util.List;

@Data
@JsonIgnoreProperties(ignoreUnknown = true)
public class ActionRule {
    private Integer order;
    private String code;
    private String name;
    private String group;
    private Boolean enabled;
    private String type; // sql/java/proc
    private String sql;
    private String handler;
    private String method; // beanName.methodName
    private String procedure;
    private List<ActionParam> params;
    private String description;
}
