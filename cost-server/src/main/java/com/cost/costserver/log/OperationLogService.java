package com.cost.costserver.log;

import com.cost.costserver.dynamic.mapper.DynamicMapper;
import com.cost.costserver.log.OperationLogContext.LogSession;
import com.cost.costserver.log.OperationLogContext.SqlDetail;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

/**
 * 操作日志服务
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class OperationLogService {

    private final DynamicMapper dynamicMapper;

    /**
     * 异步保存操作日志（不影响主业务）
     */
    @Async
    public void saveAsync(LogSession session, String status, String errorMsg) {
        try {
            save(session, status, errorMsg);
        } catch (Exception e) {
            log.error("保存操作日志失败: {}", e.getMessage());
        }
    }

    /**
     * 同步保存操作日志
     */
    public void save(LogSession session, String status, String errorMsg) {
        if (session == null) return;

        long totalCost = System.currentTimeMillis() - session.getStartTime();
        int sqlCount = session.getSqlDetails().size();

        // 1. 插入主表
        String insertLog = String.format(
            "INSERT INTO T_COST_OPERATION_LOG (ID, USER_NAME, OPERATION_TYPE, TABLE_CODE, RECORD_ID, RECORD_DESC, TOTAL_SQL_COUNT, TOTAL_COST_MS, STATUS, ERROR_MSG) " +
            "VALUES (SEQ_COST_OPERATION_LOG.NEXTVAL, '%s', '%s', '%s', %s, '%s', %d, %d, '%s', %s)",
            escape(session.getUserName()),
            escape(session.getOperationType()),
            escape(session.getTableCode()),
            session.getRecordId() != null ? session.getRecordId() : "NULL",
            escape(session.getRecordDesc()),
            sqlCount,
            totalCost,
            status,
            errorMsg != null ? "'" + escape(errorMsg) + "'" : "NULL"
        );
        dynamicMapper.insert(insertLog);

        // 2. 获取刚插入的 ID
        Long logId = dynamicMapper.selectCount("SELECT SEQ_COST_OPERATION_LOG.CURRVAL FROM DUAL");

        // 3. 插入明细
        for (SqlDetail detail : session.getSqlDetails()) {
            String insertDetail = String.format(
                "INSERT INTO T_COST_OPERATION_LOG_DETAIL (ID, LOG_ID, SEQ_NO, SQL_TYPE, SQL_TEXT, COST_MS, AFFECTED_ROWS, STATUS, ERROR_MSG) " +
                "VALUES (SEQ_COST_OPERATION_LOG_DETAIL.NEXTVAL, %d, %d, '%s', '%s', %d, %s, '%s', %s)",
                logId,
                detail.getSeqNo(),
                escape(detail.getSqlType()),
                escape(truncate(detail.getSqlText(), 4000)),
                detail.getCostMs(),
                detail.getAffectedRows() != null ? detail.getAffectedRows() : "NULL",
                detail.getStatus(),
                detail.getErrorMsg() != null ? "'" + escape(detail.getErrorMsg()) + "'" : "NULL"
            );
            dynamicMapper.insert(insertDetail);
        }

        log.info("[操作日志] {} {} {} - {}条SQL, 总耗时{}ms", 
            session.getUserName(), session.getOperationType(), session.getTableCode(), sqlCount, totalCost);
    }

    private String escape(String s) {
        return s == null ? "" : s.replace("'", "''");
    }

    private String truncate(String s, int maxLen) {
        if (s == null) return "";
        return s.length() > maxLen ? s.substring(0, maxLen) : s;
    }
}
