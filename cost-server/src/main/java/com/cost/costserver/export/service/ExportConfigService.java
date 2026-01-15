package com.cost.costserver.export.service;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.dynamic.mapper.DynamicMapper;
import com.cost.costserver.export.dto.ExportHeaderConfigDTO;
import com.cost.costserver.export.dto.ExportHeaderItemRequest;
import com.cost.costserver.export.dto.ExportUserPrefDTO;
import com.cost.costserver.export.dto.SaveExportUserPrefRequest;
import com.cost.costserver.export.entity.ExportHeaderConfig;
import com.cost.costserver.export.entity.UserExportPref;
import com.cost.costserver.export.mapper.ExportHeaderConfigMapper;
import com.cost.costserver.export.mapper.UserExportPrefMapper;
import com.cost.costserver.metadata.dto.ColumnMetadataDTO;
import com.cost.costserver.metadata.dto.PageComponentDTO;
import com.cost.costserver.metadata.dto.TableMetadataDTO;
import com.cost.costserver.metadata.service.MetadataService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

@Service
@RequiredArgsConstructor
@Slf4j
public class ExportConfigService {

    private static final String DEFAULT_MASTER_GRID_KEY = "masterGrid";

    private final ExportHeaderConfigMapper exportHeaderConfigMapper;
    private final UserExportPrefMapper userExportPrefMapper;
    private final MetadataService metadataService;
    private final DynamicMapper dynamicMapper;
    private final ObjectMapper objectMapper;

    public List<ExportHeaderConfigDTO> getHeaderConfig(String pageCode, String gridKey) {
        if (StrUtil.isBlank(pageCode)) {
            throw new BusinessException(400, "pageCode is required");
        }
        String resolvedGridKey = normalizeGridKey(gridKey);
        String tableCode = resolveTableCode(pageCode, resolvedGridKey);
        if (StrUtil.isBlank(tableCode)) {
            throw new BusinessException(400, "grid not found");
        }

        TableMetadataDTO meta = metadataService.getTableMetadata(tableCode);
        Map<String, HeaderOverride> overrides = loadHeaderOverrides(pageCode, resolvedGridKey);

        List<ColumnMetadataDTO> columns = sortColumns(meta.columns());
        List<ExportHeaderConfigDTO> result = new ArrayList<>();
        for (ColumnMetadataDTO column : columns) {
            String defaultHeader = StrUtil.isNotBlank(column.headerText()) ? column.headerText() : column.fieldName();
            HeaderOverride override = overrides.get(column.fieldName());
            String customHeader = override != null ? override.header() : null;
            Boolean visible = override != null ? normalizeVisible(override.visible()) : Boolean.TRUE;
            result.add(new ExportHeaderConfigDTO(column.fieldName(), defaultHeader, customHeader, visible));
        }
        return result;
    }

    public void saveHeaderConfig(String pageCode, String gridKey, List<ExportHeaderItemRequest> headers) {
        if (StrUtil.isBlank(pageCode)) {
            throw new BusinessException(400, "pageCode is required");
        }
        String resolvedGridKey = normalizeGridKey(gridKey);
        if (headers == null) {
            throw new BusinessException(400, "headers is required");
        }

        Map<String, HeaderOverride> payload = new HashMap<>();
        for (ExportHeaderItemRequest item : headers) {
            if (item == null || StrUtil.isBlank(item.field())) continue;
            String header = item.header() != null ? item.header().trim() : null;
            Boolean visible = normalizeVisible(item.visible());
            if (StrUtil.isBlank(header)) {
                header = null;
            }
            payload.put(item.field(), new HeaderOverride(header, visible));
        }

        String json = toJson(payload);
        ExportHeaderConfig existing = exportHeaderConfigMapper.selectOne(
            new LambdaQueryWrapper<ExportHeaderConfig>()
                .eq(ExportHeaderConfig::getPageCode, pageCode)
                .eq(ExportHeaderConfig::getGridKey, resolvedGridKey)
                .eq(ExportHeaderConfig::getDeleted, 0)
        );

        LocalDateTime now = LocalDateTime.now();
        if (existing != null) {
            existing.setHeaderConfig(json);
            existing.setUpdateTime(now);
            exportHeaderConfigMapper.updateById(existing);
            return;
        }

        Long id = dynamicMapper.getNextSequenceValue("SEQ_COST_EXPORT_HEADER_CONFIG");
        ExportHeaderConfig config = new ExportHeaderConfig();
        config.setId(id);
        config.setPageCode(pageCode);
        config.setGridKey(resolvedGridKey);
        config.setHeaderConfig(json);
        config.setDeleted(0);
        config.setUpdateTime(now);
        exportHeaderConfigMapper.insert(config);
    }

