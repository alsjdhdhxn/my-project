package com.cost.costserver.metadata.dto;

import cn.hutool.json.JSONArray;
import cn.hutool.json.JSONUtil;
import com.cost.costserver.metadata.entity.LookupConfig;

import java.util.Collections;
import java.util.List;

public record LookupConfigDTO(
    String lookupCode,
    String lookupName,
    String dataSource,
    List<DisplayColumn> displayColumns,
    List<String> searchColumns,
    String valueField,
    String labelField
) {
    public record DisplayColumn(String field, String header, Integer width) {}

    public static LookupConfigDTO from(LookupConfig entity) {
        List<DisplayColumn> columns = Collections.emptyList();
        if (entity.getDisplayColumns() != null) {
            try {
                JSONArray arr = JSONUtil.parseArray(entity.getDisplayColumns());
                columns = arr.stream()
                    .map(obj -> {
                        var json = (cn.hutool.json.JSONObject) obj;
                        return new DisplayColumn(
                            json.getStr("field"),
                            json.getStr("header"),
                            json.getInt("width")
                        );
                    })
                    .toList();
            } catch (Exception ignored) {}
        }

        List<String> searchCols = Collections.emptyList();
        if (entity.getSearchColumns() != null) {
            try {
                searchCols = JSONUtil.parseArray(entity.getSearchColumns()).toList(String.class);
            } catch (Exception ignored) {}
        }

        return new LookupConfigDTO(
            entity.getLookupCode(),
            entity.getLookupName(),
            entity.getDataSource(),
            columns,
            searchCols,
            entity.getValueField(),
            entity.getLabelField()
        );
    }
}
