-- =====================================================
-- 成品发运单 数据库脚本
-- 执行顺序：删除元数据 -> 插入元数据
-- 页面编码：wms-shipping
-- 主表：WmsConDoc (T_WMS_CON_DOC_V) - 视图，只读
-- 从表1：WmsQty (T_WMS_QTY) - 库存汇总
-- 从表2：WmsQtyDetail (T_WMS_QTY_DETAIL) - 库存明细
-- =====================================================

-- =====================================================
-- A. 删除元数据
-- =====================================================
DELETE FROM T_COST_PAGE_COMPONENT WHERE PAGE_CODE = 'wms-shipping';
DELETE FROM T_COST_PAGE_RULE WHERE PAGE_CODE = 'wms-shipping';
DELETE FROM T_COST_COLUMN_METADATA WHERE TABLE_METADATA_ID IN (
  SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE IN ('WmsConDoc', 'WmsQty', 'WmsQtyDetail')
);
DELETE FROM T_COST_TABLE_METADATA WHERE TABLE_CODE IN ('WmsConDoc', 'WmsQty', 'WmsQtyDetail');
DELETE FROM T_COST_RESOURCE WHERE PAGE_CODE = 'wms-shipping';
COMMIT;

-- =====================================================
-- B. 插入表元数据
-- =====================================================
DECLARE
    v_master_id NUMBER;
    v_qty_id NUMBER;
    v_detail_id NUMBER;
BEGIN
    -- 主表元数据（视图，只读）
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_master_id FROM DUAL;
    INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, PK_COLUMN, CREATE_BY)
    VALUES (v_master_id, 'WmsConDoc', '成品发运单', 'T_WMS_CON_DOC_V', 'T_WMS_CON_DOC_V', 'CONID', 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'id', 'CONID', '合同ID', 'number', 0, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'conno', 'CONNO', '合同编号', 'text', 1, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'customname', 'CUSTOMNAME', '客户名称', 'text', 2, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'targetposname', 'TARGETPOSNAME', '目的地', 'text', 3, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'inputmanname', 'INPUTMANNAME', '录入人', 'text', 4, 'system');

    -- 库存汇总从表元数据
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_qty_id FROM DUAL;
    INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, PARENT_TABLE_CODE, PARENT_FK_COLUMN, CREATE_BY)
    VALUES (v_qty_id, 'WmsQty', '库存汇总', 'T_WMS_QTY', 'T_WMS_QTY', 'SEQ_WMS_QTY', 'ID', 'WmsConDoc', 'CONID', 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_qty_id, 'id', 'ID', 'ID', 'number', 0, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_qty_id, 'masterId', 'CONID', 'CONID', 'CONID', '合同ID', 'number', 1, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_qty_id, 'goodsid', 'GOODSID', '产品ID', 'number', 2, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_qty_id, 'goodsgp', 'GOODSGP', '产品名称', 'text', 3, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_qty_id, 'lotno', 'LOTNO', '批号', 'text', 4, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_qty_id, 'goodsno', 'GOODSNO', '产品编码', 'text', 5, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_qty_id, 'packsize', 'PACKSIZE', '包装规格', 'number', 6, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_qty_id, 'qtyShow', 'QTY_SHOW', '库存显示', 'text', 7, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_qty_id, 'pcs', 'PCS', '件数', 'number', 8, 'system');

    -- 库存明细从表元数据
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_detail_id FROM DUAL;
    INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, PARENT_TABLE_CODE, PARENT_FK_COLUMN, CREATE_BY)
    VALUES (v_detail_id, 'WmsQtyDetail', '库存明细', 'T_WMS_QTY_DETAIL', 'T_WMS_QTY_DETAIL', 'SEQ_WMS_QTY_DETAIL', 'ID', 'WmsConDoc', 'CONID', 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'id', 'ID', 'ID', 'number', 0, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'masterId', 'CONID', 'CONID', 'CONID', '合同ID', 'number', 1, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'rn', 'RN', '序号', 'number', 2, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'goodsid', 'GOODSID', '产品ID', 'number', 3, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'goodsname', 'GOODSNAME', '产品名称', 'text', 4, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'lotno', 'LOTNO', '批号', 'text', 5, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'goodsqty', 'GOODSQTY', '数量', 'number', 6, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'pcs', 'PCS', '件数', 'number', 7, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'validdate', 'VALIDDATE', '有效期', 'date', 8, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'containerno', 'CONTAINERNO', '柜号', 'text', 9, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'memo', 'MEMO', '备注', 'text', 10, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'jz', 'JZ', '净重(KG)', 'number', 11, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'mz', 'MZ', '毛重(KG)', 'number', 12, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'tj', 'TJ', '体积(M³)', 'number', 13, 'system');
    COMMIT;
