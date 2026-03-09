-- ============================================================
-- 物料清单及成本元数据初始化
-- 包含: CostGoodsPrice
-- ============================================================

-- ============================================================
-- 1. 表元数据
-- ============================================================
INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, PARENT_TABLE_CODE, PARENT_FK_COLUMN, AUDIT_ENABLED, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (132, 'CostGoodsPrice', '物料清单及成本', 'T_COST_GOODS_PRICE_V', 'T_COST_GOODS_PRICE', 'SEQ_COST_GOODS_PRICE', 'GOODSID', NULL, NULL, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- ============================================================
-- 2. 列元数据
-- ============================================================
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1426, 132, 'GOODSID', '物料ID', 'number', 0, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1427, 132, 'GOODSNAME', '物料名称', 'text', 1, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1428, 132, 'PRICE', '价格', 'number', 2, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1429, 132, 'USEFLAG', '用途', 'text', 3, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1430, 132, 'GOODSTYPE', '规格', 'text', 4, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1431, 132, 'PACKTYPE', '包装规格', 'text', 5, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1432, 132, 'FACTORYNAME', '供应商', 'text', 6, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1433, 132, 'ISERP', '是否ERP', 'number', 7, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- ============================================================
-- 3. 页面组件
-- ============================================================
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (125, 'goods-price-manage', 'root', 'LAYOUT', NULL, '{"direction":"vertical"}', NULL, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (126, 'goods-price-manage', 'grid', 'GRID', 'root', '{"height":"100%","buttons":[{"action":"addRow","label":"新增"},{"action":"copyRow","label":"复制","requiresRow":true},{"action":"deleteRow","label":"删除","requiresRow":true},{"action":"saveGridConfig","label":"保存列配置"},{"label":"导出","items":[{"action":"exportSelected","label":"导出选中","requiresSelection":true},{"action":"exportCurrent","label":"导出当前页"},{"action":"exportAll","label":"导出全部"},{"action":"resetExportConfig","label":"重置导出配置"},{"action":"openHeaderConfig","label":"配置导出表头"}]},{"action":"save","label":"保存"},{"action":"clipboard.copy","label":"复制"},{"action":"clipboard.paste","label":"粘贴"}]}', 'CostGoodsPrice', 1, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- ============================================================
-- 4. 页面规则
-- ============================================================
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (518, 'goods-price-manage', 'grid', 'COLUMN_OVERRIDE', '[
  {"field":"id","visible":true,"editable":false},
  {"field":"goodsname","width":null,"editable":true,"searchable":true},
  {"field":"price","width":null,"editable":true},
  {"field":"useflag","width":null,"editable":true},
  {"field":"goodstype","width":null,"editable":true},
  {"field":"packtype","width":null,"editable":true},
  {"field":"factoryname","width":null,"editable":true},
  {"field":"iserp","width":null,"editable":false}
]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (519, 'goods-price-manage', 'grid', 'GRID_OPTIONS', '{"rowModelType":"infinite","cacheBlockSize":200,"maxBlocksInCache":10,"sideBar":true}', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (520, 'goods-price-manage', 'grid', 'ROW_CLASS', '[
  {"field":"rowClassFlag","operator":"eq","value":"erp","className":"row-iserp"},
  {"field":"rowClassFlag","operator":"eq","value":"erp-updated","className":"row-iserp-updated"},
  {"field":"rowClassFlag","operator":"eq","value":"erp-price-null","className":"row-iserp-price-null"}
]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (521, 'goods-price-manage', 'grid', 'CELL_EDITABLE', '[{"condition":{"field":"iserp","operator":"eq","value":1},"editableFields":["price"]}]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (524, 'goods-price-manage', 'grid', 'LOOKUP', '[{"field":"id","lookupCode":"pgoodsByMgoods","noFillback":true,"filterColumn":"GOODSID","filterValueFrom":"cell"}]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
