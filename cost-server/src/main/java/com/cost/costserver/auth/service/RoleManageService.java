package com.cost.costserver.auth.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.cost.costserver.auth.dto.*;
import com.cost.costserver.auth.entity.*;
import com.cost.costserver.auth.mapper.*;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.common.SecurityUtils;
import com.cost.costserver.dynamic.mapper.DynamicMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.BeanUtils;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

/**
 * 权限管理服务（硬编码页面专用）
 */
@Service
@RequiredArgsConstructor
public class RoleManageService {

    private final RoleMapper roleMapper;
    private final UserRoleMapper userRoleMapper;
    private final RolePageMapper rolePageMapper;
    private final UserMapper userMapper;
    private final ResourceMapper resourceMapper;
    private final DynamicMapper dynamicMapper;

    // ==================== 角色管理 ====================

    public List<RoleVO> listRoles() {
        List<Role> roles = roleMapper.selectList(
            new LambdaQueryWrapper<Role>()
                .orderByAsc(Role::getId)
        );
        return roles.stream().map(this::toRoleVO).collect(Collectors.toList());
    }

    @Transactional
    public RoleVO createRole(RoleVO vo) {
        // 检查角色编码是否重复
        Long count = roleMapper.selectCount(
            new LambdaQueryWrapper<Role>()
                .eq(Role::getRoleCode, vo.getRoleCode())
        );
        if (count > 0) {
            throw new BusinessException("角色编码已存在");
        }

        Role role = new Role();
        BeanUtils.copyProperties(vo, role);
        role.setId(getNextId("SEQ_COST_ROLE"));
        role.setDeleted(0);
        role.setCreateBy(SecurityUtils.getCurrentUsername());
        role.setCreateTime(LocalDateTime.now());
        roleMapper.insert(role);
        
        return toRoleVO(role);
    }

    @Transactional
    public RoleVO updateRole(RoleVO vo) {
        Role role = roleMapper.selectById(vo.getId());
        if (role == null) {
            throw new BusinessException("角色不存在");
        }

        // 检查角色编码是否重复（排除自己）
        Long count = roleMapper.selectCount(
            new LambdaQueryWrapper<Role>()
                .eq(Role::getRoleCode, vo.getRoleCode())
                .ne(Role::getId, vo.getId())
        );
        if (count > 0) {
            throw new BusinessException("角色编码已存在");
        }

        role.setRoleCode(vo.getRoleCode());
        role.setRoleName(vo.getRoleName());
        role.setDescription(vo.getDescription());
        role.setUpdateBy(SecurityUtils.getCurrentUsername());
        role.setUpdateTime(LocalDateTime.now());
        roleMapper.updateById(role);
        
        return toRoleVO(role);
    }

    @Transactional
    public void deleteRole(Long id) {
        Role role = roleMapper.selectById(id);
        if (role == null) {
            throw new BusinessException("角色不存在");
        }
        // 使用 MyBatis-Plus 逻辑删除
        roleMapper.deleteById(id);
    }

    // ==================== 角色人员管理 ====================

    public List<UserRoleVO> listUsersByRole(Long roleId) {
        return userRoleMapper.selectByRoleId(roleId);
    }

    @Transactional
    public UserRoleVO addUserToRole(UserRoleVO vo) {
        // 检查是否已存在
        Long count = userRoleMapper.selectCount(
            new LambdaQueryWrapper<UserRole>()
                .eq(UserRole::getRoleId, vo.getRoleId())
                .eq(UserRole::getUserId, vo.getUserId())
        );
        if (count > 0) {
            throw new BusinessException("该用户已在此角色中");
        }

        UserRole userRole = new UserRole();
        userRole.setId(getNextId("SEQ_COST_USER_ROLE"));
        userRole.setRoleId(vo.getRoleId());
        userRole.setUserId(vo.getUserId());
        userRole.setDeleted(0);
        userRole.setCreateBy(SecurityUtils.getCurrentUsername());
        userRole.setCreateTime(LocalDateTime.now());
        userRoleMapper.insert(userRole);

        // 查询返回完整信息
        List<UserRoleVO> list = userRoleMapper.selectByRoleId(vo.getRoleId());
        return list.stream()
            .filter(ur -> ur.getId().equals(userRole.getId()))
            .findFirst()
            .orElse(vo);
    }

    @Transactional
    public void removeUserFromRole(Long id) {
        UserRole userRole = userRoleMapper.selectById(id);
        if (userRole == null) {
            throw new BusinessException("记录不存在");
        }
        userRoleMapper.deleteById(id);
    }

    // ==================== 角色页面管理 ====================

    public List<RolePageVO> listPagesByRole(Long roleId) {
        return rolePageMapper.selectVOByRoleId(roleId);
    }

