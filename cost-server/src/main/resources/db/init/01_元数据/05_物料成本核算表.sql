-- ============================================================
-- 物料成本核算表元数据初始化
-- 包含: CostPinggu(主表), CostMaterial(原辅料明细), CostPackage(包材明细)
-- ============================================================

-- ============================================================
-- 1. 表元数据
-- ============================================================
INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, PARENT_TABLE_CODE, PARENT_FK_COLUMN, AUDIT_ENABLED, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (121, 'CostPinggu', '物料成本核算表', 'T_COST_PINGGU', 'T_COST_PINGGU', 'SEQ_COST_PINGGU', 'DOCID', NULL, NULL, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, PARENT_TABLE_CODE, PARENT_FK_COLUMN, AUDIT_ENABLED, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (122, 'CostMaterial', '原辅料明细', 'V_COST_PINGGU_MATERIAL', 'T_COST_PINGGU_DTL', 'SEQ_COST_PINGGU_DTL', 'DTLID', 'CostPinggu', 'DOCID', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, PARENT_TABLE_CODE, PARENT_FK_COLUMN, AUDIT_ENABLED, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (123, 'CostPackage', '包材明细', 'V_COST_PINGGU_PACKAGE', 'T_COST_PINGGU_DTL', 'SEQ_COST_PINGGU_DTL', 'DTLID', 'CostPinggu', 'DOCID', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- ============================================================
-- 2. 列元数据 - CostPinggu (物料成本核算表主表)
-- ============================================================
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1313, 121, 'id', 'DOCID', 'ID', 'number', 0, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1446, 121, 'goodsid', 'GOODSID', '产品ID', 'number', 1, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1314, 121, 'goodsname', 'GOODSNAME', '产品名称', 'text', 1, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1315, 121, 'goodsnameEn', 'GOODSNAME_EN', '产品英文名', 'text', 2, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1316, 121, 'strength', 'STRENGTH', '剂量', 'text', 3, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1450, 121, 'customid', 'CUSTOMID', '客户ID', 'number', 4, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1317, 121, 'customname', 'CUSTOMNAME', '客户名称', 'text', 4, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1318, 121, 'country', 'COUNTRY', '国家', 'text', 5, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1319, 121, 'projectno', 'PROJECTNO', '项目号', 'text', 6, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1320, 121, 'apexPl', 'APEX_PL', '批量', 'number', 7, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1321, 121, 'annualQty', 'ANNUAL_QTY', '年需求量', 'number', 8, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1322, 121, 'yield', 'YIELD', '收率(%)', 'number', 9, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1323, 121, 'pPerpack', 'P_PERPACK', '每盒片数', 'number', 10, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1324, 121, 'sPerback', 'S_PERBACK', '每箱装盒数', 'number', 11, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1325, 121, 'xPerback', 'X_PERBACK', '每托盘箱数', 'number', 12, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1326, 121, 'packtype', 'PACKTYPE', '包装形式', 'text', 13, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1327, 121, 'totalYl', 'TOTAL_YL', '原料合计', 'number', 20, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1328, 121, 'totalFl', 'TOTAL_FL', '辅料合计', 'number', 21, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1329, 121, 'totalBc', 'TOTAL_BC', '包材合计', 'number', 22, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1330, 121, 'totalCost', 'TOTAL_COST', '总物料成本', 'number', 23, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1331, 121, 'outPriceRmb', 'OUT_PRICE_RMB', '出厂价(RMB)', 'number', 24, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1332, 121, 'salemoney', 'SALEMONEY', '每批销售额', 'number', 25, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1333, 121, 'jgfBatch', 'JGF_BATCH', '每批加工费', 'number', 26, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1334, 121, 'costPerqp', 'COST_PERQP', '千片成本', 'number', 27, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1443, 121, 'costPerbox', 'COST_PERBOX', '每盒成本', 'number', 28, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1335, 121, 'jgfPerqp', 'JGF_PERQP', '千片加工费', 'number', 28, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1336, 121, 'mlPerqp', 'ML_PERQP', '千片毛利', 'number', 29, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1337, 121, 'yJgRe', 'Y_JG_RE', '年加工费', 'number', 30, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1338, 121, 'yMl', 'Y_ML', '年毛利', 'number', 31, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1339, 121, 'ySale', 'Y_SALE', '年销售额', 'number', 32, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1340, 121, 'fmname', 'FMNAME', '币种', 'text', 33, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1341, 121, 'fmrate', 'FMRATE', '汇率', 'number', 34, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1449, 121, 'memo', 'MEMO', '备注', 'text', 35, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1451, 121, 'livery', 'LIVERY', '分销商', 'text', 36, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1452, 121, 'tranposid', 'TRANPOSID', '分销商ID', 'number', 37, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPinggu');


-- ============================================================
-- 3. 列元数据 - CostMaterial (原辅料明细)
-- ============================================================
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1342, 122, 'id', 'ID', 'DTLID', 'ID', 'number', 0, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostMaterial');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1343, 122, 'masterId', 'MASTER_ID', 'MASTER_ID', 'DOCID', '主表ID', 'number', 1, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostMaterial');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1447, 122, 'apexGoodsid', 'APEX_GOODSID', '物料ID', 'number', 2, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostMaterial');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1344, 122, 'dtlUseflag', 'DTL_USEFLAG', '分类', 'text', 2, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostMaterial');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1345, 122, 'apexGoodsname', 'APEX_GOODSNAME', '物料名称', 'text', 3, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostMaterial');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1346, 122, 'spec', 'SPEC', '规格', 'text', 4, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostMaterial');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1347, 122, 'perHl', 'PER_HL', '每片含量', 'number', 5, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostMaterial');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1348, 122, 'exaddMater', 'EXADD_MATER', '额外投料量', 'number', 6, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostMaterial');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1349, 122, 'price', 'PRICE', '单价', 'number', 7, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostMaterial');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1350, 122, 'batchQty', 'BATCH_QTY', '每批数量', 'number', 8, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostMaterial');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1351, 122, 'costBatch', 'COST_BATCH', '每批成本', 'number', 9, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostMaterial');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1352, 122, 'apexFactoryname', 'APEX_FACTORYNAME', '供应商', 'text', 10, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostMaterial');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1353, 122, 'formulaType', 'FORMULA_TYPE', '公式类型', 'text', 11, 1, 1, 1, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostMaterial');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1444, 122, 'basePrice', 'BASE_PRICE', '参考采购价', 'number', 12, 1, 1, 1, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostMaterial');

