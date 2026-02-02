package com.cost.costserver.config;

import com.cost.costserver.log.OperationLogContext;
import lombok.extern.slf4j.Slf4j;
import org.apache.ibatis.executor.statement.StatementHandler;
import org.apache.ibatis.mapping.BoundSql;
import org.apache.ibatis.mapping.ParameterMapping;
import org.apache.ibatis.plugin.*;
import org.apache.ibatis.session.ResultHandler;

import java.sql.Statement;
import java.text.SimpleDateFormat;
import java.util.*;

/**
 * SQL 日志拦截器
 * 1. 控制台输出 SQL 及执行时间
 * 2. 记录到 OperationLogContext（如果有活跃会话）
 */
@Slf4j
@Intercepts({
    @Signature(type = StatementHandler.class, method = "query", args = {Statement.class, ResultHandler.class}),
    @Signature(type = StatementHandler.class, method = "update", args = {Statement.class})
})
public class SqlLogInterceptor implements Interceptor {

    @Override
    public Object intercept(Invocation invocation) throws Throwable {
        StatementHandler handler = (StatementHandler) invocation.getTarget();
        BoundSql boundSql = handler.getBoundSql();
        String sql = boundSql.getSql().replaceAll("\\s+", " ").trim();
        String sqlType = detectSqlType(sql);
        
        // 获取完整SQL（参数替换进去）
        String fullSql = getFullSql(boundSql, handler);
        
        long start = System.currentTimeMillis();
        
        try {
            Object result = invocation.proceed();
            long cost = System.currentTimeMillis() - start;
            
            // 计算影响/返回行数
            Integer rowCount = null;
            if (result instanceof Integer) {
                rowCount = (Integer) result;
            } else if (result instanceof List) {
                rowCount = ((List<?>) result).size();
            }
            
            // 记录到上下文（如果有活跃会话）
            if (OperationLogContext.isActive() && !isLogTableSql(sql)) {
                OperationLogContext.addSql(sqlType, fullSql, cost, rowCount);
            }
            
            // 控制台输出
            if ("SELECT".equals(sqlType)) {
                log.info("[SQL] {}ms | {} rows | {}", cost, rowCount, fullSql);
            } else {
                log.info("[SQL] {}ms | {} affected | {}", cost, rowCount, fullSql);
            }
            
            return result;
        } catch (Exception e) {
            long cost = System.currentTimeMillis() - start;
            
            if (OperationLogContext.isActive() && !isLogTableSql(sql)) {
                OperationLogContext.addFailedSql(sqlType, fullSql, cost, e.getMessage());
            }
            
            log.error("[SQL] {}ms | FAILED | {} | {}", cost, fullSql, e.getMessage());
            throw e;
        }
    }

    /**
     * 获取完整SQL（参数替换进去）
     */
    private String getFullSql(BoundSql boundSql, StatementHandler handler) {
        String sql = boundSql.getSql().replaceAll("\\s+", " ").trim();
        Object parameterObject = boundSql.getParameterObject();
        List<ParameterMapping> parameterMappings = boundSql.getParameterMappings();
        
        if (parameterMappings == null || parameterMappings.isEmpty()) {
            return sql;
        }
        
        if (parameterObject == null) {
            return sql.replace("?", "null");
        }

        // 简单类型
        if (parameterObject instanceof String || 
            parameterObject instanceof Number ||
            parameterObject instanceof Boolean) {
            return sql.replaceFirst("\\?", java.util.regex.Matcher.quoteReplacement(formatValue(parameterObject)));
        }
        
        // 逐个替换?
        for (ParameterMapping mapping : parameterMappings) {
            String propertyName = mapping.getProperty();
            Object value = null;
            
            if (boundSql.hasAdditionalParameter(propertyName)) {
                value = boundSql.getAdditionalParameter(propertyName);
            } else if (parameterObject instanceof Map) {
                value = getValueFromMap((Map<?, ?>) parameterObject, propertyName);
            } else {
                value = getPropertyValue(parameterObject, propertyName);
            }
            
            sql = sql.replaceFirst("\\?", java.util.regex.Matcher.quoteReplacement(formatValue(value)));
        }
        
        return sql;
    }

    private Object getValueFromMap(Map<?, ?> map, String propertyName) {
        // 直接key
        if (map.containsKey(propertyName)) {
            return map.get(propertyName);
        }
        // 处理 ew.paramNameValuePairs.MPGENVAL1 这种格式
        if (propertyName.contains(".")) {
            String[] parts = propertyName.split("\\.");
            Object current = map;
            for (String part : parts) {
                if (current instanceof Map) {
                    current = ((Map<?, ?>) current).get(part);
                } else {
                    current = getPropertyValue(current, part);
                }
                if (current == null) break;
            }
            return current;
        }
        return null;
    }

    private Object getPropertyValue(Object obj, String propertyName) {
        if (obj == null) return null;
        try {
            // 处理嵌套属性
            if (propertyName.contains(".")) {
                String[] parts = propertyName.split("\\.", 2);
                Object nested = getPropertyValue(obj, parts[0]);
                return getPropertyValue(nested, parts[1]);
            }
            
            // 尝试getter方法
            String getterName = "get" + propertyName.substring(0, 1).toUpperCase() + propertyName.substring(1);
            try {
                java.lang.reflect.Method getter = obj.getClass().getMethod(getterName);
                return getter.invoke(obj);
            } catch (NoSuchMethodException e) {
                // 尝试直接访问字段
                java.lang.reflect.Field field = obj.getClass().getDeclaredField(propertyName);
                field.setAccessible(true);
                return field.get(obj);
            }
        } catch (Exception e) {
            return null;
        }
    }

    private String formatValue(Object value) {
        if (value == null) {
            return "null";
        } else if (value instanceof String) {
            return "'" + value + "'";
        } else if (value instanceof Date) {
            return "'" + new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(value) + "'";
        } else {
            return value.toString();
        }
    }

    private String detectSqlType(String sql) {
        String upper = sql.toUpperCase().trim();
        if (upper.startsWith("SELECT")) return "SELECT";
        if (upper.startsWith("INSERT")) return "INSERT";
        if (upper.startsWith("UPDATE")) return "UPDATE";
        if (upper.startsWith("DELETE")) return "DELETE";
        return "OTHER";
    }

    /**
     * 排除操作日志表自身的 SQL，避免死循环
     */
    private boolean isLogTableSql(String sql) {
        String upper = sql.toUpperCase();
        return upper.contains("T_COST_OPERATION_LOG");
    }

    private String truncate(String s, int maxLen) {
        return s.length() > maxLen ? s.substring(0, maxLen) + "..." : s;
    }

    @Override
    public Object plugin(Object target) {
        return Plugin.wrap(target, this);
    }

    @Override
    public void setProperties(Properties properties) {
    }
}
