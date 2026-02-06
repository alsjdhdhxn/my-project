prompt Importing table T_COST_ROLE_PAGE...
set feedback off
set define off

insert into T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY, ROLE_CODE)
values (121, 3, 'audit_log', '["*"]', null, null, 'ADMIN');

insert into T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY, ROLE_CODE)
values (62, 3, 'goods-manage', '["*"]', null, null, 'ADMIN');

insert into T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY, ROLE_CODE)
values (65, 3, 'cost-pinggu', '[]', '{"masterGrid":{"id":{},"goodsname":{"editable":false},"goodsnameEn":{"editable":false},"strength":{"editable":false},"customname":{"editable":false},"country":{"editable":false},"projectno":{"editable":false},"apexPl":{"editable":false},"annualQty":{"editable":false},"yield":{"editable":false},"pPerpack":{"editable":false},"sPerback":{"editable":false},"xPerback":{"editable":false},"packtype":{"editable":false},"totalYl":{},"totalFl":{},"totalBc":{},"totalCost":{},"outPriceRmb":{"editable":false},"salemoney":{},"jgfBatch":{},"costPerqp":{"editable":false},"jgfPerqp":{},"mlPerqp":{},"yJgRe":{},"yMl":{},"ySale":{},"fmname":{"editable":false},"fmrate":{"editable":false}}}', '{"mode":"visual","logic":"AND","conditions":[{"field":"CREATE_BY","fieldLabel":"创建人","op":"eq","valueType":"dynamic","value":"${username}"},{"field":"GOODSNAME","fieldLabel":"产品名称","op":"eq","valueType":"static","value":"洒洒水"}],"sql":"CREATE_BY = ${username} AND GOODSNAME = ''洒洒水''"}', 'ADMIN');

insert into T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY, ROLE_CODE)
values (6, 3, 'home', '["*"]', null, null, 'ADMIN');

insert into T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY, ROLE_CODE)
values (23, 3, 'customer-manage', '["*"]', null, null, 'ADMIN');

insert into T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY, ROLE_CODE)
values (63, 3, 'goods-price-manage', '["*"]', null, null, 'ADMIN');

insert into T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY, ROLE_CODE)
values (98, 3, 'cost', '["*"]', null, null, 'ADMIN');

insert into T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY, ROLE_CODE)
values (119, 3, 'user-manage', '["*"]', null, null, 'ADMIN');

insert into T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY, ROLE_CODE)
values (117, 3, 'system', '["*"]', null, null, 'ADMIN');

insert into T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY, ROLE_CODE)
values (21, 3, 'formoney-manage', '["*"]', null, null, 'ADMIN');

insert into T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY, ROLE_CODE)
values (118, 3, 'permission', '["*"]', null, null, 'ADMIN');

insert into T_COST_ROLE_PAGE (ID, ROLE_ID, PAGE_CODE, BUTTON_POLICY, COLUMN_POLICY, ROW_POLICY, ROLE_CODE)
values (120, 3, 'dept-manage', '["*"]', null, null, 'ADMIN');

prompt Done.
