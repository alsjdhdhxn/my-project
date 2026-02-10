prompt Importing table T_COST_PAGE_RULE...
set feedback off
set define off

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (544, 'cost-pinggu', 'masterGrid', 'ROW_CLASS', '[{"field":"memo","operator":"eq","value":"ERP未搭建BOM","style":{"backgroundColor":"#ffcccc"}}]', 0, null, 0, '04-FEB-26 04.20.51.468000 PM', '04-FEB-26 04.20.51.468000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (516, 'goods-manage', 'grid', 'ROW_CLASS', '[{"field":"iserp","operator":"eq","value":1,"style":{"backgroundColor":"#e6ffed"}}]', 0, null, 0, '29-JAN-26 05.12.14.673000 PM', '10-FEB-26 01.16.26.268000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (276, 'customer-manage', 'masterGrid', 'ROW_CLASS', '[{"field":"iserp","operator":"eq","value":1,"style":{"backgroundColor":"#e6ffed"}}]', 0, null, 0, '26-JAN-26 05.41.10.306000 PM', '10-FEB-26 01.16.26.306000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (277, 'customer-manage', 'tranposer', 'ROW_CLASS', '[{"field":"iserp","operator":"eq","value":1,"style":{"backgroundColor":"#e6ffed"}}]', 0, null, 0, '26-JAN-26 05.41.10.357000 PM', '10-FEB-26 01.16.26.340000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (520, 'goods-price-manage', 'grid', 'ROW_CLASS', '[{"field":"rowClassFlag","operator":"eq","value":"erp","style":{"backgroundColor":"#e6ffed"}},{"field":"rowClassFlag","operator":"eq","value":"erp-updated","style":{"backgroundColor":"#fff2a8"}},{"field":"rowClassFlag","operator":"eq","value":"erp-price-null","style":{"backgroundColor":"#f8d7da"}}]', 0, null, 0, '29-JAN-26 05.25.31.049000 PM', '10-FEB-26 01.16.26.381000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (609, 'cost-pinggu-lq', 'masterGrid', 'ROW_CLASS', '[{"field":"memo","operator":"eq","value":"ERP未搭建BOM","style":{"backgroundColor":"#ffcccc"}}]', 0, null, 0, '06-FEB-26 02.29.08.379000 PM', '06-FEB-26 02.29.08.379000 PM', 'system', null);

prompt Done.
