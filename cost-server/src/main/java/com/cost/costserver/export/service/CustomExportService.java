package com.cost.costserver.export.service;

import cn.hutool.core.util.StrUtil;
import com.alibaba.excel.EasyExcel;
import com.alibaba.excel.ExcelWriter;
import com.alibaba.excel.metadata.Head;
import com.alibaba.excel.metadata.data.WriteCellData;
import com.alibaba.excel.write.handler.AbstractCellWriteHandler;
import com.alibaba.excel.write.metadata.WriteSheet;
import com.alibaba.excel.write.metadata.holder.WriteSheetHolder;
import com.alibaba.excel.write.metadata.holder.WriteTableHolder;
import com.alibaba.excel.write.style.column.LongestMatchColumnWidthStyleStrategy;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.dynamic.dto.QueryParam;
import com.cost.costserver.dynamic.mapper.DynamicMapper;
import com.cost.costserver.export.dto.CustomExportConfigDTO;
import com.cost.costserver.export.dto.CustomExportRequest;
import com.cost.costserver.export.entity.ExportConfig;
import com.cost.costserver.export.entity.ExportConfigDetail;
import com.cost.costserver.export.mapper.ExportConfigDetailMapper;
import com.cost.costserver.export.mapper.ExportConfigMapper;
import com.cost.costserver.metadata.dto.ColumnMetadataDTO;
import com.cost.costserver.metadata.dto.TableMetadataDTO;
import com.cost.costserver.metadata.service.MetadataService;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.ServletOutputStream;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.poi.common.usermodel.HyperlinkType;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.ss.usermodel.Font;
import org.apache.poi.ss.usermodel.Hyperlink;
import org.apache.poi.ss.usermodel.IndexedColors;
import org.apache.poi.ss.usermodel.Workbook;
import org.springframework.stereotype.Service;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

