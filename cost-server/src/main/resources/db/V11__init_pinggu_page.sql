-- =====================================================
-- 成本评估页面配置
-- =====================================================

-- =====================================================
-- 0. 明细表视图（含公式类型计算）
-- =====================================================
-- 公式类型说明：
-- A: 包材 + 桶/说明书/小盒/标签/瓶/盖 → apexPl / pPerpack
-- B: 辅料 + 胶囊 → apexPl / 10000
-- C: 原料/辅料（默认） → perHl * apexPl * (1 + exaddMater/100) / 1000000
-- D: 包材 + 硬片/铝箔 → perHl * apexPl * (1 + exaddMater/100) / 1000000
-- E: 包材 + 大纸箱 → ceil(apexPl / (pPerpack * sPerback))
-- F: 包材 + 托盘 → ceil(apexPl / (pPerpack * sPerback * xPerback))
CREATE OR REPLACE VIEW V_COST_PINGGU_DTL AS
SELECT 
    d.DTLID,
    d.DOCID,
    d.DTL_USEFLAG,
    d.APEX_GOODSNAME,
    d.SPEC,
    d.PER_HL,
    d.EXADD_MATER,
    d.BATCH_QTY,
    d.PRICE,
    d.COST_BATCH,
    d.MEMO,
    d.APEX_FACTORYNAME,
    d.APEX_FACTORYID,
    d.APEX_GOODSID,
    d.MODIFYDATE,
    d.ZX_SOURCE,
    d.BASE_PRICE,
    d.SUQTY,
    d.GOODSTYPE,
    d.GOODSNAME_EN,
    -- 公式类型：根据分类和货品名正则匹配
    CASE
        -- A: 包材 + 桶/说明书/小盒/标签/瓶/盖
        WHEN d.DTL_USEFLAG IN ('印字包材', '非印字包材') 
             AND REGEXP_LIKE(d.APEX_GOODSNAME, '桶|说明书|小盒|标签|瓶|盖') THEN 'A'
        -- B: 辅料 + 胶囊
        WHEN d.DTL_USEFLAG = '辅料' 
             AND REGEXP_LIKE(d.APEX_GOODSNAME, '胶囊') THEN 'B'
        -- D: 包材 + 硬片/铝箔
        WHEN d.DTL_USEFLAG IN ('印字包材', '非印字包材') 
             AND REGEXP_LIKE(d.APEX_GOODSNAME, '硬片|铝箔') THEN 'D'
        -- E: 包材 + 大纸箱
        WHEN d.DTL_USEFLAG IN ('印字包材', '非印字包材') 
             AND REGEXP_LIKE(d.APEX_GOODSNAME, '大纸箱') THEN 'E'
        -- F: 包材 + 托盘
        WHEN d.DTL_USEFLAG IN ('印字包材', '非印字包材') 
             AND REGEXP_LIKE(d.APEX_GOODSNAME, '托盘') THEN 'F'
        -- C: 原料/辅料（默认）
        WHEN d.DTL_USEFLAG IN ('原料', '辅料') THEN 'C'
        -- 其他情况
        ELSE NULL
    END AS FORMULA_TYPE
FROM T_COST_PINGGU_DTL d;

-- =====================================================
-- 1. 菜单资源
-- =====================================================
DECLARE
    v_parent_id NUMBER;
BEGIN
    SELECT ID INTO v_parent_id FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'cost';
    INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
    VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'pinggu', '成本评估', 'PAGE', 'cost-pinggu', 'mdi:calculator-variant', '/cost/pinggu', v_parent_id, 2, 'system');
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- 如果没有 cost 目录，创建在根目录
        INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PAGE_CODE, ICON, ROUTE, PARENT_ID, SORT_ORDER, CREATE_BY)
        VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'pinggu', '成本评估', 'PAGE', 'cost-pinggu', 'mdi:calculator-variant', '/pinggu', NULL, 10, 'system');
END;
/

-- =====================================================
-- 2. 主表元数据 (T_COST_PINGGU)
-- =====================================================
DECLARE
    v_master_id NUMBER;
