package com.cost.costserver.metadata.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.metadata.entity.ColumnMetadata;
import com.cost.costserver.metadata.entity.TableMetadata;
import com.cost.costserver.metadata.mapper.ColumnMetadataMapper;
import com.cost.costserver.metadata.mapper.TableMetadataMapper;
import com.cost.costserver.metadata.vo.TableMetadataVO;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
@RequiredArgsConstructor
public class MetadataService {

    private final TableMetadataMapper tableMetadataMapper;
    private final ColumnMetadataMapper columnMetadataMapper;

    private final Map<String, TableMetadataVO> cache = new ConcurrentHashMap<>();

    public TableMetadataVO getTableMetadata(String tableCode) {
        TableMetadataVO cached = cache.get(tableCode);
        if (cached != null) {
            return cached;
        }

        TableMetadata table = tableMetadataMapper.selectOne(
            new LambdaQueryWrapper<TableMetadata>()
                .eq(TableMetadata::getTableCode, tableCode)
        );
        if (table == null) {
            throw new BusinessException(400, "表元数据不存在: " + tableCode);
        }

        List<ColumnMetadata> columns = columnMetadataMapper.selectList(
            new LambdaQueryWrapper<ColumnMetadata>()
                .eq(ColumnMetadata::getTableMetadataId, table.getId())
                .orderByAsc(ColumnMetadata::getDisplayOrder)
        );

        TableMetadataVO vo = TableMetadataVO.from(table, columns);
        cache.put(tableCode, vo);
        return vo;
    }

    public void clearCache(String tableCode) {
        if (tableCode == null) {
            cache.clear();
        } else {
            cache.remove(tableCode);
        }
    }

    public boolean isValidTable(String tableCode) {
        return cache.containsKey(tableCode) || tableMetadataMapper.selectCount(
            new LambdaQueryWrapper<TableMetadata>()
                .eq(TableMetadata::getTableCode, tableCode)
        ) > 0;
    }
}
