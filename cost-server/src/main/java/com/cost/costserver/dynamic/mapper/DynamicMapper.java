package com.cost.costserver.dynamic.mapper;

import org.apache.ibatis.annotations.*;
import java.util.List;
import java.util.Map;

@Mapper
public interface DynamicMapper {

    @Select("${sql}")
    List<Map<String, Object>> selectList(@Param("sql") String sql);

    @Select("${sql}")
    Long selectCount(@Param("sql") String sql);

    @Insert("${sql}")
    int insert(@Param("sql") String sql);

    @Update("${sql}")
    int update(@Param("sql") String sql);

    @Update("${sql}")
    int delete(@Param("sql") String sql);

    @Select("SELECT ${sequenceName}.NEXTVAL FROM DUAL")
    Long getNextSequenceValue(@Param("sequenceName") String sequenceName);
}