-- ============================================================
-- 4. 列元数据 - CostPackage (包材明细)
-- ============================================================
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1354, 123, 'id', 'ID', 'DTLID', 'ID', 'number', 0, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPackage');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, QUERY_COLUMN, TARGET_COLUMN, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1355, 123, 'masterId', 'MASTER_ID', 'MASTER_ID', 'DOCID', '主表ID', 'number', 1, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPackage');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1448, 123, 'apexGoodsid', 'APEX_GOODSID', '物料ID', 'number', 2, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPackage');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1356, 123, 'dtlUseflag', 'DTL_USEFLAG', '包材类型', 'text', 2, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPackage');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1357, 123, 'apexGoodsname', 'APEX_GOODSNAME', '包材名称', 'text', 3, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPackage');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1358, 123, 'spec', 'SPEC', '规格型号', 'text', 4, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPackage');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1359, 123, 'suqty', 'SUQTY', '用量', 'number', 5, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPackage');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1360, 123, 'price', 'PRICE', '包材单价', 'number', 6, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPackage');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1361, 123, 'batchQty', 'BATCH_QTY', '每批数量', 'number', 7, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPackage');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1362, 123, 'costBatch', 'COST_BATCH', '包材成本', 'number', 8, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPackage');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1363, 123, 'apexFactoryname', 'APEX_FACTORYNAME', '包材供应商', 'text', 9, 1, 1, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPackage');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1364, 123, 'formulaType', 'FORMULA_TYPE', '公式类型', 'text', 10, 1, 1, 1, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPackage');
INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, SORTABLE, FILTERABLE, IS_VIRTUAL, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, TABLE_CODE)
VALUES (1445, 123, 'basePrice', 'BASE_PRICE', '参考采购价', 'number', 11, 1, 1, 1, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'CostPackage');


