package com.cost.costserver.auth.service;

import cn.hutool.core.util.StrUtil;
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
            
            // 行权限直接使用 SQL 条件字符串
            String rowFilter = parseRowFilter(rp.getRowPolicy());
            
            // 合并权限（多角色取并集）
            PagePermission existing = pagePermissions.get(pageCode);
            if (existing == null) {
                pagePermissions.put(pageCode, new PagePermission(pageCode, buttons, columns, rowFilter));
            } else {
                pagePermissions.put(pageCode, mergePagePermission(existing, buttons, columns, rowFilter));
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
            return new PagePermission(pageCode, Set.of("*"), Collections.emptyMap(), null);
        }
        
        List<RolePage> rolePages = rolePageMapper.selectByUserId(userId);
        
        boolean hasPage = false;
        Set<String> mergedButtons = new HashSet<>();
        Map<String, ColumnPermission> mergedColumns = new HashMap<>();
        StringBuilder mergedRowFilter = new StringBuilder();
        
        for (RolePage rp : rolePages) {
            if (!pageCode.equals(rp.getPageCode())) continue;
            hasPage = true;
            
            Set<String> buttons = parseButtons(rp.getButtonPolicy());
            mergedButtons.addAll(buttons);
            
            Map<String, ColumnPermission> columns = parseColumns(rp.getColumnPolicy());
            mergeColumns(mergedColumns, columns);
            
            String rowFilter = parseRowFilter(rp.getRowPolicy());
            if (StrUtil.isNotBlank(rowFilter)) {
                if (mergedRowFilter.length() > 0) {
                    mergedRowFilter.append(" OR ");
                }
                mergedRowFilter.append("(").append(rowFilter).append(")");
            }
        }
        
        if (!hasPage) {
            return null; // 无页面权限
        }
        
        String finalRowFilter = mergedRowFilter.length() > 0 ? mergedRowFilter.toString() : null;
        return new PagePermission(pageCode, mergedButtons, mergedColumns, finalRowFilter);
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
     * 新格式：
     * {"masterGrid": {"123": {"columnName":"GOODSNAME","visible": true, "editable": false}}, "material": {...}}
     * {"masterGrid": {"GOODSNAME": {"visible": true, "editable": false}}, "material": {...}}
     * {"GOODSNAME": {"visible": true, "editable": false}, ...}
     */
    private Map<String, ColumnPermission> parseColumns(String columnPolicy) {
        if (StrUtil.isBlank(columnPolicy)) {
            return Collections.emptyMap();
        }
        try {
            JSONObject json = JSONUtil.parseObj(columnPolicy);
            Map<String, ColumnPermission> result = new HashMap<>();
            
            for (String key : json.keySet()) {
                Object value = json.get(key);
                if (value instanceof JSONObject colOrTable) {
                    // 检查是否是新格式（按表格分组）
                    // 新格式的第一层 key 是表格名（如 masterGrid），第二层才是字段名
                    boolean isNewFormat = false;
                    for (String subKey : colOrTable.keySet()) {
                        Object subValue = colOrTable.get(subKey);
                        if (subValue instanceof JSONObject subObj) {
                            // 如果子对象包含 visible 或 editable，说明是旧格式
                            if (subObj.containsKey("visible") || subObj.containsKey("editable")) {
                                isNewFormat = true;
                                break;
                            }
                        }
                    }
                    
                    if (isNewFormat) {
                        // 新格式：key 是表格名，colOrTable 是列映射（列 id 或 columnName）
                        for (String columnKey : colOrTable.keySet()) {
                            JSONObject columnConfig = colOrTable.getJSONObject(columnKey);
                            if (columnConfig != null) {
                                boolean visible = columnConfig.getBool("visible", true);
                                boolean editable = columnConfig.getBool("editable", true);
                                Long columnId = parseColumnId(columnKey, columnConfig);
                                String columnName = columnConfig.getStr("columnName");
                                if (StrUtil.isBlank(columnName) && columnId == null) {
                                    columnName = columnKey;
                                }
                                putColumnPermission(result, key, columnId, columnName, new ColumnPermission(visible, editable));
                            }
                        }
                    } else {
                        // 简化格式：key 是列名，colOrTable 是权限配置
                        boolean visible = colOrTable.getBool("visible", true);
                        boolean editable = colOrTable.getBool("editable", true);
                        Long columnId = parseColumnId(key, colOrTable);
                        String columnName = colOrTable.getStr("columnName");
                        if (StrUtil.isBlank(columnName) && columnId == null) {
                            columnName = key;
                        }
                        putColumnPermission(result, null, columnId, columnName, new ColumnPermission(visible, editable));
                    }
                }
            }
            return result;
        } catch (Exception e) {
            log.warn("解析列权限失败: {}", columnPolicy, e);
            return Collections.emptyMap();
        }
    }

    private Long parseColumnId(String key, JSONObject config) {
        Long explicit = config != null ? config.getLong("columnId") : null;
        if (explicit != null) {
            return explicit;
        }
        if (StrUtil.isBlank(key) || !key.matches("\\d+")) {
            return null;
        }
        try {
            return Long.parseLong(key);
        } catch (NumberFormatException ignored) {
            return null;
        }
    }

    private void putColumnPermission(
            Map<String, ColumnPermission> target,
            String tableKey,
            Long columnId,
            String columnName,
            ColumnPermission permission) {
        if (target == null || permission == null) {
            return;
        }
        if (tableKey != null) {
            if (columnId != null) {
                target.put(tableKey + ":id:" + columnId, permission);
            }
            if (StrUtil.isNotBlank(columnName)) {
                target.put(tableKey + ":column:" + columnName, permission);
                target.put(tableKey + ":" + columnName, permission);
            }
        }
        if (columnId != null) {
            target.put("id:" + columnId, permission);
        }
        if (StrUtil.isNotBlank(columnName)) {
            target.put("column:" + columnName, permission);
            target.put(columnName, permission);
        }
    }

    /**
     * 解析行权限 SQL 条件
     * 支持两种格式：
     * 1. 可视化模式 JSON：{"mode":"visual","conditions":[...],"sql":"..."}
     * 2. 自定义 SQL 模式：直接是 SQL 字符串
     * 支持占位符：${userId}, ${username}
     */
    private String parseRowFilter(String rowPolicy) {
        if (StrUtil.isBlank(rowPolicy)) {
            return null;
        }
        
        String sql = rowPolicy;
        
        // 如果是 JSON 格式，提取 sql 字段
        if (rowPolicy.trim().startsWith("{")) {
            try {
                JSONObject json = JSONUtil.parseObj(rowPolicy);
                sql = json.getStr("sql");
                if (StrUtil.isBlank(sql)) {
                    return null;
                }
            } catch (Exception e) {
                log.warn("解析行权限JSON失败，尝试作为SQL处理: {}", rowPolicy);
                sql = rowPolicy;
            }
        }
        
        // 解析占位符
        Long userId = SecurityUtils.getCurrentUserId();
        String username = SecurityUtils.getCurrentUsername();
        
        if (userId != null) {
            sql = sql.replace("${userId}", userId.toString());
        }
        if (username != null) {
            sql = sql.replace("${username}", "'" + username.replace("'", "''") + "'");
        }
        
        return sql;
    }

    /**
     * 合并页面权限（多角色取并集）
     */
    private PagePermission mergePagePermission(PagePermission existing, Set<String> buttons, 
                                                Map<String, ColumnPermission> columns, String rowFilter) {
        // 按钮取并集
        Set<String> mergedButtons = new HashSet<>(existing.buttons());
        mergedButtons.addAll(buttons);
        
        // 列权限取并集（visible/editable 任一为 true 则为 true）
        Map<String, ColumnPermission> mergedColumns = new HashMap<>(existing.columns());
        mergeColumns(mergedColumns, columns);
        
        // 行权限用 OR 合并
        String mergedRowFilter = existing.rowFilter();
        if (StrUtil.isNotBlank(rowFilter)) {
            if (StrUtil.isNotBlank(mergedRowFilter)) {
                mergedRowFilter = "(" + mergedRowFilter + ") OR (" + rowFilter + ")";
            } else {
                mergedRowFilter = rowFilter;
            }
        }
        
        return new PagePermission(existing.pageCode(), mergedButtons, mergedColumns, mergedRowFilter);
    }

    /**
     * 合并列权限（取并集，visible/editable 任一为 true 则为 true）
     */
    private void mergeColumns(Map<String, ColumnPermission> target, Map<String, ColumnPermission> source) {
        for (Map.Entry<String, ColumnPermission> entry : source.entrySet()) {
            String columnKey = entry.getKey();
            ColumnPermission newPerm = entry.getValue();
            ColumnPermission existingPerm = target.get(columnKey);
            
            if (existingPerm == null) {
                target.put(columnKey, newPerm);
            } else {
                // 取并集：任一为 true 则为 true
                target.put(columnKey, new ColumnPermission(
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
