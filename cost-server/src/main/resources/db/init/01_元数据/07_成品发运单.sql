-- ============================================================
-- 成品发运单元数据初始化
-- 包含: WmsConDoc(主表), WmsQty(库存汇总), WmsQtyDetail(库存明细)
-- ============================================================

-- ============================================================
-- 1. 表元数据
-- ============================================================
INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, PARENT_TABLE_CODE, PARENT_FK_COLUMN, AUDIT_ENABLED, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (173, 'WmsConDoc', '成品发运单', 'T_WMS_CON_DOC_V', 'T_WMS_CON_DOC_V', NULL, 'CONID', NULL, NULL, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, PARENT_TABLE_CODE, PARENT_FK_COLUMN, AUDIT_ENABLED, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (174, 'WmsQty', '库存汇总', 'T_WMS_QTY', 'T_WMS_QTY', 'SEQ_WMS_QTY', 'ID', 'WmsConDoc', 'CONID', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, PARENT_TABLE_CODE, PARENT_FK_COLUMN, AUDIT_ENABLED, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (175, 'WmsQtyDetail', '库存明细', 'T_WMS_QTY_DETAIL', 'T_WMS_QTY_DETAIL', 'SEQ_WMS_QTY_DETAIL', 'ID', 'WmsConDoc', 'CONID', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- ============================================================
-- 2. 列元数据 - WmsConDoc (成品发运单主表)
-- ============================================================
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1633, 173, 'id', 'CONID', '合同ID', 'number', 0, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1634, 173, 'conno', 'CONNO', '合同编号', 'text', 1, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1635, 173, 'customname', 'CUSTOMNAME', '客户名称', 'text', 2, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1636, 173, 'targetposname', 'TARGETPOSNAME', '目的地', 'text', 3, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1637, 173, 'inputmanname', 'INPUTMANNAME', '录入人', 'text', 4, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- ============================================================
-- 3. 列元数据 - WmsQty (库存汇总)
-- ============================================================
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1638, 174, 'id', 'ID', 'ID', 'number', 0, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1639, 174, 'masterId', 'CONID', 'CONID', 'CONID', '合同ID', 'number', 1, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1640, 174, 'goodsid', 'GOODSID', '产品ID', 'number', 2, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1641, 174, 'goodsgp', 'GOODSGP', '产品名称', 'text', 3, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1642, 174, 'lotno', 'LOTNO', '批号', 'text', 4, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1643, 174, 'goodsno', 'GOODSNO', '产品编码', 'text', 5, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1644, 174, 'packsize', 'PACKSIZE', '包装规格', 'number', 6, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1645, 174, 'qtyShow', 'QTY_SHOW', '库存显示', 'text', 7, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1646, 174, 'pcs', 'PCS', '件数', 'number', 8, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- ============================================================
-- 4. 列元数据 - WmsQtyDetail (库存明细)
-- ============================================================
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1647, 175, 'id', 'ID', 'ID', 'number', 0, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1648, 175, 'masterId', 'CONID', 'CONID', 'CONID', '合同ID', 'number', 1, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1649, 175, 'rn', 'RN', '序号', 'number', 2, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1650, 175, 'goodsid', 'GOODSID', '产品ID', 'number', 3, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1651, 175, 'goodsname', 'GOODSNAME', '产品名称', 'text', 4, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1652, 175, 'lotno', 'LOTNO', '批号', 'text', 5, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1653, 175, 'goodsqty', 'GOODSQTY', '数量', 'number', 6, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1654, 175, 'pcs', 'PCS', '件数', 'number', 7, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1655, 175, 'validdate', 'VALIDDATE', '有效期', 'date', 8, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1656, 175, 'containerno', 'CONTAINERNO', '柜号', 'text', 9, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1657, 175, 'memo', 'MEMO', '备注', 'text', 10, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1658, 175, 'jz', 'JZ', '净重(KG)', 'number', 11, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1659, 175, 'mz', 'MZ', '毛重(KG)', 'number', 12, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (1660, 175, 'tj', 'TJ', '体积(M3)', 'number', 13, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- ============================================================
-- 5. 页面组件
-- ============================================================
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (173, 'wms-shipping', 'root', 'LAYOUT', NULL, '{"direction":"vertical","gap":8}', NULL, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (174, 'wms-shipping', 'masterGrid', 'GRID', 'root', '{"height":"50%","selectionMode":"single","buttons":[{"action":"syncWmsQty","label":"同步库存","requiresRow":true,"procedure":"P_WMS_SYNC_BY_CONID","params":[{"source":"data.id","mode":"IN","jdbcType":"NUMERIC"}],"refreshMode":"detail"},{"action":"save","label":"保存"},{"action":"clipboard.copy","label":"复制"},{"action":"clipboard.paste","label":"粘贴"}]}', 'WmsConDoc', 1, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (175, 'wms-shipping', 'detailTabs', 'TABS', 'root', '{"mode":"multi","tabs":[{"key":"wmsQty","title":"库存汇总","tableCode":"WmsQty","buttons":[{"action":"batchSelect","label":"从库存添加","batchSelectConfig":{"lookupCode":"wmsQtyLookup","title":"选择库存","mapping":{"goodsid":"goodsid","goodsgp":"goodsgp","lotno":"lotno","goodsno":"goodsno","packsize":"packsize","qtyShow":"qty_show","pcs":"pcs"}}},{"action":"deleteRow","label":"删除","requiresRow":true},{"type":"separator"},{"action":"save","label":"保存"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]},{"key":"wmsQtyDetail","title":"库存明细","tableCode":"WmsQtyDetail","buttons":[{"action":"addRow","label":"新增"},{"action":"deleteRow","label":"删除","requiresRow":true},{"type":"separator"},{"action":"save","label":"保存"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}]}', NULL, 2, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- ============================================================
-- 6. 页面规则 - masterGrid
-- ============================================================
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (593, 'wms-shipping', 'masterGrid', 'COLUMN_OVERRIDE', '[{"field":"id","visible":false,"editable":false},{"field":"conno","editable":false},{"field":"customname","editable":false},{"field":"targetposname","editable":false},{"field":"inputmanname","editable":false}]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (596, 'wms-shipping', 'masterGrid', 'ROLE_BINDING', '{"role":"MASTER_GRID"}', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (599, 'wms-shipping', 'masterGrid', 'CONTEXT_MENU', '{"items":[{"action":"save"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- ============================================================
-- 7. 页面规则 - detailTabs
-- ============================================================
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (597, 'wms-shipping', 'detailTabs', 'ROLE_BINDING', '{"role":"DETAIL_TABS"}', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (598, 'wms-shipping', 'detailTabs', 'RELATION', '{"masterKey":"masterGrid","detailKey":"detailTabs"}', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- ============================================================
-- 8. 页面规则 - wmsQty
-- ============================================================
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (594, 'wms-shipping', 'wmsQty', 'COLUMN_OVERRIDE', '[{"field":"id","visible":false,"editable":false},{"field":"masterId","visible":false,"editable":false},{"field":"goodsid","visible":false,"editable":false},{"field":"goodsgp","editable":true},{"field":"lotno","editable":false},{"field":"goodsno","editable":false},{"field":"packsize","editable":false},{"field":"qtyShow","editable":false},{"field":"pcs","editable":false}]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (600, 'wms-shipping', 'wmsQty', 'CONTEXT_MENU', '{"items":[{"action":"addRow"},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"save"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- ============================================================
-- 9. 页面规则 - wmsQtyDetail
-- ============================================================
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (595, 'wms-shipping', 'wmsQtyDetail', 'COLUMN_OVERRIDE', '[{"field":"id","visible":false,"editable":false},{"field":"masterId","visible":false,"editable":false},{"field":"rn","editable":false},{"field":"goodsid","visible":false,"editable":false},{"field":"goodsname","editable":false},{"field":"lotno","editable":false},{"field":"goodsqty","editable":false},{"field":"pcs","editable":false},{"field":"validdate","editable":false},{"field":"containerno","editable":false},{"field":"memo","editable":true},{"field":"jz","editable":true},{"field":"mz","editable":true},{"field":"tj","editable":true}]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (601, 'wms-shipping', 'wmsQtyDetail', 'CONTEXT_MENU', '{"items":[{"action":"addRow"},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"save"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
