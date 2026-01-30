package com.cost.costserver.auth.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.cost.costserver.auth.entity.Role;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface RoleMapper extends BaseMapper<Role> {

    /**
     * 根据用户ID查询角色列表
     * 注意：T_COST_ROLE 和 T_COST_USER_ROLE 均无逻辑删除
     */
    @Select("""
        SELECT r.* FROM T_COST_ROLE r
        JOIN T_COST_USER_ROLE ur ON r.ID = ur.ROLE_ID
        WHERE ur.USER_ID = #{userId}
        """)
    List<Role> selectByUserId(@Param("userId") Long userId);
}
