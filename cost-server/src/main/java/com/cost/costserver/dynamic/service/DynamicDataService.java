package com.cost.costserver.dynamic.service;

import cn.hutool.core.util.StrUtil;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.common.PageResult;
import com.cost.costserver.dynamic.dto.QueryParam;
import com.cost.costserver.dynamic.mapper.DynamicMapper;
import com.cost.costserver.metadata.entity.ColumnMetadata;
import com.cost.costserver.metadata.service.MetadataService;
import com.cost.costserver.metadata.vo.TableMetadataVO;
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
    private static final DateTimeFormatter DT_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    public PageResult<Map<String, Object>> query(String tableCode, QueryParam param) {
        TableMetadataVO metadata = metadataService.getTableMetadata(tableCode);
        Map<String, ColumnMetadata> columnMap = buildColumnMap(metadata);

        String queryView = metadata.getQueryView();
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

    public Map<String, Object> getById(String tableCode, Long id) {
        TableMetadataVO metadata = metadataService.getTableMetadata(tableCode);
        Map<String, ColumnMetadata> columnMap = buildColumnMap(metadata);

        String sql = String.format("SELECT * FROM %s WHERE %s = %d AND DELETED = 0",
            metadata.getQueryView(), metadata.getPkColumn(), id);

        List<Map<String, Object>> list = dynamicMapper.selectList(sql);
        if (list.isEmpty()) {
            throw new BusinessException(400, "数据不存在");
        }
        return convertToCamelCase(list.get(0), columnMap);
    }

    public Long insert(String tableCode, Map<String, Object> data) {
        TableMetadataVO metadata = metadataService.getTableMetadata(tableCode);
        Map<String, ColumnMetadata> columnMap = buildColumnMap(metadata);

        Long id = dynamicMapper.getNextSequenceValue(metadata.getSequenceName());
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
            ColumnMetadata col = columnMap.get(entry.getKey());
            String columnName = col != null ? col.getColumnName() : camelToUnderscore(entry.getKey());

            if (col == null && !isAuditField(entry.getKey())) {
                continue;
            }

            if (columns.length() > 0) {
                columns.append(", ");
                values.append(", ");
            }
            columns.append(columnName);
            values.append(formatValue(entry.getValue(), col));
        }

        String sql = String.format("INSERT INTO %s (%s) VALUES (%s)",
            metadata.getTargetTable(), columns, values);

        dynamicMapper.insert(sql);
        return id;
    }

    public void update(String tableCode, Long id, Map<String, Object> data) {
        TableMetadataVO metadata = metadataService.getTableMetadata(tableCode);
        Map<String, ColumnMetadata> columnMap = buildColumnMap(metadata);

        data.put("updateTime", LocalDateTime.now().format(DT_FORMATTER));
        data.put("updateBy", "system");
        data.remove("id");
        data.remove("createTime");
        data.remove("createBy");
        data.remove("deleted");

        StringBuilder setClause = new StringBuilder();
        for (Map.Entry<String, Object> entry : data.entrySet()) {
            ColumnMetadata col = columnMap.get(entry.getKey());
            String columnName = col != null ? col.getColumnName() : camelToUnderscore(entry.getKey());

            if (col == null && !isAuditField(entry.getKey())) {
                continue;
            }

            if (setClause.length() > 0) {
                setClause.append(", ");
            }
            setClause.append(columnName).append(" = ").append(formatValue(entry.getValue(), col));
        }

        String sql = String.format("UPDATE %s SET %s WHERE %s = %d AND DELETED = 0",
            metadata.getTargetTable(), setClause, metadata.getPkColumn(), id);

        int rows = dynamicMapper.update(sql);
        if (rows == 0) {
            throw new BusinessException(400, "数据不存在或已被删除");
        }
    }

    public void delete(String tableCode, Long id) {
        TableMetadataVO metadata = metadataService.getTableMetadata(tableCode);

        String now = LocalDateTime.now().format(DT_FORMATTER);
        String sql = String.format(
            "UPDATE %s SET DELETED = 1, UPDATE_TIME = TO_TIMESTAMP('%s', 'YYYY-MM-DD HH24:MI:SS'), UPDATE_BY = 'system' WHERE %s = %d AND DELETED = 0",
            metadata.getTargetTable(), now, metadata.getPkColumn(), id
        );

        int rows = dynamicMapper.delete(sql);
        if (rows == 0) {
            throw new BusinessException(400, "数据不存在或已被删除");
        }
    }

    private Map<String, ColumnMetadata> buildColumnMap(TableMetadataVO metadata) {
        return metadata.getColumns().stream()
            .collect(Collectors.toMap(ColumnMetadata::getFieldName, c -> c));
    }

    private String buildWhereClause(List<QueryParam.QueryCondition> conditions, Map<String, ColumnMetadata> columnMap) {
        if (conditions == null || conditions.isEmpty()) {
            return "";
        }

        StringBuilder sb = new StringBuilder();
        for (QueryParam.QueryCondition cond : conditions) {
            ColumnMetadata col = columnMap.get(cond.getField());
            if (col == null || col.getSearchable() != 1) {
                continue;
            }

            String columnName = col.getColumnName();
            String op = cond.getOperator();
            Object value = cond.getValue();

            sb.append(" AND ");
            switch (op) {
                case "eq" -> sb.append(columnName).append(" = ").append(formatValue(value, col));
                case "ne" -> sb.append(columnName).append(" <> ").append(formatValue(value, col));
                case "gt" -> sb.append(columnName).append(" > ").append(formatValue(value, col));
                case "ge" -> sb.append(columnName).append(" >= ").append(formatValue(value, col));
                case "lt" -> sb.append(columnName).append(" < ").append(formatValue(value, col));
                case "le" -> sb.append(columnName).append(" <= ").append(formatValue(value, col));
                case "like" -> sb.append(columnName).append(" LIKE '%").append(escapeSql(value.toString())).append("%'");
                case "between" -> sb.append(columnName).append(" BETWEEN ")
                    .append(formatValue(value, col)).append(" AND ").append(formatValue(cond.getValue2(), col));
                default -> log.warn("不支持的操作符: {}", op);
            }
        }
        return sb.toString();
    }

    private String buildOrderClause(String sortField, String sortOrder, Map<String, ColumnMetadata> columnMap) {
        if (StrUtil.isBlank(sortField)) {
            return "";
        }
        ColumnMetadata col = columnMap.get(sortField);
        if (col == null || col.getSortable() != 1) {
            return "";
        }
        String order = "desc".equalsIgnoreCase(sortOrder) ? "DESC" : "ASC";
        return " ORDER BY " + col.getColumnName() + " " + order;
    }

    private String formatValue(Object value, ColumnMetadata col) {
        if (value == null) {
            return "NULL";
        }
        String strValue = escapeSql(value.toString());
        if (col != null && ("date".equals(col.getDataType()) || "datetime".equals(col.getDataType()))) {
            return String.format("TO_TIMESTAMP('%s', 'YYYY-MM-DD HH24:MI:SS')", strValue);
        }
        if (col != null && "number".equals(col.getDataType())) {
            return strValue;
        }
        return "'" + strValue + "'";
    }

    private String escapeSql(String value) {
        if (value == null) return "";
        return value.replace("'", "''");
    }

    private Map<String, Object> convertToCamelCase(Map<String, Object> row, Map<String, ColumnMetadata> columnMap) {
        Map<String, Object> result = new LinkedHashMap<>();
        Map<String, String> reverseMap = columnMap.values().stream()
            .collect(Collectors.toMap(c -> c.getColumnName().toUpperCase(), ColumnMetadata::getFieldName));

        for (Map.Entry<String, Object> entry : row.entrySet()) {
            String key = entry.getKey().toUpperCase();
            String fieldName = reverseMap.getOrDefault(key, underscoreToCamel(entry.getKey()));
            result.put(fieldName, entry.getValue());
        }
        return result;
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
}
