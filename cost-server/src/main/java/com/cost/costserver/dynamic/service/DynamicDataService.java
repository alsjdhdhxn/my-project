package com.cost.costserver.dynamic.service;

import cn.hutool.core.util.StrUtil;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.common.PageResult;
import com.cost.costserver.dynamic.dto.MasterDetailSaveParam;
import com.cost.costserver.dynamic.dto.QueryParam;
import com.cost.costserver.dynamic.mapper.DynamicMapper;
import com.cost.costserver.log.AuditLogService;
import com.cost.costserver.log.OperationLogContext;
import com.cost.costserver.log.OperationLogService;
import com.cost.costserver.metadata.dto.ColumnMetadataDTO;
import com.cost.costserver.metadata.dto.TableMetadataDTO;
import com.cost.costserver.metadata.service.MetadataService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class DynamicDataService {

    private final DynamicMapper dynamicMapper;
    private final MetadataService metadataService;
    private final ValidationService validationService;
    private final OperationLogService operationLogService;
    private final AuditLogService auditLogService;
    private static final DateTimeFormatter DT_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    public PageResult<Map<String, Object>> query(String tableCode, QueryParam param) {
        TableMetadataDTO metadata = metadataService.getTableMetadata(tableCode);
        Map<String, ColumnMetadataDTO> columnMap = buildColumnMap(metadata);

        String queryView = metadata.queryView();
        String whereClause = buildWhereClause(param.getConditions(), columnMap);
        String orderClause = buildOrderClause(param.getSortField(), param.getSortOrder(), columnMap);

        String countSql = String.format("SELECT COUNT(*) FROM %s WHERE DELETED = 0 %s", queryView, whereClause);
        Long total = dynamicMapper.selectCount(countSql);

        int offset = (param.getPage() - 1) * param.getPageSize();
        String dataSql = String.format(
            "SELECT * FROM (SELECT t.*, ROWNUM rn FROM (SELECT * FROM %s WHERE DELETED = 0 %s %s) t WHERE ROWNUM <= %d) WHERE rn > %d",
            queryView, whereClause, orderClause, offset + param.getPageSize(), offset
        );

        List<Map<String, Object>> list = dynamicMapper.selectList(dataSql);
        list = list.stream().map(row -> convertToCamelCase(row, columnMap)).collect(Collectors.toList());

        return new PageResult<>(list, total, param.getPage(), param.getPageSize());
    }

    /**
     * 查询全部数据（不分页）
     */
    public List<Map<String, Object>> queryAll(String tableCode, String sortField, String sortOrder) {
        TableMetadataDTO metadata = metadataService.getTableMetadata(tableCode);
        Map<String, ColumnMetadataDTO> columnMap = buildColumnMap(metadata);

        String orderClause = buildOrderClause(sortField, sortOrder, columnMap);
        String sql = String.format("SELECT * FROM %s WHERE DELETED = 0 %s", metadata.queryView(), orderClause);

        List<Map<String, Object>> list = dynamicMapper.selectList(sql);
        return list.stream().map(row -> convertToCamelCase(row, columnMap)).collect(Collectors.toList());
    }

    public Map<String, Object> getById(String tableCode, Long id) {
        TableMetadataDTO metadata = metadataService.getTableMetadata(tableCode);
        Map<String, ColumnMetadataDTO> columnMap = buildColumnMap(metadata);

        String sql = String.format("SELECT * FROM %s WHERE %s = %d AND DELETED = 0",
            metadata.queryView(), metadata.pkColumn(), id);

        List<Map<String, Object>> list = dynamicMapper.selectList(sql);
        if (list.isEmpty()) {
            throw new BusinessException(400, "数据不存在");
        }
        return convertToCamelCase(list.get(0), columnMap);
    }

    public Long insert(String tableCode, Map<String, Object> data) {
        TableMetadataDTO metadata = metadataService.getTableMetadata(tableCode);
        Map<String, ColumnMetadataDTO> columnMap = buildColumnMap(metadata);

        Long id = dynamicMapper.getNextSequenceValue(metadata.sequenceName());
        data.put("id", id);

        String now = LocalDateTime.now().format(DT_FORMATTER);
        data.put("createTime", now);
        data.put("updateTime", now);
        data.put("deleted", 0);
        data.put("createBy", "system");
        data.put("updateBy", "system");

        StringBuilder columns = new StringBuilder();
        StringBuilder values = new StringBuilder();

        for (Map.Entry<String, Object> entry : data.entrySet()) {
            ColumnMetadataDTO col = columnMap.get(entry.getKey());
            
            // 跳过虚拟列
            if (col != null && Boolean.TRUE.equals(col.isVirtual())) {
                continue;
            }
            
            // 优先用 targetColumn，其次 columnName，最后转换
            String columnName = getTargetColumnName(col, entry.getKey());

            if (col == null && !isAuditField(entry.getKey())) {
                continue;
            }

            if (columns.length() > 0) {
                columns.append(", ");
                values.append(", ");
            }
            columns.append(columnName);
            values.append(formatValue(entry.getValue(), col, entry.getKey()));
        }

        String sql = String.format("INSERT INTO %s (%s) VALUES (%s)",
            metadata.targetTable(), columns, values);

        dynamicMapper.insert(sql);
        return id;
    }

    /**
     * 主从表批量保存
     * @param param 包含主表和从表数据，通过 tempId/masterTempId 关联
     * @return 主表真实 ID
     */
    @org.springframework.transaction.annotation.Transactional(rollbackFor = Exception.class)
    public Long saveMasterDetail(MasterDetailSaveParam param) {
        // 参数校验
        if (param == null || param.getMaster() == null || StrUtil.isBlank(param.getMasterTableCode())) {
            throw new BusinessException(400, "主表数据不能为空");
        }

        // 1. 保存主表，获取真实 ID
        String masterTempId = (String) param.getMaster().get("tempId");
        param.getMaster().remove("tempId");
        Long masterId = insert(param.getMasterTableCode(), param.getMaster());

        // 2. 保存从表，填充外键
        if (param.getDetails() != null && !param.getDetails().isEmpty()) {
            for (MasterDetailSaveParam.DetailData detail : param.getDetails()) {
                if (detail == null || StrUtil.isBlank(detail.getTableCode()) || detail.getRows() == null) {
                    continue;
                }

                TableMetadataDTO detailMeta = metadataService.getTableMetadata(detail.getTableCode());
                String fkColumn = detailMeta.parentFkColumn();
                if (StrUtil.isBlank(fkColumn)) {
                    throw new BusinessException(400, "从表 " + detail.getTableCode() + " 未配置外键列 PARENT_FK_COLUMN");
                }
                String fkFieldName = underscoreToCamel(fkColumn);

                for (Map<String, Object> row : detail.getRows()) {
                    if (row == null) continue;
                    String rowMasterTempId = (String) row.get("masterTempId");
                    // 只处理关联到当前主表的从表记录
                    if (masterTempId != null && masterTempId.equals(rowMasterTempId)) {
                        row.remove("tempId");
                        row.remove("masterTempId");
                        row.put(fkFieldName, masterId);
                        insert(detail.getTableCode(), row);
                    }
                }
            }
        }

        return masterId;
    }

    public void update(String tableCode, Long id, Map<String, Object> data) {
        if (data == null || data.isEmpty()) {
            throw new BusinessException(400, "更新数据不能为空");
        }
        if (id == null) {
            throw new BusinessException(400, "ID不能为空");
        }

        TableMetadataDTO metadata = metadataService.getTableMetadata(tableCode);
        Map<String, ColumnMetadataDTO> columnMap = buildColumnMap(metadata);

        data.put("updateTime", LocalDateTime.now().format(DT_FORMATTER));
        data.put("updateBy", "system");
        data.remove("id");
        data.remove("createTime");
        data.remove("createBy");
        data.remove("deleted");

        StringBuilder setClause = new StringBuilder();
        for (Map.Entry<String, Object> entry : data.entrySet()) {
            ColumnMetadataDTO col = columnMap.get(entry.getKey());
            
            // 跳过虚拟列
            if (col != null && Boolean.TRUE.equals(col.isVirtual())) {
                continue;
            }
            
            String columnName = getTargetColumnName(col, entry.getKey());

            if (col == null && !isAuditField(entry.getKey())) {
                continue;
            }

            if (setClause.length() > 0) {
                setClause.append(", ");
            }
            setClause.append(columnName).append(" = ").append(formatValue(entry.getValue(), col, entry.getKey()));
        }

        if (setClause.isEmpty()) {
            throw new BusinessException(400, "没有有效的更新字段");
        }

        String sql = String.format("UPDATE %s SET %s WHERE %s = %d AND DELETED = 0",
            metadata.targetTable(), setClause, metadata.pkColumn(), id);

        int rows = dynamicMapper.update(sql);
        if (rows == 0) {
            throw new BusinessException(400, "数据不存在或已被删除");
        }
    }

    @org.springframework.transaction.annotation.Transactional(rollbackFor = Exception.class)
    public void delete(String tableCode, Long id) {
        if (id == null) {
            throw new BusinessException(400, "ID不能为空");
        }

        TableMetadataDTO metadata = metadataService.getTableMetadata(tableCode);
        String now = LocalDateTime.now().format(DT_FORMATTER);

        // 1. 先级联删除子表数据
        List<TableMetadataDTO> childTables = metadataService.findChildTables(tableCode);
        for (TableMetadataDTO child : childTables) {
            if (StrUtil.isBlank(child.parentFkColumn())) {
                log.warn("子表 {} 未配置外键列，跳过级联删除", child.tableCode());
                continue;
            }
            String childSql = String.format(
                "UPDATE %s SET DELETED = 1, UPDATE_TIME = TO_TIMESTAMP('%s', 'YYYY-MM-DD HH24:MI:SS'), UPDATE_BY = 'system' WHERE %s = %d AND DELETED = 0",
                child.targetTable(), now, child.parentFkColumn(), id
            );
            dynamicMapper.delete(childSql);
        }

        // 2. 再删除主表数据
        String sql = String.format(
            "UPDATE %s SET DELETED = 1, UPDATE_TIME = TO_TIMESTAMP('%s', 'YYYY-MM-DD HH24:MI:SS'), UPDATE_BY = 'system' WHERE %s = %d AND DELETED = 0",
            metadata.targetTable(), now, metadata.pkColumn(), id
        );

        int rows = dynamicMapper.delete(sql);
        if (rows == 0) {
            throw new BusinessException(400, "数据不存在或已被删除");
        }
    }

    private Map<String, ColumnMetadataDTO> buildColumnMap(TableMetadataDTO metadata) {
        return metadata.columns().stream()
            .collect(Collectors.toMap(ColumnMetadataDTO::fieldName, c -> c));
    }

    private String buildWhereClause(List<QueryParam.QueryCondition> conditions, Map<String, ColumnMetadataDTO> columnMap) {
        if (conditions == null || conditions.isEmpty()) {
            return "";
        }

        StringBuilder sb = new StringBuilder();
        for (QueryParam.QueryCondition cond : conditions) {
            if (cond == null || StrUtil.isBlank(cond.getField()) || StrUtil.isBlank(cond.getOperator())) {
                continue;
            }

            String fieldName = cond.getField();
            ColumnMetadataDTO col = columnMap.get(fieldName);

            // 支持元数据中的列 + 审计字段
            String columnName;
            if (col != null) {
                columnName = col.columnName();
            } else if (isAuditField(fieldName)) {
                columnName = camelToUnderscore(fieldName);
            } else {
                log.warn("非法查询字段: {}", fieldName);
                continue;
            }

            String op = cond.getOperator();
            Object value = cond.getValue();

            if (value == null && !"eq".equals(op) && !"ne".equals(op)) {
                continue; // 非等于/不等于操作，值不能为空
            }

            sb.append(" AND ");
            switch (op) {
                case "eq" -> sb.append(columnName).append(value == null ? " IS NULL" : " = " + formatValue(value, col, fieldName));
                case "ne" -> sb.append(columnName).append(value == null ? " IS NOT NULL" : " <> " + formatValue(value, col, fieldName));
                case "gt" -> sb.append(columnName).append(" > ").append(formatValue(value, col, fieldName));
                case "ge" -> sb.append(columnName).append(" >= ").append(formatValue(value, col, fieldName));
                case "lt" -> sb.append(columnName).append(" < ").append(formatValue(value, col, fieldName));
                case "le" -> sb.append(columnName).append(" <= ").append(formatValue(value, col, fieldName));
                case "like" -> sb.append(columnName).append(" LIKE '%").append(escapeSql(value.toString())).append("%'");
                case "between" -> {
                    if (cond.getValue2() != null) {
                        sb.append(columnName).append(" BETWEEN ")
                            .append(formatValue(value, col, fieldName)).append(" AND ").append(formatValue(cond.getValue2(), col, fieldName));
                    }
                }
                default -> log.warn("不支持的操作符: {}", op);
            }
        }
        return sb.toString();
    }

    private String buildOrderClause(String sortField, String sortOrder, Map<String, ColumnMetadataDTO> columnMap) {
        if (StrUtil.isBlank(sortField)) {
            return "";
        }
        ColumnMetadataDTO col = columnMap.get(sortField);
        if (col == null || !Boolean.TRUE.equals(col.sortable())) {
            return "";
        }
        String order = "desc".equalsIgnoreCase(sortOrder) ? "DESC" : "ASC";
        return " ORDER BY " + col.columnName() + " " + order;
    }

    private String formatValue(Object value, ColumnMetadataDTO col, String fieldName) {
        if (value == null) {
            return "NULL";
        }
        String strValue = escapeSql(value.toString());
        
        // 审计字段中的时间字段
        if ("createTime".equals(fieldName) || "updateTime".equals(fieldName)) {
            return String.format("TO_TIMESTAMP('%s', 'YYYY-MM-DD HH24:MI:SS')", strValue);
        }
        // 审计字段中的数字字段
        if ("id".equals(fieldName) || "deleted".equals(fieldName)) {
            return validateAndFormatNumber(strValue);
        }
        
        if (col != null && ("date".equals(col.dataType()) || "datetime".equals(col.dataType()))) {
            return String.format("TO_TIMESTAMP('%s', 'YYYY-MM-DD HH24:MI:SS')", strValue);
        }
        if (col != null && "number".equals(col.dataType())) {
            return validateAndFormatNumber(strValue);
        }
        return "'" + strValue + "'";
    }

    /**
     * 校验并格式化数字，防止 SQL 注入
     */
    private String validateAndFormatNumber(String value) {
        if (value == null || value.isEmpty()) {
            return "NULL";
        }
        // 只允许数字、小数点、负号
        if (!value.matches("^-?\\d+(\\.\\d+)?$")) {
            throw new BusinessException(400, "非法的数字格式: " + value);
        }
        return value;
    }

    private String escapeSql(String value) {
        if (value == null) return "";
        return value.replace("'", "''");
    }

    private Map<String, Object> convertToCamelCase(Map<String, Object> row, Map<String, ColumnMetadataDTO> columnMap) {
        Map<String, Object> result = new LinkedHashMap<>();
        Map<String, String> reverseMap = columnMap.values().stream()
            .collect(Collectors.toMap(c -> c.columnName().toUpperCase(), ColumnMetadataDTO::fieldName));

        for (Map.Entry<String, Object> entry : row.entrySet()) {
            String key = entry.getKey().toUpperCase();
            String fieldName = reverseMap.getOrDefault(key, underscoreToCamel(entry.getKey()));
            Object value = convertOracleType(entry.getValue());
            result.put(fieldName, value);
        }
        return result;
    }

    /**
     * 转换 JDBC 类型为可序列化的 Java 类型
     * 配置 oracle.jdbc.J2EE13Compliant=true 后，Oracle 返回标准 java.sql 类型
     */
    private Object convertOracleType(Object value) {
        if (value == null) {
            return null;
        }
        // java.sql.Timestamp -> String
        if (value instanceof java.sql.Timestamp ts) {
            return ts.toLocalDateTime().format(DT_FORMATTER);
        }
        // java.sql.Date -> String
        if (value instanceof java.sql.Date date) {
            return date.toLocalDate().toString();
        }
        // 其他类型保持原样
        return value;
    }

    private String underscoreToCamel(String name) {
        StringBuilder sb = new StringBuilder();
        boolean upper = false;
        for (char c : name.toLowerCase().toCharArray()) {
            if (c == '_') {
                upper = true;
            } else {
                sb.append(upper ? Character.toUpperCase(c) : c);
                upper = false;
            }
        }
        return sb.toString();
    }

    private String camelToUnderscore(String name) {
        StringBuilder sb = new StringBuilder();
        for (char c : name.toCharArray()) {
            if (Character.isUpperCase(c)) {
                sb.append('_').append(c);
            } else {
                sb.append(Character.toUpperCase(c));
            }
        }
        return sb.toString();
    }

    private boolean isAuditField(String fieldName) {
        return Set.of("id", "deleted", "createTime", "updateTime", "createBy", "updateBy").contains(fieldName);
    }

    /**
     * 获取目标列名（用于 INSERT/UPDATE）
     * 优先级：targetColumn > columnName > 驼峰转下划线
     */
    private String getTargetColumnName(ColumnMetadataDTO col, String fieldName) {
        if (col == null) {
            return camelToUnderscore(fieldName);
        }
        if (StrUtil.isNotBlank(col.targetColumn())) {
            return col.targetColumn();
        }
        return col.columnName();
    }

    /**
     * 通用保存 - 支持单表/主从表/主从多Tab
     */
    @org.springframework.transaction.annotation.Transactional(rollbackFor = Exception.class)
    public Long save(com.cost.costserver.dynamic.dto.SaveParam param) {
        if (param == null || param.getMaster() == null) {
            throw new BusinessException(400, "主表数据不能为空");
        }

        Long masterId = null;
        String masterTableCode = null;

        // 1. 处理主表
        var master = param.getMaster();
        masterTableCode = (String) master.getData().get("_tableCode");
        if (StrUtil.isBlank(masterTableCode)) {
            throw new BusinessException(400, "主表 tableCode 不能为空");
        }
        master.getData().remove("_tableCode");

        // 开始操作日志记录
        String operationType = "added".equals(master.getStatus()) ? "INSERT" : 
                              "deleted".equals(master.getStatus()) ? "DELETE" : "UPDATE";
        OperationLogContext.start(operationType, masterTableCode, "system"); // TODO: 从 SecurityContext 获取真实用户

        try {
            // 2. 后端验证 - 主表
            if (!"deleted".equals(master.getStatus())) {
                Map<String, Object> validateData = new HashMap<>(master.getData());
                if (master.getId() != null) {
                    validateData.put("id", master.getId());
                }
                ValidationService.ValidationResult validationResult = validationService.validate(masterTableCode, validateData);
                if (!validationResult.isValid()) {
                    throw new BusinessException(400, validationResult.getMessage());
                }
            }

            switch (master.getStatus()) {
                case "added" -> {
                    masterId = insert(masterTableCode, master.getData());
                    // 审计日志 - 新增
                    TableMetadataDTO masterMeta = metadataService.getTableMetadata(masterTableCode);
                    auditLogService.logInsert("system", param.getPageCode(), masterTableCode, 
                        masterMeta.tableName(), masterId, master.getData());
                }
                case "modified" -> {
                    masterId = master.getId();
                    update(masterTableCode, masterId, master.getData());
                    // 审计日志 - 修改（只记录用户变更）
                    TableMetadataDTO masterMeta = metadataService.getTableMetadata(masterTableCode);
                    auditLogService.logAsync("system", param.getPageCode(), masterTableCode,
                        masterMeta.tableName(), masterId, "UPDATE", master.getChanges());
                }
                case "unchanged" -> masterId = master.getId();
                default -> throw new BusinessException(400, "无效的主表状态: " + master.getStatus());
            }

            // 设置记录信息
            OperationLogContext.setRecordInfo(masterId, masterTableCode + "#" + masterId);

            // 3. 处理从表
            if (param.getDetails() != null && !param.getDetails().isEmpty()) {
                for (var entry : param.getDetails().entrySet()) {
                    String detailTableCode = entry.getKey();
                    List<com.cost.costserver.dynamic.dto.SaveParam.RecordItem> items = entry.getValue();

                    if (items == null || items.isEmpty()) continue;

                    TableMetadataDTO detailMeta = metadataService.getTableMetadata(detailTableCode);
                    String fkColumn = detailMeta.parentFkColumn();
                    String fkFieldName = StrUtil.isNotBlank(fkColumn) ? underscoreToCamel(fkColumn) : null;

                    for (var item : items) {
                        if (item == null || "unchanged".equals(item.getStatus())) continue;

                        // 后端验证 - 从表（非删除操作）
                        if (!"deleted".equals(item.getStatus())) {
                            Map<String, Object> validateData = new HashMap<>(item.getData());
                            if (item.getId() != null) {
                                validateData.put("id", item.getId());
                            }
                            ValidationService.ValidationResult validationResult = validationService.validate(detailTableCode, validateData);
                            if (!validationResult.isValid()) {
                                throw new BusinessException(400, validationResult.getMessage());
                            }
                        }

                        switch (item.getStatus()) {
                            case "added" -> {
                                if (fkFieldName != null && masterId != null) {
                                    item.getData().put(fkFieldName, masterId);
                                }
                                Long detailId = insert(detailTableCode, item.getData());
                                // 审计日志 - 从表新增
                                auditLogService.logInsert("system", param.getPageCode(), detailTableCode,
                                    detailMeta.tableName(), detailId, item.getData());
                            }
                            case "modified" -> {
                                update(detailTableCode, item.getId(), item.getData());
                                // 审计日志 - 从表修改
                                auditLogService.logAsync("system", param.getPageCode(), detailTableCode,
                                    detailMeta.tableName(), item.getId(), "UPDATE", item.getChanges());
                            }
                            case "deleted" -> {
                                delete(detailTableCode, item.getId());
                                // 审计日志 - 从表删除
                                auditLogService.logDelete("system", param.getPageCode(), detailTableCode,
                                    detailMeta.tableName(), item.getId());
                            }
                        }
                    }
                }
            }

            // 保存操作日志 - 成功
            OperationLogContext.LogSession session = OperationLogContext.end();
            operationLogService.saveAsync(session, "SUCCESS", null);

            return masterId;
        } catch (Exception e) {
            // 保存操作日志 - 失败
            OperationLogContext.LogSession session = OperationLogContext.end();
            operationLogService.saveAsync(session, "FAILED", e.getMessage());
            throw e;
        }
    }
}
