prompt Importing table t_cost_page_rule...
set feedback off
set define off

insert into t_cost_page_rule (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (493, 'cost-pinggu', 'material', 'CONTEXT_MENU', '{"items":[{"action":"addRow"},{"action":"copyRow","requiresRow":true},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"saveGridConfig"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}', 0, null, 0, '28-JAN-26 05.27.13.901000 PM', '28-JAN-26 05.27.13.901000 PM', 'system', null);

insert into t_cost_page_rule (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (515, 'goods-manage', 'grid', 'CONTEXT_MENU', '{"items":[
  {"action":"addRow"},
  {"action":"copyRow","requiresRow":true},
  {"action":"deleteRow","requiresRow":true},
  {"type":"separator"},
  {"action":"saveGridConfig"},
  {"type":"separator"},
  {"label":"导出","items":[
    {"action":"exportSelected","requiresSelection":true},
    {"action":"exportCurrent"},
    {"action":"exportAll"},
    {"type":"separator"},
    {"action":"resetExportConfig"},
    {"action":"openHeaderConfig"}
  ]},
  {"type":"separator"},
  {"action":"save"},
  {"type":"separator"},
  {"action":"clipboard.copy"},
  {"action":"clipboard.paste"}
]}', 0, null, 0, '29-JAN-26 05.12.14.635000 PM', '29-JAN-26 05.12.14.635000 PM', 'system', null);

insert into t_cost_page_rule (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (13, 'user-manage', 'masterGrid', 'CONTEXT_MENU', '{"items":[{"action":"addRow"},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"save"}]}', 0, null, 0, '26-JAN-26 09.53.12.685000 AM', '26-JAN-26 09.53.12.685000 AM', 'system', null);

insert into t_cost_page_rule (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (15, 'dept-manage', 'masterGrid', 'CONTEXT_MENU', '{"items":[{"action":"addRow"},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"save"}]}', 0, null, 0, '26-JAN-26 09.53.12.823000 AM', '26-JAN-26 09.53.12.823000 AM', 'system', null);

insert into t_cost_page_rule (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (278, 'customer-manage', 'masterGrid', 'CONTEXT_MENU', '{"items":[
  {"action":"addRow"},
  {"action":"copyRow","requiresRow":true},
  {"action":"deleteRow","requiresRow":true},
  {"type":"separator"},
  {"action":"saveGridConfig"},
  {"type":"separator"},
  {"label":"导出","items":[
    {"action":"exportSelected","requiresSelection":true},
    {"action":"exportCurrent"},
    {"action":"exportAll"},
    {"type":"separator"},
    {"action":"resetExportConfig"},
    {"action":"openHeaderConfig"}
  ]},
  {"type":"separator"},
  {"action":"save"},
  {"type":"separator"},
  {"action":"clipboard.copy"},
  {"action":"clipboard.paste"}
]}', 0, null, 0, '26-JAN-26 05.41.10.415000 PM', '26-JAN-26 05.41.10.415000 PM', 'system', null);

insert into t_cost_page_rule (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (279, 'customer-manage', 'tranposer', 'CONTEXT_MENU', '{"items":[
  {"action":"addRow"},
  {"action":"copyRow","requiresRow":true},
  {"action":"deleteRow","requiresRow":true},
  {"type":"separator"},
  {"action":"saveGridConfig"},
  {"type":"separator"},
  {"label":"导出","items":[
    {"action":"exportSelected","requiresSelection":true},
    {"action":"exportCurrent"},
    {"action":"exportAll"},
    {"type":"separator"},
    {"action":"resetExportConfig"},
    {"action":"openHeaderConfig"}
  ]},
  {"type":"separator"},
  {"action":"save"},
  {"type":"separator"},
  {"action":"clipboard.copy"},
  {"action":"clipboard.paste"}
]}', 0, null, 0, '26-JAN-26 05.41.10.458000 PM', '26-JAN-26 05.41.10.458000 PM', 'system', null);

insert into t_cost_page_rule (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (142, 'formoney-manage', 'grid', 'CONTEXT_MENU', '{"items":[{"action":"addRow"},{"action":"copyRow","requiresRow":true},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"saveGridConfig"},{"type":"separator"},{"label":"导出","items":[{"action":"exportSelected","requiresSelection":true},{"action":"exportCurrent"},{"action":"exportAll"},{"type":"separator"},{"action":"resetExportConfig"},{"action":"openHeaderConfig"}]},{"type":"separator"},{"action":"save"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}', 0, null, 0, '26-JAN-26 04.53.18.735000 PM', '26-JAN-26 04.53.18.735000 PM', 'system', null);

insert into t_cost_page_rule (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (497, 'cost-pinggu', 'masterGrid', 'CONTEXT_MENU', '{"items":[{"action":"addRow"},{"action":"copyRow","requiresRow":true},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"generateFromBom","label":"由BOM生成明细","requiresRow":true,"procedure":"P_COST_BOM_INSERT","params":[{"source":"data.id","mode":"IN","jdbcType":"NUMERIC"}]},{"type":"separator"},{"action":"saveGridConfig"},{"type":"separator"},{"action":"save"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}', 0, null, 0, '29-JAN-26 10.13.59.632000 AM', '29-JAN-26 10.13.59.632000 AM', 'system', null);

insert into t_cost_page_rule (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (494, 'cost-pinggu', 'package', 'CONTEXT_MENU', '{"items":[{"action":"addRow"},{"action":"copyRow","requiresRow":true},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"saveGridConfig"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}', 0, null, 0, '28-JAN-26 05.27.14.576000 PM', '28-JAN-26 05.27.14.576000 PM', 'system', null);

insert into t_cost_page_rule (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (495, 'cost-pinggu', 'detailTabs', 'CONTEXT_MENU', '{"items":[{"action":"addRow"},{"action":"copyRow","requiresRow":true},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"saveGridConfig"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}', 0, null, 0, '28-JAN-26 05.27.14.721000 PM', '28-JAN-26 05.27.14.721000 PM', 'system', null);

insert into t_cost_page_rule (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (522, 'goods-price-manage', 'grid', 'CONTEXT_MENU', '{"items":[
  {"action":"addRow"},
  {"action":"copyRow","requiresRow":true},
  {"action":"deleteRow","requiresRow":true},
  {"type":"separator"},
  {"action":"saveGridConfig"},
  {"type":"separator"},
  {"label":"导出","items":[
    {"action":"exportSelected","requiresSelection":true},
    {"action":"exportCurrent"},
    {"action":"exportAll"},
    {"type":"separator"},
    {"action":"resetExportConfig"},
    {"action":"openHeaderConfig"}
  ]},
  {"type":"separator"},
  {"action":"save"},
  {"type":"separator"},
  {"action":"clipboard.copy"},
  {"action":"clipboard.paste"}
]}', 0, null, 0, '29-JAN-26 05.25.31.094000 PM', '29-JAN-26 05.25.31.094000 PM', 'system', null);

insert into t_cost_page_rule (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (330, 'formoney-manage', 'grid', 'TOOLBAR', '{"items":[{"action":"SYNC_ERP_RATE","label":"同步ERP汇率","type":"primary","sql":"UPDATE T_COST_FORMONEY SET FMRATE = NULL, CREATE_TIME = NULL, UPDATE_TIME = NULL WHERE CREATE_BY = ''system''"}]}', 0, null, 0, '27-JAN-26 09.52.05.674000 AM', '27-JAN-26 09.52.05.674000 AM', 'system', null);

prompt Done.
