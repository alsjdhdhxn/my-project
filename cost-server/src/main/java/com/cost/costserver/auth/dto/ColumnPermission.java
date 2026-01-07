package com.cost.costserver.auth.dto;

/**
 * 列权限
 */
public record ColumnPermission(
    boolean visible,
    boolean editable
) {
    public static ColumnPermission defaultPermission() {
        return new ColumnPermission(true, true);
    }
    
    public static ColumnPermission readOnly() {
        return new ColumnPermission(true, false);
    }
    
    public static ColumnPermission hidden() {
        return new ColumnPermission(false, false);
    }
}
