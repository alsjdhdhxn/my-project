-- =====================================================
-- 修复人员管理页面元数据
-- deptName 是视图关联字段，应标记为虚拟列
-- =====================================================

UPDATE T_COST_COLUMN_METADATA 
SET IS_VIRTUAL = 1
WHERE TABLE_METADATA_ID = (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostUser')
AND FIELD_NAME = 'deptName';

-- 同样修复角色用户表的 deptName、username、realName
UPDATE T_COST_COLUMN_METADATA 
SET IS_VIRTUAL = 1
WHERE TABLE_METADATA_ID = (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostUserRole')
AND FIELD_NAME IN ('deptName', 'username', 'realName');

COMMIT;
