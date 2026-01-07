-- V2: 添加 Lookup 配置和测试用户权限
-- 1. 给 CostPingguDtl.apexGoodsname 字段配置 Lookup（关联物料表）
-- mapping: 货品名 <- materialName, 价格 <- price
UPDATE T_COST_COLUMN_METADATA 
SET RULES_CONFIG = '{"lookup":{"code":"material","mapping":{"apexGoodsname":"materialName","price":"price"}}}'
WHERE TABLE_METADATA_ID = (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostPingguDtl')
  AND FIELD_NAME = 'apexGoodsname';

-- 2. 给测试用户（user 角色）添加 cost-pinggu 页面权限
INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, CREATE_BY)
SELECT SEQ_COST_ROLE_PAGE.NEXTVAL, r.ID, 'cost-pinggu', '["CREATE","EDIT","DELETE"]', NULL, 'system'
FROM T_COST_ROLE r
WHERE r.ROLE_CODE = 'USER'
  AND NOT EXISTS (SELECT 1 FROM T_COST_ROLE_PAGE rp WHERE rp.ROLE_ID = r.ID AND rp.PAGE_CODE = 'cost-pinggu');

-- 3. 给管理员角色添加 cost-pinggu 页面权限（全部按钮）
INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, CREATE_BY)
SELECT SEQ_COST_ROLE_PAGE.NEXTVAL, r.ID, 'cost-pinggu', '["*"]', NULL, 'system'
FROM T_COST_ROLE r
WHERE r.ROLE_CODE = 'ADMIN'
  AND NOT EXISTS (SELECT 1 FROM T_COST_ROLE_PAGE rp WHERE rp.ROLE_ID = r.ID AND rp.PAGE_CODE = 'cost-pinggu');

COMMIT;
