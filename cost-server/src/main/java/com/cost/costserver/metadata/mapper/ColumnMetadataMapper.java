package com.cost.costserver.metadata.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.cost.costserver.metadata.entity.ColumnMetadata;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface ColumnMetadataMapper extends BaseMapper<ColumnMetadata> {
}
