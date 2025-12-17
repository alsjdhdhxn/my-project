package com.cost.costserver.metadata.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.cost.costserver.metadata.entity.TableMetadata;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface TableMetadataMapper extends BaseMapper<TableMetadata> {
}
