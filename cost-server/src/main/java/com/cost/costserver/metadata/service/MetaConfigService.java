package com.cost.costserver.metadata.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.cost.costserver.auth.entity.Resource;
import com.cost.costserver.auth.mapper.ResourceMapper;
import com.cost.costserver.dynamic.mapper.DynamicMapper;
import com.cost.costserver.metadata.entity.*;
import com.cost.costserver.metadata.mapper.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class MetaConfigService {

    private final ResourceMapper resourceMapper;
    private final TableMetadataMapper tableMetadataMapper;
    private final ColumnMetadataMapper columnMetadataMapper;
    private final PageComponentMapper pageComponentMapper;
    private final PageRuleMapper pageRuleMapper;
    private final LookupConfigMapper lookupConfigMapper;
    private final DynamicMapper dynamicMapper;

    private Long nextId(String seq) {
        return dynamicMapper.getNextSequenceValue(seq);
    }

    // ==================== 目录管理 ====================

    public List<Resource> listResources() {
        return resourceMapper.selectList(
            new LambdaQueryWrapper<Resource>().orderByAsc(Resource::getSortOrder)
        );
    }

    @Transactional
    public Resource saveResource(Resource r) {
        if (r.getId() == null) {
            r.setId(nextId("SEQ_COST_RESOURCE"));
            resourceMapper.insert(r);
        } else {
            resourceMapper.updateById(r);
        }
        return r;
    }

    @Transactional
    public void deleteResource(Long id) {
        resourceMapper.deleteById(id);
    }

    // ==================== 表管理 ====================

    public List<TableMetadata> listTables() {
        return tableMetadataMapper.selectList(
            new LambdaQueryWrapper<TableMetadata>().orderByAsc(TableMetadata::getId)
        );
    }

    @Transactional
    public TableMetadata saveTable(TableMetadata t) {
        if (t.getId() == null) {
            t.setId(nextId("SEQ_COST_TABLE_METADATA"));
            tableMetadataMapper.insert(t);
        } else {
            tableMetadataMapper.updateById(t);
        }
        return t;
    }

    @Transactional
    public void deleteTable(Long id) {
        tableMetadataMapper.deleteById(id);
    }

    public List<ColumnMetadata> listColumns(Long tableMetadataId) {
        return columnMetadataMapper.selectList(
            new LambdaQueryWrapper<ColumnMetadata>()
                .eq(ColumnMetadata::getTableMetadataId, tableMetadataId)
                .orderByAsc(ColumnMetadata::getDisplayOrder)
        );
    }

    @Transactional
    public ColumnMetadata saveColumn(ColumnMetadata c) {
        if (c.getId() == null) {
            c.setId(nextId("SEQ_COST_COLUMN_METADATA"));
            columnMetadataMapper.insert(c);
        } else {
            columnMetadataMapper.updateById(c);
        }
        return c;
    }

    @Transactional
    public void deleteColumn(Long id) {
        columnMetadataMapper.deleteById(id);
    }

    // ==================== 页面管理 ====================

    public List<PageComponent> listComponents() {
        return pageComponentMapper.selectList(
            new LambdaQueryWrapper<PageComponent>().orderByAsc(PageComponent::getSortOrder)
        );
    }

    @Transactional
    public PageComponent saveComponent(PageComponent c) {
        if (c.getId() == null) {
            c.setId(nextId("SEQ_COST_PAGE_COMPONENT"));
            pageComponentMapper.insert(c);
        } else {
            pageComponentMapper.updateById(c);
        }
        return c;
    }

    @Transactional
    public void deleteComponent(Long id) {
        pageComponentMapper.deleteById(id);
    }

    public List<PageRule> listRules(String pageCode, String componentKey) {
        return pageRuleMapper.selectList(
            new LambdaQueryWrapper<PageRule>()
                .eq(PageRule::getPageCode, pageCode)
                .eq(PageRule::getComponentKey, componentKey)
                .orderByAsc(PageRule::getSortOrder)
        );
    }

    @Transactional
    public PageRule saveRule(PageRule r) {
        if (r.getId() == null) {
            r.setId(nextId("SEQ_COST_PAGE_RULE"));
            pageRuleMapper.insert(r);
        } else {
            pageRuleMapper.updateById(r);
        }
        return r;
    }

    @Transactional
    public void deleteRule(Long id) {
        pageRuleMapper.deleteById(id);
    }

    // ==================== Lookup管理 ====================

    public List<LookupConfig> listLookups() {
        return lookupConfigMapper.selectList(
            new LambdaQueryWrapper<LookupConfig>().orderByAsc(LookupConfig::getId)
        );
    }

    @Transactional
    public LookupConfig saveLookup(LookupConfig l) {
        if (l.getId() == null) {
            l.setId(nextId("SEQ_COST_LOOKUP_CONFIG"));
            lookupConfigMapper.insert(l);
        } else {
            lookupConfigMapper.updateById(l);
        }
        return l;
    }

    @Transactional
    public void deleteLookup(Long id) {
        lookupConfigMapper.deleteById(id);
    }

    // ==================== 视图列查询 ====================

    /**
     * 查询视图/表的物理列结构（从 DBA_TAB_COLUMNS）
     */
    public List<Map<String, Object>> listViewColumns(String owner, String viewName) {
        String safeOwner = owner.toUpperCase().replace("'", "''");
        String safeName = viewName.toUpperCase().replace("'", "''");
        String sql = "SELECT COLUMN_NAME, DATA_TYPE, DATA_LENGTH, DATA_PRECISION, DATA_SCALE, COLUMN_ID " +
                     "FROM DBA_TAB_COLUMNS WHERE OWNER = '" + safeOwner + "' AND TABLE_NAME = '" + safeName + "' " +
                     "ORDER BY COLUMN_ID";
        return dynamicMapper.selectList(sql);
    }

    /**
     * 根据 pageCode 查询关联的表元数据
     */
    public List<TableMetadata> listTablesByPageCode(String pageCode) {
        String safeCode = pageCode.replace("'", "''");
        // 1. 查出该 pageCode 下所有组件
        String compSql = "SELECT COMPONENT_TYPE, REF_TABLE_CODE, COMPONENT_CONFIG " +
                         "FROM T_COST_PAGE_COMPONENT WHERE PAGE_CODE = '" + safeCode + "' AND DELETED = 0";
        List<Map<String, Object>> comps = dynamicMapper.selectList(compSql);

        // 2. 提取所有关联的 tableCode
        java.util.Set<String> tableCodes = new java.util.LinkedHashSet<>();
        for (Map<String, Object> comp : comps) {
            String type = (String) comp.get("COMPONENT_TYPE");
            String refTableCode = (String) comp.get("REF_TABLE_CODE");
            // COMPONENT_CONFIG 可能是 CLOB 类型（Druid 返回 ClobProxyImpl）
            Object configObj = comp.get("COMPONENT_CONFIG");
            String config = null;
            if (configObj instanceof String s) {
                config = s;
            } else if (configObj instanceof java.sql.Clob clob) {
                try { config = clob.getSubString(1, (int) clob.length()); } catch (Exception ignored) {}
            }
            // GRID / DETAIL_GRID 的 refTableCode
            if (("GRID".equals(type) || "DETAIL_GRID".equals(type)) && refTableCode != null && !refTableCode.isEmpty()) {
                tableCodes.add(refTableCode);
            }
            // TABS 的 componentConfig -> tabs[].tableCode
            if ("TABS".equals(type) && config != null && !config.isEmpty()) {
                try {
                    cn.hutool.json.JSONObject json = cn.hutool.json.JSONUtil.parseObj(config);
                    cn.hutool.json.JSONArray tabs = json.getJSONArray("tabs");
                    if (tabs != null) {
                        for (int i = 0; i < tabs.size(); i++) {
                            String tc = tabs.getJSONObject(i).getStr("tableCode");
                            if (tc != null && !tc.isEmpty()) tableCodes.add(tc);
                        }
                    }
                } catch (Exception ignored) {}
            }
        }
        if (tableCodes.isEmpty()) return java.util.Collections.emptyList();

        // 3. 用 tableCode IN (...) 查表元数据
        String inClause = tableCodes.stream().map(c -> "'" + c.replace("'", "''") + "'")
                          .collect(java.util.stream.Collectors.joining(","));
        String sql = "SELECT * FROM T_COST_TABLE_METADATA WHERE DELETED = 0 AND TABLE_CODE IN (" + inClause + ") ORDER BY ID";
        List<Map<String, Object>> rows = dynamicMapper.selectList(sql);
        return rows.stream().map(this::mapToTableMetadata).collect(java.util.stream.Collectors.toList());
    }

    /**
     * 根据 pageCode 查询关联的 lookupCode 列表
     * 从 t_cost_page_rule 中 rule_type='LOOKUP' 的 rules JSON 提取
     */
    public List<String> listLookupCodesByPageCode(String pageCode) {
        String safeCode = pageCode.replace("'", "''");
        String sql = "SELECT RULES FROM T_COST_PAGE_RULE WHERE PAGE_CODE = '" + safeCode + "' AND RULE_TYPE = 'LOOKUP' AND DELETED = 0";
        List<Map<String, Object>> rows = dynamicMapper.selectList(sql);

        java.util.Set<String> codes = new java.util.LinkedHashSet<>();
        for (Map<String, Object> row : rows) {
            Object rulesObj = row.get("RULES");
            String rulesStr = null;
            if (rulesObj instanceof String s) {
                rulesStr = s;
            } else if (rulesObj instanceof java.sql.Clob clob) {
                try { rulesStr = clob.getSubString(1, (int) clob.length()); } catch (Exception ignored) {}
            }
            if (rulesStr == null || rulesStr.isBlank()) continue;
            try {
                cn.hutool.json.JSONArray arr = cn.hutool.json.JSONUtil.parseArray(rulesStr);
                for (int i = 0; i < arr.size(); i++) {
                    String lc = arr.getJSONObject(i).getStr("lookupCode");
                    if (lc != null && !lc.isEmpty()) codes.add(lc);
                }
            } catch (Exception ignored) {}
        }
        return new java.util.ArrayList<>(codes);
    }

    private TableMetadata mapToTableMetadata(Map<String, Object> row) {
        TableMetadata t = new TableMetadata();
        t.setId(row.get("ID") != null ? ((Number) row.get("ID")).longValue() : null);
        t.setTableCode((String) row.get("TABLE_CODE"));
        t.setTableName((String) row.get("TABLE_NAME"));
        t.setQueryView((String) row.get("QUERY_VIEW"));
        t.setTargetTable((String) row.get("TARGET_TABLE"));
        t.setSequenceName((String) row.get("SEQUENCE_NAME"));
        t.setPkColumn((String) row.get("PK_COLUMN"));
        t.setParentTableCode((String) row.get("PARENT_TABLE_CODE"));
        t.setParentFkColumn((String) row.get("PARENT_FK_COLUMN"));
        return t;
    }
}
