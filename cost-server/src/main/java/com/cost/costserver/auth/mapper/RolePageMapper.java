package com.cost.costserver.auth.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.cost.costserver.auth.entity.RolePage;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface RolePageMapper extends BaseMapper<RolePage> {

    @Select("""
        SELECT rp.* FROM T_COST_ROLE_PAGE rp
        JOIN T_COST_USER_ROLE ur ON rp.ROLE_ID = ur.ROLE_ID
        WHERE ur.USER_ID = #{userId} AND rp.DELETED = 0 AND ur.DELETED = 0
        """)
    List<RolePage> selectByUserId(@Param("userId") Long userId);
}
