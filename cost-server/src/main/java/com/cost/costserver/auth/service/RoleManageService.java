package com.cost.costserver.auth.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.cost.costserver.auth.dto.*;
import com.cost.costserver.auth.entity.*;
import com.cost.costserver.auth.mapper.*;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.dynamic.mapper.DynamicMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.BeanUtils;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

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
        roleMapper.updateById(role);
        
        return toRoleVO(role);
    }

    @Transactional
    public void deleteRole(Long id) {
        Role role = roleMapper.selectById(id);
        if (role == null) {
            throw new BusinessException("角色不存在");
        }
        // 物理删除角色及关联数据
        userRoleMapper.delete(new LambdaQueryWrapper<UserRole>().eq(UserRole::getRoleId, id));
        rolePageMapper.delete(new LambdaQueryWrapper<RolePage>().eq(RolePage::getRoleId, id));
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
        rolePage.setRowPolicy(vo.getRowPolicy());
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

        // 只更新非null的字段
        if (vo.getButtonPolicy() != null) {
            rolePage.setButtonPolicy(vo.getButtonPolicy());
        }
        if (vo.getColumnPolicy() != null) {
            rolePage.setColumnPolicy(vo.getColumnPolicy());
        }
        if (vo.getRowPolicy() != null) {
            rolePage.setRowPolicy(vo.getRowPolicy());
        }
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
        // 查询所有资源（包括目录和页面）
        List<Resource> resources = resourceMapper.selectList(
            new LambdaQueryWrapper<Resource>()
                .orderByAsc(Resource::getSortOrder)
        );
        
        // 转换为VO
        Map<Long, PageSimpleVO> voMap = new HashMap<>();
        List<PageSimpleVO> allVOs = new ArrayList<>();
        
        for (Resource r : resources) {
            PageSimpleVO vo = new PageSimpleVO();
            vo.setId(r.getId());
            vo.setPageCode(r.getPageCode());
            vo.setPageName(r.getResourceName());
            vo.setResourceType(r.getResourceType());
            vo.setParentId(r.getParentId());
            vo.setChildren(new ArrayList<>());
            voMap.put(r.getId(), vo);
            allVOs.add(vo);
        }
        
        // 构建树形结构
        List<PageSimpleVO> roots = new ArrayList<>();
        for (PageSimpleVO vo : allVOs) {
            if (vo.getParentId() == null || vo.getParentId() == 0) {
                roots.add(vo);
            } else {
                PageSimpleVO parent = voMap.get(vo.getParentId());
                if (parent != null) {
                    parent.getChildren().add(vo);
                } else {
                    roots.add(vo);
                }
            }
        }
        
        return roots;
    }

    /**
     * 获取角色的资源权限树（包含授权状态）
     */
    public List<ResourcePermissionVO> getResourcePermissionTree(Long roleId) {
        // 从视图查询
        String sql = "SELECT ID, PAGE_CODE, RESOURCE_NAME, RESOURCE_TYPE, IS_HARDCODED, ICON, ROUTE, " +
                     "PARENT_ID, SORT_ORDER, ROLE_PAGE_ID, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY, IS_AUTHORIZED " +
                     "FROM V_COST_RESOURCE_PERMISSION WHERE ROLE_ID = " + roleId + " ORDER BY SORT_ORDER";
        
        List<Map<String, Object>> rows = dynamicMapper.selectList(sql);
        
        // 转换为VO
        Map<Long, ResourcePermissionVO> voMap = new HashMap<>();
        List<ResourcePermissionVO> allVOs = new ArrayList<>();
        
        for (Map<String, Object> row : rows) {
            ResourcePermissionVO vo = new ResourcePermissionVO();
            vo.setId(getLong(row, "ID"));
            vo.setPageCode((String) row.get("PAGE_CODE"));
            vo.setResourceName((String) row.get("RESOURCE_NAME"));
            vo.setResourceType((String) row.get("RESOURCE_TYPE"));
            vo.setIsHardcoded(getInt(row, "IS_HARDCODED"));
            vo.setIcon((String) row.get("ICON"));
            vo.setRoute((String) row.get("ROUTE"));
            vo.setParentId(getLong(row, "PARENT_ID"));
            vo.setSortOrder(getInt(row, "SORT_ORDER"));
            vo.setRolePageId(getLong(row, "ROLE_PAGE_ID"));
            vo.setButtonPolicy((String) row.get("BUTTON_POLICY"));
            vo.setColumnPolicy((String) row.get("COLUMN_POLICY"));
            vo.setRowPolicy((String) row.get("ROW_POLICY"));
            vo.setIsAuthorized(getInt(row, "IS_AUTHORIZED"));
            vo.setChildren(new ArrayList<>());
            
            voMap.put(vo.getId(), vo);
            allVOs.add(vo);
        }
        
        // 构建树形结构
        List<ResourcePermissionVO> roots = new ArrayList<>();
        for (ResourcePermissionVO vo : allVOs) {
            if (vo.getParentId() == null || vo.getParentId() == 0) {
                roots.add(vo);
            } else {
                ResourcePermissionVO parent = voMap.get(vo.getParentId());
                if (parent != null) {
                    parent.getChildren().add(vo);
                } else {
                    roots.add(vo);
                }
            }
        }
        
        return roots;
    }
    
    private Long getLong(Map<String, Object> row, String key) {
        Object val = row.get(key);
        if (val == null) return null;
        if (val instanceof Number) return ((Number) val).longValue();
        return Long.parseLong(val.toString());
    }
    
    private Integer getInt(Map<String, Object> row, String key) {
        Object val = row.get(key);
        if (val == null) return null;
        if (val instanceof Number) return ((Number) val).intValue();
        return Integer.parseInt(val.toString());
    }

    public List<PageButtonVO> listPageButtons(String pageCode) {
        // 从页面规则表查询 BUTTON 类型的按钮配置
        List<Map<String, Object>> rules = dynamicMapper.selectList(
            "SELECT COMPONENT_KEY, RULES FROM T_COST_PAGE_RULE " +
            "WHERE PAGE_CODE = '" + pageCode.replace("'", "''") + "' " +
            "AND RULE_TYPE = 'BUTTON' AND DELETED = 0 " +
            "ORDER BY SORT_ORDER"
        );
        
        List<PageButtonVO> result = new ArrayList<>();
        for (Map<String, Object> rule : rules) {
            Object rulesObj = rule.get("RULES");
            String rulesJson = rulesObj != null ? rulesObj.toString() : null;
            if (rulesJson == null || rulesJson.isEmpty()) continue;
            
            try {
                cn.hutool.json.JSONObject json = cn.hutool.json.JSONUtil.parseObj(rulesJson);
                cn.hutool.json.JSONArray items = json.getJSONArray("items");
                if (items == null) continue;
                
                extractButtonsWithPosition(items, result);
            } catch (Exception e) {
                // ignore parse error
            }
        }
        return result;
    }
    
    /**
     * 从新格式 BUTTON 规则中提取按钮（根据 position 字段）
     */
    private void extractButtonsWithPosition(cn.hutool.json.JSONArray items, List<PageButtonVO> result) {
        for (int i = 0; i < items.size(); i++) {
            cn.hutool.json.JSONObject item = items.getJSONObject(i);
            String action = item.getStr("action");
            String type = item.getStr("type");
            String label = item.getStr("label");
            String position = item.getStr("position");
            
            // 跳过分隔符
            if ("separator".equals(type)) continue;
            
            // 处理子菜单（如"导出"下拉菜单）
            cn.hutool.json.JSONArray subItems = item.getJSONArray("items");
            if (subItems != null && !subItems.isEmpty()) {
                // 递归处理子菜单
                extractButtonsWithPosition(subItems, result);
                continue;
            }
            
            // 有 action 的才是按钮
            if (action == null) continue;
            
            // 根据 position 确定按钮类型，默认是 context
            String buttonType;
            if ("toolbar".equals(position)) {
                buttonType = "页面按钮";
            } else if ("both".equals(position)) {
                buttonType = "通用按钮";
            } else {
                buttonType = "菜单按钮";
            }
            
            PageButtonVO vo = new PageButtonVO();
            vo.setButtonKey(action);
            vo.setButtonLabel("[" + buttonType + "] " + (label != null ? label : action));
            result.add(vo);
        }
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
     * 注意：T_COST_USER_ROLE 无逻辑删除，T_COST_USER 仍有逻辑删除
     */
    private String buildUserExistsSql(SearchConditionDTO cond) {
        String valueCondition = buildValueCondition("u.USERNAME", cond.getOperator(), cond.getValue());
        String realNameCondition = buildValueCondition("u.REAL_NAME", cond.getOperator(), cond.getValue());
        
        return String.format(
            "SELECT 1 FROM T_COST_USER_ROLE ur " +
            "JOIN T_COST_USER u ON ur.USER_ID = u.ID AND u.DELETED = 0 " +
            "WHERE ur.ROLE_ID = T_COST_ROLE.ID " +
            "AND (%s OR %s)",
            valueCondition, realNameCondition
        );
    }

    /**
     * 构建页面EXISTS子查询
     * 注意：T_COST_ROLE_PAGE 和 T_COST_RESOURCE 均无逻辑删除
     */
    private String buildPageExistsSql(SearchConditionDTO cond) {
        String codeCondition = buildValueCondition("rp.PAGE_CODE", cond.getOperator(), cond.getValue());
        String nameCondition = buildValueCondition("res.RESOURCE_NAME", cond.getOperator(), cond.getValue());
        
        return String.format(
            "SELECT 1 FROM T_COST_ROLE_PAGE rp " +
            "LEFT JOIN T_COST_RESOURCE res ON rp.PAGE_CODE = res.PAGE_CODE " +
            "WHERE rp.ROLE_ID = T_COST_ROLE.ID " +
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
