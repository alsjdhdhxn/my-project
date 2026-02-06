-- ============================================================
-- 客户信息管理元数据初始化
-- ============================================================

-- 表元数据
INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, PARENT_TABLE_CODE, PARENT_FK_COLUMN, AUDIT_ENABLED, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (70, 'CostCustomer', '客户信息', 'T_COST_CUSTOMER_V', 'T_COST_CUSTOMER', 'SEQ_COST_CUSTOMER', 'CUSTOMID', NULL, NULL, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, PARENT_TABLE_CODE, PARENT_FK_COLUMN, AUDIT_ENABLED, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (71, 'CostTranposer', '分销商信息', 'T_COST_TRANPOSER_V', 'T_COST_TRANPOSER', 'SEQ_COST_TRANPOSER', 'TRANPOSID', 'CostCustomer', 'CUSTOMID', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, PARENT_TABLE_CODE, PARENT_FK_COLUMN, AUDIT_ENABLED, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (125, 'CostCustomerLookup', '客户选择', 'V_COST_CUSTOMER_LOOKUP', 'T_COST_CUSTOMER_V', NULL, 'CUSTOMID', NULL, NULL, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- 客户列元数据
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (734, 70, 'id', 'CUSTOMID', '客户ID', 'number', 0, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostCustomer');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (735, 70, 'customname', 'CUSTOMNAME', '客户名称', 'text', 1, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostCustomer');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (736, 70, 'zone', 'ZONE', '区域', 'text', 2, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostCustomer');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (737, 70, 'iserp', 'ISERP', '是否ERP', 'number', 99, 1, 1, 1, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostCustomer');

-- 分销商列元数据
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (738, 71, 'id', 'TRANPOSID', '分销商ID', 'number', 0, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostTranposer');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (739, 71, 'customid', 'CUSTOMID', '客户ID', 'number', 1, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostTranposer');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (740, 71, 'tranposname', 'TRANPOSNAME', '分销商名称', 'text', 2, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostTranposer');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (741, 71, 'iserp', 'ISERP', '是否ERP', 'number', 99, 1, 1, 1, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostTranposer');

-- 客户Lookup列元数据
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1377, 125, 'customid', 'CUSTOMID', '客户ID', 'number', 0, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostCustomerLookup');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1378, 125, 'customname', 'CUSTOMNAME', '客户名称', 'text', 1, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostCustomerLookup');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1379, 125, 'country', 'COUNTRY', '国家', 'text', 2, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostCustomerLookup');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1380, 125, 'livery', 'LIVERY', '分销商', 'text', 3, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostCustomerLookup');

-- 页面组件
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (83, 'customer-manage', 'root', 'LAYOUT', NULL, '{"direction":"vertical","gap":8}', NULL, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (84, 'customer-manage', 'masterGrid', 'GRID', 'root', '{"height":"50%","selectionMode":"single","buttons":[{"action":"addRow","label":"新增"},{"action":"copyRow","label":"复制","requiresRow":true},{"action":"deleteRow","label":"删除","requiresRow":true},{"action":"saveGridConfig","label":"保存列配置"},{"label":"导出","items":[{"action":"exportSelected","label":"导出选中","requiresSelection":true},{"action":"exportCurrent","label":"导出当前页"},{"action":"exportAll","label":"导出全部"},{"action":"resetExportConfig","label":"重置导出配置"},{"action":"openHeaderConfig","label":"配置导出表头"}]},{"action":"save","label":"保存"},{"action":"clipboard.copy","label":"复制"},{"action":"clipboard.paste","label":"粘贴"}]}', 'CostCustomer', 1, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (85, 'customer-manage', 'detailTabs', 'TABS', 'root', '{"mode":"single","tabs":[{"key":"tranposer","title":"分销商","tableCode":"CostTranposer","buttons":[{"action":"addRow","label":"新增"},{"action":"copyRow","label":"复制","requiresRow":true},{"action":"deleteRow","label":"删除","requiresRow":true},{"action":"saveGridConfig","label":"保存列配置"},{"label":"导出","items":[{"action":"exportSelected","label":"导出选中","requiresSelection":true},{"action":"exportCurrent","label":"导出当前页"},{"action":"exportAll","label":"导出全部"},{"action":"resetExportConfig","label":"重置导出配置"},{"action":"openHeaderConfig","label":"配置导出表头"}]},{"action":"save","label":"保存"},{"action":"clipboard.copy","label":"复制"},{"action":"clipboard.paste","label":"粘贴"}]}]}', NULL, 2, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- 页面规则
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (273, 'customer-manage', 'detailTabs', 'RELATION', '{"masterKey":"masterGrid","detailKey":"detailTabs"}', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (274, 'customer-manage', 'masterGrid', 'COLUMN_OVERRIDE', '[{"field":"id","width":null,"editable":true},{"field":"customname","width":null,"editable":true,"searchable":true},{"field":"zone","width":null,"editable":true},{"field":"iserp","visible":false}]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (275, 'customer-manage', 'tranposer', 'COLUMN_OVERRIDE', '[{"field":"id","width":null,"editable":true},{"field":"customid","visible":false,"editable":false},{"field":"tranposname","width":null,"editable":true},{"field":"iserp","visible":false}]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (276, 'customer-manage', 'masterGrid', 'ROW_CLASS', '[{"field":"iserp","operator":"eq","value":1,"className":"row-confirmed"}]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (277, 'customer-manage', 'tranposer', 'ROW_CLASS', '[{"field":"iserp","operator":"eq","value":1,"className":"row-confirmed"}]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (498, 'customer-manage', 'masterGrid', 'ROW_EDITABLE', '[{"field":"iserp","operator":"ne","value":1}]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (499, 'customer-manage', 'tranposer', 'ROW_EDITABLE', '[{"field":"iserp","operator":"ne","value":1}]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- Lookup配置已统一放在 09_Lookup配置.sql 中
