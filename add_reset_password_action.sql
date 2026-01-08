-- =====================================================
-- 为 CostUser 表配置重置密码执行器
-- =====================================================

-- 更新 CostUser 表的 ACTION_RULES
UPDATE T_COST_TABLE_METADATA
SET ACTION_RULES = '[
    {
        "code": "resetPassword",
        "group": "manual",
        "type": "java",
        "handler": "userActionHandler.resetPassword",
        "description": "重置用户密码为默认值"
    }
]'
WHERE TABLE_CODE = 'CostUser';

COMMIT;

-- 查询验证
SELECT TABLE_CODE, ACTION_RULES
FROM T_COST_TABLE_METADATA
WHERE TABLE_CODE = 'CostUser';
