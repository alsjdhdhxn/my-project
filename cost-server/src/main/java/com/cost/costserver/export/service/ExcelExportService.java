package com.cost.costserver.export.service;

import cn.hutool.core.util.StrUtil;
import com.alibaba.excel.EasyExcel;
import com.alibaba.excel.ExcelWriter;
import com.alibaba.excel.write.handler.WorkbookWriteHandler;
import com.alibaba.excel.write.metadata.WriteSheet;
import com.alibaba.excel.write.metadata.WriteTable;
import com.cost.costserver.auth.dto.PagePermission;
import com.cost.costserver.auth.service.PermissionService;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.common.SecurityUtils;
import com.cost.costserver.dynamic.dto.QueryParam;
import com.cost.costserver.dynamic.service.DynamicDataService;
import com.cost.costserver.export.dto.ExportExcelRequest;
import com.cost.costserver.metadata.dto.ColumnMetadataDTO;
import com.cost.costserver.metadata.dto.PageComponentDTO;
import com.cost.costserver.metadata.dto.TableMetadataDTO;
import com.cost.costserver.metadata.service.MetadataService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.ServletOutputStream;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.apache.poi.common.usermodel.HyperlinkType;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.ss.usermodel.CreationHelper;
import org.apache.poi.ss.usermodel.Font;
import org.apache.poi.ss.usermodel.IndexedColors;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.springframework.stereotype.Service;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class ExcelExportService {

    private static final String DEFAULT_MASTER_GRID_KEY = "masterGrid";
    private static final String DEFAULT_MASTER_SHEET = "master";
    private static final String DEFAULT_DETAIL_PREFIX = "detail_";

    private final MetadataService metadataService;
    private final PermissionService permissionService;
    private final DynamicDataService dynamicDataService;
    private final ExportConfigService exportConfigService;
    private final ObjectMapper objectMapper;

    public void exportPage(String pageCode, ExportExcelRequest request, HttpServletResponse response) {
        if (StrUtil.isBlank(pageCode)) {
            throw new BusinessException(400, "pageCode is required");
        }

        ExportMode mode = resolveMode(request);
        boolean applyUserConfig = request == null || request.getUseUserConfig() == null || request.getUseUserConfig();
        String requestedGridKey = request != null ? request.getMasterGridKey() : null;

        Long userId = SecurityUtils.getCurrentUserId();
        if (userId == null) {
            throw new BusinessException(403, "unauthorized");
        }
        PagePermission permission = permissionService.getPagePermission(userId, pageCode);
        if (permission == null) {
            throw new BusinessException(403, "no permission");
        }

        List<PageComponentDTO> components = metadataService.getPageComponents(pageCode);
        List<PageComponentDTO> flatComponents = flattenComponents(components);

        PageComponentDTO masterGrid = resolveMasterGrid(flatComponents, requestedGridKey);
        if (masterGrid == null || StrUtil.isBlank(masterGrid.refTableCode())) {
            throw new BusinessException(400, "master grid not found");
        }

        String masterGridKey = masterGrid.componentKey();
        String masterTableCode = masterGrid.refTableCode();
        TableMetadataDTO masterMeta = metadataService.getTableMetadataWithPermission(
            masterTableCode, pageCode, masterGridKey, permission, userId, applyUserConfig
        );

        List<Long> masterIds = normalizeIds(request != null ? request.getMasterIds() : null);
        List<Map<String, Object>> masterRows = loadMasterRows(mode, masterMeta, pageCode, masterIds);

        String pkField = resolvePkField(masterMeta);
        List<ColumnMetadataDTO> masterColumns = resolveMasterColumns(masterMeta, pkField);
        Map<String, ExportConfigService.HeaderOverride> masterHeaderOverrides =
            exportConfigService.getHeaderOverrides(pageCode, masterGridKey);
        masterColumns = applyHeaderOverrides(masterColumns, masterHeaderOverrides);
        List<Integer> masterHiddenColumns = resolveHiddenColumns(masterColumns);

        List<Long> resolvedMasterIds = extractIds(masterRows, pkField);
        List<String> detailSheetNames = buildDetailSheetNames(resolvedMasterIds);

        PageComponentDTO tabsComponent = resolveTabsComponent(flatComponents);
        List<TabConfig> tabConfigs = parseTabs(tabsComponent);

        List<TabExport> tabExports = buildTabExports(
            tabConfigs, pageCode, permission, userId, applyUserConfig, resolvedMasterIds
        );

        int masterLinkColumnIndex = resolveLinkColumnIndex(masterColumns, pkField);
        Map<String, List<Integer>> sheetWidths = new HashMap<>();
        sheetWidths.put(DEFAULT_MASTER_SHEET, buildColumnWidths(masterColumns));
        List<Integer> detailWidths = buildDetailColumnWidths(tabExports);

        for (String sheetName : detailSheetNames) {
            sheetWidths.put(sheetName, detailWidths);
        }

        String fileName = pageCode + "_" + mode.name().toLowerCase(Locale.ROOT) + ".xlsx";
        writeResponseHeaders(response, fileName);

        Map<String, List<Integer>> sheetHiddenColumns = new HashMap<>();
        if (!masterHiddenColumns.isEmpty()) {
            sheetHiddenColumns.put(DEFAULT_MASTER_SHEET, masterHiddenColumns);
        }

        ExportWorkbookHandler workbookHandler = new ExportWorkbookHandler(
            DEFAULT_MASTER_SHEET,
            masterLinkColumnIndex,
            detailSheetNames,
            sheetWidths,
            sheetHiddenColumns
        );

        try (ServletOutputStream outputStream = response.getOutputStream();
             ExcelWriter writer = EasyExcel.write(outputStream)
                 .registerWriteHandler(workbookHandler)
                 .build()) {

            writeMasterSheet(writer, masterColumns, masterRows);

            if (!tabExports.isEmpty() && !resolvedMasterIds.isEmpty()) {
                writeDetailSheets(writer, resolvedMasterIds, detailSheetNames, tabExports);
            }

            writer.finish();
        } catch (Exception e) {
            throw new BusinessException(500, "export failed: " + e.getMessage());
        }
    }

    private void writeMasterSheet(
        ExcelWriter writer,
        List<ColumnMetadataDTO> columns,
        List<Map<String, Object>> rows
    ) {
        List<List<String>> head = buildHead(columns);
        List<List<Object>> data = buildDataRows(rows, columns);
        WriteSheet sheet = EasyExcel.writerSheet(0, DEFAULT_MASTER_SHEET).head(head).build();
        writer.write(data, sheet);
    }

    private void writeDetailSheets(
        ExcelWriter writer,
        List<Long> masterIds,
        List<String> detailSheetNames,
        List<TabExport> tabExports
    ) {
        int maxCols = resolveMaxColumns(tabExports);
        int sheetNo = 1;
        for (int i = 0; i < masterIds.size(); i++) {
            Long masterId = masterIds.get(i);
            String sheetName = detailSheetNames.get(i);
            WriteSheet sheet = EasyExcel.writerSheet(sheetNo++, sheetName).build();
            writeDetailSheet(writer, sheet, masterId, tabExports, maxCols);
        }
    }

    private void writeDetailSheet(
        ExcelWriter writer,
        WriteSheet sheet,
        Long masterId,
        List<TabExport> tabExports,
        int maxCols
    ) {
        int tableNo = 0;
        writer.write(Collections.singletonList(paddedRow("Back to master", maxCols)),
            sheet, EasyExcel.writerTable(tableNo++).needHead(false).build());
        writer.write(Collections.singletonList(emptyRow(maxCols)),
            sheet, EasyExcel.writerTable(tableNo++).needHead(false).build());

        for (TabExport tabExport : tabExports) {
            String title = tabExport.config.title();
            writer.write(Collections.singletonList(paddedRow(title, maxCols)),
                sheet, EasyExcel.writerTable(tableNo++).needHead(false).build());

            if (tabExport.columns.isEmpty()) {
                writer.write(Collections.singletonList(emptyRow(maxCols)),
                    sheet, EasyExcel.writerTable(tableNo++).needHead(false).build());
                writer.write(Collections.singletonList(emptyRow(maxCols)),
                    sheet, EasyExcel.writerTable(tableNo++).needHead(false).build());
                continue;
            }

            List<List<String>> head = buildHead(tabExport.columns);
            List<Map<String, Object>> detailRows = tabExport.rowsByMaster.getOrDefault(masterId, Collections.emptyList());
            List<List<Object>> data = buildDataRows(detailRows, tabExport.columns);
            WriteTable table = EasyExcel.writerTable(tableNo++).head(head).needHead(true).build();
            writer.write(data, sheet, table);

            writer.write(Collections.singletonList(emptyRow(maxCols)),
                sheet, EasyExcel.writerTable(tableNo++).needHead(false).build());
        }
    }

    private List<Map<String, Object>> loadMasterRows(
        ExportMode mode,
        TableMetadataDTO meta,
        String pageCode,
        List<Long> masterIds
    ) {
        QueryParam param = new QueryParam();
        param.setPageCode(pageCode);

        String pkField = resolvePkField(meta);
        if (mode != ExportMode.ALL) {
            if (masterIds.isEmpty()) {
                throw new BusinessException(400, "masterIds is required");
            }
            param.setConditions(List.of(new QueryParam.QueryCondition(pkField, "in", masterIds, null)));
        }

        List<Map<String, Object>> rows = dynamicDataService.queryAllWithConditions(meta.tableCode(), param);
        if (mode != ExportMode.ALL) {
            return reorderByIds(rows, pkField, masterIds);
        }
        return rows;
    }

    private List<TabExport> buildTabExports(
        List<TabConfig> tabConfigs,
        String pageCode,
        PagePermission permission,
        Long userId,
        boolean applyUserConfig,
        List<Long> masterIds
    ) {
        if (tabConfigs.isEmpty()) {
            return Collections.emptyList();
        }

        List<TabExport> exports = new ArrayList<>();
        for (TabConfig config : tabConfigs) {
            TableMetadataDTO detailMeta = metadataService.getTableMetadataWithPermission(
                config.tableCode(), pageCode, config.key(), permission, userId, applyUserConfig
            );

            List<ColumnMetadataDTO> columns = resolveVisibleColumns(detailMeta);
            Map<String, ExportConfigService.HeaderOverride> headerOverrides =
                exportConfigService.getHeaderOverrides(pageCode, config.key());
            columns = applyHeaderOverrides(columns, headerOverrides);
            columns = filterExportVisible(columns);
            String fkField = resolveMasterLinkField(detailMeta);
            Map<Long, List<Map<String, Object>>> rowsByMaster = queryDetailRows(detailMeta, pageCode, fkField, masterIds);

            exports.add(new TabExport(config, columns, rowsByMaster));
        }
        return exports;
    }

    private Map<Long, List<Map<String, Object>>> queryDetailRows(
        TableMetadataDTO detailMeta,
        String pageCode,
        String fkField,
        List<Long> masterIds
    ) {
        if (masterIds.isEmpty()) {
            return Collections.emptyMap();
        }

        QueryParam param = new QueryParam();
        param.setPageCode(pageCode);
        param.setConditions(List.of(new QueryParam.QueryCondition(fkField, "in", masterIds, null)));

        List<Map<String, Object>> rows = dynamicDataService.queryAllWithConditions(detailMeta.tableCode(), param);
        Map<Long, List<Map<String, Object>>> grouped = new HashMap<>();
        for (Map<String, Object> row : rows) {
            Long masterId = toLong(row.get(fkField));
            if (masterId == null) continue;
            grouped.computeIfAbsent(masterId, key -> new ArrayList<>()).add(row);
        }
        return grouped;
    }

    private List<PageComponentDTO> flattenComponents(List<PageComponentDTO> roots) {
        List<PageComponentDTO> result = new ArrayList<>();
        if (roots == null) {
            return result;
        }
        for (PageComponentDTO root : roots) {
            result.add(root);
            if (root.children() != null && !root.children().isEmpty()) {
                result.addAll(flattenComponents(root.children()));
            }
        }
        return result;
    }

    private PageComponentDTO resolveMasterGrid(List<PageComponentDTO> components, String requestedKey) {
        if (components == null || components.isEmpty()) {
            return null;
        }
        String key = StrUtil.isBlank(requestedKey) ? DEFAULT_MASTER_GRID_KEY : requestedKey;
        for (PageComponentDTO component : components) {
            if ("GRID".equalsIgnoreCase(component.componentType())
                && key.equals(component.componentKey())) {
                return component;
            }
        }
        for (PageComponentDTO component : components) {
            if ("GRID".equalsIgnoreCase(component.componentType())) {
                return component;
            }
        }
        return null;
    }

    private PageComponentDTO resolveTabsComponent(List<PageComponentDTO> components) {
        if (components == null) {
            return null;
        }
        for (PageComponentDTO component : components) {
            if ("detailTabs".equals(component.componentKey())) {
                return component;
            }
        }
        for (PageComponentDTO component : components) {
            if ("TABS".equalsIgnoreCase(component.componentType())) {
                return component;
            }
        }
        return null;
    }

    private List<TabConfig> parseTabs(PageComponentDTO component) {
        if (component == null || StrUtil.isBlank(component.componentConfig())) {
            return Collections.emptyList();
        }
        try {
            JsonNode root = objectMapper.readTree(component.componentConfig());
            JsonNode tabs = root.get("tabs");
            if (tabs == null || !tabs.isArray()) {
                return Collections.emptyList();
            }
            List<TabConfig> result = new ArrayList<>();
            for (JsonNode tab : tabs) {
                String key = text(tab, "key");
                String title = text(tab, "title");
                String tableCode = text(tab, "tableCode");
                if (StrUtil.isBlank(tableCode)) {
                    continue;
                }
                if (StrUtil.isBlank(title)) {
                    title = key;
                }
                result.add(new TabConfig(key, title, tableCode));
            }
            return result;
        } catch (Exception e) {
            return Collections.emptyList();
        }
    }

    private String text(JsonNode node, String key) {
        JsonNode value = node.get(key);
        return value != null && value.isTextual() ? value.asText() : null;
    }

    private List<ColumnMetadataDTO> resolveVisibleColumns(TableMetadataDTO meta) {
        return sortColumns(meta.columns());
    }

    private List<ColumnMetadataDTO> resolveMasterColumns(TableMetadataDTO meta, String pkField) {
        return sortColumns(meta.columns());
    }

    private List<ColumnMetadataDTO> applyHeaderOverrides(
        List<ColumnMetadataDTO> columns,
        Map<String, ExportConfigService.HeaderOverride> overrides
    ) {
        List<ColumnMetadataDTO> result = new ArrayList<>();
        for (ColumnMetadataDTO column : columns) {
            ExportConfigService.HeaderOverride override = overrides != null ? overrides.get(column.fieldName()) : null;
            String header = column.headerText();
            if (override != null && StrUtil.isNotBlank(override.header())) {
                header = override.header();
            }
            Boolean visible = override != null ? normalizeVisible(override.visible()) : Boolean.TRUE;
            result.add(copyColumn(column, header, visible));
        }
        return result;
    }

    private List<List<String>> buildHead(List<ColumnMetadataDTO> columns) {
        List<List<String>> head = new ArrayList<>();
        for (ColumnMetadataDTO column : columns) {
            String header = column.headerText();
            if (StrUtil.isBlank(header)) {
                header = column.fieldName();
            }
            head.add(Collections.singletonList(header));
        }
        return head;
    }

    private List<List<Object>> buildDataRows(List<Map<String, Object>> rows, List<ColumnMetadataDTO> columns) {
        List<List<Object>> data = new ArrayList<>();
        if (rows == null) {
            return data;
        }
        for (Map<String, Object> row : rows) {
            List<Object> line = new ArrayList<>(columns.size());
            for (ColumnMetadataDTO column : columns) {
                line.add(row.get(column.fieldName()));
            }
            data.add(line);
        }
        return data;
    }

    private List<Integer> buildColumnWidths(List<ColumnMetadataDTO> columns) {
        List<Integer> widths = new ArrayList<>(columns.size());
        for (ColumnMetadataDTO column : columns) {
            widths.add(column.width());
        }
        return widths;
    }

    private List<Integer> buildDetailColumnWidths(List<TabExport> tabExports) {
        int maxCols = resolveMaxColumns(tabExports);
        if (maxCols == 0) {
            return Collections.emptyList();
        }
        List<Integer> widths = new ArrayList<>(Collections.nCopies(maxCols, null));
        for (TabExport tabExport : tabExports) {
            for (int i = 0; i < tabExport.columns.size(); i++) {
                Integer width = tabExport.columns.get(i).width();
                if (width == null) continue;
                Integer current = widths.get(i);
                if (current == null || width > current) {
                    widths.set(i, width);
                }
            }
        }
        return widths;
    }

    private int resolveMaxColumns(List<TabExport> tabExports) {
        int max = 0;
        for (TabExport tabExport : tabExports) {
            max = Math.max(max, tabExport.columns.size());
        }
        return Math.max(max, 1);
    }

    private List<Long> normalizeIds(List<Long> ids) {
        if (ids == null) {
            return Collections.emptyList();
        }
        return ids.stream().filter(Objects::nonNull).distinct().toList();
    }

    private List<Long> extractIds(List<Map<String, Object>> rows, String pkField) {
        List<Long> ids = new ArrayList<>();
        for (Map<String, Object> row : rows) {
            Long id = toLong(row.get(pkField));
            if (id != null) {
                ids.add(id);
            }
        }
        return ids;
    }

    private List<Map<String, Object>> reorderByIds(List<Map<String, Object>> rows, String pkField, List<Long> ids) {
        Map<Long, Map<String, Object>> mapped = new HashMap<>();
        for (Map<String, Object> row : rows) {
            Long id = toLong(row.get(pkField));
            if (id != null) {
                mapped.put(id, row);
            }
        }
        List<Map<String, Object>> result = new ArrayList<>();
        for (Long id : ids) {
            Map<String, Object> row = mapped.get(id);
            if (row != null) {
                result.add(row);
            }
        }
        return result;
    }

    private Long toLong(Object value) {
        if (value == null) return null;
        if (value instanceof Number number) {
            return number.longValue();
        }
        try {
            return Long.parseLong(value.toString());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private String resolvePkField(TableMetadataDTO meta) {
        String pkColumn = meta.pkColumn();
        if (StrUtil.isNotBlank(pkColumn)) {
            for (ColumnMetadataDTO column : meta.columns()) {
                if (pkColumn.equalsIgnoreCase(column.columnName())) {
                    return column.fieldName();
                }
            }
        }
        for (ColumnMetadataDTO column : meta.columns()) {
            if ("id".equalsIgnoreCase(column.fieldName())) {
                return column.fieldName();
            }
        }
        return meta.columns().isEmpty() ? "id" : meta.columns().get(0).fieldName();
    }

    private String resolveMasterLinkField(TableMetadataDTO detailMeta) {
        for (ColumnMetadataDTO column : detailMeta.columns()) {
            if ("masterId".equalsIgnoreCase(column.fieldName())) {
                return column.fieldName();
            }
        }
        String parentFk = detailMeta.parentFkColumn();
        if (StrUtil.isNotBlank(parentFk)) {
            for (ColumnMetadataDTO column : detailMeta.columns()) {
                if (parentFk.equalsIgnoreCase(column.columnName())) {
                    return column.fieldName();
                }
            }
        }
        return "masterId";
    }

    private int resolveLinkColumnIndex(List<ColumnMetadataDTO> columns, String pkField) {
        int pkIndex = -1;
        int firstVisible = -1;
        for (int i = 0; i < columns.size(); i++) {
            ColumnMetadataDTO column = columns.get(i);
            if (pkField.equals(column.fieldName())) {
                pkIndex = i;
            }
            if (firstVisible < 0 && (column.visible() == null || Boolean.TRUE.equals(column.visible()))) {
                firstVisible = i;
            }
        }
        if (pkIndex >= 0 && (columns.get(pkIndex).visible() == null || Boolean.TRUE.equals(columns.get(pkIndex).visible()))) {
            return pkIndex;
        }
        if (firstVisible >= 0) {
            return firstVisible;
        }
        return pkIndex >= 0 ? pkIndex : 0;
    }

    private List<String> buildDetailSheetNames(List<Long> masterIds) {
        Set<String> used = new HashSet<>();
        List<String> names = new ArrayList<>();
        for (Long id : masterIds) {
            String base = DEFAULT_DETAIL_PREFIX + id;
            String name = base.length() > 31 ? base.substring(0, 31) : base;
            if (!used.add(name)) {
                int index = 1;
                while (true) {
                    String suffix = "_" + index++;
                    String candidate = name;
                    if (candidate.length() + suffix.length() > 31) {
                        candidate = candidate.substring(0, 31 - suffix.length());
                    }
                    candidate = candidate + suffix;
                    if (used.add(candidate)) {
                        name = candidate;
                        break;
                    }
                }
            }
            names.add(name);
        }
        return names;
    }

    private List<Object> paddedRow(String value, int size) {
        List<Object> row = new ArrayList<>(Collections.nCopies(size, null));
        row.set(0, value);
        return row;
    }

    private List<Object> emptyRow(int size) {
        return new ArrayList<>(Collections.nCopies(size, null));
    }

    private List<ColumnMetadataDTO> sortColumns(List<ColumnMetadataDTO> columns) {
        if (columns == null || columns.isEmpty()) {
            return Collections.emptyList();
        }
        return columns.stream()
            .sorted(Comparator.comparingInt(col -> col.displayOrder() == null ? Integer.MAX_VALUE : col.displayOrder()))
            .toList();
    }

    private List<Integer> resolveHiddenColumns(List<ColumnMetadataDTO> columns) {
        List<Integer> hidden = new ArrayList<>();
        for (int i = 0; i < columns.size(); i++) {
            Boolean visible = columns.get(i).visible();
            if (visible != null && !visible) {
                hidden.add(i);
            }
        }
        return hidden;
    }

    private List<ColumnMetadataDTO> filterExportVisible(List<ColumnMetadataDTO> columns) {
        if (columns == null || columns.isEmpty()) {
            return Collections.emptyList();
        }
        return columns.stream()
            .filter(col -> col.visible() == null || Boolean.TRUE.equals(col.visible()))
            .toList();
    }

    private Boolean normalizeVisible(Boolean value) {
        return value == null ? Boolean.TRUE : value;
    }

    private ColumnMetadataDTO copyColumn(ColumnMetadataDTO column, String headerText, Boolean visible) {
        return new ColumnMetadataDTO(
            column.id(),
            column.fieldName(),
            column.columnName(),
            column.queryColumn(),
            column.targetColumn(),
            headerText,
            column.dataType(),
            column.displayOrder(),
            column.width(),
            visible,
            column.editable(),
            column.required(),
            column.searchable(),
            column.sortable(),
            column.pinned(),
            column.dictType(),
            column.lookupConfigId(),
            column.defaultValue(),
            column.rulesConfig(),
            column.isVirtual()
        );
    }

    private void writeResponseHeaders(HttpServletResponse response, String fileName) {
        response.setContentType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        String encoded = URLEncoder.encode(fileName, StandardCharsets.UTF_8);
        response.setHeader("Content-Disposition", "attachment; filename*=UTF-8''" + encoded);
        response.setHeader("Access-Control-Expose-Headers", "Content-Disposition");
    }

    private ExportMode resolveMode(ExportExcelRequest request) {
        if (request == null || StrUtil.isBlank(request.getMode())) {
            return ExportMode.ALL;
        }
        String mode = request.getMode().trim().toLowerCase(Locale.ROOT);
        return switch (mode) {
            case "selected" -> ExportMode.SELECTED;
            case "current" -> ExportMode.CURRENT;
            default -> ExportMode.ALL;
        };
    }

    private enum ExportMode {
        SELECTED,
        CURRENT,
        ALL
    }

    private record TabConfig(String key, String title, String tableCode) {}

    private record TabExport(
        TabConfig config,
        List<ColumnMetadataDTO> columns,
        Map<Long, List<Map<String, Object>>> rowsByMaster
    ) {}

    private static final class ExportWorkbookHandler implements WorkbookWriteHandler {
        private final String masterSheetName;
        private final int masterLinkColumnIndex;
        private final List<String> detailSheetNames;
        private final Map<String, List<Integer>> sheetWidths;
        private final Map<String, List<Integer>> sheetHiddenColumns;

        private ExportWorkbookHandler(
            String masterSheetName,
            int masterLinkColumnIndex,
            List<String> detailSheetNames,
            Map<String, List<Integer>> sheetWidths,
            Map<String, List<Integer>> sheetHiddenColumns
        ) {
            this.masterSheetName = masterSheetName;
            this.masterLinkColumnIndex = masterLinkColumnIndex;
            this.detailSheetNames = detailSheetNames;
            this.sheetWidths = sheetWidths;
            this.sheetHiddenColumns = sheetHiddenColumns;
        }

        @Override
        public void afterWorkbookDispose(com.alibaba.excel.write.metadata.holder.WriteWorkbookHolder writeWorkbookHolder) {
            Workbook workbook = writeWorkbookHolder.getWorkbook();
            if (workbook == null) return;

            applyColumnWidths(workbook);
            applyHiddenColumns(workbook);
            applyMasterLinks(workbook);
            applyDetailLinks(workbook);
        }

        private void applyColumnWidths(Workbook workbook) {
            for (Map.Entry<String, List<Integer>> entry : sheetWidths.entrySet()) {
                Sheet sheet = workbook.getSheet(entry.getKey());
                if (sheet == null) continue;
                List<Integer> widths = entry.getValue();
                for (int i = 0; i < widths.size(); i++) {
                    Integer width = widths.get(i);
                    if (width == null || width <= 0) continue;
                    sheet.setColumnWidth(i, pixelToWidth(width));
                }
            }
        }

        private void applyHiddenColumns(Workbook workbook) {
            for (Map.Entry<String, List<Integer>> entry : sheetHiddenColumns.entrySet()) {
                Sheet sheet = workbook.getSheet(entry.getKey());
                if (sheet == null) continue;
                for (Integer index : entry.getValue()) {
                    if (index == null || index < 0) continue;
                    sheet.setColumnHidden(index, true);
                }
            }
        }

        private void applyMasterLinks(Workbook workbook) {
            Sheet masterSheet = workbook.getSheet(masterSheetName);
            if (masterSheet == null) return;
            CreationHelper helper = workbook.getCreationHelper();

            for (int i = 0; i < detailSheetNames.size(); i++) {
                String detailSheetName = detailSheetNames.get(i);
                int rowIndex = i + 1;
                Row row = masterSheet.getRow(rowIndex);
                if (row == null) continue;
                Cell cell = row.getCell(masterLinkColumnIndex);
                if (cell == null) continue;
                org.apache.poi.ss.usermodel.Hyperlink link = helper.createHyperlink(HyperlinkType.DOCUMENT);
                link.setAddress("'" + detailSheetName + "'!A1");
                cell.setHyperlink(link);
            }
        }

        private void applyDetailLinks(Workbook workbook) {
            CreationHelper helper = workbook.getCreationHelper();
            CellStyle linkStyle = createLinkStyle(workbook);
            for (int i = 0; i < detailSheetNames.size(); i++) {
                String detailSheetName = detailSheetNames.get(i);
                Sheet sheet = workbook.getSheet(detailSheetName);
                if (sheet == null) continue;
                Row row = sheet.getRow(0);
                if (row == null) row = sheet.createRow(0);
                Cell cell = row.getCell(0);
                if (cell == null) cell = row.createCell(0);
                cell.setCellValue("Back to master");
                org.apache.poi.ss.usermodel.Hyperlink link = helper.createHyperlink(HyperlinkType.DOCUMENT);
                int excelRow = i + 2;
                link.setAddress("'" + masterSheetName + "'!" + columnIndexToName(masterLinkColumnIndex) + excelRow);
                cell.setHyperlink(link);
                if (linkStyle != null) {
                    cell.setCellStyle(linkStyle);
                }
            }
        }

        private int pixelToWidth(int pixel) {
            int width = (int) Math.round(pixel * 256.0 / 7.0);
            int max = 255 * 256;
            if (width > max) return max;
            if (width < 0) return 0;
            return width;
        }

        private CellStyle createLinkStyle(Workbook workbook) {
            if (workbook == null) {
                return null;
            }
            CellStyle style = workbook.createCellStyle();
            Font font = workbook.createFont();
            font.setUnderline(Font.U_SINGLE);
            font.setColor(IndexedColors.BLUE.getIndex());
            style.setFont(font);
            return style;
        }

        private String columnIndexToName(int index) {
            int value = index + 1;
            StringBuilder sb = new StringBuilder();
            while (value > 0) {
                int mod = (value - 1) % 26;
                sb.insert(0, (char) ('A' + mod));
                value = (value - 1) / 26;
            }
            return sb.toString();
        }
    }
}