/**
 * 自定义 SQL 导出服务
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CustomExportService {

    private static final String DEFAULT_PAGE_VIEW_ALIAS = "p";
    private static final DateTimeFormatter DT_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    private final ExportConfigMapper exportConfigMapper;
    private final ExportConfigDetailMapper exportConfigDetailMapper;
    private final DynamicMapper dynamicMapper;
    private final MetadataService metadataService;
    private final ObjectMapper objectMapper;

    /**
     * 获取页面可用的导出配置列表
     */
    public List<CustomExportConfigDTO> getExportConfigs(String pageCode) {
        List<ExportConfig> configs = exportConfigMapper.findByPageCode(pageCode);
        return configs.stream().map(this::toSimpleDTO).collect(Collectors.toList());
    }

    /**
     * 执行自定义导出
     */
    public void export(String exportCode, CustomExportRequest request, HttpServletResponse response) {
        ExportConfig config = exportConfigMapper.findByCode(exportCode);
        if (config == null) {
            throw new BusinessException(400, "??????? " + exportCode);
        }

        List<ExportConfigDetail> details = exportConfigDetailMapper.findByConfigId(config.getId());

        boolean exportAll = request == null || StrUtil.isBlank(request.getMode())
                || "all".equalsIgnoreCase(request.getMode());
        List<QueryParam.QueryCondition> conditions = request != null ? request.getConditions() : null;
        List<CustomExportRequest.SortItem> sorts = request != null ? request.getSorts() : null;

        TableMetadataDTO pageMeta = null;
        String pageView = null;
        if (!exportAll && StrUtil.isNotBlank(config.getPageCode())) {
            pageMeta = metadataService.getTableMetadataByPageCode(config.getPageCode());
            if (pageMeta != null) {
                pageView = pageMeta.queryView();
            }
        }
        if (!exportAll) {
            if (pageMeta == null || StrUtil.isBlank(pageView)) {
                throw new BusinessException(400, "page view not found for export config");
            }
            if (StrUtil.isBlank(config.getPageFkColumn())) {
                throw new BusinessException(400, "pageFkColumn is required for current export");
            }
        }

        List<CustomExportConfigDTO.ColumnConfig> masterColumnsForSort =
                resolveColumns(config.getColumns(), Collections.emptyList());
        String masterSql = buildMasterSql(config, exportAll, pageView, pageMeta, conditions, sorts, masterColumnsForSort);
        log.info("Custom export master SQL: {}", masterSql);
        List<Map<String, Object>> masterRows = dynamicMapper.selectList(masterSql);

        List<CustomExportConfigDTO.ColumnConfig> masterColumns =
                resolveColumns(config.getColumns(), masterRows);

        String masterLinkColumn = resolveMasterLinkColumn(config);
        List<DetailSheetInfo> detailSheets = buildDetailSheets(config, details, masterRows, masterLinkColumn,
                exportAll, pageView, pageMeta, conditions);

        String fileName = config.getExportName() + ".xlsx";
        writeResponseHeaders(response, fileName);

        try (ServletOutputStream outputStream = response.getOutputStream();
                ExcelWriter writer = EasyExcel.write(outputStream)
                        .registerWriteHandler(new LongestMatchColumnWidthStyleStrategy())
                        .build()) {

            String masterSheetName = StrUtil.isNotBlank(config.getMasterSheetName())
                    ? config.getMasterSheetName()
                    : "master";
            int masterLinkColumnIndex = resolveLinkColumnIndex(masterColumns, masterLinkColumn);
            int masterHeadRowCount = resolveHeadRowCount(masterColumns);
            List<String> masterRowKeys = buildRowKeys(masterRows, masterLinkColumn);
            Map<String, Integer> masterRowIndexByKey = buildFirstRowIndexByKey(masterRows, masterLinkColumn);

            Map<String, SheetLinkTarget> detailTargetByKey = new HashMap<>();
            for (DetailSheetInfo detailSheet : detailSheets) {
                String detailLinkColumn = resolveDetailLinkColumn(config, detailSheet.detail);
                detailSheet.linkColumn = detailLinkColumn;
                detailSheet.linkColumnIndex = resolveLinkColumnIndex(detailSheet.columns, detailLinkColumn);
                detailSheet.headRowCount = resolveHeadRowCount(detailSheet.columns);
                detailSheet.rowKeys = buildRowKeys(detailSheet.rows, detailLinkColumn);
                detailSheet.rowIndexByKey = buildFirstRowIndexByKey(detailSheet.rows, detailLinkColumn);
                if (masterLinkColumnIndex >= 0
                        && detailSheet.linkColumnIndex >= 0
                        && !detailSheet.rowIndexByKey.isEmpty()) {
                    String key = detailSheet.linkKey;
                    if (StrUtil.isBlank(key)) {
                        key = detailSheet.rowIndexByKey.keySet().iterator().next();
                    }
                    Integer rowIndex = detailSheet.rowIndexByKey.get(key);
                    if (StrUtil.isNotBlank(key) && rowIndex != null && !detailTargetByKey.containsKey(key)) {
                        detailTargetByKey.put(key,
                                new SheetLinkTarget(detailSheet.sheetName, rowIndex, detailSheet.headRowCount));
                    }
                }
            }

            MasterDetailLinkCellWriteHandler masterLinkHandler = null;
            if (masterLinkColumnIndex >= 0 && !detailTargetByKey.isEmpty()) {
                masterLinkHandler = new MasterDetailLinkCellWriteHandler(
                        masterLinkColumnIndex,
                        masterRowKeys,
                        detailTargetByKey);
            }

            writeMasterSheet(writer, masterSheetName, masterColumns, masterRows, masterLinkHandler);

            for (DetailSheetInfo detailSheet : detailSheets) {
                HyperlinkCellWriteHandler detailLinkHandler = null;
                if (detailSheet.linkColumnIndex >= 0 && !masterRowIndexByKey.isEmpty()) {
                    detailLinkHandler = new HyperlinkCellWriteHandler(
                            detailSheet.linkColumnIndex,
                            detailSheet.rowKeys,
                            masterRowIndexByKey,
                            masterSheetName,
                            masterHeadRowCount);
                }
                writeDetailSheet(writer, detailSheet.sheetNo, detailSheet.sheetName,
                        detailSheet.columns, detailSheet.rows, detailLinkHandler);
            }

            writer.finish();
        } catch (Exception e) {
            log.error("Custom export failed", e);
            throw new BusinessException(500, "????: " + e.getMessage());
        }
    }


    /**
     * 构建主表 SQL
     */
    private String buildMasterSql(ExportConfig config, boolean exportAll,
            String pageView, TableMetadataDTO pageMeta,
            List<QueryParam.QueryCondition> conditions,
            List<CustomExportRequest.SortItem> sorts,
            List<CustomExportConfigDTO.ColumnConfig> columnsForSort) {
        String baseSql = config.getMasterSql();

        if (exportAll || StrUtil.isBlank(pageView)) {
            return appendOrderByClause(baseSql, sorts, columnsForSort, config.getMasterTableAlias());
        }

        String masterAlias = config.getMasterTableAlias();
        if (StrUtil.isBlank(masterAlias)) {
            throw new BusinessException(400, "masterTableAlias is required for current export");
        }

        String pkColumn = resolvePkColumn(config);
        ensureColumnReference(baseSql, masterAlias, pkColumn, "masterSql");

        String existsClause = buildPageExistsClause(config, pageView, pageMeta, conditions, masterAlias);
        String filtered = appendWhereClause(baseSql, existsClause);
        return appendOrderByClause(filtered, sorts, columnsForSort, masterAlias);
    }

    private String buildDetailSql(ExportConfig config, ExportConfigDetail detail,
            boolean exportAll, String pageView, TableMetadataDTO pageMeta,
            List<QueryParam.QueryCondition> conditions) {
        String baseSql = detail.getDetailSql();

        if (exportAll || StrUtil.isBlank(pageView)) {
            return baseSql;
        }

        String masterAlias = StrUtil.isNotBlank(detail.getMasterTableAlias())
                ? detail.getMasterTableAlias()
                : config.getMasterTableAlias();
        if (StrUtil.isBlank(masterAlias)) {
            throw new BusinessException(400, "masterTableAlias is required for detail export");
        }

        String existsClause = buildPageExistsClause(config, pageView, pageMeta, conditions, masterAlias);
        return appendWhereClause(baseSql, existsClause);
    }

    private String buildPageExistsClause(ExportConfig config, String pageView, TableMetadataDTO pageMeta,
            List<QueryParam.QueryCondition> conditions, String masterAlias) {
        String pageViewAlias = StrUtil.isNotBlank(config.getPageViewAlias())
                ? config.getPageViewAlias()
                : DEFAULT_PAGE_VIEW_ALIAS;
        String pageFkColumn = config.getPageFkColumn();
        if (!isSafeIdentifier(pageFkColumn)) {
            throw new BusinessException(400, "invalid pageFkColumn");
        }

        String pkColumn = resolvePkColumn(config);
        if (!isSafeIdentifier(pkColumn)) {
            throw new BusinessException(400, "invalid pkColumn");
        }

        Map<String, ColumnMetadataDTO> columnMap = buildColumnMap(pageMeta);
        StringBuilder sb = new StringBuilder();
        sb.append("EXISTS (SELECT 1 FROM ").append(pageView).append(" ").append(pageViewAlias);
        sb.append(" WHERE ").append(pageViewAlias).append(".").append(pageFkColumn);
        sb.append(" = ").append(masterAlias).append(".").append(pkColumn);

        if (hasDeletedColumn(columnMap)) {
            sb.append(" AND ").append(pageViewAlias).append(".DELETED = 0");
        }

        String conditionClause = buildConditionClause(conditions, pageViewAlias, columnMap);
        if (StrUtil.isNotBlank(conditionClause)) {
            sb.append(conditionClause);
        }

        sb.append(")");
        return sb.toString();
    }

    private String resolvePkColumn(ExportConfig config) {
        String pkColumn = config.getPkColumn();
        if (StrUtil.isBlank(pkColumn)) {
            throw new BusinessException(400, "pkColumn is required for current export");
        }
        return pkColumn;
    }

    private void ensureColumnReference(String sql, String alias, String column, String label) {
        if (StrUtil.isBlank(sql) || StrUtil.isBlank(alias) || StrUtil.isBlank(column)) {
            return;
        }
        String normalizedSql = sql.replaceAll("\\s+", "").toUpperCase(Locale.ROOT);
        String target = (alias + "." + column).replaceAll("\\s+", "").toUpperCase(Locale.ROOT);
        if (!normalizedSql.contains(target)) {
            throw new BusinessException(400, label + " must reference " + alias + "." + column);
        }
    }

    private String buildConditionClause(List<QueryParam.QueryCondition> conditions,
            String tableAlias, Map<String, ColumnMetadataDTO> columnMap) {
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

            String columnName;
            if (col != null) {
                columnName = col.columnName();
            } else if (isAuditField(fieldName)) {
                columnName = camelToUnderscore(fieldName);
            } else {
                log.warn("invalid query field: {}", fieldName);
                continue;
            }

            String qualified = tableAlias + "." + columnName;
            String op = cond.getOperator();
            Object value = cond.getValue();

            if (value == null && !"eq".equals(op) && !"ne".equals(op)) {
                continue;
            }

            String clause = null;
            switch (op) {
                case "eq" ->
                    clause = qualified + (value == null ? " IS NULL" : " = " + formatValue(value, col, fieldName));
                case "ne" ->
                    clause = qualified + (value == null ? " IS NOT NULL" : " <> " + formatValue(value, col, fieldName));
                case "gt" -> clause = qualified + " > " + formatValue(value, col, fieldName);
                case "ge" -> clause = qualified + " >= " + formatValue(value, col, fieldName);
                case "lt" -> clause = qualified + " < " + formatValue(value, col, fieldName);
                case "le" -> clause = qualified + " <= " + formatValue(value, col, fieldName);
                case "like" -> clause = qualified + " LIKE '%" + escapeSql(value.toString()) + "%'";
                case "between" -> {
                    if (cond.getValue2() != null) {
                        clause = qualified + " BETWEEN " + formatValue(value, col, fieldName) + " AND "
                                + formatValue(cond.getValue2(), col, fieldName);
                    }
                }
                case "in" -> {
                    String inClause = buildInClause(value, col, fieldName);
                    if (inClause != null) {
                        clause = qualified + " IN (" + inClause + ")";
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

    private String appendWhereClause(String sql, String clause) {
        if (StrUtil.isBlank(clause)) {
            return sql;
        }
        int insertPos = findClauseInsertPosition(sql);
        String head = sql.substring(0, insertPos);
        String tail = sql.substring(insertPos);
        String upperHead = head.toUpperCase(Locale.ROOT);
        if (upperHead.contains(" WHERE ")) {
            return head + " AND " + clause + tail;
        }
        return head + " WHERE " + clause + tail;
    }

    private int findClauseInsertPosition(String sql) {
        String upper = sql.toUpperCase(Locale.ROOT);
        int orderIdx = upper.lastIndexOf(" ORDER BY ");
        int groupIdx = upper.lastIndexOf(" GROUP BY ");
        int havingIdx = upper.lastIndexOf(" HAVING ");
        int idx = Math.max(orderIdx, Math.max(groupIdx, havingIdx));
        return idx >= 0 ? idx : sql.length();
    }

    private String appendOrderByClause(String sql, List<CustomExportRequest.SortItem> sorts,
            List<CustomExportConfigDTO.ColumnConfig> columns, String alias) {
        if (sorts == null || sorts.isEmpty() || columns == null || columns.isEmpty()) {
            return sql;
        }
        String upperSql = sql.toUpperCase(Locale.ROOT);
        if (upperSql.contains(" ORDER BY ")) {
            return sql;
        }
        String orderClause = buildOrderByClause(sorts, columns, alias);
        return StrUtil.isBlank(orderClause) ? sql : sql + orderClause;
    }

    private String buildOrderByClause(List<CustomExportRequest.SortItem> sorts,
            List<CustomExportConfigDTO.ColumnConfig> columns, String alias) {
        if (sorts == null || sorts.isEmpty() || columns == null || columns.isEmpty()) {
            return "";
        }

        Map<String, CustomExportConfigDTO.ColumnConfig> columnMap = new HashMap<>();
        for (CustomExportConfigDTO.ColumnConfig column : columns) {
            if (column == null || StrUtil.isBlank(column.getField())) {
                continue;
            }
            columnMap.put(column.getField().toLowerCase(Locale.ROOT), column);
        }

        List<String> parts = new ArrayList<>();
        for (CustomExportRequest.SortItem sort : sorts) {
            if (sort == null || StrUtil.isBlank(sort.getField())) {
                continue;
            }
            CustomExportConfigDTO.ColumnConfig column = columnMap.get(sort.getField().toLowerCase(Locale.ROOT));
            if (column == null || StrUtil.isBlank(column.getField())) {
                continue;
            }
            if (!isSafeIdentifier(column.getField())) {
                continue;
            }
            String prefix = StrUtil.isNotBlank(alias) ? alias + "." : "";
            parts.add(prefix + column.getField() + " " + normalizeSortOrder(sort.getOrder()));
        }
        if (parts.isEmpty()) {
            return "";
        }
        return " ORDER BY " + String.join(", ", parts);
    }

    private String normalizeSortOrder(String order) {
        return "desc".equalsIgnoreCase(order) ? "DESC" : "ASC";
    }

    private boolean isSafeIdentifier(String value) {
        if (StrUtil.isBlank(value)) {
            return false;
        }
        return value.matches("[A-Za-z0-9_]+");
    }

    private boolean hasDeletedColumn(Map<String, ColumnMetadataDTO> columnMap) {
        if (columnMap == null || columnMap.isEmpty()) {
            return false;
        }
        return columnMap.keySet().stream().anyMatch(key -> "deleted".equalsIgnoreCase(key));
    }

    private Map<String, ColumnMetadataDTO> buildColumnMap(TableMetadataDTO metadata) {
        if (metadata == null || metadata.columns() == null) {
            return Collections.emptyMap();
        }
        Map<String, ColumnMetadataDTO> map = new HashMap<>();
        for (ColumnMetadataDTO column : metadata.columns()) {
            if (column != null && StrUtil.isNotBlank(column.fieldName())) {
                map.put(column.fieldName(), column);
            }
        }
        return map;
    }

    private String resolveMasterLinkColumn(ExportConfig config) {
        if (config == null) {
            return null;
        }
        if (StrUtil.isNotBlank(config.getMasterLinkColumn())) {
            return config.getMasterLinkColumn();
        }
        return config.getPkColumn();
    }

    private List<DetailSheetInfo> buildDetailSheets(ExportConfig config, List<ExportConfigDetail> details,
            List<Map<String, Object>> masterRows, String masterLinkColumn,
            boolean exportAll, String pageView, TableMetadataDTO pageMeta,
            List<QueryParam.QueryCondition> conditions) {
        List<DetailSheetInfo> detailSheets = new ArrayList<>();
        if (details == null || details.isEmpty()) {
            return detailSheets;
        }

        boolean perRowDetail = StrUtil.isNotBlank(masterLinkColumn)
                && masterRows != null
                && !masterRows.isEmpty();
        int detailSheetNo = 1;
        Set<String> usedNames = new HashSet<>();

        for (ExportConfigDetail detail : details) {
            String detailSql = buildDetailSql(config, detail, exportAll, pageView, pageMeta, conditions);
            log.info("Custom export detail SQL [{}]: {}", detail.getTabKey(), detailSql);
            List<Map<String, Object>> detailRows = dynamicMapper.selectList(detailSql);
            if (detailRows == null || detailRows.isEmpty()) {
                continue;
            }
            List<CustomExportConfigDTO.ColumnConfig> detailColumns = resolveColumns(detail.getColumns(), detailRows);

            if (!perRowDetail) {
                String sheetName = resolveDetailSheetName(detail, detailSheetNo, usedNames);
                detailSheets.add(new DetailSheetInfo(detail, detailSheetNo, sheetName, detailRows, detailColumns));
                detailSheetNo++;
                continue;
            }

            String detailLinkColumn = resolveDetailLinkColumn(config, detail);
            Map<String, List<Map<String, Object>>> rowsByKey = groupRowsByKey(detailRows, detailLinkColumn);
            if (rowsByKey.isEmpty()) {
                continue;
            }

            for (Map<String, Object> masterRow : masterRows) {
                String key = normalizeLinkValue(resolveRowValue(masterRow, masterLinkColumn));
                if (StrUtil.isBlank(key)) {
                    continue;
                }
                List<Map<String, Object>> rowsForKey = rowsByKey.get(key);
                if (rowsForKey == null || rowsForKey.isEmpty()) {
                    continue;
                }
                String sheetName = resolveDetailSheetName(detail, key, detailSheetNo, usedNames);
                DetailSheetInfo sheetInfo =
                        new DetailSheetInfo(detail, detailSheetNo, sheetName, rowsForKey, detailColumns);
                sheetInfo.linkKey = key;
                detailSheets.add(sheetInfo);
                detailSheetNo++;
            }
        }

        return detailSheets;
    }

    private Map<String, List<Map<String, Object>>> groupRowsByKey(
            List<Map<String, Object>> rows, String linkColumn) {
        if (rows == null || rows.isEmpty() || StrUtil.isBlank(linkColumn)) {
            return Collections.emptyMap();
        }
        Map<String, List<Map<String, Object>>> grouped = new LinkedHashMap<>();
        for (Map<String, Object> row : rows) {
            String key = normalizeLinkValue(resolveRowValue(row, linkColumn));
            if (StrUtil.isBlank(key)) {
                continue;
            }
            grouped.computeIfAbsent(key, k -> new ArrayList<>()).add(row);
        }
        return grouped;
    }

    private String resolveDetailSheetName(ExportConfigDetail detail, int index, Set<String> usedNames) {
        String base = resolveDetailSheetBaseName(detail);
        String name = base;
        if (detail == null
                || (StrUtil.isBlank(detail.getSheetName()) && StrUtil.isBlank(detail.getTabKey()))) {
            name = base + "_" + index;
        }
        return ensureUniqueSheetName(sanitizeSheetName(name), usedNames);
    }

    private String resolveDetailSheetName(ExportConfigDetail detail, String key, int index, Set<String> usedNames) {
        String base = resolveDetailSheetBaseName(detail);
        String name = StrUtil.isNotBlank(key) ? base + "_" + key : base + "_" + index;
        return ensureUniqueSheetName(sanitizeSheetName(name), usedNames);
    }

    private String resolveDetailSheetBaseName(ExportConfigDetail detail) {
        if (detail != null && StrUtil.isNotBlank(detail.getSheetName())) {
            return detail.getSheetName();
        }
        if (detail != null && StrUtil.isNotBlank(detail.getTabKey())) {
            return detail.getTabKey();
        }
        return "detail";
    }

    private void writeMasterSheet(ExcelWriter writer, String sheetName,
            List<CustomExportConfigDTO.ColumnConfig> columns,
            List<Map<String, Object>> rows,
            AbstractCellWriteHandler linkHandler) {
        List<List<String>> head = buildHead(columns);
        List<List<Object>> data = buildDataRows(rows, columns);
        WriteSheet sheet = buildSheet(0, sheetName, head, linkHandler);
        writer.write(data, sheet);
    }

    /**
     * 写入从表 Sheet
     */
    private void writeDetailSheet(ExcelWriter writer, int sheetNo, String sheetName,
            List<CustomExportConfigDTO.ColumnConfig> columns,
            List<Map<String, Object>> rows,
            AbstractCellWriteHandler linkHandler) {
        List<List<String>> head = buildHead(columns);
        List<List<Object>> data = buildDataRows(rows, columns);
        WriteSheet sheet = buildSheet(sheetNo, sheetName, head, linkHandler);
        writer.write(data, sheet);
    }

    private WriteSheet buildSheet(int sheetNo, String sheetName, List<List<String>> head,
            AbstractCellWriteHandler linkHandler) {
        var builder = EasyExcel.writerSheet(sheetNo, sheetName).head(head);
        if (linkHandler != null) {
            builder.registerWriteHandler(linkHandler);
        }
        return builder.build();
    }

    /**
     * 构建表头
     */
    private List<List<String>> buildHead(List<CustomExportConfigDTO.ColumnConfig> columns) {
        if (columns == null || columns.isEmpty()) {
            return Collections.emptyList();
        }
        return resolveVisibleColumns(columns).stream()
                .map(c -> Collections.singletonList(
                        StrUtil.isNotBlank(c.getHeader()) ? c.getHeader() : c.getField()))
                .collect(Collectors.toList());
    }

    /**
     * 构建数据行
     */
    private List<List<Object>> buildDataRows(List<Map<String, Object>> rows,
            List<CustomExportConfigDTO.ColumnConfig> columns) {
        if (rows == null || rows.isEmpty() || columns == null || columns.isEmpty()) {
            return Collections.emptyList();
        }

        List<CustomExportConfigDTO.ColumnConfig> visibleColumns = resolveVisibleColumns(columns);

        List<List<Object>> data = new ArrayList<>();
        for (Map<String, Object> row : rows) {
            List<Object> line = new ArrayList<>();
            for (CustomExportConfigDTO.ColumnConfig col : visibleColumns) {
                Object value = resolveRowValue(row, col.getField());
                line.add(normalizeCellValue(value));
            }
            data.add(line);
        }
        return data;
    }

    private List<CustomExportConfigDTO.ColumnConfig> resolveVisibleColumns(
            List<CustomExportConfigDTO.ColumnConfig> columns) {
        if (columns == null || columns.isEmpty()) {
            return Collections.emptyList();
        }
        return columns.stream()
                .filter(Objects::nonNull)
                .filter(c -> c.getVisible() == null || c.getVisible())
                .filter(c -> StrUtil.isNotBlank(c.getField()))
                .sorted(Comparator.comparingInt(c -> c.getOrder() == null ? Integer.MAX_VALUE : c.getOrder()))
                .toList();
    }

    private Object resolveRowValue(Map<String, Object> row, String field) {
        if (row == null || StrUtil.isBlank(field)) {
            return null;
        }
        Object value = row.get(field);
        if (value == null) {
            value = row.get(field.toUpperCase(Locale.ROOT));
        }
        if (value == null) {
            value = row.get(camelToUnderscore(field));
        }
        return value;
    }

    /**
     * 解析列配置 JSON
     */
    private List<CustomExportConfigDTO.ColumnConfig> resolveColumns(
            String columnsJson, List<Map<String, Object>> rows) {
        List<CustomExportConfigDTO.ColumnConfig> columns = new ArrayList<>(parseColumns(columnsJson));

        if (!columns.isEmpty()) {
            for (CustomExportConfigDTO.ColumnConfig column : columns) {
                if (column == null || StrUtil.isBlank(column.getField())) {
                    continue;
                }
                if (StrUtil.isBlank(column.getHeader())) {
                    column.setHeader(column.getField());
                }
            }
            return columns;
        }

        if (rows != null && !rows.isEmpty()) {
            Map<String, Object> first = rows.get(0);
            int order = 1;
            for (String key : first.keySet()) {
                if (StrUtil.isBlank(key)) {
                    continue;
                }
                CustomExportConfigDTO.ColumnConfig column = new CustomExportConfigDTO.ColumnConfig();
                column.setField(key);
                column.setHeader(key);
                column.setOrder(order++);
                column.setVisible(Boolean.TRUE);
                columns.add(column);
            }
        }

        return columns;
    }

    private int resolveHeadRowCount(List<CustomExportConfigDTO.ColumnConfig> columns) {
        List<CustomExportConfigDTO.ColumnConfig> visible = resolveVisibleColumns(columns);
        return visible.isEmpty() ? 0 : 1;
    }

    private int resolveLinkColumnIndex(List<CustomExportConfigDTO.ColumnConfig> columns, String linkColumn) {
        if (StrUtil.isBlank(linkColumn)) {
            return -1;
        }
        List<CustomExportConfigDTO.ColumnConfig> visible = resolveVisibleColumns(columns);
        if (visible.isEmpty()) {
            return -1;
        }
        String target = normalizeLinkColumn(linkColumn);
        if (target == null) {
            return -1;
        }
        for (int i = 0; i < visible.size(); i++) {
            CustomExportConfigDTO.ColumnConfig col = visible.get(i);
            String field = normalizeLinkColumn(col.getField());
            if (target.equals(field)) {
                return i;
            }
        }
        return -1;
    }

    private String normalizeLinkColumn(String value) {
        if (StrUtil.isBlank(value)) {
            return null;
        }
        return value.replace("_", "").trim().toUpperCase(Locale.ROOT);
    }

    private List<String> buildRowKeys(List<Map<String, Object>> rows, String linkColumn) {
        if (rows == null || rows.isEmpty() || StrUtil.isBlank(linkColumn)) {
            return Collections.emptyList();
        }
        List<String> keys = new ArrayList<>(rows.size());
        for (Map<String, Object> row : rows) {
            Object value = resolveRowValue(row, linkColumn);
            keys.add(normalizeLinkValue(value));
        }
        return keys;
    }

    private Map<String, Integer> buildFirstRowIndexByKey(List<Map<String, Object>> rows, String linkColumn) {
        if (rows == null || rows.isEmpty() || StrUtil.isBlank(linkColumn)) {
            return Collections.emptyMap();
        }
        Map<String, Integer> map = new HashMap<>();
        for (int i = 0; i < rows.size(); i++) {
            Object value = resolveRowValue(rows.get(i), linkColumn);
            String key = normalizeLinkValue(value);
            if (StrUtil.isBlank(key) || map.containsKey(key)) {
                continue;
            }
            map.put(key, i);
        }
        return map;
    }

    private String normalizeLinkValue(Object value) {
        if (value == null) {
            return null;
        }
        String text = value.toString().trim();
        return text.isEmpty() ? null : text;
    }

    private String resolveDetailLinkColumn(ExportConfig config, ExportConfigDetail detail) {
        if (detail != null && StrUtil.isNotBlank(detail.getDetailLinkColumn())) {
            return detail.getDetailLinkColumn();
        }
        return config != null ? config.getMasterLinkColumn() : null;
    }

    private static String escapeSheetName(String sheetName) {
        if (sheetName == null) {
            return "";
        }
        return sheetName.replace("'", "''");
    }

    private List<CustomExportConfigDTO.ColumnConfig> parseColumns(String columnsJson) {
        if (StrUtil.isBlank(columnsJson)) {
            return Collections.emptyList();
        }
        try {
            return objectMapper.readValue(columnsJson,
                    new TypeReference<List<CustomExportConfigDTO.ColumnConfig>>() {
                    });
        } catch (Exception e) {
            log.warn("Parse columns failed: {}", e.getMessage());
            return Collections.emptyList();
        }
    }

    /**
     * 转换为简单 DTO（列表展示用）
     */
    private CustomExportConfigDTO toSimpleDTO(ExportConfig config) {
        CustomExportConfigDTO dto = new CustomExportConfigDTO();
        dto.setId(config.getId());
        dto.setExportCode(config.getExportCode());
        dto.setExportName(config.getExportName());
        dto.setPageCode(config.getPageCode());
        dto.setDisplayOrder(config.getDisplayOrder());
        return dto;
    }

    private void writeResponseHeaders(HttpServletResponse response, String fileName) {
        response.setContentType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        String encoded = URLEncoder.encode(fileName, StandardCharsets.UTF_8);
        response.setHeader("Content-Disposition", "attachment; filename*=UTF-8''" + encoded);
        response.setHeader("Access-Control-Expose-Headers", "Content-Disposition");
    }

    private String formatValue(Object value, ColumnMetadataDTO col, String fieldName) {
        if (value == null) {
            return "NULL";
        }
        String strValue = escapeSql(value.toString());

        if ("createTime".equals(fieldName) || "updateTime".equals(fieldName)) {
            return String.format("TO_TIMESTAMP('%s', 'YYYY-MM-DD HH24:MI:SS')", strValue);
        }
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

    private String buildInClause(Object value, ColumnMetadataDTO col, String fieldName) {
        if (value == null) {
            return null;
        }
        Collection<?> values = null;
        if (value instanceof Collection<?> collection) {
            values = collection;
        } else if (value.getClass().isArray()) {
            int length = java.lang.reflect.Array.getLength(value);
            List<Object> items = new ArrayList<>(length);
            for (int i = 0; i < length; i++) {
                items.add(java.lang.reflect.Array.get(value, i));
            }
            values = items;
        }
        if (values == null || values.isEmpty()) {
            return null;
        }
        List<String> parts = new ArrayList<>(values.size());
        for (Object item : values) {
            parts.add(formatValue(item, col, fieldName));
        }
        return String.join(", ", parts);
    }

    private String validateAndFormatNumber(String value) {
        if (value == null || value.isEmpty()) {
            return "NULL";
        }
        if (!value.matches("^-?\\d+(\\.\\d+)?$")) {
            throw new BusinessException(400, "invalid number: " + value);
        }
        return value;
    }

    private String escapeSql(String value) {
        if (value == null)
            return "";
        return value.replace("'", "''");
    }

    private Object normalizeCellValue(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof java.sql.Timestamp ts) {
            return ts.toLocalDateTime().format(DT_FORMATTER);
        }
        if (value instanceof java.sql.Date date) {
            return date.toLocalDate().toString();
        }
        if (value instanceof java.util.Date date) {
            LocalDateTime dt = Instant.ofEpochMilli(date.getTime())
                    .atZone(ZoneId.systemDefault())
                    .toLocalDateTime();
            return dt.format(DT_FORMATTER);
        }
        if (value instanceof java.sql.Clob clob) {
            try {
                return clob.getSubString(1, (int) clob.length());
            } catch (java.sql.SQLException e) {
                log.warn("CLOB convert failed: {}", e.getMessage());
                return null;
            }
        }
        return value;
    }

    private static class DetailSheetInfo {
        private final ExportConfigDetail detail;
        private final int sheetNo;
        private final String sheetName;
        private final List<Map<String, Object>> rows;
        private final List<CustomExportConfigDTO.ColumnConfig> columns;

        private String linkKey;
        private String linkColumn;
        private int linkColumnIndex = -1;
        private int headRowCount;
        private List<String> rowKeys = Collections.emptyList();
        private Map<String, Integer> rowIndexByKey = Collections.emptyMap();

        private DetailSheetInfo(ExportConfigDetail detail, int sheetNo, String sheetName,
                List<Map<String, Object>> rows, List<CustomExportConfigDTO.ColumnConfig> columns) {
            this.detail = detail;
            this.sheetNo = sheetNo;
            this.sheetName = sheetName;
            this.rows = rows;
            this.columns = columns;
        }
    }

    private static class SheetLinkTarget {
        private final String sheetName;
        private final int rowIndex;
        private final int headRowCount;

        private SheetLinkTarget(String sheetName, int rowIndex, int headRowCount) {
            this.sheetName = sheetName;
            this.rowIndex = rowIndex;
            this.headRowCount = headRowCount;
        }
    }

    private static class MasterDetailLinkCellWriteHandler extends AbstractCellWriteHandler {
        private final int linkColumnIndex;
        private final List<String> rowKeys;
        private final Map<String, SheetLinkTarget> targets;
        private final Map<Short, CellStyle> hyperlinkStyles = new HashMap<>();

        private MasterDetailLinkCellWriteHandler(int linkColumnIndex, List<String> rowKeys,
                Map<String, SheetLinkTarget> targets) {
            this.linkColumnIndex = linkColumnIndex;
            this.rowKeys = rowKeys == null ? Collections.emptyList() : rowKeys;
            this.targets = targets == null ? Collections.emptyMap() : targets;
        }

        @Override
        public void afterCellDispose(WriteSheetHolder writeSheetHolder, WriteTableHolder writeTableHolder,
                List<WriteCellData<?>> cellDataList, Cell cell, Head head, Integer relativeRowIndex, Boolean isHead) {
            if (Boolean.TRUE.equals(isHead) || cell == null || relativeRowIndex == null) {
                return;
            }
            if (cell.getColumnIndex() != linkColumnIndex) {
                return;
            }
            if (relativeRowIndex < 0 || relativeRowIndex >= rowKeys.size()) {
                return;
            }
            String key = rowKeys.get(relativeRowIndex);
            if (StrUtil.isBlank(key)) {
                return;
            }
            SheetLinkTarget target = targets.get(key);
            if (target == null) {
                return;
            }
            int excelRow = target.rowIndex + target.headRowCount + 1;
            Hyperlink link = writeSheetHolder.getSheet().getWorkbook().getCreationHelper()
                    .createHyperlink(HyperlinkType.DOCUMENT);
            link.setAddress("'" + escapeSheetName(target.sheetName) + "'!A" + excelRow);
            cell.setHyperlink(link);
            CellStyle style = resolveHyperlinkStyle(writeSheetHolder.getSheet().getWorkbook(),
                    cell.getCellStyle(), hyperlinkStyles);
            if (style != null) {
                cell.setCellStyle(style);
            }
        }
    }

    private static class HyperlinkCellWriteHandler extends AbstractCellWriteHandler {
        private final int linkColumnIndex;
        private final List<String> rowKeys;
        private final Map<String, Integer> targetRowIndexByKey;
        private final String targetSheetName;
        private final int targetHeadRowCount;
        private final Map<Short, CellStyle> hyperlinkStyles = new HashMap<>();

        private HyperlinkCellWriteHandler(int linkColumnIndex, List<String> rowKeys,
                Map<String, Integer> targetRowIndexByKey, String targetSheetName, int targetHeadRowCount) {
            this.linkColumnIndex = linkColumnIndex;
            this.rowKeys = rowKeys == null ? Collections.emptyList() : rowKeys;
            this.targetRowIndexByKey = targetRowIndexByKey == null ? Collections.emptyMap() : targetRowIndexByKey;
            this.targetSheetName = targetSheetName;
            this.targetHeadRowCount = targetHeadRowCount;
        }

        @Override
        public void afterCellDispose(WriteSheetHolder writeSheetHolder, WriteTableHolder writeTableHolder,
                List<WriteCellData<?>> cellDataList, Cell cell, Head head, Integer relativeRowIndex, Boolean isHead) {
            if (Boolean.TRUE.equals(isHead) || cell == null || relativeRowIndex == null) {
                return;
            }
            if (cell.getColumnIndex() != linkColumnIndex) {
                return;
            }
            if (relativeRowIndex < 0 || relativeRowIndex >= rowKeys.size()) {
                return;
            }
            String key = rowKeys.get(relativeRowIndex);
            if (key == null) {
                return;
            }
            Integer targetRowIndex = targetRowIndexByKey.get(key);
            if (targetRowIndex == null) {
                return;
            }
            int excelRow = targetRowIndex + targetHeadRowCount + 1;
            Hyperlink link = writeSheetHolder.getSheet().getWorkbook().getCreationHelper()
                    .createHyperlink(HyperlinkType.DOCUMENT);
            link.setAddress("'" + escapeSheetName(targetSheetName) + "'!A" + excelRow);
            cell.setHyperlink(link);
            CellStyle style = resolveHyperlinkStyle(writeSheetHolder.getSheet().getWorkbook(),
                    cell.getCellStyle(), hyperlinkStyles);
            if (style != null) {
                cell.setCellStyle(style);
            }
        }
    }

    private static CellStyle resolveHyperlinkStyle(Workbook workbook, CellStyle baseStyle,
            Map<Short, CellStyle> cache) {
        if (workbook == null || cache == null) {
            return baseStyle;
        }
        short baseIndex = baseStyle != null ? baseStyle.getIndex() : -1;
        CellStyle cached = cache.get(baseIndex);
        if (cached != null) {
            return cached;
        }
        CellStyle style = workbook.createCellStyle();
        if (baseStyle != null) {
            style.cloneStyleFrom(baseStyle);
        }
        Font font = workbook.createFont();
        font.setColor(IndexedColors.BLUE.getIndex());
        font.setUnderline(Font.U_SINGLE);
        style.setFont(font);
        cache.put(baseIndex, style);
        return style;
    }

    private String camelToUnderscore(String name) {
        if (name == null)
            return null;
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
        if (fieldName == null) {
            return false;
        }
        return Set.of("id", "deleted", "createTime", "updateTime", "createBy", "updateBy")
                .contains(fieldName);
    }

    private String sanitizeSheetName(String sheetName) {
        if (sheetName == null) {
            return "detail";
        }
        String cleaned = sheetName.replaceAll("[\\\\/?*\\[\\]:]", "_").trim();
        if (cleaned.isEmpty()) {
            cleaned = "detail";
        }
        if (cleaned.length() > 31) {
            cleaned = cleaned.substring(0, 31);
        }
        return cleaned;
    }

    private String ensureUniqueSheetName(String sheetName, Set<String> usedNames) {
        if (usedNames == null) {
            return sheetName;
        }
        String base = sheetName;
        String candidate = base;
        int suffix = 1;
        while (usedNames.contains(candidate)) {
            String extra = "_" + suffix;
            int maxBaseLength = 31 - extra.length();
            String trimmed = base.length() > maxBaseLength ? base.substring(0, maxBaseLength) : base;
            candidate = trimmed + extra;
            suffix++;
        }
        usedNames.add(candidate);
        return candidate;
    }
}
