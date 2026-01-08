-- =====================================================
-- 为用户管理页面添加右键菜单配置
-- =====================================================

-- 插入右键菜单组件配置
INSERT INTO T_COST_PAGE_COMPONENT (
    ID, 
    PAGE_CODE, 
    COMPONENT_KEY, 
    COMPONENT_TYPE, 
    PARENT_KEY,
    SORT_ORDER, 
    COMPONENT_CONFIG
)
VALUES (
    SEQ_COST_PAGE_COMPONENT.NEXTVAL,
    'user-manage',            -- 用户管理页面
    'contextMenu',            -- 组件Key
    'CONTEXT_MENU',           -- 组件类型：右键菜单
    NULL,                     -- 无父组件
    99,                       -- 排序顺序（最后）
    '{
        "items": [
            {
                "label": "新增行",
                "key": "add",
                "icon": "mdi:plus",
                "action": "addRow"
            },
            {
                "label": "编辑",
                "key": "edit",
                "icon": "mdi:pencil",
                "action": "editRow",
                "disabled": "!selectedRow"
            },
            {
                "label": "复制行",
                "key": "copy",
                "icon": "mdi:content-copy",
                "action": "copyRow",
                "disabled": "!selectedRow"
            },
            {
                "label": "删除",
                "key": "delete",
                "icon": "mdi:delete",
                "action": "deleteRow",
                "confirm": true,
                "confirmMessage": "确认删除选中的用户吗？",
                "disabled": "!selectedRow"
            },
            {
                "type": "divider"
            },
            {
                "label": "重置密码",
                "key": "resetPassword",
                "icon": "mdi:lock-reset",
                "action": "executeAction",
                "actionParams": {
                    "tableCode": "CostUser",
                    "group": "manual",
                    "dataFields": ["id"],
                    "extraData": {
                        "password": "{{DEFAULT_PASSWORD}}"
                    }
                },
                "confirm": true,
                "confirmMessage": "确认重置密码为默认值（Abc123..）吗？",
                "disabled": "!selectedRow"
            },
            {
                "type": "divider"
            },
            {
                "label": "刷新",
                "key": "refresh",
                "icon": "mdi:refresh",
                "action": "refresh"
            }
        ]
    }'
);

COMMIT;

-- 查询验证
SELECT 
    PAGE_CODE,
    COMPONENT_KEY,
    COMPONENT_TYPE,
    COMPONENT_CONFIG
FROM T_COST_PAGE_COMPONENT
WHERE PAGE_CODE = 'user-manage' AND COMPONENT_TYPE = 'CONTEXT_MENU';
