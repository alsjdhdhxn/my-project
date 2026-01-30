package com.cost.costserver.auth.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.cost.costserver.auth.dto.RolePageVO;
import com.cost.costserver.auth.entity.RolePage;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface RolePageMapper extends BaseMapper<RolePage> {

    /**
     * 根据用户ID查询角色页面权限
     * 注意：T_COST_USER_ROLE 和 T_COST_ROLE_PAGE 均无逻辑删除
     */
    @Select("""
        SELECT rp.* FROM T_COST_ROLE_PAGE rp
        JOIN T_COST_USER_ROLE ur ON rp.ROLE_ID = ur.ROLE_ID
        WHERE ur.USER_ID = #{userId}
        """)
    List<RolePage> selectByUserId(@Param("userId") Long userId);

    /**
     * 根据角色ID查询页面权限VO
     * 注意：视图已更新，无需 DELETED 条件
     */
    @Select("""
        SELECT ID, ROLE_ID, PAGE_CODE, PAGE_NAME, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY
        FROM V_COST_ROLE_PAGE
        WHERE ROLE_ID = #{roleId}
        ORDER BY ID DESC
        """)
    List<RolePageVO> selectVOByRoleId(@Param("roleId") Long roleId);
}
