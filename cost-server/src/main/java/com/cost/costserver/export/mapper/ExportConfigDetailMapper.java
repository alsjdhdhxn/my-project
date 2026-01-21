package com.cost.costserver.export.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.cost.costserver.export.entity.ExportConfigDetail;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface ExportConfigDetailMapper extends BaseMapper<ExportConfigDetail> {

    @Select("SELECT * FROM T_COST_EXPORT_CONFIG_DETAIL WHERE EXPORT_CONFIG_ID = #{configId} ORDER BY DISPLAY_ORDER")
    List<ExportConfigDetail> findByConfigId(Long configId);
}