    public Map<String, HeaderOverride> getHeaderOverrides(String pageCode, String gridKey) {
        if (StrUtil.isBlank(pageCode) || StrUtil.isBlank(gridKey)) {
            return Collections.emptyMap();
        }
        return loadHeaderOverrides(pageCode, gridKey);
    }

    public ExportUserPrefDTO getUserPref(Long userId, String pageCode) {
        if (userId == null || StrUtil.isBlank(pageCode)) {
            throw new BusinessException(400, "invalid request");
        }
        UserExportPref pref = userExportPrefMapper.selectOne(
            new LambdaQueryWrapper<UserExportPref>()
                .eq(UserExportPref::getUserId, userId)
                .eq(UserExportPref::getPageCode, pageCode)
                .eq(UserExportPref::getDeleted, 0)
        );
        if (pref == null || StrUtil.isBlank(pref.getPrefJson())) {
            return null;
        }
        return parseUserPref(pref.getPrefJson());
    }

    public void saveUserPref(Long userId, String pageCode, SaveExportUserPrefRequest request) {
        if (userId == null || StrUtil.isBlank(pageCode)) {
            throw new BusinessException(400, "invalid request");
        }
        if (request == null) {
            throw new BusinessException(400, "request is required");
        }

        boolean autoExport = Boolean.TRUE.equals(request.getAutoExport());
        boolean useUserConfig = request.getUseUserConfig() == null || request.getUseUserConfig();

        Map<String, Object> payload = new HashMap<>();
        payload.put("autoExport", autoExport);
        payload.put("useUserConfig", useUserConfig);
        String json = toJson(payload);

        UserExportPref existing = userExportPrefMapper.selectOne(
            new LambdaQueryWrapper<UserExportPref>()
                .eq(UserExportPref::getUserId, userId)
                .eq(UserExportPref::getPageCode, pageCode)
                .eq(UserExportPref::getDeleted, 0)
        );

        LocalDateTime now = LocalDateTime.now();
        if (existing != null) {
            existing.setPrefJson(json);
            existing.setUpdateTime(now);
            userExportPrefMapper.updateById(existing);
            return;
        }

        Long id = dynamicMapper.getNextSequenceValue("SEQ_COST_USER_EXPORT_PREF");
        UserExportPref pref = new UserExportPref();
        pref.setId(id);
        pref.setUserId(userId);
        pref.setPageCode(pageCode);
        pref.setPrefJson(json);
        pref.setDeleted(0);
        pref.setUpdateTime(now);
        userExportPrefMapper.insert(pref);
    }

    public void resetUserPref(Long userId, String pageCode) {
        if (userId == null || StrUtil.isBlank(pageCode)) {
            throw new BusinessException(400, "invalid request");
        }
        UserExportPref existing = userExportPrefMapper.selectOne(
            new LambdaQueryWrapper<UserExportPref>()
                .eq(UserExportPref::getUserId, userId)
                .eq(UserExportPref::getPageCode, pageCode)
                .eq(UserExportPref::getDeleted, 0)
        );
        if (existing == null) {
            return;
        }
        existing.setDeleted(1);
        existing.setUpdateTime(LocalDateTime.now());
        userExportPrefMapper.updateById(existing);
    }

    private Map<String, HeaderOverride> loadHeaderOverrides(String pageCode, String gridKey) {
        ExportHeaderConfig config = exportHeaderConfigMapper.selectOne(
            new LambdaQueryWrapper<ExportHeaderConfig>()
                .eq(ExportHeaderConfig::getPageCode, pageCode)
                .eq(ExportHeaderConfig::getGridKey, gridKey)
                .eq(ExportHeaderConfig::getDeleted, 0)
        );
        if (config == null || StrUtil.isBlank(config.getHeaderConfig())) {
            return Collections.emptyMap();
        }
        return parseHeaderConfig(config.getHeaderConfig());
    }

    private String resolveTableCode(String pageCode, String gridKey) {
        List<PageComponentDTO> components = metadataService.getPageComponents(pageCode);
        List<PageComponentDTO> flat = flattenComponents(components);

        for (PageComponentDTO component : flat) {
            if ("GRID".equalsIgnoreCase(component.componentType())
                && gridKey.equals(component.componentKey())) {
                return component.refTableCode();
            }
        }

        if (DEFAULT_MASTER_GRID_KEY.equals(gridKey)) {
            for (PageComponentDTO component : flat) {
                if ("GRID".equalsIgnoreCase(component.componentType())
                    && StrUtil.isNotBlank(component.refTableCode())) {
                    return component.refTableCode();
                }
            }
        }

        for (PageComponentDTO component : flat) {
            if ("TABS".equalsIgnoreCase(component.componentType())) {
                String tableCode = resolveTabTableCode(component, gridKey);
                if (StrUtil.isNotBlank(tableCode)) {
                    return tableCode;
                }
            }
        }
        return null;
    }

