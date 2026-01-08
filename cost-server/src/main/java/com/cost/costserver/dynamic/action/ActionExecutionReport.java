package com.cost.costserver.dynamic.action;

import lombok.Data;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Data
public class ActionExecutionReport {
    private List<String> executedActions = new ArrayList<>();
    private Map<String, Object> vars = new HashMap<>();
}