BEGIN
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_master_id FROM DUAL;
    
    INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, PK_COLUMN, CREATE_BY)
    VALUES (v_master_id, 'CostPinggu', '成本评估', 'T_COST_PINGGU', 'T_COST_PINGGU', 'DOCID', 'system');
    
    -- 主表列元数据
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, VISIBLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'docid', 'DOCID', 'ID', 'number', 0, 0, 0, 80, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, SEARCHABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'goodsname', 'GOODSNAME', '产品名称', 'text', 1, 1, 1, 150, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'goodsnameEn', 'GOODSNAME_EN', '产品英文名', 'text', 2, 1, 200, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'strength', 'STRENGTH', '剂量', 'text', 3, 1, 80, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'dosage', 'DOSAGE', '剂型', 'text', 4, 1, 80, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'form', 'FORM', '片型', 'text', 5, 1, 80, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'maNo', 'MA_NO', '注册号', 'text', 6, 1, 120, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'mah', 'MAH', '注册持有人', 'text', 7, 1, 120, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, SEARCHABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'customname', 'CUSTOMNAME', '客户名称', 'text', 8, 1, 1, 120, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'country', 'COUNTRY', '国家', 'text', 9, 1, 80, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'projectno', 'PROJECTNO', '项目号', 'text', 10, 1, 100, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'apexPl', 'APEX_PL', '批量', 'number', 11, 1, 100, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'annualQty', 'ANNUAL_QTY', '年需求量', 'number', 12, 1, 100, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'yield', 'YIELD', '收率(%)', 'number', 13, 1, 80, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'pPerpack', 'P_PERPACK', '每盒片数', 'number', 14, 1, 80, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'sPerback', 'S_PERBACK', '每箱装盒数', 'number', 15, 1, 80, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'xPerback', 'X_PERBACK', '每托盘箱数', 'number', 16, 1, 80, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'packtype', 'PACKTYPE', '包装形式', 'text', 17, 1, 100, 'system');
    
    -- 汇总字段（不可编辑，由聚合计算）
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'totalYl', 'TOTAL_YL', '原料合计', 'number', 20, 0, 100, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'totalFl', 'TOTAL_FL', '辅料合计', 'number', 21, 0, 100, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'totalBc', 'TOTAL_BC', '包材合计', 'number', 22, 0, 100, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'totalCost', 'TOTAL_COST', '总物料成本', 'number', 23, 0, 100, 'system');
    
    -- 计算字段
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'outPriceRmb', 'OUT_PRICE_RMB', '出厂价(RMB)', 'number', 24, 1, 100, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'salemoney', 'SALEMONEY', '每批销售额', 'number', 25, 0, 100, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'jgfBatch', 'JGF_BATCH', '每批加工费', 'number', 26, 0, 100, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'costPerqp', 'COST_PERQP', '千片成本', 'number', 27, 1, 100, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'jgfPerqp', 'JGF_PERQP', '千片加工费', 'number', 28, 0, 100, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'mlPerqp', 'ML_PERQP', '千片毛利', 'number', 29, 0, 100, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'yJgRe', 'Y_JG_RE', '年加工收入', 'number', 30, 0, 100, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'yMl', 'Y_ML', '年毛利', 'number', 31, 0, 100, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'ySale', 'Y_SALE', '年销售额', 'number', 32, 0, 100, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'usestatus', 'USESTATUS', '状态', 'text', 33, 1, 80, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_master_id, 'memo', 'MEMO', '备注', 'text', 34, 1, 150, 'system');

    COMMIT;
END;
/

-- =====================================================
-- 3. 明细表元数据 (T_COST_PINGGU_DTL)
-- =====================================================
DECLARE
    v_detail_id NUMBER;
