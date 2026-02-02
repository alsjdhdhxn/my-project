package com.cost.costserver.auth.dto;

import lombok.Data;

/**
 * 页面列信息VO（用于列权限配置）
 */
@Data
public class PageColumnVO {
    private String fieldName;
    private String headerText;
    private Boolean visible;
    private Boolean editable;
}
