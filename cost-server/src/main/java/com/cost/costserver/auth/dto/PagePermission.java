package com.cost.costserver.auth.dto;

import java.util.Map;
import java.util.Set;

/**
 * 页面权限（包含按钮、列、数据权限）
 */
public record PagePermission(
    String pageCode,
    Set<String> buttons,                      // 允许的按钮，["*"] 表示全部
    Map<String, ColumnPermission> columns,    // 支持按 columnId / fieldName 两种键存取
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
    public ColumnPermission getColumnPermission(Long columnId, String fieldName) {
        if (columns == null) {
            return ColumnPermission.defaultPermission();
        }
        ColumnPermission merged = resolveColumnPermission(columnId, fieldName);
        return merged != null ? merged : ColumnPermission.defaultPermission();
    }

    /**
     * 获取列权限（优先匹配 tableKey + columnId，其次匹配 tableKey + fieldName，最后匹配全局键）
     */
    public ColumnPermission getColumnPermission(String tableKey, Long columnId, String fieldName) {
        if (columns == null) {
            return ColumnPermission.defaultPermission();
        }
        ColumnPermission merged = null;
        if (tableKey != null) {
            if (columnId != null) {
                merged = mergePermission(merged, columns.get(tableKey + ":id:" + columnId));
            }
            if (fieldName != null) {
                merged = mergePermission(merged, columns.get(tableKey + ":field:" + fieldName));
                merged = mergePermission(merged, columns.get(tableKey + ":" + fieldName));
            }
        }
        merged = mergePermission(merged, resolveColumnPermission(columnId, fieldName));
        return merged != null ? merged : ColumnPermission.defaultPermission();
    }

    private ColumnPermission resolveColumnPermission(Long columnId, String fieldName) {
        ColumnPermission merged = null;
        if (columnId != null) {
            merged = mergePermission(merged, columns.get("id:" + columnId));
        }
        if (fieldName != null) {
            merged = mergePermission(merged, columns.get("field:" + fieldName));
            merged = mergePermission(merged, columns.get(fieldName));
        }
        return merged;
    }

    private ColumnPermission mergePermission(ColumnPermission current, ColumnPermission next) {
        if (next == null) {
            return current;
        }
        if (current == null) {
            return next;
        }
        return new ColumnPermission(
            current.visible() || next.visible(),
            current.editable() || next.editable()
        );
    }
}
