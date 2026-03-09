package com.cost.costserver.auth.dto;

import java.util.Map;
import java.util.Set;

/**
 * 页面权限，包含按钮、列、行级过滤。
 */
public record PagePermission(
    String pageCode,
    Set<String> buttons,
    Map<String, ColumnPermission> columns,
    String rowFilter
) {
    public boolean hasButton(String button) {
        return buttons != null && (buttons.contains("*") || buttons.contains(button));
    }

    public ColumnPermission getColumnPermission(Long columnId, String columnName) {
        if (columns == null) {
            return ColumnPermission.defaultPermission();
        }
        ColumnPermission merged = resolveColumnPermission(columnId, columnName);
        return merged != null ? merged : ColumnPermission.defaultPermission();
    }

    public ColumnPermission getColumnPermission(String tableKey, Long columnId, String columnName) {
        if (columns == null) {
            return ColumnPermission.defaultPermission();
        }
        ColumnPermission merged = null;
        if (tableKey != null) {
            if (columnId != null) {
                merged = mergePermission(merged, columns.get(tableKey + ":id:" + columnId));
            }
            if (columnName != null) {
                merged = mergePermission(merged, columns.get(tableKey + ":column:" + columnName));
                merged = mergePermission(merged, columns.get(tableKey + ":" + columnName));
            }
        }
        merged = mergePermission(merged, resolveColumnPermission(columnId, columnName));
        return merged != null ? merged : ColumnPermission.defaultPermission();
    }

    private ColumnPermission resolveColumnPermission(Long columnId, String columnName) {
        ColumnPermission merged = null;
        if (columnId != null) {
            merged = mergePermission(merged, columns.get("id:" + columnId));
        }
        if (columnName != null) {
            merged = mergePermission(merged, columns.get("column:" + columnName));
            merged = mergePermission(merged, columns.get(columnName));
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
