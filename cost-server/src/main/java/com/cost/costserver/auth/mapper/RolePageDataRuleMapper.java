package com.cost.costserver.auth.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.cost.costserver.auth.entity.RolePageDataRule;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface RolePageDataRuleMapper extends BaseMapper<RolePageDataRule> {

    @Select("""
        SELECT dr.* FROM T_COST_ROLE_PAGE_DATA_RULE dr
        JOIN T_COST_ROLE_PAGE rp ON dr.ROLE_PAGE_ID = rp.ID
        JOIN T_COST_USER_ROLE ur ON rp.ROLE_ID = ur.ROLE_ID
        WHERE ur.USER_ID = #{userId} AND dr.DELETED = 0 AND rp.DELETED = 0 AND ur.DELETED = 0
        """)
    List<RolePageDataRule> selectByUserId(@Param("userId") Long userId);
}
