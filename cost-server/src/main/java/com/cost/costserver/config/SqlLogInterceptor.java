package com.cost.costserver.config;

import com.cost.costserver.log.OperationLogContext;
import lombok.extern.slf4j.Slf4j;
import org.apache.ibatis.executor.statement.StatementHandler;
import org.apache.ibatis.mapping.BoundSql;
import org.apache.ibatis.plugin.*;
import org.apache.ibatis.session.ResultHandler;

import java.sql.Statement;
import java.util.Properties;

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
        
        long start = System.currentTimeMillis();
        
        try {
            Object result = invocation.proceed();
            long cost = System.currentTimeMillis() - start;
            
            // 计算影响行数
            Integer affectedRows = null;
            if (result instanceof Integer) {
                affectedRows = (Integer) result;
            }
            
            // 记录到上下文（如果有活跃会话）
            if (OperationLogContext.isActive() && !isLogTableSql(sql)) {
                OperationLogContext.addSql(sqlType, sql, cost, affectedRows);
            }
            
            // 控制台输出
            log.debug("[SQL] {}ms | {} | {}", cost, sqlType, truncate(sql, 200));
            
            return result;
        } catch (Exception e) {
            long cost = System.currentTimeMillis() - start;
            
            if (OperationLogContext.isActive() && !isLogTableSql(sql)) {
                OperationLogContext.addFailedSql(sqlType, sql, cost, e.getMessage());
            }
            
            log.error("[SQL] {}ms | FAILED | {}", cost, truncate(sql, 200));
            throw e;
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
