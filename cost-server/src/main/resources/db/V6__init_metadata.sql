-- =====================================================
-- 表/列元数据初始化
-- =====================================================

-- =====================================================
-- 1. CostEval 评估单
-- =====================================================
DECLARE
    v_eval_id NUMBER;
    v_detail_id NUMBER;
BEGIN
    -- 主表元数据
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_eval_id FROM DUAL;
    INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, VALIDATION_RULES, CREATE_BY)
    VALUES (v_eval_id, 'CostEval', '评估单', 'T_COST_EVAL', 'T_COST_EVAL', 'SEQ_COST_EVAL', 'ID',
    '[{"order":1,"name":"evalNoUnique","sql":"SELECT COUNT(*) FROM T_COST_EVAL WHERE EVAL_NO = :evalNo AND ID != NVL(:id, -1) AND DELETED = 0","condition":"result == 0","message":"评估单号已存在"},{"order":2,"name":"apexPlPositive","sql":"SELECT CASE WHEN :apexPl > 0 THEN 1 ELSE 0 END FROM DUAL","condition":"result == 1","message":"批量必须大于0"}]',
    'system');
    
    -- 主表列
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_eval_id, 'id', 'ID', 'ID', 'number', 0, 0, 80, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, SEARCHABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_eval_id, 'evalNo', 'EVAL_NO', '评估单号', 'text', 1, 0, 1, 120, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, RULES_CONFIG, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_eval_id, 'productName', 'PRODUCT_NAME', '产品名称', 'text', 2, 1, 150, 
    '{"style":[{"condition":{"type":"contains","pattern":"瓶"},"cellStyle":{"color":"red","fontWeight":"bold"}},{"condition":{"type":"contains","pattern":"清"},"rowStyle":{"backgroundColor":"#e3f2fd"}}]}', 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_eval_id, 'apexPl', 'APEX_PL', '批量(万片)', 'number', 3, 1, 100, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_eval_id, 'yield', 'YIELD', '收率(%)', 'number', 4, 1, 80, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_eval_id, 'outPriceRmb', 'OUT_PRICE_RMB', '出厂价', 'number', 5, 1, 100, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_eval_id, 'totalYl', 'TOTAL_YL', '原料合计', 'number', 6, 0, 100, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_eval_id, 'totalFl', 'TOTAL_FL', '辅料合计', 'number', 7, 0, 100, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_eval_id, 'totalPack', 'TOTAL_PACK', '包材合计', 'number', 8, 0, 100, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_eval_id, 'totalCost', 'TOTAL_COST', '总成本', 'number', 9, 0, 100, 'system');

    -- 从表元数据
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_detail_id FROM DUAL;
    INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, PARENT_TABLE_CODE, PARENT_FK_COLUMN, CREATE_BY)
    VALUES (v_detail_id, 'CostEvalDetail', '物料明细', 'T_COST_EVAL_DETAIL', 'T_COST_EVAL_DETAIL', 'SEQ_COST_EVAL_DETAIL', 'ID', 'CostEval', 'EVAL_ID', 'system');
    
    -- 从表列
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'id', 'ID', 'ID', 'number', 0, 0, 80, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'evalId', 'EVAL_ID', '主表ID', 'number', 1, 0, 80, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, RULES_CONFIG, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'materialName', 'MATERIAL_NAME', '物料名称', 'text', 2, 1, 150, 
    '{"lookup":{"code":"material","mapping":{"materialName":"materialName","useFlag":"useFlag","perHl":"perHl","price":"price"}}}', 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'useFlag', 'USE_FLAG', '物料类型', 'text', 3, 0, 80, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'perHl', 'PER_HL', '百万片用量', 'number', 4, 1, 100, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, RULES_CONFIG, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'price', 'PRICE', '单价', 'number', 5, 1, 100, 
    '{"validate":[{"order":1,"type":"notZero","message":"单价不能为0"},{"order":2,"type":"min","value":0,"message":"单价不能为负数"}],"compare":{"enabled":true,"format":"both"}}', 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, IS_VIRTUAL, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'batchQty', 'BATCH_QTY', '批用量', 'number', 6, 0, 1, 100, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, IS_VIRTUAL, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'costBatch', 'COST_BATCH', '批成本', 'number', 7, 0, 1, 100, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'packSpec', 'PACK_SPEC', '规格', 'text', 8, 1, 100, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, IS_VIRTUAL, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'packQty', 'PACK_QTY', '包装数量', 'number', 9, 0, 1, 100, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, IS_VIRTUAL, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'packCost', 'PACK_COST', '包装成本', 'number', 10, 0, 1, 100, 'system');
    
    COMMIT;
END;
/

