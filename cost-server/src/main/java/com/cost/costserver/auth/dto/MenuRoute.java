package com.cost.costserver.auth.dto;

import lombok.Data;
import java.util.List;

@Data
public class MenuRoute {
    private String id;
    private String name;
    private String path;
    private String component;
    private MenuMeta meta;
    private List<MenuRoute> children;

    @Data
    public static class MenuMeta {
        private String title;
        private String i18nKey;
        private String icon;
        private Integer order;
        private Boolean hideInMenu;
        private Boolean keepAlive;
        private String pageCode;  // 动态页面使用
    }
}
