package com.cost.costserver.auth.dto;

import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 页面权限（包含按钮、列、数据权限）
 */
public record PagePermission(
    String pageCode,
    Set<String> buttons,                      // 允许的按钮，["*"] 表示全部
    Map<String, ColumnPermission> columns,    // fieldName -> 列权限
    String rowFilter                          // 行权限SQL条件，如 "DEPT_ID = 1" 或 "CREATE_BY = '${username}'"
) {
    /**
     * 是否有某个按钮权限
     */
    public boolean hasButton(String button) {
        return buttons != null && (buttons.contains("*") || buttons.contains(button));
    }
    
    /**
     * 获取列权限，不存在则返回默认（可见可编辑）
     */
    public ColumnPermission getColumnPermission(String fieldName) {
        if (columns == null || !columns.containsKey(fieldName)) {
            return ColumnPermission.defaultPermission();
        }
        return columns.get(fieldName);
    }
}
