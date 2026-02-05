-- =====================================================
-- 装箱发运单 初始化脚本
-- =====================================================
-- 数据来源：ERP视图（bms_sa_con_doc_v@hyerp、wms_st_qty_lst_baseunit_v@to_wms）
-- =====================================================

-- =====================================================
-- A. 删除视图
-- =====================================================
BEGIN EXECUTE IMMEDIATE 'DROP VIEW T_WMS_CON_DOC_V'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP VIEW T_WMS_QTY_V'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP VIEW T_WMS_QTY_DTL_V'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- =====================================================
-- B. 删除元数据
-- =====================================================
DELETE FROM T_COST_PAGE_RULE WHERE PAGE_CODE = 'wms-con-doc';
DELETE FROM T_COST_PAGE_COMPONENT WHERE PAGE_CODE = 'wms-con-doc';
DELETE FROM T_COST_COLUMN_METADATA WHERE TABLE_METADATA_ID IN (
  SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE IN ('WmsConDoc', 'WmsQty', 'WmsQtyDtl')
);
DELETE FROM T_COST_TABLE_METADATA WHERE TABLE_CODE IN ('WmsConDoc', 'WmsQty', 'WmsQtyDtl');
DELETE FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'wms-con-doc';
COMMIT;

-- =====================================================
-- C. 创建视图
-- =====================================================

-- 装箱发运单主表视图
CREATE OR REPLACE VIEW T_WMS_CON_DOC_V AS
SELECT a.conid,
       a.conno,
       a.customname,
       a.targetposname,
       a.inputmanname,
       0 AS DELETED,
       NULL AS CREATE_TIME,
       NULL AS UPDATE_TIME,
       NULL AS CREATE_BY,
       NULL AS UPDATE_BY
  FROM bms_sa_con_doc_v@hyerp a;

-- 装箱发运数量汇总视图
CREATE OR REPLACE VIEW T_WMS_QTY_V AS
SELECT
    NVL(TO_CHAR(a.conid), '-') || '-' || NVL(TO_CHAR(a.goodsid), '-') || '-' || NVL(a.lotno, '-') || '-' || NVL(TO_CHAR(a.packtype), '-') AS ID,
    a.conid,
    a.goodsid,
    a.goodsno,
    a.goodsname,
    a.lotno,
    a.packtype,
    b.goodsqty_total,
    b.goodsqty_oddtray1,
    b.packname,
    TO_CHAR(NVL(b.goodsqty_total, 0)) || b.packname
    || '（'
    || CASE
         WHEN NVL(b.goodsqty_oddtray1, 0) > 0
         THEN '含零头' || TO_CHAR(b.goodsqty_oddtray1) || b.packname || '，'
       END
    || '样品__' || b.packname
    || '）' AS QTY_SHOW,
    0 AS DELETED,
    NULL AS CREATE_TIME,
    NULL AS UPDATE_TIME,
    NULL AS CREATE_BY,
    NULL AS UPDATE_BY
FROM bms_sa_con_dtl_v@hyerp a,
     (
       SELECT
           x.goodsownid,
           x.lotno,
           x.packname,
           SUM(x.goodsqty) AS goodsqty_total,
           SUM(CASE WHEN x.oddtray = 1 THEN x.goodsqty ELSE 0 END) AS goodsqty_oddtray1
       FROM wms_st_qty_lst_baseunit_v@to_wms x
       GROUP BY x.goodsownid, x.lotno, x.packname
     ) b
WHERE a.goodsid = b.goodsownid(+)
  AND a.lotno   = b.lotno(+);

-- 装箱发运数量明细视图
CREATE OR REPLACE VIEW T_WMS_QTY_DTL_V AS
SELECT
    NVL(TO_CHAR(a.conid), '-') || '-' || NVL(TO_CHAR(a.goodsid), '-') || '-' || NVL(a.lotno, '-') || '-' || NVL(TO_CHAR(b.packsize), '-') AS ID,
    NVL(b.goodsownid, a.goodsid) AS GOODSOWNID,
    b.goodsname,
    NVL(b.lotno, a.lotno) AS LOTNO,
    b.goodsqty,
    b.packsize,
    CEIL(b.goodsqty / NULLIF(b.packsize, 0)) AS QTY_BOX,
    b.validdate,
    NULL AS MEMO,
    NULL AS GROSS_WEIGHT_KG,
    NULL AS NET_WEIGHT_KG,
    NULL AS VOLUME_M2,
    a.conid,
    0 AS DELETED,
    NULL AS CREATE_TIME,
    NULL AS UPDATE_TIME,
    NULL AS CREATE_BY,
    NULL AS UPDATE_BY
