package com.cost.costserver.log;

import cn.hutool.json.JSONUtil;
import com.cost.costserver.dynamic.dto.SaveParam;
import com.cost.costserver.dynamic.mapper.DynamicMapper;
import com.cost.costserver.metadata.dto.ColumnMetadataDTO;
import com.cost.costserver.metadata.dto.TableMetadataDTO;
import com.cost.costserver.metadata.service.MetadataService;
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
    private final MetadataService metadataService;

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

        // 转换为可读文本
        String changesText = formatChanges(tableCode, userChanges);

        String sql = String.format(
            "INSERT INTO T_COST_AUDIT_LOG (ID, USER_NAME, PAGE_CODE, TABLE_CODE, TABLE_NAME, RECORD_ID, OPERATION_TYPE, FIELD_CHANGES) " +
            "VALUES (SEQ_COST_AUDIT_LOG.NEXTVAL, '%s', '%s', '%s', '%s', %s, '%s', %s)",
            escape(userName),
            escape(pageCode),
            escape(tableCode),
            escape(tableName),
            recordId != null ? recordId : "NULL",
            operationType,
            changesText != null ? "'" + escape(changesText) + "'" : "NULL"
        );

        dynamicMapper.insert(sql);
        log.debug("[审计日志] {} {} {} #{}", userName, operationType, tableCode, recordId);
    }

    /**
     * 记录新增操作
     */
    public void logInsert(String userName, String pageCode, String tableCode, String tableName,
                          Long recordId, Map<String, Object> data) {
        // 新增时，记录所有非系统字段
        StringBuilder sb = new StringBuilder();
        Map<String, String> fieldNameMap = getFieldNameMap(tableCode);
        
        for (Map.Entry<String, Object> entry : data.entrySet()) {
            String field = entry.getKey();
            if (isSystemField(field)) continue;
            
            String fieldLabel = fieldNameMap.getOrDefault(field, field);
            Object value = entry.getValue();
            
            if (sb.length() > 0) sb.append("；");
            sb.append("字段「").append(fieldLabel).append("」值「").append(formatValue(value)).append("」");
        }

        String changesText = sb.length() > 0 ? sb.toString() : null;

        String sql = String.format(
            "INSERT INTO T_COST_AUDIT_LOG (ID, USER_NAME, PAGE_CODE, TABLE_CODE, TABLE_NAME, RECORD_ID, OPERATION_TYPE, FIELD_CHANGES) " +
            "VALUES (SEQ_COST_AUDIT_LOG.NEXTVAL, '%s', '%s', '%s', '%s', %s, '%s', %s)",
            escape(userName),
            escape(pageCode),
            escape(tableCode),
            escape(tableName),
            recordId != null ? recordId : "NULL",
            "INSERT",
            changesText != null ? "'" + escape(changesText) + "'" : "NULL"
        );

        dynamicMapper.insert(sql);
        log.debug("[审计日志] {} INSERT {} #{}", userName, tableCode, recordId);
    }

    /**
     * 记录删除操作
     */
    public void logDelete(String userName, String pageCode, String tableCode, String tableName, Long recordId) {
        log(userName, pageCode, tableCode, tableName, recordId, "DELETE", null);
    }

    /**
     * 格式化变更为可读文本
     */
    private String formatChanges(String tableCode, List<SaveParam.FieldChange> changes) {
        if (changes == null || changes.isEmpty()) return null;
        
        Map<String, String> fieldNameMap = getFieldNameMap(tableCode);
        
        StringBuilder sb = new StringBuilder();
        for (SaveParam.FieldChange change : changes) {
            String fieldLabel = fieldNameMap.getOrDefault(change.getField(), change.getField());
            
            if (sb.length() > 0) sb.append("；");
            sb.append("字段「").append(fieldLabel).append("」")
              .append("原值「").append(formatValue(change.getOldValue())).append("」")
              .append("新值「").append(formatValue(change.getNewValue())).append("」");
        }
        
        return sb.toString();
    }

    /**
     * 获取字段名到中文名的映射
     */
    private Map<String, String> getFieldNameMap(String tableCode) {
        try {
            TableMetadataDTO meta = metadataService.getTableMetadata(tableCode);
            return meta.columns().stream()
                .collect(Collectors.toMap(
                    ColumnMetadataDTO::fieldName,
                    ColumnMetadataDTO::headerText,
                    (a, b) -> a
                ));
        } catch (Exception e) {
            log.warn("获取表元数据失败: {}", tableCode);
            return Map.of();
        }
    }

    private String formatValue(Object value) {
        if (value == null) return "空";
        return value.toString();
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
