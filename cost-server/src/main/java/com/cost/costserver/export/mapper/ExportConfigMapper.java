package com.cost.costserver.export.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.cost.costserver.export.entity.ExportConfig;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface ExportConfigMapper extends BaseMapper<ExportConfig> {

    @Select("SELECT * FROM T_COST_EXPORT_CONFIG WHERE PAGE_CODE = #{pageCode} AND DELETED = 0 ORDER BY DISPLAY_ORDER")
    List<ExportConfig> findByPageCode(String pageCode);

    @Select("SELECT * FROM T_COST_EXPORT_CONFIG WHERE EXPORT_CODE = #{exportCode} AND DELETED = 0")
    ExportConfig findByCode(String exportCode);
}
