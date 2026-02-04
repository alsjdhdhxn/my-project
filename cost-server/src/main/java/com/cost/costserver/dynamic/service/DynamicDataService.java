package com.cost.costserver.dynamic.service;

import cn.hutool.core.util.StrUtil;
import com.cost.costserver.auth.dto.PagePermission;
import com.cost.costserver.auth.service.PermissionService;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.common.PageResult;
import com.cost.costserver.common.SecurityUtils;
import com.cost.costserver.dynamic.dto.MasterDetailSaveParam;
import com.cost.costserver.dynamic.dto.QueryParam;
import com.cost.costserver.dynamic.dto.SaveParam;
import com.cost.costserver.dynamic.dto.SaveResult;
import com.cost.costserver.dynamic.mapper.DynamicMapper;
import com.cost.costserver.log.AuditLogService;
import com.cost.costserver.log.OperationLogContext;
import com.cost.costserver.log.OperationLogService;
import com.cost.costserver.metadata.dto.ColumnMetadataDTO;
import com.cost.costserver.metadata.dto.LookupConfigDTO;
import com.cost.costserver.metadata.dto.TableMetadataDTO;
import com.cost.costserver.metadata.service.MetadataService;
import com.cost.costserver.dynamic.validation.ValidationReport;
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
    private final PermissionService permissionService;
    private static final DateTimeFormatter DT_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    public PageResult<Map<String, Object>> query(String tableCode, QueryParam param) {
        // Lookup 查询放行：不校验 pageCode，不注入数据权限
        boolean isLookup = param != null && Boolean.TRUE.equals(param.getLookup());

        if (!isLookup) {
            if (param == null || StrUtil.isBlank(param.getPageCode())) {
                throw new BusinessException(400, "pageCode不能为空");
            }
            Long userId = SecurityUtils.getCurrentUserId();
            if (userId == null) {
                throw new BusinessException(403, "无权限访问");
            }
            PagePermission permission = permissionService.getPagePermission(userId, param.getPageCode());
            if (permission == null) {
                throw new BusinessException(403, "无权限访问");
            }
        }

        TableMetadataDTO metadata = metadataService.getTableMetadata(tableCode);
        Map<String, ColumnMetadataDTO> columnMap = buildColumnMap(metadata);

        String queryView = metadata.queryView();
        String whereClause = buildWhereClause(param != null ? param.getConditions() : null, columnMap);

        // 注入数据权限条件（Lookup 查询不注入，从表查询不注入）
        // 从表通过外键关联主表，间接继承主表的数据权限
        boolean isDetailTable = StrUtil.isNotBlank(metadata.parentTableCode());
        if (!isLookup && !isDetailTable && param != null && StrUtil.isNotBlank(param.getPageCode())) {
            Long userId = SecurityUtils.getCurrentUserId();
            PagePermission permission = permissionService.getPagePermission(userId, param.getPageCode());
            String dataRuleClause = buildDataRuleClause(permission, columnMap);
            whereClause = whereClause + dataRuleClause;
        }

        String orderClause = buildOrderClause(
                param != null ? param.getSortField() : null,
                param != null ? param.getSortOrder() : null,
                columnMap,
                metadata.pkColumn());

        String countSql = String.format("SELECT COUNT(*) FROM %s WHERE DELETED = 0 %s", queryView, whereClause);
        Long total = dynamicMapper.selectCount(countSql);

        int page = param != null ? param.getPage() : 1;
        Integer pSize = param != null ? param.getPageSize() : null;
        int pageSize = (pSize != null && pSize > 0) ? pSize : 20;
        int offset = (page - 1) * pageSize;
        String dataSql = String.format(
                "SELECT * FROM (SELECT t.*, ROWNUM rn FROM (SELECT * FROM %s WHERE DELETED = 0 %s %s) t WHERE ROWNUM <= %d) WHERE rn > %d",
                queryView, whereClause, orderClause, offset + pageSize, offset);

        List<Map<String, Object>> list = dynamicMapper.selectList(dataSql);
        list = list.stream().map(row -> convertToCamelCase(row, columnMap)).collect(Collectors.toList());

        // 合并历史对比数据
        mergeHistoryData(list, metadata, columnMap);

        return new PageResult<>(list, total, page, pageSize);
    }

    /**
     * 构建数据权限 WHERE 子句
     */
    public List<Map<String, Object>> queryAllWithConditions(String tableCode, QueryParam param) {
        boolean isLookup = param != null && Boolean.TRUE.equals(param.getLookup());

        if (!isLookup) {
            if (param == null || StrUtil.isBlank(param.getPageCode())) {
                throw new BusinessException(400, "pageCode????????????");
            }
            Long userId = SecurityUtils.getCurrentUserId();
            if (userId == null) {
                throw new BusinessException(403, "???????????????");
            }
            PagePermission permission = permissionService.getPagePermission(userId, param.getPageCode());
            if (permission == null) {
                throw new BusinessException(403, "???????????????");
            }
        }

        TableMetadataDTO metadata = metadataService.getTableMetadata(tableCode);
        Map<String, ColumnMetadataDTO> columnMap = buildColumnMap(metadata);

        String whereClause = buildWhereClause(param != null ? param.getConditions() : null, columnMap);

        // 注入数据权限条件（Lookup 查询不注入，从表查询不注入）
        boolean isDetailTable = StrUtil.isNotBlank(metadata.parentTableCode());
        if (!isLookup && !isDetailTable && param != null && StrUtil.isNotBlank(param.getPageCode())) {
            Long userId = SecurityUtils.getCurrentUserId();
            PagePermission permission = permissionService.getPagePermission(userId, param.getPageCode());
            String dataRuleClause = buildDataRuleClause(permission, columnMap);
            whereClause = whereClause + dataRuleClause;
        }

        String orderClause = buildOrderClause(
                param != null ? param.getSortField() : null,
                param != null ? param.getSortOrder() : null,
                columnMap,
                metadata.pkColumn());

        String sql = String.format("SELECT * FROM %s WHERE DELETED = 0 %s %s", metadata.queryView(), whereClause,
                orderClause);
        List<Map<String, Object>> list = dynamicMapper.selectList(sql);
        return list.stream().map(row -> convertToCamelCase(row, columnMap)).collect(Collectors.toList());
    }

    private String buildDataRuleClause(PagePermission permission, Map<String, ColumnMetadataDTO> columnMap) {
        if (permission == null || StrUtil.isBlank(permission.rowFilter())) {
            return "";
        }
        // 直接返回 SQL 条件（占位符已在 PermissionService 中解析）
        return " AND (" + permission.rowFilter() + ")";
    }

    /**
     * 查询全部数据（不分页）
     */
    public List<Map<String, Object>> queryAll(String tableCode, String sortField, String sortOrder) {
        TableMetadataDTO metadata = metadataService.getTableMetadata(tableCode);
        Map<String, ColumnMetadataDTO> columnMap = buildColumnMap(metadata);

        String orderClause = buildOrderClause(sortField, sortOrder, columnMap, metadata.pkColumn());
        String sql = String.format("SELECT * FROM %s WHERE DELETED = 0 %s", metadata.queryView(), orderClause);

        List<Map<String, Object>> list = dynamicMapper.selectList(sql);
        return list.stream().map(row -> convertToCamelCase(row, columnMap)).collect(Collectors.toList());
    }

    /**
     * Lookup 查询（不依赖表元数据）
     */
    public PageResult<Map<String, Object>> queryLookupData(String lookupCode, Integer page, Integer pageSize, 
            String filterColumn, String filterValue) {
        LookupConfigDTO config = metadataService.getLookupConfig(lookupCode);
        if (config == null || StrUtil.isBlank(config.dataSource())) {
            throw new BusinessException(400, "Lookup 数据源不能为空");
        }

        String dataSource = config.dataSource().trim();
        validateIdentifier(dataSource, "dataSource");

        int currentPage = (page != null && page > 0) ? page : 1;
        Integer pSize = (pageSize != null && pageSize > 0) ? pageSize : null;

        // 构建 WHERE 条件
        StringBuilder whereClause = new StringBuilder(" WHERE DELETED = 0");
        if (StrUtil.isNotBlank(filterColumn) && StrUtil.isNotBlank(filterValue)) {
            validateIdentifier(filterColumn, "filterColumn");
            // 对 filterValue 进行转义防止 SQL 注入
            String safeValue = filterValue.replace("'", "''");
            whereClause.append(String.format(" AND %s = '%s'", filterColumn, safeValue));
        }
        
        String countSql = String.format("SELECT COUNT(*) FROM %s%s", dataSource, whereClause);
        Long total = dynamicMapper.selectCount(countSql);

        if (pSize == null) {
            String sql = String.format("SELECT * FROM %s%s", dataSource, whereClause);
            List<Map<String, Object>> list = dynamicMapper.selectList(sql);
            List<Map<String, Object>> result = list.stream()
                    .map(this::convertToCamelCaseSimple)
                    .collect(Collectors.toList());
            return new PageResult<>(result, total == null ? result.size() : total, 1, result.size());
        }

        int offset = (currentPage - 1) * pSize;
        String dataSql = String.format(
                "SELECT * FROM (SELECT t.*, ROWNUM rn FROM (SELECT * FROM %s%s) t WHERE ROWNUM <= %d) WHERE rn > %d",
                dataSource, whereClause, offset + pSize, offset);

        List<Map<String, Object>> list = dynamicMapper.selectList(dataSql);
        List<Map<String, Object>> result = list.stream()
                .map(this::convertToCamelCaseSimple)
                .collect(Collectors.toList());

        return new PageResult<>(result, total == null ? 0 : total, currentPage, pSize);
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
        String currentUser = SecurityUtils.getCurrentUsername();
        String operator = StrUtil.isNotBlank(currentUser) ? currentUser : "system";
        data.put("createBy", operator);
        data.put("updateBy", operator);

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
     * 
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
                    if (row == null)
                        continue;
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
        String currentUser = SecurityUtils.getCurrentUsername();
        data.put("updateBy", StrUtil.isNotBlank(currentUser) ? currentUser : "system");
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
        String currentUser = SecurityUtils.getCurrentUsername();
        String operator = StrUtil.isNotBlank(currentUser) ? currentUser : "system";

        // 1. 先级联删除子表数据
        List<TableMetadataDTO> childTables = metadataService.findChildTables(tableCode);
        for (TableMetadataDTO child : childTables) {
            if (StrUtil.isBlank(child.parentFkColumn())) {
                log.warn("子表 {} 未配置外键列，跳过级联删除", child.tableCode());
                continue;
            }
            String childSql = String.format(
                    "UPDATE %s SET DELETED = 1, UPDATE_TIME = TO_TIMESTAMP('%s', 'YYYY-MM-DD HH24:MI:SS'), UPDATE_BY = '%s' WHERE %s = %d AND DELETED = 0",
                    child.targetTable(), now, operator, child.parentFkColumn(), id);
            dynamicMapper.delete(childSql);
        }

        // 2. 再删除主表数据
        String sql = String.format(
                "UPDATE %s SET DELETED = 1, UPDATE_TIME = TO_TIMESTAMP('%s', 'YYYY-MM-DD HH24:MI:SS'), UPDATE_BY = '%s' WHERE %s = %d AND DELETED = 0",
                metadata.targetTable(), now, operator, metadata.pkColumn(), id);

        int rows = dynamicMapper.delete(sql);
        if (rows == 0) {
            throw new BusinessException(400, "数据不存在或已被删除");
        }
    }

    private Map<String, ColumnMetadataDTO> buildColumnMap(TableMetadataDTO metadata) {
        return metadata.columns().stream()
                .collect(Collectors.toMap(ColumnMetadataDTO::fieldName, c -> c));
    }

    private String buildWhereClause(List<QueryParam.QueryCondition> conditions,
            Map<String, ColumnMetadataDTO> columnMap) {
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

            // Metadata columns + audit fields
            String columnName;
            if (col != null) {
                columnName = col.columnName();
            } else if (isAuditField(fieldName)) {
                columnName = camelToUnderscore(fieldName);
            } else {
                log.warn("invalid query field: {}", fieldName);
                continue;
            }

            String op = cond.getOperator();
            Object value = cond.getValue();

            if (value == null && !"eq".equals(op) && !"ne".equals(op)) {
                continue; // non-eq/ne requires a value
            }

            String clause = null;
            switch (op) {
                case "eq" ->
                    clause = columnName + (value == null ? " IS NULL" : " = " + formatValue(value, col, fieldName));
                case "ne" -> clause = columnName
                        + (value == null ? " IS NOT NULL" : " <> " + formatValue(value, col, fieldName));
                case "gt" -> clause = columnName + " > " + formatValue(value, col, fieldName);
                case "ge" -> clause = columnName + " >= " + formatValue(value, col, fieldName);
                case "lt" -> clause = columnName + " < " + formatValue(value, col, fieldName);
                case "le" -> clause = columnName + " <= " + formatValue(value, col, fieldName);
                case "like" -> clause = columnName + " LIKE '%" + escapeSql(value.toString()) + "%'";
                case "between" -> {
                    if (cond.getValue2() != null) {
                        clause = columnName + " BETWEEN " + formatValue(value, col, fieldName) + " AND "
                                + formatValue(cond.getValue2(), col, fieldName);
                    }
                }
                case "in" -> {
                    String inClause = buildInClause(value, col, fieldName);
                    if (inClause != null) {
                        clause = columnName + " IN (" + inClause + ")";
                    }
                }
                default -> log.warn("unsupported operator: {}", op);
            }

            if (clause != null && !clause.isEmpty()) {
                sb.append(" AND ").append(clause);
            }
        }
        return sb.toString();
    }

    private String buildInClause(Object value, ColumnMetadataDTO col, String fieldName) {
        if (value == null) {
            return null;
        }
        java.util.Collection<?> values = null;
        if (value instanceof java.util.Collection<?> collection) {
            values = collection;
        } else if (value.getClass().isArray()) {
            int length = java.lang.reflect.Array.getLength(value);
            java.util.List<Object> items = new java.util.ArrayList<>(length);
            for (int i = 0; i < length; i++) {
                items.add(java.lang.reflect.Array.get(value, i));
            }
            values = items;
        }
        if (values == null || values.isEmpty()) {
            return null;
        }
        java.util.List<String> parts = new java.util.ArrayList<>(values.size());
        for (Object item : values) {
            parts.add(formatValue(item, col, fieldName));
        }
        return String.join(", ", parts);
    }

    private String buildOrderClause(String sortField, String sortOrder, Map<String, ColumnMetadataDTO> columnMap, String pkColumn) {
        // 查找主键字段在视图中的列名
        // 优先从列元数据中查找 targetColumn 匹配 pkColumn 的列，取其 columnName
        String pkViewColumn = null;
        for (ColumnMetadataDTO col : columnMap.values()) {
            String target = StrUtil.isNotBlank(col.targetColumn()) ? col.targetColumn() : col.columnName();
            if (target != null && target.equalsIgnoreCase(pkColumn)) {
                pkViewColumn = col.columnName();
                break;
            }
        }
        // 如果没找到，回退到 pkColumn
        String pk = StrUtil.isNotBlank(pkViewColumn) ? pkViewColumn : pkColumn;
        if (StrUtil.isBlank(pk)) {
            pk = "ID"; // 最终兜底
        }
        
        if (StrUtil.isBlank(sortField)) {
            // 没有排序字段时，默认按主键排序以确保分页稳定性
            return " ORDER BY " + pk + " ASC";
        }
        ColumnMetadataDTO col = columnMap.get(sortField);
        if (col == null || !Boolean.TRUE.equals(col.sortable())) {
            // 排序字段无效时，默认按主键排序
            return " ORDER BY " + pk + " ASC";
        }
        String order = "desc".equalsIgnoreCase(sortOrder) ? "DESC" : "ASC";
        // 添加主键作为二级排序，确保分页结果稳定（避免排序字段值重复时返回不确定的结果）
        return " ORDER BY " + col.columnName() + " " + order + ", " + pk + " " + order;
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
        // 支持普通数字和科学计数法（如 6.5E-6, 1.23e+10）
        if (!value.matches("^-?\\d+(\\.\\d+)?([eE][+-]?\\d+)?$")) {
            throw new BusinessException(400, "非法的数字格式: " + value);
        }
        // 如果是科学计数法，转换为普通数字格式（Oracle 不支持科学计数法字面量）
        if (value.toLowerCase().contains("e")) {
            try {
                return new java.math.BigDecimal(value).toPlainString();
            } catch (NumberFormatException e) {
                throw new BusinessException(400, "非法的数字格式: " + value);
            }
        }
        return value;
    }

    private String escapeSql(String value) {
        if (value == null)
            return "";
        return value.replace("'", "''");
    }

    /**
     * 简化版：将下划线列名转换为 camelCase（不依赖元数据）
     */
    private Map<String, Object> convertToCamelCaseSimple(Map<String, Object> row) {
        Map<String, Object> result = new LinkedHashMap<>();
        for (Map.Entry<String, Object> entry : row.entrySet()) {
            String fieldName = underscoreToCamel(entry.getKey());
            Object value = convertOracleType(entry.getValue());
            result.put(fieldName, value);
        }
        return result;
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
     * 仅允许字母/数字/下划线/点，防止注入
     */
    private void validateIdentifier(String value, String label) {
        if (value == null || value.isBlank()) {
            throw new BusinessException(400, label + " 不能为空");
        }
        if (!value.matches("^[A-Za-z][A-Za-z0-9_\\.]*$")) {
            throw new BusinessException(400, label + " 非法: " + value);
        }
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
        // java.sql.Clob -> String
        if (value instanceof java.sql.Clob clob) {
            try {
                return clob.getSubString(1, (int) clob.length());
            } catch (java.sql.SQLException e) {
                log.warn("CLOB 转换失败: {}", e.getMessage());
                return null;
            }
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

    private Long extractTempId(Map<String, Object> data) {
        if (data == null)
            return null;
        Object raw = data.get("id");
        if (raw == null)
            return null;
        if (raw instanceof Number)
            return ((Number) raw).longValue();
        if (raw instanceof String) {
            String value = ((String) raw).trim();
            if (value.isEmpty())
                return null;
            try {
                return Long.parseLong(value);
            } catch (NumberFormatException ignored) {
                return null;
            }
        }
        return null;
    }

    /**
     * 通用保存 - 支持单表/主从表/主从多Tab
     */
    @org.springframework.transaction.annotation.Transactional(rollbackFor = Exception.class)
    public SaveResult save(SaveParam param) {
        if (param == null || param.getMaster() == null) {
            throw new BusinessException(400, "主表数据不能为空");
        }

        // 获取当前操作用户
        String currentUser = SecurityUtils.getCurrentUsername();
        if (StrUtil.isBlank(currentUser)) {
            currentUser = "anonymous";
        }

        Long masterId = null;
        String masterTableCode = null;
        Map<Long, Long> idMapping = new HashMap<>();

        // 1. 处理主表
        var master = param.getMaster();
        masterTableCode = (String) master.getData().get("_tableCode");
        if (StrUtil.isBlank(masterTableCode)) {
            throw new BusinessException(400, "主表 tableCode 不能为空");
        }
        master.getData().remove("_tableCode");

        // 开始操作日志记录
        String operationType = "added".equals(master.getStatus()) ? "INSERT"
                : "deleted".equals(master.getStatus()) ? "DELETE" : "UPDATE";
        OperationLogContext.start(operationType, masterTableCode, currentUser);

        final String userName = currentUser; // for lambda
        try {
            // 2. 后端验证 - 主表
            ValidationReport masterValidationReport = null;
            if (!"deleted".equals(master.getStatus())) {
                Map<String, Object> validateData = new HashMap<>(master.getData());
                if (master.getId() != null) {
                    validateData.put("id", master.getId());
                }
                masterValidationReport = validationService.validate(masterTableCode, "save", validateData);
                if (!masterValidationReport.isPassed()) {
                    throw new BusinessException(400, masterValidationReport.getMessage());
                }
            }

            switch (master.getStatus()) {
                case "added" -> {
                    Long tempId = extractTempId(master.getData());
                    masterId = insert(masterTableCode, master.getData());
                    if (tempId != null && !tempId.equals(masterId)) {
                        idMapping.put(tempId, masterId);
                    }
                    // 审计日志 - 新增
                    TableMetadataDTO masterMeta = metadataService.getTableMetadata(masterTableCode);
                    auditLogService.logInsert(userName, param.getPageCode(), masterTableCode,
                            masterMeta.tableName(), masterId, master.getData());
                }
                case "modified" -> {
                    masterId = master.getId();
                    update(masterTableCode, masterId, master.getData());
                    // 审计日志 - 修改（只记录用户变更）
                    TableMetadataDTO masterMeta = metadataService.getTableMetadata(masterTableCode);
                    auditLogService.logAsync(userName, param.getPageCode(), masterTableCode,
                            masterMeta.tableName(), masterId, "UPDATE", master.getChanges());
                }
                case "deleted" -> {
                    masterId = master.getId();
                    delete(masterTableCode, masterId);
                    // 审计日志 - 删除
                    TableMetadataDTO masterMeta = metadataService.getTableMetadata(masterTableCode);
                    auditLogService.logDelete(userName, param.getPageCode(), masterTableCode,
                            masterMeta.tableName(), masterId);
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

                    if (items == null || items.isEmpty())
                        continue;

                    TableMetadataDTO detailMeta = metadataService.getTableMetadata(detailTableCode);
                    String fkColumn = detailMeta.parentFkColumn();
                    // 根据 TARGET_COLUMN 查找对应的 FIELD_NAME
                    String fkFieldName = null;
                    if (StrUtil.isNotBlank(fkColumn)) {
                        for (ColumnMetadataDTO col : detailMeta.columns()) {
                            if (fkColumn.equalsIgnoreCase(col.targetColumn())) {
                                fkFieldName = col.fieldName();
                                break;
                            }
                        }
                        // 如果没找到，回退到驼峰转换
                        if (fkFieldName == null) {
                            fkFieldName = underscoreToCamel(fkColumn);
                        }
                    }

                    for (var item : items) {
                        if (item == null || "unchanged".equals(item.getStatus()))
                            continue;

                        // 后端验证 - 从表（非删除操作）
                        ValidationReport detailValidationReport = null;
                        if (!"deleted".equals(item.getStatus())) {
                            Map<String, Object> validateData = new HashMap<>(item.getData());
                            if (item.getId() != null) {
                                validateData.put("id", item.getId());
                            }
                            detailValidationReport = validationService.validate(detailTableCode, "save", validateData);
                            if (!detailValidationReport.isPassed()) {
                                throw new BusinessException(400, detailValidationReport.getMessage());
                            }
                        }

                        switch (item.getStatus()) {
                            case "added" -> {
                                Long tempId = extractTempId(item.getData());
                                if (fkFieldName != null && masterId != null) {
                                    item.getData().put(fkFieldName, masterId);
                                }
                                Long detailId = insert(detailTableCode, item.getData());
                                if (tempId != null && !tempId.equals(detailId)) {
                                    idMapping.put(tempId, detailId);
                                }
                                // 审计日志 - 从表新增
                                auditLogService.logInsert(userName, param.getPageCode(), detailTableCode,
                                        detailMeta.tableName(), detailId, item.getData());
                            }
                            case "modified" -> {
                                update(detailTableCode, item.getId(), item.getData());
                                // 审计日志 - 从表修改
                                auditLogService.logAsync(userName, param.getPageCode(), detailTableCode,
                                        detailMeta.tableName(), item.getId(), "UPDATE", item.getChanges());
                            }
                            case "deleted" -> {
                                delete(detailTableCode, item.getId());
                                // 审计日志 - 从表删除
                                auditLogService.logDelete(userName, param.getPageCode(), detailTableCode,
                                        detailMeta.tableName(), item.getId());
                            }
                        }
                    }
                }
            }

            // 保存操作日志 - 成功
            OperationLogContext.LogSession session = OperationLogContext.end();
            operationLogService.saveAsync(session, "SUCCESS", null);

            SaveResult result = new SaveResult(masterId, idMapping.isEmpty() ? null : idMapping);
            
            // 查询更新后的主表行数据（非删除操作）
            if (masterId != null && !"deleted".equals(master.getStatus())) {
                try {
                    QueryParam queryParam = new QueryParam();
                    queryParam.setLookup(true); // 跳过权限检查
                    // 使用 id 字段查询（元数据统一映射主键为 id）
                    queryParam.setConditions(List.of(
                        new QueryParam.QueryCondition("id", "eq", masterId, null)
                    ));
                    PageResult<Map<String, Object>> queryResult = query(masterTableCode, queryParam);
                    if (queryResult.getList() != null && !queryResult.getList().isEmpty()) {
                        result.setMasterRow(queryResult.getList().get(0));
                    }
                } catch (Exception e) {
                    log.warn("查询更新后的主表数据失败: {}", e.getMessage());
                }
            }
            
            return result;
        } catch (Exception e) {
            // 保存操作日志 - 失败
            OperationLogContext.LogSession session = OperationLogContext.end();
            operationLogService.saveAsync(session, "FAILED", e.getMessage());
            throw e;
        }
    }

    /**
     * 合并对比数据
     * 支持两种模式：
     * 1. viewField 模式：对比字段已在当前视图中（通过 SQL JOIN 预先关联）
     * 2. dynamicQuery 模式：运行时动态 LEFT JOIN 对比数据源
     */
    private void mergeHistoryData(List<Map<String, Object>> list, TableMetadataDTO metadata,
            Map<String, ColumnMetadataDTO> columnMap) {
        if (list == null || list.isEmpty())
            return;

        // 1. 找出需要对比的列，按模式分组
        List<CompareConfig> viewFieldConfigs = new ArrayList<>();
        List<CompareConfig> dynamicQueryConfigs = new ArrayList<>();

        for (ColumnMetadataDTO col : metadata.columns()) {
            if (StrUtil.isBlank(col.rulesConfig()))
                continue;
            try {
                cn.hutool.json.JSONObject config = cn.hutool.json.JSONUtil.parseObj(col.rulesConfig());
                cn.hutool.json.JSONObject compare = config.getJSONObject("compare");
                if (compare == null || !compare.getBool("enabled", false))
                    continue;

                String mode = compare.getStr("mode", "viewField");
                CompareConfig compareConfig = new CompareConfig(
                        col.fieldName(),
                        col.columnName(),
                        compare.getStr("compareField"),
                        compare.getStr("compareDataSource"),
                        parseJoinConditions(compare.getJSONArray("joinConditions")),
                        compare.getStr("format", "value")
                );

                if ("dynamicQuery".equals(mode)) {
                    dynamicQueryConfigs.add(compareConfig);
                } else {
                    viewFieldConfigs.add(compareConfig);
                }
            } catch (Exception e) {
                log.warn("解析 compare 配置失败: {}", col.fieldName(), e);
            }
        }

        // 2. 处理 viewField 模式（对比字段已在数据中）
        if (!viewFieldConfigs.isEmpty()) {
            processViewFieldCompare(list, viewFieldConfigs, columnMap);
        }

        // 3. 处理 dynamicQuery 模式（需要动态查询）
        if (!dynamicQueryConfigs.isEmpty()) {
            processDynamicQueryCompare(list, dynamicQueryConfigs, columnMap);
        }
    }

    /**
     * 解析 joinConditions 配置
     */
    private List<JoinCondition> parseJoinConditions(cn.hutool.json.JSONArray jsonArray) {
        if (jsonArray == null || jsonArray.isEmpty())
            return Collections.emptyList();
        List<JoinCondition> conditions = new ArrayList<>();
        for (int i = 0; i < jsonArray.size(); i++) {
            cn.hutool.json.JSONObject item = jsonArray.getJSONObject(i);
            if (item != null) {
                conditions.add(new JoinCondition(
                        item.getStr("currentField"),
                        item.getStr("compareField")));
            }
        }
        return conditions;
    }

    /**
     * 处理 viewField 模式的对比
     * 对比字段已在当前数据中，直接计算差值
     */
    private void processViewFieldCompare(List<Map<String, Object>> list, List<CompareConfig> configs,
            Map<String, ColumnMetadataDTO> columnMap) {
        for (Map<String, Object> row : list) {
            for (CompareConfig config : configs) {
                Object currentValue = row.get(config.fieldName);
                
                // 获取对比字段的值（可能是驼峰或下划线格式）
                String compareFieldName = config.compareField;
                Object compareValue = row.get(compareFieldName);
                if (compareValue == null) {
                    // 尝试下划线转驼峰
                    compareValue = row.get(underscoreToCamel(compareFieldName));
                }

                // 计算差值
                calculateAndSetDiff(row, config.fieldName, currentValue, compareValue);
            }
        }
    }

    /**
     * 处理 dynamicQuery 模式的对比
     * 动态查询对比数据源，然后合并
     */
    private void processDynamicQueryCompare(List<Map<String, Object>> list, List<CompareConfig> configs,
            Map<String, ColumnMetadataDTO> columnMap) {
        // 按数据源分组（同一数据源的配置合并查询）
        Map<String, List<CompareConfig>> configsByDataSource = configs.stream()
                .filter(c -> StrUtil.isNotBlank(c.compareDataSource) && !c.joinConditions.isEmpty())
                .collect(Collectors.groupingBy(c -> c.compareDataSource));

        for (Map.Entry<String, List<CompareConfig>> entry : configsByDataSource.entrySet()) {
            String dataSource = entry.getKey();
            List<CompareConfig> dataSourceConfigs = entry.getValue();

            // 使用第一个配置的 joinConditions（同一数据源应该用相同的关联条件）
            List<JoinCondition> joinConditions = dataSourceConfigs.get(0).joinConditions;
            if (joinConditions.isEmpty())
                continue;

            // 收集需要查询的对比字段
            Set<String> compareFields = dataSourceConfigs.stream()
                    .map(c -> c.compareField)
                    .filter(StrUtil::isNotBlank)
                    .collect(Collectors.toSet());
            if (compareFields.isEmpty())
                continue;

            // 收集关联字段的值（用于 IN 查询）
            // 支持多字段关联，构建复合键
            Map<String, Map<String, Object>> rowKeyMap = new LinkedHashMap<>();
            for (Map<String, Object> row : list) {
                StringBuilder keyBuilder = new StringBuilder();
                Map<String, Object> keyValues = new LinkedHashMap<>();
                boolean valid = true;
                
                for (JoinCondition jc : joinConditions) {
                    Object value = row.get(jc.currentField);
                    if (value == null) {
                        valid = false;
                        break;
                    }
                    if (keyBuilder.length() > 0) keyBuilder.append("_");
                    keyBuilder.append(value);
                    keyValues.put(jc.compareField, value);
                }
                
                if (valid) {
                    rowKeyMap.put(keyBuilder.toString(), keyValues);
                }
            }

            if (rowKeyMap.isEmpty())
                continue;

            // 构建查询 SQL
            String compareFieldList = String.join(", ", compareFields);
            String joinFieldList = joinConditions.stream()
                    .map(JoinCondition::compareField)
                    .collect(Collectors.joining(", "));

            // 构建 WHERE 条件
            String whereClause;
            if (joinConditions.size() == 1) {
                // 单字段关联，使用 IN
                JoinCondition jc = joinConditions.get(0);
                String inValues = rowKeyMap.values().stream()
                        .map(m -> formatSqlValue(m.get(jc.compareField)))
                        .collect(Collectors.joining(", "));
                whereClause = String.format("%s IN (%s)", jc.compareField, inValues);
            } else {
                // 多字段关联，使用 OR 组合
                List<String> conditions = new ArrayList<>();
                for (Map<String, Object> keyValues : rowKeyMap.values()) {
                    String condition = keyValues.entrySet().stream()
                            .map(e -> e.getKey() + " = " + formatSqlValue(e.getValue()))
                            .collect(Collectors.joining(" AND "));
                    conditions.add("(" + condition + ")");
                }
                whereClause = String.join(" OR ", conditions);
            }

            String sql = String.format("SELECT %s, %s FROM %s WHERE %s",
                    joinFieldList, compareFieldList, dataSource, whereClause);

            // 执行查询
            Map<String, Map<String, Object>> compareDataMap = new HashMap<>();
            try {
                List<Map<String, Object>> compareList = dynamicMapper.selectList(sql);
                for (Map<String, Object> compareRow : compareList) {
                    // 构建复合键
                    StringBuilder keyBuilder = new StringBuilder();
                    for (JoinCondition jc : joinConditions) {
                        Object value = compareRow.get(jc.compareField.toUpperCase());
                        if (value == null) value = compareRow.get(jc.compareField);
                        if (keyBuilder.length() > 0) keyBuilder.append("_");
                        keyBuilder.append(value);
                    }
                    compareDataMap.put(keyBuilder.toString(), compareRow);
                }
            } catch (Exception e) {
                log.warn("查询对比数据源失败: {}, SQL: {}", e.getMessage(), sql);
                continue;
            }

            // 合并对比数据
            for (Map<String, Object> row : list) {
                // 构建当前行的复合键
                StringBuilder keyBuilder = new StringBuilder();
                boolean valid = true;
                for (JoinCondition jc : joinConditions) {
                    Object value = row.get(jc.currentField);
                    if (value == null) {
                        valid = false;
                        break;
                    }
                    if (keyBuilder.length() > 0) keyBuilder.append("_");
                    keyBuilder.append(value);
                }
                if (!valid) continue;

                Map<String, Object> compareRow = compareDataMap.get(keyBuilder.toString());

                for (CompareConfig config : dataSourceConfigs) {
                    Object currentValue = row.get(config.fieldName);
                    Object compareValue = null;
                    if (compareRow != null) {
                        compareValue = compareRow.get(config.compareField.toUpperCase());
                        if (compareValue == null) {
                            compareValue = compareRow.get(config.compareField);
                        }
                    }
                    calculateAndSetDiff(row, config.fieldName, currentValue, compareValue);
                }
            }
        }
    }

    /**
     * 计算并设置差值字段
     */
    private void calculateAndSetDiff(Map<String, Object> row, String fieldName, Object currentValue, Object compareValue) {
        // 添加对比值字段
        row.put(fieldName + "Compare", compareValue);

        // 计算差值（仅数值类型）
        if (currentValue instanceof Number && compareValue instanceof Number) {
            double current = ((Number) currentValue).doubleValue();
            double compare = ((Number) compareValue).doubleValue();
            double diff = current - compare;

            row.put(fieldName + "Diff", diff);

            if (compare != 0) {
                double percent = (diff / compare) * 100;
                row.put(fieldName + "DiffPercent", Math.round(percent * 100) / 100.0);
            }
        }
    }

    /**
     * 格式化 SQL 值
     */
    private String formatSqlValue(Object value) {
        if (value == null) return "NULL";
        if (value instanceof Number) return value.toString();
        return "'" + escapeSql(value.toString()) + "'";
    }

    /** 对比配置 */
    private record CompareConfig(
            String fieldName,
            String columnName,
            String compareField,
            String compareDataSource,
            List<JoinCondition> joinConditions,
            String format) {
    }

    /** 关联条件 */
    private record JoinCondition(String currentField, String compareField) {
    }
}
