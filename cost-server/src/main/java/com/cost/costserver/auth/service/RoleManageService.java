package com.cost.costserver.auth.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.cost.costserver.auth.dto.*;
import com.cost.costserver.auth.entity.*;
import com.cost.costserver.auth.mapper.*;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.dynamic.mapper.DynamicMapper;
import com.cost.costserver.export.entity.ExportConfig;
import com.cost.costserver.export.mapper.ExportConfigMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.BeanUtils;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.stream.Collectors;

/**
 * 权限管理服务（硬编码页面专用）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RoleManageService {

    private final RoleMapper roleMapper;
    private final UserRoleMapper userRoleMapper;
    private final RolePageMapper rolePageMapper;
    private final UserMapper userMapper;
    private final ResourceMapper resourceMapper;
    private final DynamicMapper dynamicMapper;
    private final ExportConfigMapper exportConfigMapper;

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
            // 校验行权限格式
            validateRowPolicy(vo.getRowPolicy());
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
    
    /**
     * 校验行权限格式
     * 只允许两种格式：
     * 1. 可视化模式 JSON：必须包含 mode=visual 和 sql 字段
     * 2. 自定义 SQL 模式：纯 SQL 字符串（不以 { 开头）
     */
    private void validateRowPolicy(String rowPolicy) {
        if (rowPolicy == null || rowPolicy.trim().isEmpty()) {
            return; // 空值允许
        }
        
        String trimmed = rowPolicy.trim();
        
        if (trimmed.startsWith("{")) {
            // JSON 格式，必须是可视化模式
            try {
                cn.hutool.json.JSONObject json = cn.hutool.json.JSONUtil.parseObj(trimmed);
                String mode = json.getStr("mode");
                if (!"visual".equals(mode)) {
                    throw new BusinessException("行权限JSON格式错误：mode必须为visual");
                }
                String sql = json.getStr("sql");
                if (sql == null) {
                    throw new BusinessException("行权限JSON格式错误：缺少sql字段");
                }
                // 校验 SQL 不能包含危险条件
                validateSqlCondition(sql);
            } catch (cn.hutool.json.JSONException e) {
                throw new BusinessException("行权限JSON格式错误：" + e.getMessage());
            }
        } else {
            // 纯 SQL 字符串
            validateSqlCondition(trimmed);
        }
    }
    
    /**
     * 校验 SQL 条件，防止危险条件
     */
    private void validateSqlCondition(String sql) {
        if (sql == null || sql.trim().isEmpty()) {
            return;
        }
        String lower = sql.toLowerCase().replaceAll("\\s+", "");
        // 禁止永假条件
        if (lower.contains("1=2") || lower.contains("1=0") || lower.contains("0=1") || lower.contains("2=1")) {
            throw new BusinessException("行权限不允许使用永假条件（如1=2），如需禁止访问请取消页面授权");
        }
        // 禁止永真条件
        if (lower.contains("1=1") || lower.contains("0=0")) {
            throw new BusinessException("行权限不允许使用永真条件（如1=1），如需全部访问请清空行权限");
        }
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
            vo.setButtonPolicy(convertClobToString(row.get("BUTTON_POLICY")));
            vo.setColumnPolicy(convertClobToString(row.get("COLUMN_POLICY")));
            vo.setRowPolicy(convertClobToString(row.get("ROW_POLICY")));
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
        // 从页面组件表查询按钮配置（按钮现在存在 COMPONENT_CONFIG.buttons 中）
        List<Map<String, Object>> components = dynamicMapper.selectList(
            "SELECT c.COMPONENT_KEY, c.COMPONENT_TYPE, c.COMPONENT_CONFIG, c.REF_TABLE_CODE, m.TABLE_NAME " +
            "FROM T_COST_PAGE_COMPONENT c " +
            "LEFT JOIN T_COST_TABLE_METADATA m ON c.REF_TABLE_CODE = m.TABLE_CODE " +
            "WHERE c.PAGE_CODE = '" + pageCode.replace("'", "''") + "' " +
            "AND c.DELETED = 0 " +
            "ORDER BY c.SORT_ORDER"
        );
        
        List<PageButtonVO> result = new ArrayList<>();
        for (Map<String, Object> comp : components) {
            Object configObj = comp.get("COMPONENT_CONFIG");
            String configJson = convertClobToString(configObj);
            if (configJson == null || configJson.isEmpty()) continue;
            
            String componentType = comp.get("COMPONENT_TYPE") != null ? comp.get("COMPONENT_TYPE").toString() : "";
            Object tableNameObj = comp.get("TABLE_NAME");
            String tableName = tableNameObj != null ? tableNameObj.toString() : "";
            
            try {
                cn.hutool.json.JSONObject config = cn.hutool.json.JSONUtil.parseObj(configJson);
                
                if ("TABS".equals(componentType)) {
                    // TABS 组件：从每个 tab 的 buttons 中提取
                    cn.hutool.json.JSONArray tabs = config.getJSONArray("tabs");
                    if (tabs != null) {
                        for (int i = 0; i < tabs.size(); i++) {
                            cn.hutool.json.JSONObject tab = tabs.getJSONObject(i);
                            String tabTitle = tab.getStr("title");
                            cn.hutool.json.JSONArray buttons = tab.getJSONArray("buttons");
                            if (buttons != null) {
                                extractButtonsWithTableName(buttons, result, tabTitle != null ? tabTitle : "");
                            }
                        }
                    }
                } else {
                    // 其他组件：从 buttons 中提取
                    cn.hutool.json.JSONArray buttons = config.getJSONArray("buttons");
                    if (buttons != null) {
                        extractButtonsWithTableName(buttons, result, tableName);
                    }
                }
            } catch (Exception e) {
                log.warn("解析组件配置失败, pageCode={}, componentKey={}, error={}", 
                    pageCode, comp.get("COMPONENT_KEY"), e.getMessage());
            }
        }
        
        // 添加导出配置到按钮列表
        addExportConfigsToButtons(pageCode, result);
        
        return result;
    }
    
    /**
     * 将CLOB或其他类型转换为字符串
     */
    private String convertClobToString(Object obj) {
        if (obj == null) return null;
        if (obj instanceof String) return (String) obj;
        if (obj instanceof java.sql.Clob) {
            try {
                java.sql.Clob clob = (java.sql.Clob) obj;
                return clob.getSubString(1, (int) clob.length());
            } catch (Exception e) {
                log.warn("读取CLOB失败: {}", e.getMessage());
                return null;
            }
        }
        return obj.toString();
    }
    
    /**
     * 从按钮规则中提取按钮，使用表名作为前缀
     */
    private void extractButtonsWithTableName(cn.hutool.json.JSONArray items, List<PageButtonVO> result, String tableName) {
        for (int i = 0; i < items.size(); i++) {
            cn.hutool.json.JSONObject item = items.getJSONObject(i);
            String action = item.getStr("action");
            String type = item.getStr("type");
            String label = item.getStr("label");
            
            // 跳过分隔符
            if ("separator".equals(type)) continue;
            
            // 处理子菜单（如"导出"下拉菜单）
            cn.hutool.json.JSONArray subItems = item.getJSONArray("items");
            if (subItems != null && !subItems.isEmpty()) {
                extractButtonsWithTableName(subItems, result, tableName);
                continue;
            }
            
            // 有 action 的才是按钮
            if (action == null) continue;
            
            PageButtonVO vo = new PageButtonVO();
            vo.setButtonKey(action);
            vo.setButtonLabel(label != null ? label : action);
            vo.setGroupName(tableName);
            result.add(vo);
        }
    }
    
    /**
     * 添加导出配置到按钮列表
     */
    private void addExportConfigsToButtons(String pageCode, List<PageButtonVO> result) {
        List<ExportConfig> exportConfigs = exportConfigMapper.findByPageCode(pageCode);
        for (ExportConfig config : exportConfigs) {
            PageButtonVO vo = new PageButtonVO();
            vo.setButtonKey(config.getExportCode());  // 直接用 exportCode
            vo.setButtonLabel(config.getExportName());
            vo.setGroupName("自定义导出");
            result.add(vo);
        }
    }
    
    /**
     * 获取页面的所有表格及其列信息（用于列权限配置）
     * 从 COLUMN_OVERRIDE 规则中提取列的 visible 和 editable 配置
     */
    public List<PageTableColumnsVO> listPageColumns(String pageCode) {
        List<PageTableColumnsVO> result = new ArrayList<>();
        String escapedPageCode = pageCode.replace("'", "''");

        List<Map<String, Object>> components = dynamicMapper.selectList(
            "SELECT c.COMPONENT_KEY, c.COMPONENT_TYPE, c.COMPONENT_CONFIG, c.REF_TABLE_CODE, m.TABLE_NAME " +
            "FROM T_COST_PAGE_COMPONENT c " +
            "LEFT JOIN T_COST_TABLE_METADATA m ON c.REF_TABLE_CODE = m.TABLE_CODE " +
            "WHERE c.PAGE_CODE = '" + escapedPageCode + "' " +
            "AND c.DELETED = 0 " +
            "ORDER BY c.SORT_ORDER"
        );

        Map<String, String> columnOverrideRules = new HashMap<>();
        List<Map<String, Object>> rules = dynamicMapper.selectList(
            "SELECT COMPONENT_KEY, RULES FROM T_COST_PAGE_RULE " +
            "WHERE PAGE_CODE = '" + escapedPageCode + "' " +
            "AND RULE_TYPE = 'COLUMN_OVERRIDE' AND DELETED = 0"
        );
        for (Map<String, Object> rule : rules) {
            String componentKey = (String) rule.get("COMPONENT_KEY");
            String rulesJson = convertClobToString(rule.get("RULES"));
            if (componentKey != null && rulesJson != null) {
                columnOverrideRules.put(componentKey, rulesJson);
            }
        }

        Set<String> tableCodes = new HashSet<>();
        for (Map<String, Object> comp : components) {
            String refTableCode = (String) comp.get("REF_TABLE_CODE");
            if (refTableCode != null) {
                tableCodes.add(refTableCode);
            }
            String componentType = (String) comp.get("COMPONENT_TYPE");
            if ("TABS".equals(componentType)) {
                collectTabTableCodes(convertClobToString(comp.get("COMPONENT_CONFIG")), tableCodes);
            }
        }
        Map<String, List<PageColumnVO>> baseColumnsByTableCode = loadBaseColumnsByTableCode(tableCodes);

        Set<String> addedTableKeys = new HashSet<>();
        for (Map<String, Object> comp : components) {
            String componentKey = (String) comp.get("COMPONENT_KEY");
            String componentType = (String) comp.get("COMPONENT_TYPE");
            String tableName = (String) comp.get("TABLE_NAME");
            String refTableCode = (String) comp.get("REF_TABLE_CODE");

            if ("TABS".equals(componentType)) {
                addTabColumns(
                    result,
                    addedTableKeys,
                    convertClobToString(comp.get("COMPONENT_CONFIG")),
                    columnOverrideRules,
                    baseColumnsByTableCode
                );
                continue;
            }

            if (!"GRID".equals(componentType) && !"DETAIL_GRID".equals(componentType)) {
                continue;
            }
            if (componentKey == null || !addedTableKeys.add(componentKey)) {
                continue;
            }

            String rulesJson = resolveOverrideRules(componentKey, columnOverrideRules);
            Map<String, ColumnOverrideSetting> overrideMap = parseColumnOverrideSettings(rulesJson);
            List<PageColumnVO> baseColumns = refTableCode != null
                ? baseColumnsByTableCode.getOrDefault(refTableCode, Collections.emptyList())
                : Collections.emptyList();

            PageTableColumnsVO tableVO = new PageTableColumnsVO();
            tableVO.setTableKey(componentKey);
            tableVO.setTableName(tableName != null ? tableName : componentKey);
            tableVO.setColumns(applyOverrideRestrictions(baseColumns, overrideMap));
            result.add(tableVO);
        }

        return result;
    }

    private void collectTabTableCodes(String configJson, Set<String> tableCodes) {
        if (configJson == null) return;
        try {
            cn.hutool.json.JSONObject config = cn.hutool.json.JSONUtil.parseObj(configJson);
            cn.hutool.json.JSONArray tabs = config.getJSONArray("tabs");
            if (tabs == null) return;
            for (int i = 0; i < tabs.size(); i++) {
                String tableCode = tabs.getJSONObject(i).getStr("tableCode");
                if (tableCode != null) {
                    tableCodes.add(tableCode);
                }
            }
        } catch (Exception ignored) {
        }
    }

    private void addTabColumns(
            List<PageTableColumnsVO> result,
            Set<String> addedTableKeys,
            String configJson,
            Map<String, String> columnOverrideRules,
            Map<String, List<PageColumnVO>> baseColumnsByTableCode) {
        if (configJson == null) return;
        try {
            cn.hutool.json.JSONObject config = cn.hutool.json.JSONUtil.parseObj(configJson);
            cn.hutool.json.JSONArray tabs = config.getJSONArray("tabs");
            if (tabs == null) return;

            for (int i = 0; i < tabs.size(); i++) {
                cn.hutool.json.JSONObject tab = tabs.getJSONObject(i);
                String tabKey = tab.getStr("key");
                if (tabKey == null || !addedTableKeys.add(tabKey)) {
                    continue;
                }

                String tabTitle = tab.getStr("title");
                String tableCode = tab.getStr("tableCode");
                String rulesJson = resolveOverrideRules(tabKey, columnOverrideRules);
                Map<String, ColumnOverrideSetting> overrideMap = parseColumnOverrideSettings(rulesJson);
                List<PageColumnVO> baseColumns = tableCode != null
                    ? baseColumnsByTableCode.getOrDefault(tableCode, Collections.emptyList())
                    : Collections.emptyList();

                PageTableColumnsVO tableVO = new PageTableColumnsVO();
                tableVO.setTableKey(tabKey);
                tableVO.setTableName(tabTitle != null ? tabTitle : tabKey);
                tableVO.setColumns(applyOverrideRestrictions(baseColumns, overrideMap));
                result.add(tableVO);
            }
        } catch (Exception e) {
            log.warn("解析TABS组件配置失败: {}", e.getMessage());
        }
    }

    private String resolveOverrideRules(String componentKey, Map<String, String> columnOverrideRules) {
        String rulesJson = columnOverrideRules.get(componentKey);
        if (rulesJson == null && "masterGrid".equals(componentKey)) {
            rulesJson = columnOverrideRules.get("master");
        }
        if (rulesJson == null && "master".equals(componentKey)) {
            rulesJson = columnOverrideRules.get("masterGrid");
        }
        return rulesJson;
    }

    private Map<String, List<PageColumnVO>> loadBaseColumnsByTableCode(Set<String> tableCodes) {
        if (tableCodes == null || tableCodes.isEmpty()) {
            return Collections.emptyMap();
        }

        String tableCodeList = tableCodes.stream()
            .map(tc -> "'" + tc.replace("'", "''") + "'")
            .collect(Collectors.joining(","));

        List<Map<String, Object>> columnMetas = dynamicMapper.selectList(
            "SELECT m.TABLE_CODE, c.FIELD_NAME, c.HEADER_TEXT " +
            "FROM T_COST_COLUMN_METADATA c " +
            "JOIN T_COST_TABLE_METADATA m ON c.TABLE_METADATA_ID = m.ID " +
            "WHERE m.TABLE_CODE IN (" + tableCodeList + ") AND c.DELETED = 0 " +
            "ORDER BY m.TABLE_CODE, c.DISPLAY_ORDER"
        );

        Map<String, List<PageColumnVO>> result = new HashMap<>();
        for (Map<String, Object> cm : columnMetas) {
            String tableCode = (String) cm.get("TABLE_CODE");
            String fieldName = (String) cm.get("FIELD_NAME");
            if (tableCode == null || fieldName == null) {
                continue;
            }

            PageColumnVO vo = new PageColumnVO();
            vo.setFieldName(fieldName);
            vo.setHeaderText((String) cm.get("HEADER_TEXT"));
            // T_COST_COLUMN_METADATA 没有 visible/editable 字段，基线默认为可见可编辑。
            vo.setVisible(true);
            vo.setEditable(true);
            result.computeIfAbsent(tableCode, k -> new ArrayList<>()).add(vo);
        }
        return result;
    }

    private Map<String, ColumnOverrideSetting> parseColumnOverrideSettings(String rulesJson) {
        Map<String, ColumnOverrideSetting> result = new HashMap<>();
        if (rulesJson == null || rulesJson.isBlank()) {
            return result;
        }
        try {
            cn.hutool.json.JSONArray arr = cn.hutool.json.JSONUtil.parseArray(rulesJson);
            for (int i = 0; i < arr.size(); i++) {
                cn.hutool.json.JSONObject col = arr.getJSONObject(i);
                String field = col.getStr("field");
                if (field == null) field = col.getStr("fieldName");
                if (field == null) continue;
                result.put(field, new ColumnOverrideSetting(col.getBool("visible"), col.getBool("editable")));
            }
        } catch (Exception e) {
            log.warn("解析COLUMN_OVERRIDE规则失败: {}", e.getMessage());
        }
        return result;
    }

    private List<PageColumnVO> applyOverrideRestrictions(
            List<PageColumnVO> baseColumns,
            Map<String, ColumnOverrideSetting> overrideMap) {
        List<PageColumnVO> result = new ArrayList<>();
        for (PageColumnVO base : baseColumns) {
            boolean visible = base.getVisible() == null || base.getVisible();
            boolean editable = base.getEditable() == null || base.getEditable();

            ColumnOverrideSetting override = overrideMap.get(base.getFieldName());
            if (override != null) {
                // COLUMN_OVERRIDE 只允许收紧，不允许放开上层配置。
                if (Boolean.FALSE.equals(override.visible())) {
                    visible = false;
                }
                if (Boolean.FALSE.equals(override.editable())) {
                    editable = false;
                }
            }
            if (!visible) {
                editable = false;
            }

            PageColumnVO merged = new PageColumnVO();
            merged.setFieldName(base.getFieldName());
            merged.setHeaderText(base.getHeaderText() != null ? base.getHeaderText() : base.getFieldName());
            merged.setVisible(visible);
            merged.setEditable(editable);
            result.add(merged);
        }
        return result;
    }

    private record ColumnOverrideSetting(Boolean visible, Boolean editable) {
    }
    public List<RowFilterFieldVO> listRowFilterFields(String pageCode) {
        List<RowFilterFieldVO> result = new ArrayList<>();
        
        // 1. 查询页面的主表组件（GRID 类型，componentKey 为 masterGrid 或 master）
        List<Map<String, Object>> components = dynamicMapper.selectList(
            "SELECT c.COMPONENT_KEY, c.REF_TABLE_CODE " +
            "FROM T_COST_PAGE_COMPONENT c " +
            "WHERE c.PAGE_CODE = '" + pageCode.replace("'", "''") + "' " +
            "AND c.COMPONENT_TYPE = 'GRID' " +
            "AND c.COMPONENT_KEY IN ('masterGrid', 'master') " +
            "AND c.DELETED = 0"
        );
        
        if (components.isEmpty()) {
            return result;
        }
        
        String refTableCode = (String) components.get(0).get("REF_TABLE_CODE");
        if (refTableCode == null) {
            return result;
        }
        
        // 2. 查询该表的列元数据
        List<Map<String, Object>> columns = dynamicMapper.selectList(
            "SELECT c.COLUMN_NAME, c.FIELD_NAME, c.HEADER_TEXT, c.DATA_TYPE " +
            "FROM T_COST_COLUMN_METADATA c " +
            "JOIN T_COST_TABLE_METADATA m ON c.TABLE_METADATA_ID = m.ID " +
            "WHERE m.TABLE_CODE = '" + refTableCode.replace("'", "''") + "' " +
            "AND c.DELETED = 0 " +
            "ORDER BY c.DISPLAY_ORDER"
        );
        
        // 3. 添加常用审计字段
        result.add(createRowFilterField("CREATE_BY", "创建人", "string"));
        result.add(createRowFilterField("CREATE_TIME", "创建时间", "date"));
        result.add(createRowFilterField("UPDATE_BY", "更新人", "string"));
        result.add(createRowFilterField("UPDATE_TIME", "更新时间", "date"));
        
        // 4. 添加业务字段
        for (Map<String, Object> col : columns) {
            String columnName = (String) col.get("COLUMN_NAME");
            String headerText = (String) col.get("HEADER_TEXT");
            String dataType = (String) col.get("DATA_TYPE");
            
            // 跳过已添加的审计字段
            if ("CREATE_BY".equals(columnName) || "CREATE_TIME".equals(columnName) ||
                "UPDATE_BY".equals(columnName) || "UPDATE_TIME".equals(columnName) ||
                "DELETED".equals(columnName) || "ID".equals(columnName)) {
                continue;
            }
            
            result.add(createRowFilterField(columnName, headerText, mapDataType(dataType)));
        }
        
        return result;
    }
    
    private RowFilterFieldVO createRowFilterField(String field, String label, String dataType) {
        RowFilterFieldVO vo = new RowFilterFieldVO();
        vo.setField(field);
        vo.setLabel(label != null ? label : field);
        vo.setDataType(dataType);
        return vo;
    }
    
    private String mapDataType(String dataType) {
        if (dataType == null) return "string";
        return switch (dataType.toLowerCase()) {
            case "number", "integer", "decimal", "float", "double" -> "number";
            case "date", "datetime", "timestamp" -> "date";
            default -> "string";
        };
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
