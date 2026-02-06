prompt Importing table T_COST_ROLE...
set feedback off
set define off

insert into T_COST_ROLE (ID, ROLE_CODE, ROLE_NAME, DESCRIPTION)
values (41, '普通用户', '普通用户', '测试用');

insert into T_COST_ROLE (ID, ROLE_CODE, ROLE_NAME, DESCRIPTION)
values (3, 'ADMIN', '系统管理员', '拥有所有权限');

prompt Done.