    private String resolveTabTableCode(PageComponentDTO component, String gridKey) {
        if (component == null || StrUtil.isBlank(component.componentConfig())) {
            return null;
        }
        try {
            JsonNode root = objectMapper.readTree(component.componentConfig());
            JsonNode tabs = root.get("tabs");
            if (tabs == null || !tabs.isArray()) {
                return null;
            }
            for (JsonNode tab : tabs) {
                String key = text(tab, "key");
                if (!gridKey.equals(key)) continue;
                String tableCode = text(tab, "tableCode");
                if (StrUtil.isNotBlank(tableCode)) {
                    return tableCode;
                }
                return component.refTableCode();
            }
        } catch (Exception e) {
            log.warn("parse tabs failed: {}", e.getMessage());
        }
        return null;
    }

    private List<PageComponentDTO> flattenComponents(List<PageComponentDTO> roots) {
        List<PageComponentDTO> result = new ArrayList<>();
        if (roots == null) return result;
        for (PageComponentDTO root : roots) {
            result.add(root);
            if (root.children() != null && !root.children().isEmpty()) {
                result.addAll(flattenComponents(root.children()));
            }
        }
        return result;
    }

    private List<ColumnMetadataDTO> sortColumns(List<ColumnMetadataDTO> columns) {
        if (columns == null || columns.isEmpty()) {
            return Collections.emptyList();
        }
        return columns.stream()
            .filter(Objects::nonNull)
            .sorted(Comparator.comparingInt(col -> col.displayOrder() == null ? Integer.MAX_VALUE : col.displayOrder()))
            .toList();
    }

    private Map<String, HeaderOverride> parseHeaderConfig(String raw) {
        try {
            JsonNode node = objectMapper.readTree(raw);
            if (node.isObject()) {
                Map<String, HeaderOverride> result = new HashMap<>();
                node.fields().forEachRemaining(entry -> {
                    JsonNode value = entry.getValue();
                    if (value == null || value.isNull()) return;
                    if (value.isTextual()) {
                        result.put(entry.getKey(), new HeaderOverride(value.asText(), null));
                        return;
                    }
                    if (value.isObject()) {
                        String header = text(value, "header");
                        Boolean visible = bool(value, "visible");
                        result.put(entry.getKey(), new HeaderOverride(header, visible));
                    }
                });
                return result;
            }
            if (node.isArray()) {
                Map<String, HeaderOverride> result = new HashMap<>();
                for (JsonNode item : node) {
                    String field = text(item, "field");
                    String header = text(item, "header");
                    Boolean visible = bool(item, "visible");
                    if (StrUtil.isNotBlank(field)) {
                        result.put(field, new HeaderOverride(header, visible));
                    }
                }
                return result;
            }
        } catch (Exception e) {
            log.warn("parse header config failed: {}", e.getMessage());
        }
        return Collections.emptyMap();
    }

    private ExportUserPrefDTO parseUserPref(String raw) {
        try {
            JsonNode node = objectMapper.readTree(raw);
            Boolean autoExport = bool(node, "autoExport");
            Boolean useUserConfig = bool(node, "useUserConfig");
            return new ExportUserPrefDTO(autoExport, useUserConfig);
        } catch (Exception e) {
            log.warn("parse export pref failed: {}", e.getMessage());
            return null;
        }
    }

    private Boolean bool(JsonNode node, String key) {
        if (node == null || node.isNull()) return null;
        JsonNode value = node.get(key);
        if (value == null || value.isNull()) return null;
        if (value.isBoolean()) return value.asBoolean();
        if (value.isTextual()) {
            return Boolean.parseBoolean(value.asText());
        }
        return null;
    }

    private Boolean normalizeVisible(Boolean value) {
        return value == null ? Boolean.TRUE : value;
    }

    private String text(JsonNode node, String key) {
        JsonNode value = node.get(key);
        return value != null && value.isTextual() ? value.asText() : null;
    }

    private String normalizeGridKey(String gridKey) {
        if (StrUtil.isBlank(gridKey)) return DEFAULT_MASTER_GRID_KEY;
        if ("master".equalsIgnoreCase(gridKey)) return DEFAULT_MASTER_GRID_KEY;
        return gridKey.trim();
    }

    private String toJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (Exception e) {
            throw new BusinessException(400, "config serialize failed");
        }
    }

    public record HeaderOverride(String header, Boolean visible) {}
}
