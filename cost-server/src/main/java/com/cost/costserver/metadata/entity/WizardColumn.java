package com.cost.costserver.metadata.entity;

import lombok.Data;

@Data
public class WizardColumn {

    /** 视图列名 (即 COLUMN_NAME / FIELD_NAME) */
    private String columnName;

    /** 写入目标列名 (真实列有值，虚拟列为空) */
    private String targetColumn;

    /** 列标题 */
    private String headerText;

    /** 数据类型: text | number | date */
    private String dataType;

    /** 显示排序号 */
    private Integer displayOrder;

    /** 0=真实列, 1=虚拟列 */
    private Integer isVirtual;

    /** 是否显示 */
    private Boolean visible;

    /** 是否可编辑 */
    private Boolean editable;

    /** 是否可查询/筛选 */
    private Boolean filterable;

    /** 控件类型: text | number | date | select | checkbox */
    private String widgetType;
}
