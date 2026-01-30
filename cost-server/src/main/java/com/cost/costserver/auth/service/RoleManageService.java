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
import java.util.List;
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
                .eq(Role::getDeleted, 0)
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
                .eq(Role::getDeleted, 0)
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
        if (role == null || role.getDeleted() == 1) {
            throw new BusinessException("角色不存在");
        }

        // 检查角色编码是否重复（排除自己）
        Long count = roleMapper.selectCount(
            new LambdaQueryWrapper<Role>()
                .eq(Role::getRoleCode, vo.getRoleCode())
                .ne(Role::getId, vo.getId())
                .eq(Role::getDeleted, 0)
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
        role.setDeleted(1);
        role.setUpdateBy(SecurityUtils.getCurrentUsername());
        role.setUpdateTime(LocalDateTime.now());
        roleMapper.updateById(role);
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
                .eq(UserRole::getDeleted, 0)
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
        userRole.setDeleted(1);
        userRole.setUpdateBy(SecurityUtils.getCurrentUsername());
        userRole.setUpdateTime(LocalDateTime.now());
        userRoleMapper.updateById(userRole);
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
                .eq(RolePage::getDeleted, 0)
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
        if (rolePage == null || rolePage.getDeleted() == 1) {
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
        rolePage.setDeleted(1);
        rolePage.setUpdateBy(SecurityUtils.getCurrentUsername());
        rolePage.setUpdateTime(LocalDateTime.now());
        rolePageMapper.updateById(rolePage);
    }

    // ==================== 辅助查询 ====================

    public List<UserSimpleVO> listAllUsers() {
        List<User> users = userMapper.selectList(
            new LambdaQueryWrapper<User>()
                .eq(User::getDeleted, 0)
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
                .eq(Resource::getDeleted, 0)
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
