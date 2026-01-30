package com.cost.costserver.auth.service;

import cn.hutool.core.util.StrUtil;
import cn.hutool.json.JSONArray;
import cn.hutool.json.JSONObject;
import cn.hutool.json.JSONUtil;
import com.cost.costserver.auth.dto.*;
import com.cost.costserver.auth.entity.RolePage;
import com.cost.costserver.auth.mapper.RolePageMapper;
import com.cost.costserver.common.SecurityUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.*;

/**
 * 权限组装服务
 * 负责将分散的权限配置组装为完整的用户权限上下文
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class PermissionService {

    private final RolePageMapper rolePageMapper;
    
    private static final String SUPER_ADMIN_USERNAME = "admin";

    /**
     * 组装用户完整权限上下文
     */
    public UserPermissionContext buildUserPermissionContext(Long userId, String username, List<String> roles) {
        // 查询用户所有页面权限
        List<RolePage> rolePages = rolePageMapper.selectByUserId(userId);
        
        // 组装页面权限（多角色合并：取并集）
        Map<String, PagePermission> pagePermissions = new HashMap<>();
        Set<String> pageCodes = new HashSet<>();
        
        for (RolePage rp : rolePages) {
            String pageCode = rp.getPageCode();
            pageCodes.add(pageCode);
            
            // 解析按钮权限
            Set<String> buttons = parseButtons(rp.getButtonPolicy());
            
            // 解析列权限
            Map<String, ColumnPermission> columns = parseColumns(rp.getColumnPolicy());
            
            // 解析行权限规则（从 rowPolicy 字段）
            List<DataRule> rules = parseRowPolicy(rp.getRowPolicy());
            
            // 合并权限（多角色取并集）
            PagePermission existing = pagePermissions.get(pageCode);
            if (existing == null) {
                pagePermissions.put(pageCode, new PagePermission(pageCode, buttons, columns, rules));
            } else {
                pagePermissions.put(pageCode, mergePagePermission(existing, buttons, columns, rules));
            }
        }
        
        return new UserPermissionContext(userId, username, roles, pageCodes, pagePermissions);
    }

    /**
     * 获取指定页面的权限
     * 用户名为 admin 直接返回全权限
     */
    public PagePermission getPagePermission(Long userId, String pageCode) {
        // admin 用户直接放行，返回全权限
        if (isSuperAdmin()) {
            return new PagePermission(pageCode, Set.of("*"), Collections.emptyMap(), Collections.emptyList());
        }
        
        List<RolePage> rolePages = rolePageMapper.selectByUserId(userId);
        
        boolean hasPage = false;
        Set<String> mergedButtons = new HashSet<>();
        Map<String, ColumnPermission> mergedColumns = new HashMap<>();
        List<DataRule> mergedRules = new ArrayList<>();
        
        for (RolePage rp : rolePages) {
            if (!pageCode.equals(rp.getPageCode())) continue;
            hasPage = true;
            
            Set<String> buttons = parseButtons(rp.getButtonPolicy());
            mergedButtons.addAll(buttons);
            
            Map<String, ColumnPermission> columns = parseColumns(rp.getColumnPolicy());
            mergeColumns(mergedColumns, columns);
            
            List<DataRule> rules = parseRowPolicy(rp.getRowPolicy());
            mergedRules.addAll(rules);
        }
        
        if (!hasPage) {
            return null; // 无页面权限
        }
        
        return new PagePermission(pageCode, mergedButtons, mergedColumns, mergedRules);
    }

    /**
     * 解析按钮权限 JSON
     * 格式：["add", "edit", "delete"] 或 ["*"]
     */
    private Set<String> parseButtons(String buttonPolicy) {
        if (StrUtil.isBlank(buttonPolicy)) {
            return Collections.emptySet();
        }
        try {
            return new HashSet<>(JSONUtil.parseArray(buttonPolicy).toList(String.class));
        } catch (Exception e) {
            log.warn("解析按钮权限失败: {}", buttonPolicy, e);
            return Collections.emptySet();
        }
    }

    /**
     * 解析列权限 JSON
     * 格式：{"fieldName": {"visible": true, "editable": false}, ...}
     */
    private Map<String, ColumnPermission> parseColumns(String columnPolicy) {
        if (StrUtil.isBlank(columnPolicy)) {
            return Collections.emptyMap();
        }
        try {
            JSONObject json = JSONUtil.parseObj(columnPolicy);
            Map<String, ColumnPermission> result = new HashMap<>();
            for (String fieldName : json.keySet()) {
                JSONObject colConfig = json.getJSONObject(fieldName);
                boolean visible = colConfig.getBool("visible", true);
                boolean editable = colConfig.getBool("editable", true);
                result.put(fieldName, new ColumnPermission(visible, editable));
            }
            return result;
        } catch (Exception e) {
            log.warn("解析列权限失败: {}", columnPolicy, e);
            return Collections.emptyMap();
        }
    }

    /**
     * 解析行权限 JSON
     * 格式：[{"fieldName":"DEPT_ID","operator":"eq","value":"${userDeptId}","valueType":"placeholder"}, ...]
     */
    private List<DataRule> parseRowPolicy(String rowPolicy) {
        if (StrUtil.isBlank(rowPolicy)) {
            return Collections.emptyList();
        }
        try {
            JSONArray arr = JSONUtil.parseArray(rowPolicy);
            List<DataRule> rules = new ArrayList<>();
            for (int i = 0; i < arr.size(); i++) {
                JSONObject obj = arr.getJSONObject(i);
                DataRule rule = new DataRule(
                    obj.getStr("fieldName"),
                    obj.getStr("operator"),
                    obj.getStr("value"),
                    obj.getStr("valueType")
                );
                rules.add(rule);
            }
            return rules;
        } catch (Exception e) {
            log.warn("解析行权限失败: {}", rowPolicy, e);
            return Collections.emptyList();
        }
    }

    /**
     * 合并页面权限（多角色取并集）
     */
    private PagePermission mergePagePermission(PagePermission existing, Set<String> buttons, 
                                                Map<String, ColumnPermission> columns, List<DataRule> rules) {
        // 按钮取并集
        Set<String> mergedButtons = new HashSet<>(existing.buttons());
        mergedButtons.addAll(buttons);
        
        // 列权限取并集（visible/editable 任一为 true 则为 true）
        Map<String, ColumnPermission> mergedColumns = new HashMap<>(existing.columns());
        mergeColumns(mergedColumns, columns);
        
        // 数据规则取并集
        List<DataRule> mergedRules = new ArrayList<>(existing.dataRules());
        mergedRules.addAll(rules);
        
        return new PagePermission(existing.pageCode(), mergedButtons, mergedColumns, mergedRules);
    }

    /**
     * 合并列权限（取并集，visible/editable 任一为 true 则为 true）
     */
    private void mergeColumns(Map<String, ColumnPermission> target, Map<String, ColumnPermission> source) {
        for (Map.Entry<String, ColumnPermission> entry : source.entrySet()) {
            String fieldName = entry.getKey();
            ColumnPermission newPerm = entry.getValue();
            ColumnPermission existingPerm = target.get(fieldName);
            
            if (existingPerm == null) {
                target.put(fieldName, newPerm);
            } else {
                // 取并集：任一为 true 则为 true
                target.put(fieldName, new ColumnPermission(
                    existingPerm.visible() || newPerm.visible(),
                    existingPerm.editable() || newPerm.editable()
                ));
            }
        }
    }

    /**
     * 判断当前用户是否为超级管理员（用户名为 admin）
     */
    private boolean isSuperAdmin() {
        String username = SecurityUtils.getCurrentUsername();
        return SUPER_ADMIN_USERNAME.equalsIgnoreCase(username);
    }
}
