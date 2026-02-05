-- =====================================================
-- 07_物料清单及成本初始化.sql
-- 成本管理系统 - 物料清单及成本功能初始化
-- 页面: goods-price-manage
-- =====================================================

-- 1. 表元数据
DELETE FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostGoodsPrice';

INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, PARENT_TABLE_CODE, PARENT_FK_COLUMN, AUDIT_ENABLED, VALIDATION_RULES, ACTION_RULES, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) 
VALUES (132, 'CostGoodsPrice', '物料清单及成本', 'T_COST_GOODS_PRICE_V', 'T_COST_GOODS_PRICE', 'SEQ_COST_GOODS_PRICE', 'GOODSID', NULL, NULL, 0, NULL, NULL, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);

-- 2. 列元数据
DELETE FROM T_COST_COLUMN_METADATA WHERE TABLE_METADATA_ID = 132;

INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DICT_TYPE, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) VALUES (1426, 132, 'id', 'GOODSID', NULL, NULL, '物料ID', 'number', 0, 1, 1, 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DICT_TYPE, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) VALUES (1427, 132, 'goodsname', 'GOODSNAME', NULL, NULL, '物料名称', 'text', 1, 1, 1, 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DICT_TYPE, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) VALUES (1428, 132, 'price', 'PRICE', NULL, NULL, '价格', 'number', 2, 1, 1, 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DICT_TYPE, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) VALUES (1429, 132, 'useflag', 'USEFLAG', NULL, NULL, '用途', 'text', 3, 1, 1, 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DICT_TYPE, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) VALUES (1430, 132, 'goodstype', 'GOODSTYPE', NULL, NULL, '规格', 'text', 4, 1, 1, 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DICT_TYPE, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) VALUES (1431, 132, 'packtype', 'PACKTYPE', NULL, NULL, '包装规格', 'text', 5, 1, 1, 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DICT_TYPE, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) VALUES (1432, 132, 'factoryname', 'FACTORYNAME', NULL, NULL, '供应商', 'text', 6, 1, 1, 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DICT_TYPE, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) VALUES (1433, 132, 'iserp', 'ISERP', NULL, NULL, '是否ERP', 'number', 7, 1, 1, 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);

-- 3. 页面组件
DELETE FROM T_COST_PAGE_COMPONENT WHERE PAGE_CODE = 'goods-price-manage';

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SLOT_NAME, SORT_ORDER, DELETED, DESCRIPTION, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) VALUES (125, 'goods-price-manage', 'root', 'LAYOUT', NULL, '{"direction":"vertical"}', NULL, NULL, 0, 0, NULL, SYSDATE, SYSDATE, 'system', NULL);
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SLOT_NAME, SORT_ORDER, DELETED, DESCRIPTION, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) VALUES (126, 'goods-price-manage', 'grid', 'GRID', 'root', '{"height":"100%","buttons":[{"action":"addRow","label":"新增"},{"action":"copyRow","label":"复制","requiresRow":true},{"action":"deleteRow","label":"删除","requiresRow":true},{"action":"saveGridConfig","label":"保存列配置"},{"label":"导出","items":[{"action":"exportSelected","label":"导出选中","requiresSelection":true},{"action":"exportCurrent","label":"导出当前页"},{"action":"exportAll","label":"导出全部"},{"action":"resetExportConfig","label":"重置导出配置"},{"action":"openHeaderConfig","label":"配置导出表头"}]},{"action":"save","label":"保存"},{"action":"clipboard.copy","label":"复制"},{"action":"clipboard.paste","label":"粘贴"}]}', 'CostGoodsPrice', NULL, 1, 0, NULL, SYSDATE, SYSDATE, 'system', NULL);

-- 4. 页面规则
DELETE FROM T_COST_PAGE_RULE WHERE PAGE_CODE = 'goods-price-manage';

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) VALUES (518, 'goods-price-manage', 'grid', 'COLUMN_OVERRIDE', '[{"field":"id","visible":true,"editable":false},{"field":"goodsname","width":null,"editable":true,"searchable":true},{"field":"price","width":null,"editable":true},{"field":"useflag","width":null,"editable":true},{"field":"goodstype","width":null,"editable":true},{"field":"packtype","width":null,"editable":true},{"field":"factoryname","width":null,"editable":true},{"field":"iserp","width":null,"editable":false}]', 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) VALUES (519, 'goods-price-manage', 'grid', 'GRID_OPTIONS', '{"rowModelType":"infinite","cacheBlockSize":200,"maxBlocksInCache":10,"sideBar":true}', 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) VALUES (520, 'goods-price-manage', 'grid', 'ROW_CLASS', '[{"field":"rowClassFlag","operator":"eq","value":"erp","className":"row-iserp"},{"field":"rowClassFlag","operator":"eq","value":"erp-updated","className":"row-iserp-updated"},{"field":"rowClassFlag","operator":"eq","value":"erp-price-null","className":"row-iserp-price-null"}]', 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) VALUES (521, 'goods-price-manage', 'grid', 'CELL_EDITABLE', '[{"condition":{"field":"iserp","operator":"eq","value":1},"editableFields":["price"]}]', 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DESCRIPTION, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) VALUES (524, 'goods-price-manage', 'grid', 'LOOKUP', '[{"field":"id","lookupCode":"pgoodsByMgoods","noFillback":true,"filterColumn":"GOODSID","filterValueFrom":"cell"}]', 0, NULL, 0, SYSDATE, SYSDATE, 'system', NULL);

-- 5. Lookup配置
DELETE FROM T_COST_LOOKUP_CONFIG WHERE LOOKUP_CODE IN ('costMaterial', 'pgoodsByMgoods');

INSERT INTO T_COST_LOOKUP_CONFIG (ID, LOOKUP_CODE, LOOKUP_NAME, DATA_SOURCE, DISPLAY_COLUMNS, VALUE_FIELD, LABEL_FIELD, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) VALUES (78, 'costMaterial', '物料选择', 'T_COST_GOODS_PRICE_V', '[{"field":"goodsname","header":"物料名称","width":200},{"field":"useflag","header":"用途","width":80},{"field":"goodstype","header":"规格","width":150},{"field":"price","header":"单价","width":100},{"field":"factoryname","header":"供应商","width":150}]', 'goodsid', 'goodsname', 0, SYSDATE, SYSDATE, 'system', NULL);
INSERT INTO T_COST_LOOKUP_CONFIG (ID, LOOKUP_CODE, LOOKUP_NAME, DATA_SOURCE, DISPLAY_COLUMNS, VALUE_FIELD, LABEL_FIELD, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY) VALUES (101, 'pgoodsByMgoods', '产品选择(按物料)', 'V_COST_PGOODS_BY_MGOODS', '[{"field":"goodsid","header":"物料ID"},{"field":"apexGoodsname","header":"物料名称"},{"field":"dtlUseflag","header":"生产属性"},{"field":"factoryname","header":"厂家"},{"field":"price","header":"价格"},{"field":"goodsno","header":"华益代码"},{"field":"pgoodsid","header":"成品ID"},{"field":"pgoodsno","header":"成品编码"},{"field":"goodsname","header":"成品名称"},{"field":"apexPl","header":"批量"},{"field":"batchQty","header":"每批用量"}]', 'goodsid', 'apexGoodsname', 0, SYSDATE, SYSDATE, 'system', NULL);

COMMIT;
