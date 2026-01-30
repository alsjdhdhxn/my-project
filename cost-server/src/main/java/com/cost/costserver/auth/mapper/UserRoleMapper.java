package com.cost.costserver.auth.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.cost.costserver.auth.dto.UserRoleVO;
import com.cost.costserver.auth.entity.UserRole;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface UserRoleMapper extends BaseMapper<UserRole> {

    @Select("""
        SELECT ID, USER_ID, USERNAME, REAL_NAME, ROLE_ID, CREATE_TIME, CREATE_BY
        FROM V_COST_USER_ROLE
        WHERE ROLE_ID = #{roleId}
        ORDER BY CREATE_TIME DESC
        """)
    List<UserRoleVO> selectByRoleId(@Param("roleId") Long roleId);
}