    @Transactional
    public RolePageVO addPageToRole(RolePageVO vo) {
        // 检查是否已存在
        Long count = rolePageMapper.selectCount(
            new LambdaQueryWrapper<RolePage>()
                .eq(RolePage::getRoleId, vo.getRoleId())
                .eq(RolePage::getPageCode, vo.getPageCode())
        );
        if (count > 0) {
            throw new BusinessException("该页面已授权给此角色");
        }

        RolePage rolePage = new RolePage();
        rolePage.setId(getNextId("SEQ_COST_ROLE_PAGE"));
        rolePage.setRoleId(vo.getRoleId());
        rolePage.setPageCode(vo.getPageCode());
        rolePage.setButtonPolicy(vo.getButtonPolicy());
        rolePage.setColumnPolicy(vo.getColumnPolicy());
        rolePage.setDeleted(0);
        rolePage.setCreateBy(SecurityUtils.getCurrentUsername());
        rolePage.setCreateTime(LocalDateTime.now());
        rolePageMapper.insert(rolePage);

        // 查询返回完整信息
        List<RolePageVO> list = rolePageMapper.selectVOByRoleId(vo.getRoleId());
        return list.stream()
            .filter(rp -> rp.getId().equals(rolePage.getId()))
            .findFirst()
            .orElse(vo);
    }

    @Transactional
    public RolePageVO updateRolePage(RolePageVO vo) {
        RolePage rolePage = rolePageMapper.selectById(vo.getId());
        if (rolePage == null) {
            throw new BusinessException("记录不存在");
        }

        rolePage.setButtonPolicy(vo.getButtonPolicy());
        rolePage.setColumnPolicy(vo.getColumnPolicy());
        rolePage.setUpdateBy(SecurityUtils.getCurrentUsername());
        rolePage.setUpdateTime(LocalDateTime.now());
        rolePageMapper.updateById(rolePage);

        // 查询返回完整信息
        List<RolePageVO> list = rolePageMapper.selectVOByRoleId(rolePage.getRoleId());
        return list.stream()
            .filter(rp -> rp.getId().equals(vo.getId()))
            .findFirst()
            .orElse(vo);
    }

    @Transactional
    public void removePageFromRole(Long id) {
        RolePage rolePage = rolePageMapper.selectById(id);
        if (rolePage == null) {
            throw new BusinessException("记录不存在");
        }
        rolePageMapper.deleteById(id);
    }

    // ==================== 辅助查询 ====================

    public List<UserSimpleVO> listAllUsers() {
        List<User> users = userMapper.selectList(
            new LambdaQueryWrapper<User>()
                .orderByAsc(User::getId)
        );
        return users.stream().map(u -> {
            UserSimpleVO vo = new UserSimpleVO();
            vo.setId(u.getId());
            vo.setUsername(u.getUsername());
            vo.setRealName(u.getRealName());
            return vo;
        }).collect(Collectors.toList());
    }

    public List<PageSimpleVO> listAllPages() {
        List<Resource> resources = resourceMapper.selectList(
            new LambdaQueryWrapper<Resource>()
                .isNotNull(Resource::getPageCode)
                .orderByAsc(Resource::getSortOrder)
        );
        return resources.stream().map(r -> {
            PageSimpleVO vo = new PageSimpleVO();
            vo.setPageCode(r.getPageCode());
            vo.setPageName(r.getResourceName());
            return vo;
        }).collect(Collectors.toList());
    }

    public List<PageButtonVO> listPageButtons(String pageCode) {
        // 从页面组件表查询BUTTON类型的组件
        List<Map<String, Object>> buttons = dynamicMapper.selectList(
            "SELECT COMPONENT_KEY, COMPONENT_CONFIG FROM T_COST_PAGE_COMPONENT " +
            "WHERE PAGE_CODE = '" + pageCode.replace("'", "''") + "' " +
            "AND COMPONENT_TYPE = 'BUTTON' AND DELETED = 0 " +
            "ORDER BY SORT_ORDER"
        );
        
        List<PageButtonVO> result = new ArrayList<>();
        for (Map<String, Object> btn : buttons) {
            PageButtonVO vo = new PageButtonVO();
            String key = (String) btn.get("COMPONENT_KEY");
            vo.setButtonKey(key);
            
            // 尝试从componentConfig解析label
            String config = (String) btn.get("COMPONENT_CONFIG");
            String label = key;
            if (config != null && !config.isEmpty()) {
                try {
                    // 简单解析JSON获取label
                    if (config.contains("\"label\"")) {
                        int start = config.indexOf("\"label\"") + 9;
                        int end = config.indexOf("\"", start);
                        if (end > start) {
                            label = config.substring(start, end);
                        }
                    }
                } catch (Exception e) {
                    // ignore
                }
            }
            vo.setButtonLabel(label);
            result.add(vo);
        }
        return result;
    }

    // ==================== 高级查询 ====================

