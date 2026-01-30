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

    /**
     * 根据角色ID查询用户角色关联VO
     * 注意：视图已更新，无需 DELETED 条件
     */
    @Select("""
        SELECT ID, USER_ID, USERNAME, REAL_NAME, ROLE_ID
        FROM V_COST_USER_ROLE
        WHERE ROLE_ID = #{roleId}
        ORDER BY ID DESC
        """)
    List<UserRoleVO> selectByRoleId(@Param("roleId") Long roleId);
}
