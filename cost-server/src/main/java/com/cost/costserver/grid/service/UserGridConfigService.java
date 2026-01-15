package com.cost.costserver.grid.service;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.dynamic.mapper.DynamicMapper;
import com.cost.costserver.grid.dto.ColumnPreference;
import com.cost.costserver.grid.entity.UserGridConfig;
import com.cost.costserver.grid.mapper.UserGridConfigMapper;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
@Slf4j
public class UserGridConfigService {

    private final UserGridConfigMapper userGridConfigMapper;
    private final DynamicMapper dynamicMapper;
    private final ObjectMapper objectMapper;

    public Object getConfig(Long userId, String pageCode, String gridKey) {
        if (userId == null || StrUtil.isBlank(pageCode) || StrUtil.isBlank(gridKey)) {
            throw new BusinessException(400, "invalid request");
        }

        UserGridConfig config = userGridConfigMapper.selectOne(
            new LambdaQueryWrapper<UserGridConfig>()
                .eq(UserGridConfig::getUserId, userId)
                .eq(UserGridConfig::getPageCode, pageCode)
                .eq(UserGridConfig::getGridKey, gridKey)
                .eq(UserGridConfig::getDeleted, 0)
        );

        if (config == null || StrUtil.isBlank(config.getConfigData())) {
            return null;
        }

        try {
            return objectMapper.readTree(config.getConfigData());
        } catch (Exception e) {
            log.warn("grid config parse failed: {}", e.getMessage());
            return config.getConfigData();
        }
    }

    public Map<String, ColumnPreference> getColumnPreferences(Long userId, String pageCode, String gridKey) {
        if (userId == null || StrUtil.isBlank(pageCode) || StrUtil.isBlank(gridKey)) {
            return Collections.emptyMap();
        }

        UserGridConfig config = userGridConfigMapper.selectOne(
            new LambdaQueryWrapper<UserGridConfig>()
                .eq(UserGridConfig::getUserId, userId)
                .eq(UserGridConfig::getPageCode, pageCode)
                .eq(UserGridConfig::getGridKey, gridKey)
                .eq(UserGridConfig::getDeleted, 0)
        );

        if (config == null || StrUtil.isBlank(config.getConfigData())) {
            return Collections.emptyMap();
        }

        List<ColumnPreference> preferences = parseColumnPreferences(config.getConfigData());
        if (preferences.isEmpty()) {
            return Collections.emptyMap();
        }

        Map<String, ColumnPreference> result = new HashMap<>();
        for (ColumnPreference preference : preferences) {
            if (StrUtil.isBlank(preference.field())) continue;
            result.put(preference.field(), preference);
        }
        return result;
    }

    public void saveConfig(Long userId, String pageCode, String gridKey, Object configData) {
        if (userId == null || StrUtil.isBlank(pageCode) || StrUtil.isBlank(gridKey)) {
            throw new BusinessException(400, "invalid request");
        }
        if (configData == null) {
            throw new BusinessException(400, "configData is required");
        }

        String payload = normalizeConfigData(configData);

        UserGridConfig existing = userGridConfigMapper.selectOne(
            new LambdaQueryWrapper<UserGridConfig>()
                .eq(UserGridConfig::getUserId, userId)
                .eq(UserGridConfig::getPageCode, pageCode)
                .eq(UserGridConfig::getGridKey, gridKey)
                .eq(UserGridConfig::getDeleted, 0)
        );

        LocalDateTime now = LocalDateTime.now();
        if (existing != null) {
            existing.setConfigData(payload);
            existing.setUpdateTime(now);
            userGridConfigMapper.updateById(existing);
            return;
        }

        Long id = dynamicMapper.getNextSequenceValue("SEQ_COST_USER_GRID");
        UserGridConfig config = new UserGridConfig();
        config.setId(id);
        config.setUserId(userId);
        config.setPageCode(pageCode);
        config.setGridKey(gridKey);
        config.setConfigData(payload);
        config.setDeleted(0);
        config.setUpdateTime(now);
        userGridConfigMapper.insert(config);
    }

    private String normalizeConfigData(Object configData) {
        try {
            JsonNode node;
            if (configData instanceof String str) {
                node = objectMapper.readTree(str);
            } else {
                node = objectMapper.valueToTree(configData);
            }
            List<ColumnPreference> preferences = parseColumnPreferences(node);
            return objectMapper.writeValueAsString(preferences);
        } catch (Exception e) {
            throw new BusinessException(400, "configData serialize failed");
        }
    }

    private List<ColumnPreference> parseColumnPreferences(String raw) {
        try {
            JsonNode node = objectMapper.readTree(raw);
            return parseColumnPreferences(node);
        } catch (Exception e) {
            log.warn("grid config parse failed: {}", e.getMessage());
            return Collections.emptyList();
        }
    }

    private List<ColumnPreference> parseColumnPreferences(JsonNode node) {
        if (node == null || node.isNull()) {
            return Collections.emptyList();
        }
        if (node.isArray()) {
            return parsePreferenceArray(node);
        }
        if (node.isObject()) {
            JsonNode state = node.get("columnState");
            if (state != null && state.isArray()) {
                return parsePreferenceArray(state);
            }
            JsonNode columns = node.get("columns");
            if (columns != null && columns.isArray()) {
                return parsePreferenceArray(columns);
            }
        }
        return Collections.emptyList();
    }

    private List<ColumnPreference> parsePreferenceArray(JsonNode arrayNode) {
        List<ColumnPreference> preferences = new ArrayList<>();
        int index = 0;
        for (JsonNode node : arrayNode) {
            ColumnPreference preference = toPreference(node, index++);
            if (preference != null && StrUtil.isNotBlank(preference.field())) {
                preferences.add(preference);
            }
        }
        return preferences;
    }

    private ColumnPreference toPreference(JsonNode node, int index) {
        if (node == null || node.isNull()) return null;
        String field = text(node, "field");
        if (StrUtil.isBlank(field)) {
            field = text(node, "colId");
        }
        if (StrUtil.isBlank(field)) return null;

        Integer width = number(node, "width");
        Integer order = number(node, "order");
        if (order == null) order = index;

        Boolean hidden = bool(node, "hidden");
        if (hidden == null && node.has("hide")) {
            hidden = bool(node, "hide");
        }

        String pinned = text(node, "pinned");
        if (!("left".equalsIgnoreCase(pinned) || "right".equalsIgnoreCase(pinned))) {
            pinned = null;
        } else {
            pinned = pinned.toLowerCase();
        }

        return new ColumnPreference(field, width, order, hidden, pinned);
    }

    private String text(JsonNode node, String key) {
        JsonNode value = node.get(key);
        return value != null && value.isTextual() ? value.asText() : null;
    }

    private Integer number(JsonNode node, String key) {
        JsonNode value = node.get(key);
        return value != null && value.isNumber() ? value.intValue() : null;
    }

    private Boolean bool(JsonNode node, String key) {
        JsonNode value = node.get(key);
        return value != null && value.isBoolean() ? value.asBoolean() : null;
    }
}
