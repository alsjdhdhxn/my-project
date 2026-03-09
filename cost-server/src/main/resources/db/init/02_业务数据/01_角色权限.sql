-- ============================================================
-- 角色权限初始化
-- 包含: 角色、菜单资源、角色页面权限
-- ============================================================

-- ============================================================
-- 1. 角色数据
-- ============================================================
INSERT INTO T_COST_ROLE (ID, ROLE_CODE, ROLE_NAME, DESCRIPTION)
VALUES (3, 'ADMIN', '系统管理员', '拥有所有权限');

INSERT INTO T_COST_ROLE (ID, ROLE_CODE, ROLE_NAME, DESCRIPTION)
VALUES (41, '普通用户', '普通用户', '测试用');

-- ============================================================
-- 2. 菜单资源数据
-- ============================================================
-- 首页
INSERT INTO T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
VALUES (5, '首页', 'PAGE', 'home', 'mdi:monitor-dashboard', '/home', NULL, 0, 0);

-- 基础信息目录
INSERT INTO T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
VALUES (41, '基础信息', 'DIRECTORY', 'cost', 'mdi:currency-usd', '/cost', NULL, 1, 0);

-- 物料成本核算表
INSERT INTO T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
VALUES (65, '物料成本核算表', 'PAGE', 'cost-pinggu', 'mdi:calculator-variant', '/cost/cost-pinggu', NULL, 1, 0);

-- 产品信息维护
INSERT INTO T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
VALUES (82, '产品信息维护', 'PAGE', 'goods-manage', 'mdi:package-variant', '/cost/goods', 41, 2, 0);

-- 客户信息
INSERT INTO T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
VALUES (50, '客户信息', 'PAGE', 'customer-manage', 'mdi:account-box', '/cost/customer', 41, 3, 0);

-- 物料清单及成本
INSERT INTO T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
VALUES (83, '物料清单及成本', 'PAGE', 'goods-price-manage', 'mdi:tag-outline', '/cost/goods-price', 41, 4, 0);

-- 外币管理
INSERT INTO T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
VALUES (42, '外币管理', 'PAGE', 'formoney-manage', 'mdi:currency-usd', '/cost/formoney', 41, 10, 0);

-- 系统管理目录
INSERT INTO T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
VALUES (6, '系统管理', 'DIRECTORY', 'system', 'mdi:cog', '/system', NULL, 99, 0);

-- 人员管理
INSERT INTO T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
VALUES (7, '人员管理', 'PAGE', 'user-manage', 'mdi:account-group', '/system/user', 6, 1, 0);

-- 权限管理
INSERT INTO T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
VALUES (85, '权限管理', 'PAGE', 'permission', 'mdi:shield-account', '/system/permission', 6, 1, 1);

-- 部门管理
INSERT INTO T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
VALUES (8, '部门管理', 'PAGE', 'dept-manage', 'mdi:domain', '/system/dept', 6, 3, 0);

-- 审计追踪
INSERT INTO T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
VALUES (105, '审计追踪', 'PAGE', 'auditLog', 'mdi:file-document-outline', '/audit-log', NULL, 99, 0);

-- 成品发运单
INSERT INTO T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
VALUES (123, '成品发运单', 'PAGE', 'wms-shipping', 'mdi:truck-delivery', '/wms/shipping', NULL, 100, 0);

-- ============================================================
-- 3. 角色页面权限数据 (ADMIN角色)
-- ============================================================
INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY)
VALUES (6, 3, 'home', '["*"]', NULL, NULL);

INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY)
VALUES (98, 3, 'cost', '["*"]', NULL, NULL);

INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY)
VALUES (65, 3, 'cost-pinggu', '[]', '{"masterGrid":{"DOCID":{},"GOODSNAME":{"editable":false},"GOODSNAME_EN":{"editable":false},"STRENGTH":{"editable":false},"CUSTOMNAME":{"editable":false},"COUNTRY":{"editable":false},"PROJECTNO":{"editable":false},"APEX_PL":{"editable":false},"ANNUAL_QTY":{"editable":false},"YIELD":{"editable":false},"P_PERPACK":{"editable":false},"M_PERPACK":{"editable":false},"S_PERBACK":{"editable":false},"X_PERBACK":{"editable":false},"PACKTYPE":{"editable":false},"TOTAL_YL":{},"TOTAL_FL":{},"TOTAL_BC":{},"TOTAL_COST":{},"OUT_PRICE_RMB":{"editable":false},"SALEMONEY":{},"JGF_BATCH":{},"COST_PERQP":{"editable":false},"COST_PERBOX":{},"JGF_PERQP":{},"ML_PERQP":{},"Y_JG_RE":{},"Y_ML":{},"Y_SALE":{},"FMNAME":{"editable":false},"FMRATE":{"editable":false}}}', '{"mode":"visual","logic":"AND","conditions":[{"field":"CREATE_BY","fieldLabel":"创建人","op":"eq","valueType":"dynamic","value":"${username}"},{"field":"GOODSNAME","fieldLabel":"产品名称","op":"eq","valueType":"static","value":"洒洒水"}],"sql":"CREATE_BY = ${username} AND GOODSNAME = ''洒洒水''"}');

INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY)
VALUES (62, 3, 'goods-manage', '["*"]', NULL, NULL);

INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY)
VALUES (23, 3, 'customer-manage', '["*"]', NULL, NULL);

INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY)
VALUES (63, 3, 'goods-price-manage', '["*"]', NULL, NULL);

INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY)
VALUES (21, 3, 'formoney-manage', '["*"]', NULL, NULL);

INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY)
VALUES (117, 3, 'system', '["*"]', NULL, NULL);

INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY)
VALUES (119, 3, 'user-manage', '["*"]', NULL, NULL);

INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY)
VALUES (118, 3, 'permission', '["*"]', NULL, NULL);

INSERT INTO T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY)
VALUES (120, 3, 'dept-manage', '["*"]', NULL, NULL);