END;
/

-- =====================================================
-- C. 插入页面规则
-- =====================================================
-- 主表列规则（只读）
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY) VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'wms-shipping', 'masterGrid', 'COLUMN_OVERRIDE', '[{"field":"id","visible":false,"editable":false},{"field":"conno","editable":false},{"field":"customname","editable":false},{"field":"targetposname","editable":false},{"field":"inputmanname","editable":false}]', 'system');

-- 库存汇总列规则
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY) VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'wms-shipping', 'wmsQty', 'COLUMN_OVERRIDE', '[{"field":"id","visible":false,"editable":false},{"field":"masterId","visible":false,"editable":false},{"field":"goodsid","visible":false,"editable":false},{"field":"goodsgp","editable":true},{"field":"lotno","editable":false},{"field":"goodsno","editable":false},{"field":"packsize","editable":false},{"field":"qtyShow","editable":false},{"field":"pcs","editable":false}]', 'system');

-- 库存明细列规则
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY) VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'wms-shipping', 'wmsQtyDetail', 'COLUMN_OVERRIDE', '[{"field":"id","visible":false,"editable":false},{"field":"masterId","visible":false,"editable":false},{"field":"rn","editable":false},{"field":"goodsid","visible":false,"editable":false},{"field":"goodsname","editable":false},{"field":"lotno","editable":false},{"field":"goodsqty","editable":false},{"field":"pcs","editable":false},{"field":"validdate","editable":false},{"field":"containerno","editable":false},{"field":"memo","editable":true},{"field":"jz","editable":true},{"field":"mz","editable":true},{"field":"tj","editable":true}]', 'system');

-- 主表角色绑定
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY) VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'wms-shipping', 'masterGrid', 'ROLE_BINDING', '{"role":"MASTER_GRID"}', 'system');

-- 从表角色绑定和主从关联
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY) VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'wms-shipping', 'detailTabs', 'ROLE_BINDING', '{"role":"DETAIL_TABS"}', 'system');
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY) VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'wms-shipping', 'detailTabs', 'RELATION', '{"masterKey":"masterGrid","detailKey":"detailTabs"}', 'system');

-- 右键菜单
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY) VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'wms-shipping', 'wmsQty', 'CONTEXT_MENU', '{"items":[{"action":"save"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}', 'system');
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY) VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'wms-shipping', 'wmsQtyDetail', 'CONTEXT_MENU', '{"items":[{"action":"addRow"},{"action":"deleteRow","requiresRow":true},{"type":"separator"},{"action":"save"},{"type":"separator"},{"action":"clipboard.copy"},{"action":"clipboard.paste"}]}', 'system');

COMMIT;

-- =====================================================
-- D. 插入页面组件
-- =====================================================
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'wms-shipping', 'root', 'LAYOUT', NULL, 0, '{"direction":"vertical","gap":8}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'wms-shipping', 'masterGrid', 'GRID', 'root', 1, 'WmsConDoc', '{"height":"50%","selectionMode":"single"}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'wms-shipping', 'detailTabs', 'TABS', 'root', 2, '{"mode":"multi","tabs":[{"key":"wmsQty","title":"库存汇总","tableCode":"WmsQty"},{"key":"wmsQtyDetail","title":"库存明细","tableCode":"WmsQtyDetail"}]}', 'system');

COMMIT;

-- =====================================================
-- E. 插入菜单资源
-- =====================================================
INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'wms-shipping', '成品发运单', 'PAGE', 'wms-shipping', 'mdi:truck-delivery', '/wms/shipping', NULL, 100, 'system');

COMMIT;
