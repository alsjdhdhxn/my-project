prompt Importing table T_COST_PAGE_RULE...
set feedback off
set define off

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (550, 'auditLog', 'masterGrid', 'COLUMN_OVERRIDE', '[
  {"field":"id","width":80,"editable":false},
  {"field":"userName","width":120,"editable":false},
  {"field":"operationTime","width":180,"editable":false},
  {"field":"pageCode","width":150,"editable":false},
  {"field":"tableCode","width":150,"editable":false},
  {"field":"tableName","width":150,"editable":false},
  {"field":"recordId","width":100,"editable":false},
  {"field":"operationType","width":100,"editable":false},
  {"field":"fieldChanges","width":400,"editable":false,"wrapText":true,"autoHeight":true},
  {"field":"createTime","width":180,"editable":false}
]', 1, '列覆盖配置', 0, '04-FEB-26 06.16.19.928000 PM', '04-FEB-26 06.16.19.928000 PM', null, null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (488, 'cost-pinggu', 'detailTabs', 'ROLE_BINDING', '{"role":"DETAIL_TABS"}', 0, null, 0, '28-JAN-26 05.27.12.661000 PM', '28-JAN-26 05.27.12.661000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (491, 'cost-pinggu', 'detailTabs', 'SUMMARY_CONFIG', '{"enabled":true,"groupLabelField":"groupLabel","groupLabelHeader":"分类","summaryColumns":[{"field":"totalAmount","headerName":"汇总金额","width":null},{"field":"rowCount","headerName":"行数","width":null}],"summaryAggregates":[{"sourceField":"costBatch","targetField":"totalAmount","algorithm":"SUM"},{"sourceField":"costBatch","targetField":"rowCount","algorithm":"COUNT"}]}', 0, null, 0, '28-JAN-26 05.27.13.008000 PM', '28-JAN-26 05.27.13.008000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (490, 'cost-pinggu', 'detailTabs', 'BROADCAST', '["apexPl","pPerpack","sPerback","xPerback"]', 0, null, 0, '28-JAN-26 05.27.12.908000 PM', '28-JAN-26 05.27.12.908000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (489, 'cost-pinggu', 'detailTabs', 'RELATION', '{"masterKey":"masterGrid","detailKey":"detailTabs"}', 0, null, 0, '28-JAN-26 05.27.12.784000 PM', '28-JAN-26 05.27.12.784000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (486, 'cost-pinggu', 'masterGrid', 'ROLE_BINDING', '{"role":"MASTER_GRID"}', 0, null, 0, '28-JAN-26 05.27.12.409000 PM', '28-JAN-26 05.27.12.409000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (477, 'cost-pinggu', 'masterGrid', 'LOOKUP', '[{"field":"goodsname","lookupCode":"costGoods","mapping":{"goodsid":"goodsid","goodsname":"goodsname","maNo":"maNo","apexPl":"apexPl","mah":"mah","pPerpack":"pPerpack","sPerback":"sPerback","customid":"customid","customname":"customname","memo":"memo","strength":"strength","livery":"livery"}},{"field":"fmname","lookupCode":"formoney","mapping":{"fmname":"fmname","fmrate":"fmrate"}},{"field":"customname","lookupCode":"costCustomer","mapping":{"customid":"customid","customname":"customname","country":"country","tranposid":"tranposid","livery":"livery"}}]', 0, null, 0, '28-JAN-26 05.27.11.167000 PM', '28-JAN-26 05.27.11.167000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (476, 'cost-pinggu', 'masterGrid', 'AGGREGATE', '[
  {"sourceField":"costBatch","targetField":"totalYl","algorithm":"SUM","sourceTab":"material","filter":"dtlUseflag === ''原料''"},
  {"sourceField":"costBatch","targetField":"totalFl","algorithm":"SUM","sourceTab":"material","filter":"dtlUseflag === ''辅料''"},
  {"sourceField":"costBatch","targetField":"totalBc","algorithm":"SUM","sourceTab":"package","filter":"dtlUseflag === ''非印字包材'' || dtlUseflag === ''印字包材''"},
  {"targetField":"totalYl","expression":"totalYl > 0 ? totalYl / 1.13 : totalYl"},
  {"targetField":"totalFl","expression":"totalYl > 0 ? totalFl / 1.13 : totalFl"},
  {"targetField":"totalBc","expression":"totalYl > 0 ? totalBc / 1.13 : totalBc"},
  {"targetField":"totalCost","expression":"totalYl + totalFl + totalBc"}
]', 0, null, 0, '28-JAN-26 05.27.11.026000 PM', '28-JAN-26 05.27.11.026000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (475, 'cost-pinggu', 'masterGrid', 'CALC', '[
  {"field":"salemoney","expression":"outPriceRmb / pPerpack * apexPl * (yield / 100)","triggerFields":["outPriceRmb","pPerpack","apexPl","yield"]},
  {"field":"jgfBatch","expression":"salemoney - totalCost","triggerFields":["salemoney","totalCost"]},
  {"field":"costPerbox","expression":"totalCost / apexPl * pPerpack","triggerFields":["totalCost","apexPl","pPerpack"]},
  {"field":"jgfPerqp","expression":"jgfBatch / apexPl * 1000","triggerFields":["jgfBatch","apexPl"]},
  {"field":"mlPerqp","expression":"jgfPerqp - costPerqp","triggerFields":["jgfPerqp","costPerqp"]},
  {"field":"yJgRe","expression":"jgfPerqp / 1000 * annualQty","triggerFields":["jgfPerqp","annualQty"]},
  {"field":"yMl","expression":"mlPerqp / 1000 * annualQty","triggerFields":["mlPerqp","annualQty"]},
  {"field":"ySale","expression":"salemoney / apexPl * annualQty","triggerFields":["salemoney","apexPl","annualQty"]}
]', 0, null, 0, '28-JAN-26 05.27.10.872000 PM', '28-JAN-26 05.27.10.872000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (474, 'cost-pinggu', 'masterGrid', 'VALIDATION', '[]', 0, null, 0, '28-JAN-26 05.27.10.731000 PM', '28-JAN-26 05.27.10.731000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (473, 'cost-pinggu', 'masterGrid', 'COLUMN_OVERRIDE', '[{"field":"id","visible":true,"editable":false},{"field":"goodsid","visible":true,"editable":false},{"field":"goodsname","visible":true,"editable":true,"searchable":true},{"field":"goodsnameEn","visible":true,"editable":true},{"field":"strength","visible":true,"editable":true},{"field":"customid","visible":true,"editable":false},{"field":"customname","visible":true,"editable":true,"searchable":true},{"field":"country","visible":true,"editable":true},{"field":"tranposid","visible":true,"editable":false},{"field":"livery","visible":true,"editable":true},{"field":"projectno","visible":true,"editable":true},{"field":"apexPl","visible":true,"editable":true},{"field":"annualQty","visible":true,"editable":true},{"field":"yield","visible":true,"editable":true},{"field":"pPerpack","visible":true,"editable":true},{"field":"sPerback","visible":true,"editable":true},{"field":"xPerback","visible":true,"editable":true},{"field":"packtype","visible":true,"editable":true},{"field":"totalYl","visible":true,"editable":false},{"field":"totalFl","visible":true,"editable":false},{"field":"totalBc","visible":true,"editable":false},{"field":"totalCost","visible":true,"editable":false},{"field":"outPriceRmb","visible":true,"editable":true},{"field":"salemoney","visible":true,"editable":false},{"field":"jgfBatch","visible":true,"editable":false},{"field":"costPerqp","visible":true,"editable":true},{"field":"jgfPerqp","visible":true,"editable":false},{"field":"mlPerqp","visible":true,"editable":false},{"field":"yJgRe","visible":true,"editable":false},{"field":"yMl","visible":true,"editable":false},{"field":"ySale","visible":true,"editable":false},{"field":"fmname","visible":true,"editable":true},{"field":"fmrate","visible":true,"editable":true},{"field":"memo","visible":true,"editable":true}]', 0, null, 0, '28-JAN-26 05.27.10.532000 PM', '28-JAN-26 05.27.10.532000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (544, 'cost-pinggu', 'masterGrid', 'ROW_CLASS', '[{"field":"memo","operator":"eq","value":"ERP未搭建BOM","style":{"backgroundColor":"#ffcccc"}}]', 0, null, 0, '04-FEB-26 04.20.51.468000 PM', '04-FEB-26 04.20.51.468000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (487, 'cost-pinggu', 'masterGrid', 'GRID_OPTIONS', '{"cellSelection":true,"sideBar":true}', 0, null, 0, '28-JAN-26 05.27.12.544000 PM', '28-JAN-26 05.27.12.544000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (478, 'cost-pinggu', 'material', 'COLUMN_OVERRIDE', '[{"field":"id","visible":true,"editable":false},{"field":"masterId","visible":true,"editable":false},{"field":"apexGoodsid","visible":true,"editable":false},{"field":"dtlUseflag","visible":true,"editable":true,"cellEditor":"agSelectCellEditor","cellEditorParams":{"values":["原料","辅料"]}},{"field":"apexGoodsname","visible":true,"editable":true},{"field":"spec","visible":true,"editable":true},{"field":"perHl","visible":true,"editable":true},{"field":"exaddMater","visible":true,"editable":true},{"field":"price","visible":true,"editable":true},{"field":"batchQty","visible":true,"editable":false},{"field":"costBatch","visible":true,"editable":false},{"field":"apexFactoryname","visible":true,"editable":true},{"field":"formulaType","visible":false,"editable":false}]', 0, null, 0, '28-JAN-26 05.27.11.346000 PM', '28-JAN-26 05.27.11.346000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (481, 'cost-pinggu', 'material', 'LOOKUP', '[{"field":"apexGoodsname","lookupCode":"costMaterial","mapping":{"apexGoodsid":"goodsid","apexGoodsname":"goodsname","spec":"goodstype","price":"price","apexFactoryname":"factoryname","goodstype":"goodstype","basePrice":"price"}}]', 0, null, 0, '28-JAN-26 05.27.11.688000 PM', '28-JAN-26 05.27.11.688000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (480, 'cost-pinggu', 'material', 'CALC', '[
  {"field":"batchQty","formulaField":"formulaType","formulas":{
    "B":{"expression":"apexPl / 10000","triggerFields":["apexPl"]},
    "C":{"expression":"perHl * apexPl * (1 + exaddMater / 100) / 1000000","triggerFields":["perHl","apexPl","exaddMater"]}
  }},
  {"field":"costBatch","expression":"batchQty * price","triggerFields":["batchQty","price"]}
]', 0, null, 0, '28-JAN-26 05.27.11.569000 PM', '28-JAN-26 05.27.11.569000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (479, 'cost-pinggu', 'material', 'VALIDATION', '[{"field":"perHl","required":true,"min":0.001,"message":"每片含量必填且必须大于0"},{"field":"price","required":true,"min":0,"message":"单价必填且不能为负数"}]', 0, null, 0, '28-JAN-26 05.27.11.457000 PM', '28-JAN-26 05.27.11.457000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (484, 'cost-pinggu', 'package', 'CALC', '[
  {"field":"batchQty","formulaField":"formulaType","formulas":{
    "A":{"expression":"apexPl / pPerpack * (1 + exaddMater)","triggerFields":["apexPl","pPerpack","exaddMater"]},
    "D":{"expression":"perHl * apexPl * (1 + exaddMater / 100) / 1000000","triggerFields":["perHl","apexPl","exaddMater"]},
    "E":{"expression":"ceil(apexPl / (pPerpack * sPerback))","triggerFields":["apexPl","pPerpack","sPerback"]},
    "F":{"expression":"ceil(apexPl / (pPerpack * sPerback * xPerback))","triggerFields":["apexPl","pPerpack","sPerback","xPerback"]}
  }},
  {"field":"costBatch","expression":"batchQty * price","triggerFields":["batchQty","price"]}
]', 0, null, 0, '28-JAN-26 05.27.12.059000 PM', '28-JAN-26 05.27.12.059000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (483, 'cost-pinggu', 'package', 'VALIDATION', '[{"field":"price","min":0,"message":"包材单价不能为负数"}]', 0, null, 0, '28-JAN-26 05.27.11.907000 PM', '28-JAN-26 05.27.11.907000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (482, 'cost-pinggu', 'package', 'COLUMN_OVERRIDE', '[{"field":"id","visible":true,"editable":false},{"field":"masterId","visible":true,"editable":false},{"field":"apexGoodsid","visible":true,"editable":false},{"field":"dtlUseflag","visible":true,"editable":true,"cellEditor":"agSelectCellEditor","cellEditorParams":{"values":["印字包材","非印字包材"]}},{"field":"apexGoodsname","visible":true,"editable":true},{"field":"spec","visible":true,"editable":true},{"field":"suqty","visible":true,"editable":true},{"field":"price","visible":true,"editable":true},{"field":"batchQty","visible":true,"editable":false},{"field":"costBatch","visible":true,"editable":false},{"field":"apexFactoryname","visible":true,"editable":true},{"field":"formulaType","visible":false,"editable":false}]', 0, null, 0, '28-JAN-26 05.27.11.810000 PM', '28-JAN-26 05.27.11.810000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (485, 'cost-pinggu', 'package', 'LOOKUP', '[{"field":"apexGoodsname","lookupCode":"costMaterial","mapping":{"apexGoodsid":"goodsid","apexGoodsname":"goodsname","spec":"goodstype","price":"price","apexFactoryname":"factoryname","suqty":"lastsuqty"}}]', 0, null, 0, '28-JAN-26 05.27.12.212000 PM', '28-JAN-26 05.27.12.212000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (273, 'customer-manage', 'detailTabs', 'RELATION', '{"masterKey":"masterGrid","detailKey":"detailTabs"}', 0, null, 0, '26-JAN-26 05.41.10.122000 PM', '26-JAN-26 05.41.10.122000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (274, 'customer-manage', 'masterGrid', 'COLUMN_OVERRIDE', '[
  {"field":"id","width":null,"editable":true},
  {"field":"customname","width":null,"editable":true,"searchable":true},
  {"field":"zone","width":null,"editable":true},
  {"field":"iserp","visible":false}
]', 0, null, 0, '26-JAN-26 05.41.10.191000 PM', '26-JAN-26 05.41.10.191000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (498, 'customer-manage', 'masterGrid', 'ROW_EDITABLE', '[{"field":"iserp","operator":"ne","value":1}]', 0, null, 0, '29-JAN-26 11.42.06.996000 AM', '29-JAN-26 11.42.06.996000 AM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (276, 'customer-manage', 'masterGrid', 'ROW_CLASS', '[{"field":"iserp","operator":"eq","value":1,"className":"row-confirmed"}]', 0, null, 0, '26-JAN-26 05.41.10.306000 PM', '26-JAN-26 05.41.10.306000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (275, 'customer-manage', 'tranposer', 'COLUMN_OVERRIDE', '[
  {"field":"id","width":null,"editable":true},
  {"field":"customid","visible":false,"editable":false},
  {"field":"tranposname","width":null,"editable":true},
  {"field":"iserp","visible":false}
]', 0, null, 0, '26-JAN-26 05.41.10.270000 PM', '26-JAN-26 05.41.10.270000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (499, 'customer-manage', 'tranposer', 'ROW_EDITABLE', '[{"field":"iserp","operator":"ne","value":1}]', 0, null, 0, '29-JAN-26 11.42.46.966000 AM', '29-JAN-26 11.42.46.966000 AM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (277, 'customer-manage', 'tranposer', 'ROW_CLASS', '[{"field":"iserp","operator":"eq","value":1,"className":"row-confirmed"}]', 0, null, 0, '26-JAN-26 05.41.10.357000 PM', '26-JAN-26 05.41.10.357000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (14, 'dept-manage', 'masterGrid', 'COLUMN_OVERRIDE', '[
        {"field":"id","visible":false,"editable":false},
        {"field":"deptCode","editable":true},
        {"field":"deptName","editable":true},
        {"field":"parentId","editable":true},
        {"field":"sortOrder","editable":true}
    ]', 0, null, 0, '26-JAN-26 09.53.12.747000 AM', '26-JAN-26 09.53.12.747000 AM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (141, 'formoney-manage', 'grid', 'COLUMN_OVERRIDE', '[{"field":"id","visible":false,"editable":false},{"field":"fmopcode","width":null,"editable":true,"searchable":true},{"field":"fmname","width":null,"editable":true,"searchable":true},{"field":"fmsign","width":null,"editable":true},{"field":"fmunit","width":null,"editable":true},{"field":"fmrate","width":null,"editable":true},{"field":"usestatus","width":null,"editable":true}]', 0, null, 0, '26-JAN-26 04.53.18.693000 PM', '26-JAN-26 04.53.18.693000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (516, 'goods-manage', 'grid', 'ROW_CLASS', '[{"field":"iserp","operator":"eq","value":1,"className":"row-confirmed"}]', 0, null, 0, '29-JAN-26 05.12.14.673000 PM', '29-JAN-26 05.12.14.673000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (517, 'goods-manage', 'grid', 'ROW_EDITABLE', '[{"field":"iserp","operator":"ne","value":1}]', 0, null, 0, '29-JAN-26 05.12.14.709000 PM', '29-JAN-26 05.12.14.709000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (513, 'goods-manage', 'grid', 'COLUMN_OVERRIDE', '[
  {"field":"id","visible":true,"editable":false},
  {"field":"goodsno","width":null,"editable":false,"searchable":true},
  {"field":"goodsname","width":null,"editable":true,"searchable":true},
  {"field":"goodstype","width":null,"editable":true,"searchable":true},
  {"field":"packtype","width":null,"editable":true},
  {"field":"tranposid","width":null,"editable":true},
  {"field":"tranposname","width":null,"editable":false},
  {"field":"zxCustomerid","width":null,"editable":true},
  {"field":"customname","width":null,"editable":false},
  {"field":"zone","width":null,"editable":false},
  {"field":"iserp","visible":false},
  {"field":"createBy","visible":false}
]', 0, null, 0, '29-JAN-26 05.12.14.563000 PM', '29-JAN-26 05.12.14.563000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (514, 'goods-manage', 'grid', 'LOOKUP', '[
  {"field":"zxCustomerid","lookupCode":"costCustomer","mapping":{"zxCustomerid":"customid","customname":"customname","zone":"country","tranposid":"tranposid","tranposname":"livery"}}
]', 0, null, 0, '29-JAN-26 05.12.14.595000 PM', '29-JAN-26 05.12.14.595000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (524, 'goods-price-manage', 'grid', 'LOOKUP', '[{"field":"id","lookupCode":"pgoodsByMgoods","noFillback":true,"filterColumn":"GOODSID","filterValueFrom":"cell"}]', 0, null, 0, '29-JAN-26 06.00.39.233000 PM', '29-JAN-26 06.00.39.233000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (521, 'goods-price-manage', 'grid', 'CELL_EDITABLE', '[{"condition":{"field":"iserp","operator":"eq","value":1},"editableFields":["price"]}]', 0, null, 0, '29-JAN-26 05.25.31.072000 PM', '29-JAN-26 05.25.31.072000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (520, 'goods-price-manage', 'grid', 'ROW_CLASS', '[
  {"field":"rowClassFlag","operator":"eq","value":"erp","className":"row-iserp"},
  {"field":"rowClassFlag","operator":"eq","value":"erp-updated","className":"row-iserp-updated"},
  {"field":"rowClassFlag","operator":"eq","value":"erp-price-null","className":"row-iserp-price-null"}
]', 0, null, 0, '29-JAN-26 05.25.31.049000 PM', '29-JAN-26 05.25.31.049000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (519, 'goods-price-manage', 'grid', 'GRID_OPTIONS', '{"rowModelType":"infinite","cacheBlockSize":200,"maxBlocksInCache":10,"sideBar":true}', 0, null, 0, '29-JAN-26 05.25.31.028000 PM', '29-JAN-26 05.25.31.028000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (518, 'goods-price-manage', 'grid', 'COLUMN_OVERRIDE', '[
  {"field":"id","visible":true,"editable":false},
  {"field":"goodsname","width":null,"editable":true,"searchable":true},
  {"field":"price","width":null,"editable":true},
  {"field":"useflag","width":null,"editable":true},
  {"field":"goodstype","width":null,"editable":true},
  {"field":"packtype","width":null,"editable":true},
  {"field":"factoryname","width":null,"editable":true},
  {"field":"iserp","width":null,"editable":false}
]', 0, null, 0, '29-JAN-26 05.25.30.993000 PM', '29-JAN-26 05.25.30.993000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (11, 'user-manage', 'masterGrid', 'COLUMN_OVERRIDE', '[
        {"field":"id","visible":false,"editable":false},
        {"field":"username","editable":true},
        {"field":"realName","editable":true},
        {"field":"email","editable":true},
        {"field":"phone","editable":true},
        {"field":"departmentId","visible":false,"editable":false},
        {"field":"deptName","editable":false},
        {"field":"status","editable":true}
    ]', 0, null, 0, '26-JAN-26 09.53.12.530000 AM', '26-JAN-26 09.53.12.530000 AM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (12, 'user-manage', 'masterGrid', 'LOOKUP', '[
        {"field":"deptName","lookupCode":"department","mapping":{"departmentId":"id","deptName":"deptName"}}
    ]', 0, null, 0, '26-JAN-26 09.53.12.615000 AM', '26-JAN-26 09.53.12.615000 AM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (597, 'wms-shipping', 'detailTabs', 'ROLE_BINDING', '{"role":"DETAIL_TABS"}', 0, null, 0, '05-FEB-26 05.40.28.463000 PM', '05-FEB-26 05.40.28.463000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (598, 'wms-shipping', 'detailTabs', 'RELATION', '{"masterKey":"masterGrid","detailKey":"detailTabs"}', 0, null, 0, '05-FEB-26 05.40.28.503000 PM', '05-FEB-26 05.40.28.503000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (599, 'wms-shipping', 'masterGrid', 'CONTEXT_MENU', '{"items":[{"action":"save"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}', 0, null, 0, '05-FEB-26 05.40.28.539000 PM', '05-FEB-26 05.40.28.539000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (596, 'wms-shipping', 'masterGrid', 'ROLE_BINDING', '{"role":"MASTER_GRID"}', 0, null, 0, '05-FEB-26 05.40.28.425000 PM', '05-FEB-26 05.40.28.425000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (593, 'wms-shipping', 'masterGrid', 'COLUMN_OVERRIDE', '[{"field":"id","visible":false,"editable":false},{"field":"conno","editable":false},{"field":"customname","editable":false},{"field":"targetposname","editable":false},{"field":"inputmanname","editable":false}]', 0, null, 0, '05-FEB-26 05.40.28.306000 PM', '05-FEB-26 05.40.28.306000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (600, 'wms-shipping', 'wmsQty', 'CONTEXT_MENU', '{"items":[{"action":"addRow"},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"save"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}', 0, null, 0, '05-FEB-26 05.40.28.571000 PM', '05-FEB-26 05.40.28.571000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (594, 'wms-shipping', 'wmsQty', 'COLUMN_OVERRIDE', '[{"field":"id","visible":false,"editable":false},{"field":"masterId","visible":false,"editable":false},{"field":"goodsid","visible":false,"editable":false},{"field":"goodsgp","editable":true},{"field":"lotno","editable":false},{"field":"goodsno","editable":false},{"field":"packsize","editable":false},{"field":"qtyShow","editable":false},{"field":"pcs","editable":false}]', 0, null, 0, '05-FEB-26 05.40.28.341000 PM', '05-FEB-26 05.40.28.341000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (601, 'wms-shipping', 'wmsQtyDetail', 'CONTEXT_MENU', '{"items":[{"action":"addRow"},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"save"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}', 0, null, 0, '05-FEB-26 05.40.28.602000 PM', '05-FEB-26 05.40.28.602000 PM', 'system', null);

insert into T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
values (595, 'wms-shipping', 'wmsQtyDetail', 'COLUMN_OVERRIDE', '[{"field":"id","visible":false,"editable":false},{"field":"masterId","visible":false,"editable":false},{"field":"rn","editable":false},{"field":"goodsid","visible":false,"editable":false},{"field":"goodsname","editable":false},{"field":"lotno","editable":false},{"field":"goodsqty","editable":false},{"field":"pcs","editable":false},{"field":"validdate","editable":false},{"field":"containerno","editable":false},{"field":"memo","editable":true},{"field":"jz","editable":true},{"field":"mz","editable":true},{"field":"tj","editable":true}]', 0, null, 0, '05-FEB-26 05.40.28.383000 PM', '05-FEB-26 05.40.28.383000 PM', 'system', null);

prompt Done.