-- ============================================================
-- 5. 页面组件
-- ============================================================
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (113, 'cost-pinggu', 'root', 'LAYOUT', NULL, '{"direction":"vertical","gap":8}', NULL, 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (114, 'cost-pinggu', 'masterGrid', 'GRID', 'root', '{"height":"50%","selectionMode":"single","buttons":[{"action":"addRow","label":"新增"},{"action":"copyRow","label":"复制","requiresRow":true},{"action":"deleteRow","label":"删除","requiresRow":true},{"action":"generateFromBom","label":"由BOM生成明细","requiresRow":true,"procedure":"P_COST_BOM_INSERT","params":[{"source":"data.id","mode":"IN","jdbcType":"NUMERIC"}]},{"action":"syncPrice","label":"同步采购价","procedure":"P_PINGGU_COMPUTE_ALL","params":[]},{"action":"saveGridConfig","label":"保存列配置"},{"action":"save","label":"保存"}]}', 'CostPinggu', 1, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, COMPONENT_CONFIG, REF_TABLE_CODE, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (115, 'cost-pinggu', 'detailTabs', 'TABS', 'root', '{"mode":"multi","tabs":[{"key":"material","title":"原料/辅料","tableCode":"CostMaterial","buttons":[{"action":"addRow","label":"新增"},{"action":"copyRow","label":"复制","requiresRow":true},{"action":"deleteRow","label":"删除","requiresRow":true},{"action":"saveGridConfig","label":"保存列配置"},{"action":"clipboard.copy","label":"复制"},{"action":"clipboard.paste","label":"粘贴"}]},{"key":"package","title":"包材","tableCode":"CostPackage","buttons":[{"action":"addRow","label":"新增"},{"action":"copyRow","label":"复制","requiresRow":true},{"action":"deleteRow","label":"删除","requiresRow":true},{"action":"saveGridConfig","label":"保存列配置"},{"action":"clipboard.copy","label":"复制"},{"action":"clipboard.paste","label":"粘贴"}]}]}', NULL, 2, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- ============================================================
-- 6. 页面规则 - masterGrid
-- ============================================================
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (473, 'cost-pinggu', 'masterGrid', 'COLUMN_OVERRIDE', '[{"field":"id","visible":true,"editable":false},{"field":"goodsid","visible":true,"editable":false},{"field":"goodsname","visible":true,"editable":true,"searchable":true},{"field":"goodsnameEn","visible":true,"editable":true},{"field":"strength","visible":true,"editable":true},{"field":"customid","visible":true,"editable":false},{"field":"customname","visible":true,"editable":true,"searchable":true},{"field":"country","visible":true,"editable":true},{"field":"tranposid","visible":true,"editable":false},{"field":"livery","visible":true,"editable":true},{"field":"projectno","visible":true,"editable":true},{"field":"apexPl","visible":true,"editable":true},{"field":"annualQty","visible":true,"editable":true},{"field":"yield","visible":true,"editable":true},{"field":"pPerpack","visible":true,"editable":true},{"field":"sPerback","visible":true,"editable":true},{"field":"xPerback","visible":true,"editable":true},{"field":"packtype","visible":true,"editable":true},{"field":"totalYl","visible":true,"editable":false},{"field":"totalFl","visible":true,"editable":false},{"field":"totalBc","visible":true,"editable":false},{"field":"totalCost","visible":true,"editable":false},{"field":"outPriceRmb","visible":true,"editable":true},{"field":"salemoney","visible":true,"editable":false},{"field":"jgfBatch","visible":true,"editable":false},{"field":"costPerqp","visible":true,"editable":true},{"field":"jgfPerqp","visible":true,"editable":false},{"field":"mlPerqp","visible":true,"editable":false},{"field":"yJgRe","visible":true,"editable":false},{"field":"yMl","visible":true,"editable":false},{"field":"ySale","visible":true,"editable":false},{"field":"fmname","visible":true,"editable":true},{"field":"fmrate","visible":true,"editable":true},{"field":"memo","visible":true,"editable":true}]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (474, 'cost-pinggu', 'masterGrid', 'VALIDATION', '[]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (475, 'cost-pinggu', 'masterGrid', 'CALC', '[
  {"field":"salemoney","expression":"outPriceRmb / pPerpack * apexPl * (yield / 100)","triggerFields":["outPriceRmb","pPerpack","apexPl","yield"]},
  {"field":"jgfBatch","expression":"salemoney - totalCost","triggerFields":["salemoney","totalCost"]},
  {"field":"costPerbox","expression":"totalCost / apexPl * pPerpack","triggerFields":["totalCost","apexPl","pPerpack"]},
  {"field":"jgfPerqp","expression":"jgfBatch / apexPl * 1000","triggerFields":["jgfBatch","apexPl"]},
  {"field":"mlPerqp","expression":"jgfPerqp - costPerqp","triggerFields":["jgfPerqp","costPerqp"]},
  {"field":"yJgRe","expression":"jgfPerqp / 1000 * annualQty","triggerFields":["jgfPerqp","annualQty"]},
  {"field":"yMl","expression":"mlPerqp / 1000 * annualQty","triggerFields":["mlPerqp","annualQty"]},
  {"field":"ySale","expression":"salemoney / apexPl * annualQty","triggerFields":["salemoney","apexPl","annualQty"]}
]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (476, 'cost-pinggu', 'masterGrid', 'AGGREGATE', '[
  {"sourceField":"costBatch","targetField":"totalYl","algorithm":"SUM","sourceTab":"material","filter":"dtlUseflag === ''原料''"},
  {"sourceField":"costBatch","targetField":"totalFl","algorithm":"SUM","sourceTab":"material","filter":"dtlUseflag === ''辅料''"},
  {"sourceField":"costBatch","targetField":"totalBc","algorithm":"SUM","sourceTab":"package","filter":"dtlUseflag === ''非印字包材'' || dtlUseflag === ''印字包材''"},
  {"targetField":"totalYl","expression":"totalYl > 0 ? totalYl / 1.13 : totalYl"},
  {"targetField":"totalFl","expression":"totalYl > 0 ? totalFl / 1.13 : totalFl"},
  {"targetField":"totalBc","expression":"totalYl > 0 ? totalBc / 1.13 : totalBc"},
  {"targetField":"totalCost","expression":"totalYl + totalFl + totalBc"}
]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (477, 'cost-pinggu', 'masterGrid', 'LOOKUP', '[{"field":"goodsname","lookupCode":"costGoods","mapping":{"goodsid":"goodsid","goodsname":"goodsname","maNo":"maNo","apexPl":"apexPl","mah":"mah","pPerpack":"pPerpack","sPerback":"sPerback","customid":"customid","customname":"customname","memo":"memo","strength":"strength","livery":"livery"}},{"field":"fmname","lookupCode":"formoney","mapping":{"fmname":"fmname","fmrate":"fmrate"}},{"field":"customname","lookupCode":"costCustomer","mapping":{"customid":"customid","customname":"customname","country":"country","tranposid":"tranposid","livery":"livery"}}]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (486, 'cost-pinggu', 'masterGrid', 'ROLE_BINDING', '{"role":"MASTER_GRID"}', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (487, 'cost-pinggu', 'masterGrid', 'GRID_OPTIONS', '{"cellSelection":true,"sideBar":true}', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (544, 'cost-pinggu', 'masterGrid', 'ROW_CLASS', '[{"field":"memo","operator":"eq","value":"ERP未搭建BOM","style":{"backgroundColor":"#ffcccc"}}]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- ============================================================
-- 7. 页面规则 - detailTabs
-- ============================================================
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (488, 'cost-pinggu', 'detailTabs', 'ROLE_BINDING', '{"role":"DETAIL_TABS"}', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (489, 'cost-pinggu', 'detailTabs', 'RELATION', '{"masterKey":"masterGrid","detailKey":"detailTabs"}', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (490, 'cost-pinggu', 'detailTabs', 'BROADCAST', '["apexPl","pPerpack","sPerback","xPerback"]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (491, 'cost-pinggu', 'detailTabs', 'SUMMARY_CONFIG', '{"enabled":true,"groupLabelField":"groupLabel","groupLabelHeader":"分类","summaryColumns":[{"field":"totalAmount","headerName":"汇总金额","width":null},{"field":"rowCount","headerName":"行数","width":null}],"summaryAggregates":[{"sourceField":"costBatch","targetField":"totalAmount","algorithm":"SUM"},{"sourceField":"costBatch","targetField":"rowCount","algorithm":"COUNT"}]}', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- ============================================================
-- 8. 页面规则 - material (原辅料明细)
-- ============================================================
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (478, 'cost-pinggu', 'material', 'COLUMN_OVERRIDE', '[{"field":"id","visible":true,"editable":false},{"field":"masterId","visible":true,"editable":false},{"field":"apexGoodsid","visible":true,"editable":false},{"field":"dtlUseflag","visible":true,"editable":true,"cellEditor":"agSelectCellEditor","cellEditorParams":{"values":["原料","辅料"]}},{"field":"apexGoodsname","visible":true,"editable":true},{"field":"spec","visible":true,"editable":true},{"field":"perHl","visible":true,"editable":true},{"field":"exaddMater","visible":true,"editable":true},{"field":"price","visible":true,"editable":true},{"field":"batchQty","visible":true,"editable":false},{"field":"costBatch","visible":true,"editable":false},{"field":"apexFactoryname","visible":true,"editable":true},{"field":"formulaType","visible":false,"editable":false}]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (479, 'cost-pinggu', 'material', 'VALIDATION', '[{"field":"perHl","required":true,"min":0.001,"message":"每片含量必填且必须大于0"},{"field":"price","required":true,"min":0,"message":"单价必填且不能为负数"}]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (480, 'cost-pinggu', 'material', 'CALC', '[
  {"field":"batchQty","formulaField":"formulaType","formulas":{
    "B":{"expression":"apexPl / 10000","triggerFields":["apexPl"]},
    "C":{"expression":"perHl * apexPl * (1 + exaddMater / 100) / 1000000","triggerFields":["perHl","apexPl","exaddMater"]}
  }},
  {"field":"costBatch","expression":"batchQty * price","triggerFields":["batchQty","price"]}
]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (481, 'cost-pinggu', 'material', 'LOOKUP', '[{"field":"apexGoodsname","lookupCode":"costMaterial","mapping":{"apexGoodsid":"goodsid","apexGoodsname":"goodsname","spec":"goodstype","price":"price","apexFactoryname":"factoryname","goodstype":"goodstype","basePrice":"price"}}]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- ============================================================
-- 9. 页面规则 - package (包材明细)
-- ============================================================
INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (482, 'cost-pinggu', 'package', 'COLUMN_OVERRIDE', '[{"field":"id","visible":true,"editable":false},{"field":"masterId","visible":true,"editable":false},{"field":"apexGoodsid","visible":true,"editable":false},{"field":"dtlUseflag","visible":true,"editable":true,"cellEditor":"agSelectCellEditor","cellEditorParams":{"values":["印字包材","非印字包材"]}},{"field":"apexGoodsname","visible":true,"editable":true},{"field":"spec","visible":true,"editable":true},{"field":"suqty","visible":true,"editable":true},{"field":"price","visible":true,"editable":true},{"field":"batchQty","visible":true,"editable":false},{"field":"costBatch","visible":true,"editable":false},{"field":"apexFactoryname","visible":true,"editable":true},{"field":"formulaType","visible":false,"editable":false}]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (483, 'cost-pinggu', 'package', 'VALIDATION', '[{"field":"price","min":0,"message":"包材单价不能为负数"}]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (484, 'cost-pinggu', 'package', 'CALC', '[
  {"field":"batchQty","formulaField":"formulaType","formulas":{
    "A":{"expression":"apexPl / pPerpack * (1 + exaddMater)","triggerFields":["apexPl","pPerpack","exaddMater"]},
    "D":{"expression":"perHl * apexPl * (1 + exaddMater / 100) / 1000000","triggerFields":["perHl","apexPl","exaddMater"]},
    "E":{"expression":"ceil(apexPl / (pPerpack * sPerback))","triggerFields":["apexPl","pPerpack","sPerback"]},
    "F":{"expression":"ceil(apexPl / (pPerpack * sPerback * xPerback))","triggerFields":["apexPl","pPerpack","sPerback","xPerback"]}
  }},
  {"field":"costBatch","expression":"batchQty * price","triggerFields":["batchQty","price"]}
]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (485, 'cost-pinggu', 'package', 'LOOKUP', '[{"field":"apexGoodsname","lookupCode":"costMaterial","mapping":{"apexGoodsid":"goodsid","apexGoodsname":"goodsname","spec":"goodstype","price":"price","apexFactoryname":"factoryname","suqty":"lastsuqty"}}]', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