    public List<RoleVO> searchRoles(List<SearchConditionDTO> conditions) {
        // 分离角色本身的条件和关联表的条件
        List<SearchConditionDTO> roleConditions = new ArrayList<>();
        List<SearchConditionDTO> userConditions = new ArrayList<>();
        List<SearchConditionDTO> pageConditions = new ArrayList<>();

        for (SearchConditionDTO cond : conditions) {
            switch (cond.getField()) {
                case "roleCode", "roleName" -> roleConditions.add(cond);
                case "username" -> userConditions.add(cond);
                case "pageCode" -> pageConditions.add(cond);
            }
        }

        // 构建角色查询
        LambdaQueryWrapper<Role> wrapper = new LambdaQueryWrapper<Role>().orderByAsc(Role::getId);
        
        // 主表条件
        for (SearchConditionDTO cond : roleConditions) {
            applyCondition(wrapper, cond);
        }

        // 从表条件：用户 EXISTS
        if (!userConditions.isEmpty()) {
            for (SearchConditionDTO cond : userConditions) {
                String existsSql = buildUserExistsSql(cond);
                wrapper.exists(existsSql);
            }
        }

        // 从表条件：页面 EXISTS
        if (!pageConditions.isEmpty()) {
            for (SearchConditionDTO cond : pageConditions) {
                String existsSql = buildPageExistsSql(cond);
                wrapper.exists(existsSql);
            }
        }

        List<Role> roles = roleMapper.selectList(wrapper);
        return roles.stream().map(this::toRoleVO).collect(Collectors.toList());
    }

    /**
     * 构建用户EXISTS子查询
     */
    private String buildUserExistsSql(SearchConditionDTO cond) {
        String valueCondition = buildValueCondition("u.USERNAME", cond.getOperator(), cond.getValue());
        String realNameCondition = buildValueCondition("u.REAL_NAME", cond.getOperator(), cond.getValue());
        
        return String.format(
            "SELECT 1 FROM T_COST_USER_ROLE ur " +
            "JOIN T_COST_USER u ON ur.USER_ID = u.ID AND u.DELETED = 0 " +
            "WHERE ur.ROLE_ID = T_COST_ROLE.ID AND ur.DELETED = 0 " +
            "AND (%s OR %s)",
            valueCondition, realNameCondition
        );
    }

    /**
     * 构建页面EXISTS子查询
     */
    private String buildPageExistsSql(SearchConditionDTO cond) {
        String codeCondition = buildValueCondition("rp.PAGE_CODE", cond.getOperator(), cond.getValue());
        String nameCondition = buildValueCondition("res.RESOURCE_NAME", cond.getOperator(), cond.getValue());
        
        return String.format(
            "SELECT 1 FROM T_COST_ROLE_PAGE rp " +
            "LEFT JOIN T_COST_RESOURCE res ON rp.PAGE_CODE = res.PAGE_CODE AND res.DELETED = 0 " +
            "WHERE rp.ROLE_ID = T_COST_ROLE.ID AND rp.DELETED = 0 " +
            "AND (%s OR %s)",
            codeCondition, nameCondition
        );
    }

    /**
     * 构建值条件SQL片段
     */
    private String buildValueCondition(String column, String operator, String value) {
        // 防SQL注入：简单转义单引号
        String safeValue = value.replace("'", "''");
        
        return switch (operator) {
            case "eq" -> String.format("%s = '%s'", column, safeValue);
            case "ne" -> String.format("%s <> '%s'", column, safeValue);
            case "like" -> String.format("%s LIKE '%%%s%%'", column, safeValue);
            case "likeLeft" -> String.format("%s LIKE '%%%s'", column, safeValue);
            case "likeRight" -> String.format("%s LIKE '%s%%'", column, safeValue);
            case "gt" -> String.format("%s > '%s'", column, safeValue);
            case "ge" -> String.format("%s >= '%s'", column, safeValue);
            case "lt" -> String.format("%s < '%s'", column, safeValue);
            case "le" -> String.format("%s <= '%s'", column, safeValue);
            case "in" -> {
                String[] values = safeValue.split(",");
                String inList = Arrays.stream(values)
                    .map(v -> "'" + v.trim() + "'")
                    .collect(Collectors.joining(","));
                yield String.format("%s IN (%s)", column, inList);
            }
            default -> String.format("%s LIKE '%%%s%%'", column, safeValue);
        };
    }

    private void applyCondition(LambdaQueryWrapper<Role> wrapper, SearchConditionDTO cond) {
        String value = cond.getValue();
        switch (cond.getField()) {
            case "roleCode" -> applyStringCondition(wrapper, Role::getRoleCode, cond.getOperator(), value);
            case "roleName" -> applyStringCondition(wrapper, Role::getRoleName, cond.getOperator(), value);
        }
    }

    private <T> void applyStringCondition(LambdaQueryWrapper<T> wrapper, 
            com.baomidou.mybatisplus.core.toolkit.support.SFunction<T, String> column,
            String operator, String value) {
        switch (operator) {
            case "eq" -> wrapper.eq(column, value);
            case "ne" -> wrapper.ne(column, value);
            case "like" -> wrapper.like(column, value);
            case "likeLeft" -> wrapper.likeLeft(column, value);
            case "likeRight" -> wrapper.likeRight(column, value);
            case "in" -> wrapper.in(column, Arrays.asList(value.split(",")));
        }
    }

    // ==================== 工具方法 ====================

    private RoleVO toRoleVO(Role role) {
        RoleVO vo = new RoleVO();
        BeanUtils.copyProperties(role, vo);
        return vo;
    }

    private Long getNextId(String sequenceName) {
        return dynamicMapper.getNextSequenceValue(sequenceName);
    }
}
