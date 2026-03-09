-- ============================================================
-- 外币汇率管理元数据初始化
-- ============================================================

-- 表元数据
INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, PARENT_TABLE_CODE, PARENT_FK_COLUMN, AUDIT_ENABLED, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (41, 'CostFormoney', '外币管理', 'T_COST_FORMONEY_V', 'T_COST_FORMONEY', 'SEQ_COST_FORMONEY', 'FMID', NULL, NULL, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- 列元数据
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (341, 41, 'FMID', '外币ID', 'number', 0, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (342, 41, 'FMOPCODE', '外币编码', 'text', 1, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (343, 41, 'FMNAME', '外币名称', 'text', 2, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (344, 41, 'FMSIGN', '外币符号', 'text', 3, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (345, 41, 'FMUNIT', '外币单位', 'text', 4, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (346, 41, 'FMRATE', '汇率', 'number', 5, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (347, 41, 'USESTATUS', '使用状态', 'number', 6, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- 页面组件
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (61, 'formoney-manage', 'root', 'LAYOUT', NULL, '{"direction":"vertical","gap":8}', NULL, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (62, 'formoney-manage', 'grid', 'GRID', 'root', '{"height":"100%","selectionMode":"single","buttons":[{"action":"addRow","label":"新增"},{"action":"copyRow","label":"复制","requiresRow":true},{"action":"deleteRow","label":"删除","requiresRow":true},{"action":"saveGridConfig","label":"保存列配置"},{"label":"导出","items":[{"action":"exportSelected","label":"导出选中","requiresSelection":true},{"action":"exportCurrent","label":"导出当前页"},{"action":"exportAll","label":"导出全部"},{"action":"resetExportConfig","label":"重置导出配置"},{"action":"openHeaderConfig","label":"配置导出表头"}]},{"action":"save","label":"保存"},{"action":"clipboard.copy","label":"复制"},{"action":"clipboard.paste","label":"粘贴"},{"action":"SYNC_ERP_RATE","label":"同步ERP汇率","position":"toolbar","type":"primary","sql":"UPDATE T_COST_FORMONEY SET FMRATE = NULL, CREATE_TIME = NULL, UPDATE_TIME = NULL WHERE CREATE_BY = ''system''"}]}', 'CostFormoney', 1, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- 页面规则
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (141, 'formoney-manage', 'grid', 'COLUMN_OVERRIDE', '[{"columnName":"FMID","visible":false,"editable":false},{"columnName":"FMOPCODE","width":null,"editable":true,"searchable":true},{"columnName":"FMNAME","width":null,"editable":true,"searchable":true},{"columnName":"FMSIGN","width":null,"editable":true},{"columnName":"FMUNIT","width":null,"editable":true},{"columnName":"FMRATE","width":null,"editable":true},{"columnName":"USESTATUS","width":null,"editable":true}]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- Lookup配置已统一放在 09_Lookup配置.sql 中
