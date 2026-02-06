prompt Importing table T_COST_RESOURCE...
set feedback off
set define off

insert into T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
values (5, '首页', 'PAGE', 'home', 'mdi:monitor-dashboard', '/home', null, 0, 0);

insert into T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
values (41, '基础信息', 'DIRECTORY', 'cost', 'mdi:currency-usd', '/cost', null, 1, 0);

insert into T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
values (65, '物料成本核算表', 'PAGE', 'cost-pinggu', 'mdi:calculator-variant', '/cost/cost-pinggu', null, 1, 0);

insert into T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
values (85, '权限管理', 'PAGE', 'permission', 'mdi:shield-account', '/system/permission', 6, 1, 1);

insert into T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
values (7, '人员管理', 'PAGE', 'user-manage', 'mdi:account-group', '/system/user', 6, 1, 0);

insert into T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
values (82, '产品信息维护', 'PAGE', 'goods-manage', 'mdi:package-variant', '/cost/goods', 41, 2, 0);

insert into T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
values (50, '客户信息', 'PAGE', 'customer-manage', 'mdi:account-box', '/cost/customer', 41, 3, 0);

insert into T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
values (8, '部门管理', 'PAGE', 'dept-manage', 'mdi:domain', '/system/dept', 6, 3, 0);

insert into T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
values (83, '物料清单及成本', 'PAGE', 'goods-price-manage', 'mdi:tag-outline', '/cost/goods-price', 41, 4, 0);

insert into T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
values (42, '外币管理', 'PAGE', 'formoney-manage', 'mdi:currency-usd', '/cost/formoney', 41, 10, 0);

insert into T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
values (105, '审计追踪', 'PAGE', 'auditLog', 'mdi:file-document-outline', '/audit-log', null, 99, 0);

insert into T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
values (6, '系统管理', 'DIRECTORY', 'system', 'mdi:cog', '/system', null, 99, 0);

insert into T_COST_RESOURCE (ID, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, IS_HARDCODED)
values (123, '成品发运单', 'PAGE', 'wms-shipping', 'mdi:truck-delivery', '/wms/shipping', null, 100, 0);

prompt Done.
