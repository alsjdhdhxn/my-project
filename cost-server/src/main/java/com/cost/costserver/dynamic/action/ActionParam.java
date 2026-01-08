package com.cost.costserver.dynamic.action;

import lombok.Data;

@Data
public class ActionParam {
    private String name;
    private String mode; // IN/OUT/INOUT
    private String jdbcType;
    private String source;
    private String target;
}
