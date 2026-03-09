-- ============================================================
-- Lookup配置初始化
-- 包含: 所有弹窗选择器配置
-- ============================================================

-- 部门选择
INSERT INTO T_COST_LOOKUP_CONFIG (ID, LOOKUP_CODE, LOOKUP_NAME, DATA_SOURCE, DISPLAY_COLUMNS, VALUE_FIELD, LABEL_FIELD, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (3, 'department', '部门选择', 'T_COST_DEPARTMENT', '[{"field":"DEPT_CODE","header":"部门编码","width":120},{"field":"DEPT_NAME","header":"部门名称","width":200}]', 'ID', 'DEPT_NAME', 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- 产品选择
INSERT INTO T_COST_LOOKUP_CONFIG (ID, LOOKUP_CODE, LOOKUP_NAME, DATA_SOURCE, DISPLAY_COLUMNS, VALUE_FIELD, LABEL_FIELD, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (77, 'costGoods', '产品选择', 'V_COST_GOODS_LOOKUP', '[{"field":"GOODSID","header":"产品ID","width":80},{"field":"GOODSNAME","header":"产品名称","width":200},{"field":"MA_NO","header":"批准文号","width":150},{"field":"APEX_PL","header":"批量","width":80},{"field":"MAH","header":"持证商","width":150},{"field":"P_PERPACK","header":"每盒片数","width":100},{"field":"S_PERBACK","header":"每箱装盒数","width":100},{"field":"CUSTOMID","header":"客户ID","width":80},{"field":"CUSTOMNAME","header":"客户名称","width":150},{"field":"MEMO","header":"BOM状态","width":120},{"field":"STRENGTH","header":"剂量","width":100},{"field":"LIVERY","header":"分销商","width":150}]', 'GOODSID', 'GOODSNAME', 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- 物料选择
INSERT INTO T_COST_LOOKUP_CONFIG (ID, LOOKUP_CODE, LOOKUP_NAME, DATA_SOURCE, DISPLAY_COLUMNS, VALUE_FIELD, LABEL_FIELD, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (78, 'costMaterial', '物料选择', 'T_COST_GOODS_PRICE_V', '[{"field":"GOODSNAME","header":"物料名称","width":200},{"field":"USEFLAG","header":"用途","width":80},{"field":"GOODSTYPE","header":"规格","width":150},{"field":"PRICE","header":"单价","width":100},{"field":"FACTORYNAME","header":"供应商","width":150}]', 'GOODSID', 'GOODSNAME', 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- 币种选择
INSERT INTO T_COST_LOOKUP_CONFIG (ID, LOOKUP_CODE, LOOKUP_NAME, DATA_SOURCE, DISPLAY_COLUMNS, VALUE_FIELD, LABEL_FIELD, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (79, 'formoney', '币种选择', 'T_COST_FORMONEY_V', '[{"field":"FMNAME","header":"币种名称","width":150},{"field":"FMRATE","header":"汇率","width":100},{"field":"FMSIGN","header":"符号","width":80}]', 'FMID', 'FMNAME', 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- 客户选择
INSERT INTO T_COST_LOOKUP_CONFIG (ID, LOOKUP_CODE, LOOKUP_NAME, DATA_SOURCE, DISPLAY_COLUMNS, VALUE_FIELD, LABEL_FIELD, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (80, 'costCustomer', '客户选择', 'V_COST_CUSTOMER_LOOKUP', '[{"field":"CUSTOMID","header":"客户ID","width":80},{"field":"CUSTOMNAME","header":"客户名称","width":200},{"field":"COUNTRY","header":"国家","width":100},{"field":"LIVERY","header":"分销商","width":150}]', 'CUSTOMID', 'CUSTOMNAME', 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- 产品选择(按物料)
INSERT INTO T_COST_LOOKUP_CONFIG (ID, LOOKUP_CODE, LOOKUP_NAME, DATA_SOURCE, DISPLAY_COLUMNS, VALUE_FIELD, LABEL_FIELD, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (101, 'pgoodsByMgoods', '产品选择(按物料)', 'V_COST_PGOODS_BY_MGOODS', '[{"field":"GOODSID","header":"物料ID"},{"field":"GOODSNAME","header":"物料名称"},{"field":"DTL_USEFLAG","header":"生产属性"},{"field":"FACTORYNAME","header":"厂家"},{"field":"PRICE","header":"价格"},{"field":"GOODSNO","header":"华益代码"},{"field":"PGOODSID","header":"成品ID"},{"field":"PGOODSNO","header":"成品编码"},{"field":"PGOODSNAME","header":"成品名称"},{"field":"APEX_PL","header":"批量"},{"field":"BATCH_QTY","header":"每批用量"}]', 'GOODSID', 'GOODSNAME', 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');

-- 库存选择
INSERT INTO T_COST_LOOKUP_CONFIG (ID, LOOKUP_CODE, LOOKUP_NAME, DATA_SOURCE, DISPLAY_COLUMNS, VALUE_FIELD, LABEL_FIELD, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
VALUES (122, 'wmsQtyLookup', '库存选择', 'T_WMS_QTY_V', '[{"field":"GOODSID","header":"产品ID","width":80},{"field":"GOODSGP","header":"产品名称","width":200},{"field":"LOTNO","header":"批号","width":100},{"field":"GOODSNO","header":"产品编码","width":120},{"field":"PACKSIZE","header":"包装规格","width":80},{"field":"QTY_SHOW","header":"库存显示","width":150},{"field":"PCS","header":"件数","width":80}]', 'GOODSID', 'GOODSGP', 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
