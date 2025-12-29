package com.cost.costserver.log;

import lombok.Data;
import java.util.ArrayList;
import java.util.List;

/**
 * 操作日志上下文（线程绑定）
 */
public class OperationLogContext {

    private static final ThreadLocal<LogSession> CONTEXT = new ThreadLocal<>();

    @Data
    public static class LogSession {
        private Long logId;
        private String operationType;
        private String tableCode;
        private Long recordId;
        private String recordDesc;
        private String userName;
        private long startTime;
        private List<SqlDetail> sqlDetails = new ArrayList<>();
    }

    @Data
    public static class SqlDetail {
        private int seqNo;
        private String sqlType;
        private String sqlText;
        private long costMs;
        private Integer affectedRows;
        private String status = "SUCCESS";
        private String errorMsg;
    }

    /**
     * 开始记录
     */
    public static void start(String operationType, String tableCode, String userName) {
        LogSession session = new LogSession();
        session.setOperationType(operationType);
        session.setTableCode(tableCode);
        session.setUserName(userName);
        session.setStartTime(System.currentTimeMillis());
        CONTEXT.set(session);
    }

    /**
     * 设置记录信息
     */
    public static void setRecordInfo(Long recordId, String recordDesc) {
        LogSession session = CONTEXT.get();
        if (session != null) {
            session.setRecordId(recordId);
            session.setRecordDesc(recordDesc);
        }
    }

    /**
     * 添加 SQL 执行记录
     */
    public static void addSql(String sqlType, String sqlText, long costMs, Integer affectedRows) {
        LogSession session = CONTEXT.get();
        if (session != null) {
            SqlDetail detail = new SqlDetail();
            detail.setSeqNo(session.getSqlDetails().size() + 1);
            detail.setSqlType(sqlType);
            detail.setSqlText(sqlText);
            detail.setCostMs(costMs);
            detail.setAffectedRows(affectedRows);
            session.getSqlDetails().add(detail);
        }
    }

    /**
     * 添加失败的 SQL
     */
    public static void addFailedSql(String sqlType, String sqlText, long costMs, String errorMsg) {
        LogSession session = CONTEXT.get();
        if (session != null) {
            SqlDetail detail = new SqlDetail();
            detail.setSeqNo(session.getSqlDetails().size() + 1);
            detail.setSqlType(sqlType);
            detail.setSqlText(sqlText);
            detail.setCostMs(costMs);
            detail.setStatus("FAILED");
            detail.setErrorMsg(errorMsg);
            session.getSqlDetails().add(detail);
        }
    }

    /**
     * 获取当前会话
     */
    public static LogSession get() {
        return CONTEXT.get();
    }

    /**
     * 是否有活跃会话
     */
    public static boolean isActive() {
        return CONTEXT.get() != null;
    }

    /**
     * 结束并清理
     */
    public static LogSession end() {
        LogSession session = CONTEXT.get();
        CONTEXT.remove();
        return session;
    }
}
