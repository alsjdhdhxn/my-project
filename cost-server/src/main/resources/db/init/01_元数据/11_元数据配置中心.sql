-- ============================================================
-- 元数据配置中心 - 菜单资源
-- 放在"系统管理"目录下 (parentId=6)，硬编码页面
-- ============================================================

INSERT INTO T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
VALUES (200, '元数据配置', 'PAGE', 'meta-config', 'mdi:database-cog', '/system/meta-config', 6, 10, 1);
