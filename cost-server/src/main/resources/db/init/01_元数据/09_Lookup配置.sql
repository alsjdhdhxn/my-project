-- ============================================================
-- Lookup配置初始化
-- 包含: 所有弹窗选择器配置
-- ============================================================

-- 部门选择
INSERT INTO T_COST_LOOKUP_CONFIG (ID, LOOKUP_CODE, LOOKUP_NAME, DATA_SOURCE, DISPLAY_COLUMNS, VALUE_FIELD, LABEL_FIELD, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (3, 'department', '部门选择', 'T_COST_DEPARTMENT', '[{"field":"deptCode","header":"部门编码","width":120},{"field":"deptName","header":"部门名称","width":200}]', 'id', 'deptName', 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- 产品选择
INSERT INTO T_COST_LOOKUP_CONFIG (ID, LOOKUP_CODE, LOOKUP_NAME, DATA_SOURCE, DISPLAY_COLUMNS, VALUE_FIELD, LABEL_FIELD, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (77, 'costGoods', '产品选择', 'V_COST_GOODS_LOOKUP', '[{"field":"goodsid","header":"产品ID","width":80},{"field":"goodsname","header":"产品名称","width":200},{"field":"maNo","header":"批准文号","width":150},{"field":"apexPl","header":"批量","width":80},{"field":"mah","header":"持证商","width":150},{"field":"pPerpack","header":"每盒片数","width":100},{"field":"sPerback","header":"每箱装盒数","width":100},{"field":"customid","header":"客户ID","width":80},{"field":"customname","header":"客户名称","width":150},{"field":"memo","header":"BOM状态","width":120},{"field":"strength","header":"剂量","width":100},{"field":"livery","header":"分销商","width":150}]', 'goodsid', 'goodsname', 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- 物料选择
INSERT INTO T_COST_LOOKUP_CONFIG (ID, LOOKUP_CODE, LOOKUP_NAME, DATA_SOURCE, DISPLAY_COLUMNS, VALUE_FIELD, LABEL_FIELD, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (78, 'costMaterial', '物料选择', 'T_COST_GOODS_PRICE_V', '[{"field":"goodsname","header":"物料名称","width":200},{"field":"useflag","header":"用途","width":80},{"field":"goodstype","header":"规格","width":150},{"field":"price","header":"单价","width":100},{"field":"factoryname","header":"供应商","width":150}]', 'goodsid', 'goodsname', 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- 币种选择
INSERT INTO T_COST_LOOKUP_CONFIG (ID, LOOKUP_CODE, LOOKUP_NAME, DATA_SOURCE, DISPLAY_COLUMNS, VALUE_FIELD, LABEL_FIELD, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (79, 'formoney', '币种选择', 'T_COST_FORMONEY_V', '[{"field":"fmname","header":"币种名称","width":150},{"field":"fmrate","header":"汇率","width":100},{"field":"fmsign","header":"符号","width":80}]', 'fmid', 'fmname', 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- 客户选择
INSERT INTO T_COST_LOOKUP_CONFIG (ID, LOOKUP_CODE, LOOKUP_NAME, DATA_SOURCE, DISPLAY_COLUMNS, VALUE_FIELD, LABEL_FIELD, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (80, 'costCustomer', '客户选择', 'V_COST_CUSTOMER_LOOKUP', '[{"field":"customid","header":"客户ID","width":80},{"field":"customname","header":"客户名称","width":200},{"field":"country","header":"国家","width":100},{"field":"livery","header":"分销商","width":150}]', 'customid', 'customname', 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- 产品选择(按物料)
INSERT INTO T_COST_LOOKUP_CONFIG (ID, LOOKUP_CODE, LOOKUP_NAME, DATA_SOURCE, DISPLAY_COLUMNS, VALUE_FIELD, LABEL_FIELD, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (101, 'pgoodsByMgoods', '产品选择(按物料)', 'V_COST_PGOODS_BY_MGOODS', '[{"field":"goodsid","header":"物料ID"},{"field":"apexGoodsname","header":"物料名称"},{"field":"dtlUseflag","header":"生产属性"},{"field":"factoryname","header":"厂家"},{"field":"price","header":"价格"},{"field":"goodsno","header":"华益代码"},{"field":"pgoodsid","header":"成品ID"},{"field":"pgoodsno","header":"成品编码"},{"field":"goodsname","header":"成品名称"},{"field":"apexPl","header":"批量"},{"field":"batchQty","header":"每批用量"}]', 'goodsid', 'apexGoodsname', 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- 库存选择
INSERT INTO T_COST_LOOKUP_CONFIG (ID, LOOKUP_CODE, LOOKUP_NAME, DATA_SOURCE, DISPLAY_COLUMNS, VALUE_FIELD, LABEL_FIELD, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (122, 'wmsQtyLookup', '库存选择', 'T_WMS_QTY_V', '[{"field":"goodsid","header":"产品ID","width":80},{"field":"goodsgp","header":"产品名称","width":200},{"field":"lotno","header":"批号","width":100},{"field":"goodsno","header":"产品编码","width":120},{"field":"packsize","header":"包装规格","width":80},{"field":"qty_show","header":"库存显示","width":150},{"field":"pcs","header":"件数","width":80}]', 'goodsid', 'goodsgp', 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
