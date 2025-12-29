package com.cost.costserver.log;

import cn.hutool.json.JSONUtil;
import com.cost.costserver.dynamic.dto.SaveParam;
import com.cost.costserver.dynamic.mapper.DynamicMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 业务审计日志服务
 * 只记录用户手动修改的字段变更
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AuditLogService {

    private final DynamicMapper dynamicMapper;

    /**
     * 异步记录审计日志
     */
    @Async
    public void logAsync(String userName, String pageCode, String tableCode, String tableName,
                         Long recordId, String operationType, List<SaveParam.FieldChange> changes) {
        try {
            log(userName, pageCode, tableCode, tableName, recordId, operationType, changes);
        } catch (Exception e) {
            log.error("记录审计日志失败: {}", e.getMessage());
        }
    }

    /**
     * 记录审计日志
     */
    public void log(String userName, String pageCode, String tableCode, String tableName,
                    Long recordId, String operationType, List<SaveParam.FieldChange> changes) {
        // 只保留用户手动修改的变更
        List<SaveParam.FieldChange> userChanges = null;
        if (changes != null) {
            userChanges = changes.stream()
                .filter(c -> "user".equals(c.getChangeType()))
                .collect(Collectors.toList());
        }

        // 如果是 UPDATE 且没有用户变更，不记录
        if ("UPDATE".equals(operationType) && (userChanges == null || userChanges.isEmpty())) {
            return;
        }

        String changesJson = userChanges != null && !userChanges.isEmpty() 
            ? JSONUtil.toJsonStr(userChanges) : null;

        String sql = String.format(
            "INSERT INTO T_COST_AUDIT_LOG (ID, USER_NAME, PAGE_CODE, TABLE_CODE, TABLE_NAME, RECORD_ID, OPERATION_TYPE, FIELD_CHANGES) " +
            "VALUES (SEQ_COST_AUDIT_LOG.NEXTVAL, '%s', '%s', '%s', '%s', %s, '%s', %s)",
            escape(userName),
            escape(pageCode),
            escape(tableCode),
            escape(tableName),
            recordId != null ? recordId : "NULL",
            operationType,
            changesJson != null ? "'" + escape(changesJson) + "'" : "NULL"
        );

        dynamicMapper.insert(sql);
        log.debug("[审计日志] {} {} {} #{}", userName, operationType, tableCode, recordId);
    }

    /**
     * 记录新增操作（记录所有字段作为变更）
     */
    public void logInsert(String userName, String pageCode, String tableCode, String tableName,
                          Long recordId, Map<String, Object> data) {
        // 新增时，所有字段都算用户输入
        List<SaveParam.FieldChange> changes = data.entrySet().stream()
            .filter(e -> !isSystemField(e.getKey()))
            .map(e -> {
                SaveParam.FieldChange change = new SaveParam.FieldChange();
                change.setField(e.getKey());
                change.setOldValue(null);
                change.setNewValue(e.getValue());
                change.setChangeType("user");
                return change;
            })
            .collect(Collectors.toList());

        log(userName, pageCode, tableCode, tableName, recordId, "INSERT", changes);
    }

    /**
     * 记录删除操作
     */
    public void logDelete(String userName, String pageCode, String tableCode, String tableName, Long recordId) {
        log(userName, pageCode, tableCode, tableName, recordId, "DELETE", null);
    }

    private boolean isSystemField(String field) {
        return "id".equals(field) || "createTime".equals(field) || "updateTime".equals(field)
            || "createBy".equals(field) || "updateBy".equals(field) || "deleted".equals(field)
            || field.startsWith("_");
    }

    private String escape(String s) {
        return s == null ? "" : s.replace("'", "''");
    }
}
