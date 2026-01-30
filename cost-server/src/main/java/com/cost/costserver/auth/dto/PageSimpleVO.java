package com.cost.costserver.auth.dto;

import lombok.Data;
import java.util.List;

@Data
public class PageSimpleVO {
    private Long id;
    private String pageCode;
    private String pageName;
    private String resourceType;  // DIRECTORY, PAGE
    private Long parentId;
    private List<PageSimpleVO> children;
}
