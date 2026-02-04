package com.cost.costserver.auth.dto;

import lombok.Data;

/**
 * 行权限字段 VO（用于可视化配置）
 */
@Data
public class RowFilterFieldVO {
    /** 字段名（数据库列名） */
    private String field;
    /** 显示名称 */
    private String label;
    /** 数据类型：string, number, date */
    private String dataType;
}
