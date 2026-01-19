package com.cost.costserver.dynamic.dto;

import lombok.Data;
import java.util.List;

@Data
public class QueryParam {
    private int page = 1;
    private Integer pageSize; // null 或 <= 0 表示不分页
    private String sortField;
    private String sortOrder;
    private String pageCode; // 页面编码，用于数据权限过滤
    private Boolean lookup; // 是否为 Lookup 弹窗查询（放行，不校验权限）
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
