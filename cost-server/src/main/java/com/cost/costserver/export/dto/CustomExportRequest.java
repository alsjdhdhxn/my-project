package com.cost.costserver.export.dto;

import com.cost.costserver.dynamic.dto.QueryParam;
import lombok.Data;
import java.util.List;

/**
 * 自定义导出请求
 */
@Data
public class CustomExportRequest {

    /**
     * 导出模式：all=导出所有，current=导出当前
     */
    private String mode;

    /**
     * 页面筛选条件（导出当前时使用）
     */
    private List<QueryParam.QueryCondition> conditions;

    /**
     * 排序字段（可选，预留给后续保持页面排序）
     */
    private List<SortItem> sorts;

    @Data
    public static class SortItem {
        private String field;
        private String order;
    }
}
