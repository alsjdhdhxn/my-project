package com.cost.costserver.dynamic.dto;

import lombok.Data;
import java.util.List;

@Data
public class QueryParam {
    private int page = 1;
    private int pageSize = 20;
    private String sortField;
    private String sortOrder;
    private List<QueryCondition> conditions;

    @Data
    @lombok.AllArgsConstructor
    @lombok.NoArgsConstructor
    public static class QueryCondition {
        private String field;
        private String operator;
        private Object value;
        private Object value2;
    }
}
