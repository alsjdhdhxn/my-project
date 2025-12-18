package com.cost.costserver.auth.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.cost.costserver.auth.entity.Role;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface RoleMapper extends BaseMapper<Role> {

    @Select("""
        SELECT r.* FROM T_COST_ROLE r
        JOIN T_COST_USER_ROLE ur ON r.ID = ur.ROLE_ID
        WHERE ur.USER_ID = #{userId} AND r.DELETED = 0 AND ur.DELETED = 0
        """)
    List<Role> selectByUserId(@Param("userId") Long userId);
}