FROM bms_sa_con_dtl_v@hyerp a, wms_st_qty_lst_baseunit_v@to_wms b
WHERE a.goodsid = b.goodsownid(+)
  AND a.lotno   = b.lotno(+);

COMMIT;

-- =====================================================
-- D. 插入表元数据
-- =====================================================

-- 装箱发运单主表元数据
DECLARE
    v_wms_con_doc_id NUMBER;
BEGIN
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_wms_con_doc_id FROM DUAL;
    INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, CREATE_BY)
    VALUES (v_wms_con_doc_id, 'WmsConDoc', '装箱发运单', 'T_WMS_CON_DOC_V', 'T_WMS_CON_DOC_V', 'SEQ_WMS_CON_DOC', 'CONID', 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_con_doc_id, 'id', 'CONID', '单据ID', 'number', 0, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_con_doc_id, 'conno', 'CONNO', '装箱单号', 'text', 1, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_con_doc_id, 'customname', 'CUSTOMNAME', '客户名称', 'text', 2, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_con_doc_id, 'targetposname', 'TARGETPOSNAME', '目的地', 'text', 3, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_con_doc_id, 'inputmanname', 'INPUTMANNAME', '录入人', 'text', 4, 'system');
    COMMIT;
END;
/

-- 装箱发运数量汇总元数据
DECLARE
    v_wms_qty_id NUMBER;
BEGIN
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_wms_qty_id FROM DUAL;
    INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, PARENT_TABLE_CODE, PARENT_FK_COLUMN, CREATE_BY)
    VALUES (v_wms_qty_id, 'WmsQty', '装箱数量汇总', 'T_WMS_QTY_V', 'T_WMS_QTY_V', 'SEQ_WMS_QTY', 'ID', 'WmsConDoc', 'CONID', 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_id, 'id', 'ID', 'ID', 'text', 0, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_id, 'conid', 'CONID', '单据ID', 'number', 1, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_id, 'goodsid', 'GOODSID', '产品ID', 'number', 2, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_id, 'goodsno', 'GOODSNO', '产品编码', 'text', 3, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_id, 'goodsname', 'GOODSNAME', '产品名称', 'text', 4, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_id, 'lotno', 'LOTNO', '批号', 'text', 5, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_id, 'packtype', 'PACKTYPE', '包装规格', 'text', 6, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_id, 'goodsqtyTotal', 'GOODSQTY_TOTAL', '总数量', 'number', 7, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_id, 'goodsqtyOddtray1', 'GOODSQTY_ODDTRAY1', '零头数量', 'number', 8, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_id, 'packname', 'PACKNAME', '包装单位', 'text', 9, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_id, 'qtyShow', 'QTY_SHOW', '数量展示', 'text', 10, 'system');
    COMMIT;
END;
/

-- 装箱发运数量明细元数据
DECLARE
    v_wms_qty_dtl_id NUMBER;
BEGIN
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_wms_qty_dtl_id FROM DUAL;
    INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, PARENT_TABLE_CODE, PARENT_FK_COLUMN, CREATE_BY)
    VALUES (v_wms_qty_dtl_id, 'WmsQtyDtl', '装箱数量明细', 'T_WMS_QTY_DTL_V', 'T_WMS_QTY_DTL_V', 'SEQ_WMS_QTY_DTL', 'ID', 'WmsConDoc', 'CONID', 'system');

    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_dtl_id, 'id', 'ID', 'ID', 'text', 0, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_dtl_id, 'conid', 'CONID', '单据ID', 'number', 1, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_dtl_id, 'goodsownid', 'GOODSOWNID', '产品ID', 'number', 2, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_dtl_id, 'goodsname', 'GOODSNAME', '产品名称', 'text', 3, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_dtl_id, 'lotno', 'LOTNO', '批号', 'text', 4, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_dtl_id, 'goodsqty', 'GOODSQTY', '数量', 'number', 5, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_dtl_id, 'packsize', 'PACKSIZE', '包装规格', 'number', 6, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_dtl_id, 'qtyBox', 'QTY_BOX', '数量（箱）', 'number', 7, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_dtl_id, 'validdate', 'VALIDDATE', '有效期', 'date', 8, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_dtl_id, 'memo', 'MEMO', '备注', 'text', 9, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_dtl_id, 'grossWeightKg', 'GROSS_WEIGHT_KG', '毛重(kg)', 'number', 10, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_dtl_id, 'netWeightKg', 'NET_WEIGHT_KG', '净重(kg)', 'number', 11, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, CREATE_BY) VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_wms_qty_dtl_id, 'volumeM2', 'VOLUME_M2', '体积(m2)', 'number', 12, 'system');
    COMMIT;
