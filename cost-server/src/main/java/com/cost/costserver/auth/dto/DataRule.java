package com.cost.costserver.auth.dto;

/**
 * 数据权限规则
 */
public record DataRule(
    String fieldName,   // 字段名
    String operator,    // 操作符：eq/ne/in/like/gt/ge/lt/le
    String value,       // 值或占位符（如 ${userId}）
    String valueType    // 值类型：literal/placeholder
) {}