-- =====================================================
-- 2. CostEval 页面组件配置
-- =====================================================
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'cost-eval', 'root', 'LAYOUT', NULL, 0, '{"direction":"vertical","gap":8}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'cost-eval', 'masterGrid', 'GRID', 'root', 1, 'CostEval', '{"height":"50%","selectionMode":"single"}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'cost-eval', 'detailTabs', 'TABS', 'root', 2, 'CostEvalDetail', 
'{
  "mode": "group",
  "groupField": "useFlag",
  "tabs": [
    {"key": "material", "title": "原料", "value": "原料", "columns": ["materialName", "perHl", "price", "batchQty", "costBatch"]},
    {"key": "auxiliary", "title": "辅料", "value": "辅料", "columns": ["materialName", "perHl", "price", "batchQty", "costBatch"]},
    {"key": "package", "title": "包材", "value": "包材", "columns": ["materialName", "packSpec", "price", "packQty", "packCost"]}
  ],
  "broadcast": ["apexPl", "yield"],
  "calcRules": [
    {"field": "batchQty", "expression": "apexPl * perHl / 100 / yield * 100", "triggerFields": ["perHl"], "condition": "useFlag !== ''包材''"},
    {"field": "costBatch", "expression": "batchQty * price", "triggerFields": ["batchQty", "price"], "condition": "useFlag !== ''包材''"},
    {"field": "packQty", "expression": "apexPl * 1000", "triggerFields": [], "condition": "useFlag === ''包材''"},
    {"field": "packCost", "expression": "packQty * price", "triggerFields": ["packQty", "price"], "condition": "useFlag === ''包材''"}
  ],
  "aggregates": [
    {"sourceField": "costBatch", "targetField": "totalYl", "algorithm": "SUM", "filter": "useFlag === ''原料''"},
    {"sourceField": "costBatch", "targetField": "totalFl", "algorithm": "SUM", "filter": "useFlag === ''辅料''"},
    {"sourceField": "packCost", "targetField": "totalPack", "algorithm": "SUM", "filter": "useFlag === ''包材''"},
    {"targetField": "totalCost", "expression": "totalYl + totalFl + totalPack"}
  ]
}', 'system');

COMMIT;

-- =====================================================
-- 3. CostMaterial 物料基础数据
-- =====================================================
DECLARE
    v_material_id NUMBER;
BEGIN
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_material_id FROM DUAL;
    INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, CREATE_BY)
    VALUES (v_material_id, 'CostMaterial', '物料基础数据', 'T_COST_MATERIAL', 'T_COST_MATERIAL', 'SEQ_COST_MATERIAL', 'ID', 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_material_id, 'id', 'ID', 'ID', 'number', 0, 0, 80, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, SEARCHABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_material_id, 'materialCode', 'MATERIAL_CODE', '物料编码', 'text', 1, 1, 1, 100, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, SEARCHABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_material_id, 'materialName', 'MATERIAL_NAME', '物料名称', 'text', 2, 1, 1, 150, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_material_id, 'useFlag', 'USE_FLAG', '物料类型', 'text', 3, 1, 80, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_material_id, 'perHl', 'PER_HL', '百万片用量', 'number', 4, 1, 100, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_material_id, 'price', 'PRICE', '单价', 'number', 5, 1, 100, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_material_id, 'unit', 'UNIT', '单位', 'text', 6, 1, 80, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_material_id, 'spec', 'SPEC', '规格', 'text', 7, 1, 100, 'system');
    
    COMMIT;
END;
/

-- =====================================================
-- 4. Customer 客户表
-- =====================================================
DECLARE
    v_customer_id NUMBER;
BEGIN
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_customer_id FROM DUAL;
    INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, CREATE_BY)
    VALUES (v_customer_id, 'Customer', '客户', 'T_COST_CUSTOMER', 'T_COST_CUSTOMER', 'SEQ_COST_CUSTOMER', 'ID', 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_customer_id, 'id', 'ID', 'ID', 'number', 0, 0, 80, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, SEARCHABLE, WIDTH, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_customer_id, 'customerCode', 'CUSTOMER_CODE', '客户编码', 'text', 1, 1, 1, 120, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, SEARCHABLE, WIDTH, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_customer_id, 'customerName', 'CUSTOMER_NAME', '客户名称', 'text', 2, 1, 1, 180, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, SEARCHABLE, WIDTH, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_customer_id, 'contactPerson', 'CONTACT_PERSON', '联系人', 'text', 3, 1, 1, 100, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_customer_id, 'phone', 'PHONE', '电话', 'text', 4, 1, 120, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY)
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_customer_id, 'address', 'ADDRESS', '地址', 'text', 5, 1, 200, 'system');

    COMMIT;
END;
/

-- =====================================================
-- 5. 弹窗选择器配置
-- =====================================================
INSERT INTO T_COST_LOOKUP_CONFIG (ID, LOOKUP_CODE, LOOKUP_NAME, DATA_SOURCE, DISPLAY_COLUMNS, SEARCH_COLUMNS, VALUE_FIELD, LABEL_FIELD, CREATE_BY)
VALUES (SEQ_COST_LOOKUP_CONFIG.NEXTVAL, 'material', '物料选择', 'CostMaterial', 
  '[{"field":"materialCode","header":"物料编码","width":100},{"field":"materialName","header":"物料名称","width":150},{"field":"useFlag","header":"类型","width":80},{"field":"price","header":"单价","width":80}]',
  '["materialCode","materialName"]', 'id', 'materialName', 'system');

INSERT INTO T_COST_LOOKUP_CONFIG (ID, LOOKUP_CODE, LOOKUP_NAME, DATA_SOURCE, DISPLAY_COLUMNS, SEARCH_COLUMNS, VALUE_FIELD, LABEL_FIELD, CREATE_BY)
VALUES (SEQ_COST_LOOKUP_CONFIG.NEXTVAL, 'customer', '客户选择', 'Customer', 
  '[{"field":"customerCode","header":"客户编码","width":100},{"field":"customerName","header":"客户名称","width":180},{"field":"contactPerson","header":"联系人","width":100}]',
  '["customerCode","customerName"]', 'id', 'customerName', 'system');

COMMIT;