END;
/

-- =====================================================
-- E. 插入页面组件
-- =====================================================
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'wms-con-doc', 'root', 'LAYOUT', NULL, 0, '{"direction":"vertical","gap":8}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'wms-con-doc', 'masterGrid', 'GRID', 'root', 1, 'WmsConDoc', '{"height":"50%","selectionMode":"single"}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'wms-con-doc', 'detailTabs', 'TABS', 'root', 2,
'{"mode":"multi","tabs":[{"key":"qty","title":"数量汇总","tableCode":"WmsQty"},{"key":"qtyDtl","title":"数量明细","tableCode":"WmsQtyDtl"}]}', 'system');

COMMIT;

-- =====================================================
-- F. 插入页面规则
-- =====================================================

-- 主表列配置
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'wms-con-doc', 'masterGrid', 'COLUMN_OVERRIDE',
'[{"field":"id","visible":false,"editable":false},{"field":"conno","width":null,"editable":false,"searchable":true},{"field":"customname","width":null,"editable":false,"searchable":true},{"field":"targetposname","width":null,"editable":false},{"field":"inputmanname","width":null,"editable":false}]', 'system');

-- 主从关系
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'wms-con-doc', 'detailTabs', 'RELATION',
'{"masterKey":"masterGrid","detailKey":"detailTabs"}', 'system');

-- 数量汇总列配置
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'wms-con-doc', 'qty', 'COLUMN_OVERRIDE',
'[{"field":"id","visible":false,"editable":false},{"field":"conid","visible":false,"editable":false},{"field":"goodsid","width":null,"editable":false},{"field":"goodsno","width":null,"editable":false},{"field":"goodsname","width":null,"editable":false},{"field":"lotno","width":null,"editable":false},{"field":"packtype","width":null,"editable":false},{"field":"goodsqtyTotal","width":null,"editable":false},{"field":"goodsqtyOddtray1","width":null,"editable":false},{"field":"packname","width":null,"editable":false},{"field":"qtyShow","width":null,"editable":false}]', 'system');

-- 数量明细列配置
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, CREATE_BY)
VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, 'wms-con-doc', 'qtyDtl', 'COLUMN_OVERRIDE',
'[{"field":"id","visible":false,"editable":false},{"field":"conid","visible":false,"editable":false},{"field":"goodsownid","width":null,"editable":false},{"field":"goodsname","width":null,"editable":false},{"field":"lotno","width":null,"editable":false},{"field":"goodsqty","width":null,"editable":false},{"field":"packsize","width":null,"editable":false},{"field":"qtyBox","width":null,"editable":false},{"field":"validdate","width":null,"editable":false},{"field":"memo","width":null,"editable":false},{"field":"grossWeightKg","width":null,"editable":false},{"field":"netWeightKg","width":null,"editable":false},{"field":"volumeM2","width":null,"editable":false}]', 'system');

COMMIT;

-- =====================================================
-- G. 插入菜单资源
-- =====================================================
DECLARE
    v_cost_id NUMBER;
BEGIN
    SELECT ID INTO v_cost_id FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'cost-manage' AND ROWNUM = 1;
    INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
    VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'wms-con-doc', '装箱发运单', 'PAGE', 'wms-con-doc', 'mdi:truck', '/cost/wms-con-doc', v_cost_id, 5, 'system');
    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
        VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'wms-con-doc', '装箱发运单', 'PAGE', 'wms-con-doc', 'mdi:truck', '/cost/wms-con-doc', NULL, 5, 'system');
        COMMIT;
END;
/
