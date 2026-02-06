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
}