BEGIN
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_detail_id FROM DUAL;
    
    -- 查询用视图（含 FORMULA_TYPE），保存用表
    INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, PK_COLUMN, PARENT_TABLE_CODE, PARENT_FK_COLUMN, CREATE_BY)
    VALUES (v_detail_id, 'CostPingguDtl', '成本评估明细', 'V_COST_PINGGU_DTL', 'T_COST_PINGGU_DTL', 'DTLID', 'CostPinggu', 'DOCID', 'system');
    
    -- 明细表列元数据
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, VISIBLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'dtlid', 'DTLID', 'ID', 'number', 0, 0, 0, 80, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, VISIBLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'docid', 'DOCID', '主表ID', 'number', 1, 0, 0, 80, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, SEARCHABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'dtlUseflag', 'DTL_USEFLAG', '分类', 'text', 2, 1, 1, 100, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, SEARCHABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'apexGoodsname', 'APEX_GOODSNAME', '货品名', 'text', 3, 1, 1, 150, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'spec', 'SPEC', '规格', 'text', 4, 1, 100, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'perHl', 'PER_HL', '每片含量', 'number', 5, 1, 100, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'exaddMater', 'EXADD_MATER', '额外投料量', 'number', 6, 1, 100, 'system');
    
    -- batchQty 多公式计算：根据 formulaType 选择公式
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, RULES_CONFIG, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'batchQty', 'BATCH_QTY', '每批数量', 'number', 7, 0, 100, 
    '{"calculate":{"formulaField":"formulaType","formulas":{"A":{"expression":"apexPl / pPerpack","triggerFields":["apexPl","pPerpack"]},"B":{"expression":"apexPl / 10000","triggerFields":["apexPl"]},"C":{"expression":"perHl * apexPl * (1 + exaddMater / 100) / 1000000","triggerFields":["perHl","apexPl","exaddMater"]},"D":{"expression":"perHl * apexPl * (1 + exaddMater / 100) / 1000000","triggerFields":["perHl","apexPl","exaddMater"]},"E":{"expression":"ceil(apexPl / (pPerpack * sPerback))","triggerFields":["apexPl","pPerpack","sPerback"]},"F":{"expression":"ceil(apexPl / (pPerpack * sPerback * xPerback))","triggerFields":["apexPl","pPerpack","sPerback","xPerback"]}}}}', 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'price', 'PRICE', '价格', 'number', 8, 1, 100, 'system');
    
    -- costBatch 计算字段：batchQty * price
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, RULES_CONFIG, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'costBatch', 'COST_BATCH', '每批成本', 'number', 9, 0, 100, 
    '{"calculate":{"expression":"batchQty * price","triggerFields":["batchQty","price"]}}', 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'apexFactoryname', 'APEX_FACTORYNAME', '厂家名', 'text', 10, 1, 120, 'system');
    
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'memo', 'MEMO', '备注', 'text', 11, 1, 150, 'system');
    
    -- formulaType 虚拟列（由视图计算）
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, VISIBLE, IS_VIRTUAL, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'formulaType', 'FORMULA_TYPE', '公式类型', 'text', 12, 0, 0, 1, 60, 'system');

    COMMIT;
END;
/

-- =====================================================
-- 4. 页面组件配置
-- =====================================================
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'cost-pinggu', 'root', 'LAYOUT', NULL, 0, '{"direction":"vertical","gap":8}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'cost-pinggu', 'masterGrid', 'GRID', 'root', 1, 'CostPinggu', '{"height":"50%","selectionMode":"single"}', 'system');

INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'cost-pinggu', 'detailTabs', 'TABS', 'root', 2, 'CostPingguDtl', 
'{
  "mode": "group",
  "groupField": "dtlUseflag",
  "tabs": [
    {"key": "ylfl", "title": "原料/辅料", "values": ["原料", "辅料"]},
    {"key": "bc", "title": "包材", "values": ["印字包材", "非印字包材"]}
  ],
  "broadcast": ["apexPl", "pPerpack", "sPerback", "xPerback"],
  "aggregates": [
    {"sourceField": "costBatch", "targetField": "totalYl", "algorithm": "SUM", "filter": "dtlUseflag === ''原料''"},
    {"sourceField": "costBatch", "targetField": "totalFl", "algorithm": "SUM", "filter": "dtlUseflag === ''辅料''"},
    {"sourceField": "costBatch", "targetField": "totalBc", "algorithm": "SUM", "filter": "dtlUseflag === ''印字包材'' || dtlUseflag === ''非印字包材''"},
    {"targetField": "totalCost", "expression": "totalYl + totalFl + totalBc"}
  ],
  "postProcess": "if (totalYl > 0) { totalYl /= 1.13; totalFl /= 1.13; totalBc /= 1.13; totalCost = totalYl + totalFl + totalBc; }",
  "masterCalcRules": [
    {"field": "salemoney", "expression": "outPriceRmb / pPerpack * apexPl * (yield / 100)", "triggerFields": ["outPriceRmb", "pPerpack", "apexPl", "yield", "totalCost"]},
    {"field": "jgfBatch", "expression": "salemoney - totalCost", "triggerFields": ["salemoney", "totalCost"]},
    {"field": "jgfPerqp", "expression": "jgfBatch / apexPl * 1000", "triggerFields": ["jgfBatch", "apexPl"]},
    {"field": "mlPerqp", "expression": "jgfPerqp - costPerqp", "triggerFields": ["jgfPerqp", "costPerqp"]},
    {"field": "yJgRe", "expression": "jgfPerqp / 1000 * annualQty", "triggerFields": ["jgfPerqp", "annualQty"]},
    {"field": "yMl", "expression": "mlPerqp / 1000 * annualQty", "triggerFields": ["mlPerqp", "annualQty"]},
    {"field": "ySale", "expression": "salemoney / apexPl * annualQty", "triggerFields": ["salemoney", "apexPl", "annualQty"]}
  ]
}', 'system');

COMMIT;
