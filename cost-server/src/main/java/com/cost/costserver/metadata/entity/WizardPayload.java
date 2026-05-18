package com.cost.costserver.metadata.entity;

import lombok.Data;
import java.util.List;

@Data
public class WizardPayload {

    /** 父级资源 ID */
    private Long parentId;

    /** 页面名称 */
    private String resourceName;

    /** 页面编码 (UPPER_SNAKE_CASE) */
    private String resourceCode;

    /** 图标，默认 "folder" */
    private String icon;

    /** 页面模式: "single" | "master-detail" */
    private String mode;

    /** 自动推导的页面编码 (kebab-case) */
    private String pageCode;

    /** 主表配置 */
    private WizardTable masterTable;

    /** 从表列表（主从模式） */
    private List<WizardTable> detailTables;
}
