package com.cost.costserver.dynamic.util;

import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class SqlTemplateUtils {
    private static final Pattern PARAM_PATTERN = Pattern.compile(":([a-zA-Z][a-zA-Z0-9]*)");

    private SqlTemplateUtils() {
    }

    public static String buildSql(String sqlTemplate, Map<String, Object> data) {
        Matcher matcher = PARAM_PATTERN.matcher(sqlTemplate);
        StringBuffer sb = new StringBuffer();

        while (matcher.find()) {
            String paramName = matcher.group(1);
            Object value = data.get(paramName);
            String replacement = formatValue(value);
            matcher.appendReplacement(sb, Matcher.quoteReplacement(replacement));
        }
        matcher.appendTail(sb);

        return sb.toString();
    }

    private static String formatValue(Object value) {
        if (value == null) {
            return "NULL";
        }
        if (value instanceof Number) {
            return value.toString();
        }
        String strValue = value.toString().replace("'", "''");
        return "'" + strValue + "'";
    }
}
