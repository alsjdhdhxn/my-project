package com.cost.costserver.dynamic.action;

import lombok.Data;

import java.util.HashMap;
import java.util.Map;

@Data
public class ActionResult {
    private Map<String, Object> vars = new HashMap<>();
    private String message;

    public static ActionResult empty() {
        return new ActionResult();
    }
}
