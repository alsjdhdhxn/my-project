-- =====================================================
-- 计算引擎示例：评估单（主表） + 物料明细（从表）
-- =====================================================

-- 清理已有数据
DELETE FROM T_COST_PAGE_COMPONENT WHERE PAGE_CODE = 'cost-eval';
DELETE FROM T_COST_COLUMN_METADATA WHERE TABLE_METADATA_ID IN (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE IN ('CostEval', 'CostEvalDetail'));
DELETE FROM T_COST_TABLE_METADATA WHERE TABLE_CODE IN ('CostEval', 'CostEvalDetail');
DELETE FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'cost-eval';
COMMIT;

-- 删除已有对象
BEGIN EXECUTE IMMEDIATE 'DROP TABLE T_COST_EVAL_DETAIL CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE T_COST_EVAL CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE SEQ_COST_EVAL'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE SEQ_COST_EVAL_DETAIL'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- =====================================================
-- 1. 评估单主表
-- =====================================================
CREATE TABLE T_COST_EVAL (
    ID              NUMBER(19)      PRIMARY KEY,
    EVAL_NO         VARCHAR2(32)    NOT NULL UNIQUE,
    PRODUCT_NAME    VARCHAR2(128)   NOT NULL,
    APEX_PL         NUMBER(18,4)    DEFAULT 0,      -- 批量(万片)
    YIELD           NUMBER(18,4)    DEFAULT 100,    -- 收率(%)
    OUT_PRICE_RMB   NUMBER(18,4)    DEFAULT 0,      -- 出厂价
    TOTAL_YL        NUMBER(18,2)    DEFAULT 0,      -- 原料合计
    TOTAL_FL        NUMBER(18,2)    DEFAULT 0,      -- 辅料合计
    TOTAL_PACK      NUMBER(18,2)    DEFAULT 0,      -- 包材合计
    TOTAL_COST      NUMBER(18,2)    DEFAULT 0,      -- 总成本
    DELETED         NUMBER(1)       DEFAULT 0,
    CREATE_TIME     TIMESTAMP       DEFAULT SYSTIMESTAMP,
    UPDATE_TIME     TIMESTAMP       DEFAULT SYSTIMESTAMP,
    CREATE_BY       VARCHAR2(64),
    UPDATE_BY       VARCHAR2(64)
);
CREATE SEQUENCE SEQ_COST_EVAL START WITH 1 INCREMENT BY 1;

-- =====================================================
-- 2. 物料明细从表
-- =====================================================
CREATE TABLE T_COST_EVAL_DETAIL (
    ID              NUMBER(19)      PRIMARY KEY,
    EVAL_ID         NUMBER(19)      NOT NULL,
    MATERIAL_NAME   VARCHAR2(128)   NOT NULL,
    USE_FLAG        VARCHAR2(32)    NOT NULL,       -- 物料类型：原料/辅料/包材
    PER_HL          NUMBER(18,6)    DEFAULT 0,      -- 百万片用量
    PRICE           NUMBER(18,4)    DEFAULT 0,      -- 单价
    BATCH_QTY       NUMBER(18,4)    DEFAULT 0,      -- 批用量（计算列）
    COST_BATCH      NUMBER(18,2)    DEFAULT 0,      -- 批成本（计算列）
    PACK_SPEC       VARCHAR2(64),                   -- 包材规格
    PACK_QTY        NUMBER(18,4)    DEFAULT 0,      -- 包装数量（计算列）
    PACK_COST       NUMBER(18,2)    DEFAULT 0,      -- 包装成本（计算列）
    DELETED         NUMBER(1)       DEFAULT 0,
    CREATE_TIME     TIMESTAMP       DEFAULT SYSTIMESTAMP,
    UPDATE_TIME     TIMESTAMP       DEFAULT SYSTIMESTAMP,
    CREATE_BY       VARCHAR2(64),
    UPDATE_BY       VARCHAR2(64),
    CONSTRAINT FK_EVAL_DETAIL FOREIGN KEY (EVAL_ID) REFERENCES T_COST_EVAL(ID)
);
CREATE SEQUENCE SEQ_COST_EVAL_DETAIL START WITH 1 INCREMENT BY 1;
CREATE INDEX IDX_EVAL_DETAIL_EVAL_ID ON T_COST_EVAL_DETAIL(EVAL_ID);

-- =====================================================
-- 3. 表元数据
-- =====================================================
DECLARE
    v_eval_id NUMBER;
    v_detail_id NUMBER;
BEGIN
    -- 主表元数据
    SELECT SEQ_COST_TABLE_METADATA.NEXTVAL INTO v_eval_id FROM DUAL;
    INSERT INTO T_COST_TABLE_METADATA (ID, TABLE_CODE, TABLE_NAME, QUERY_VIEW, TARGET_TABLE, SEQUENCE_NAME, PK_COLUMN, CREATE_BY)
    VALUES (v_eval_id, 'CostEval', '评估单', 'T_COST_EVAL', 'T_COST_EVAL', 'SEQ_COST_EVAL', 'ID', 'system');
    
    -- 主表列
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_eval_id, 'id', 'ID', 'ID', 'number', 0, 0, 80, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, SEARCHABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_eval_id, 'evalNo', 'EVAL_NO', '评估单号', 'text', 1, 0, 1, 120, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_eval_id, 'productName', 'PRODUCT_NAME', '产品名称', 'text', 2, 1, 150, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_eval_id, 'apexPl', 'APEX_PL', '批量(万片)', 'number', 3, 1, 100, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_eval_id, 'yield', 'YIELD', '收率(%)', 'number', 4, 1, 80, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_eval_id, 'outPriceRmb', 'OUT_PRICE_RMB', '出厂价', 'number', 5, 1, 100, 'system');
    -- 聚合字段（只读）
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
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'materialName', 'MATERIAL_NAME', '物料名称', 'text', 2, 1, 150, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'useFlag', 'USE_FLAG', '物料类型', 'text', 3, 0, 80, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'perHl', 'PER_HL', '百万片用量', 'number', 4, 1, 100, 'system');
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'price', 'PRICE', '单价', 'number', 5, 1, 100, 'system');
    -- 计算列：批用量 = 批量 * 百万片用量 / 100 / 收率 * 100
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, IS_VIRTUAL, WIDTH, RULES_CONFIG, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'batchQty', 'BATCH_QTY', '批用量', 'number', 6, 0, 1, 100, 
    '{"calculate":{"expression":"apexPl * perHl / 100 / yield * 100","triggerFields":["perHl"]}}', 'system');
    -- 计算列：批成本 = 批用量 * 单价
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, IS_VIRTUAL, WIDTH, RULES_CONFIG, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'costBatch', 'COST_BATCH', '批成本', 'number', 7, 0, 1, 100, 
    '{"calculate":{"expression":"batchQty * price","triggerFields":["batchQty","price"]}}', 'system');
    -- 包材规格
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, WIDTH, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'packSpec', 'PACK_SPEC', '规格', 'text', 8, 1, 100, 'system');
    -- 计算列：包装数量 = 批量 * 1000
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, IS_VIRTUAL, WIDTH, RULES_CONFIG, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'packQty', 'PACK_QTY', '包装数量', 'number', 9, 0, 1, 100, 
    '{"calculate":{"expression":"apexPl * 1000","triggerFields":[]}}', 'system');
    -- 计算列：包装成本 = 包装数量 * 单价
    INSERT INTO T_COST_COLUMN_METADATA (ID, TABLE_METADATA_ID, FIELD_NAME, COLUMN_NAME, HEADER_TEXT, DATA_TYPE, DISPLAY_ORDER, EDITABLE, IS_VIRTUAL, WIDTH, RULES_CONFIG, CREATE_BY) 
    VALUES (SEQ_COST_COLUMN_METADATA.NEXTVAL, v_detail_id, 'packCost', 'PACK_COST', '包装成本', 'number', 10, 0, 1, 100, 
    '{"calculate":{"expression":"packQty * price","triggerFields":["packQty","price"]}}', 'system');
    
    COMMIT;
END;
/

-- =====================================================
-- 4. 页面组件配置
-- =====================================================
-- 页面根节点
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'cost-eval', 'root', 'LAYOUT', NULL, 0, '{"direction":"vertical","gap":16}', 'system');

-- 主表Grid
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'cost-eval', 'masterGrid', 'GRID', 'root', 1, 'CostEval', '{"height":250,"master":true}', 'system');

-- Tab容器
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'cost-eval', 'detailTabs', 'TABS', 'root', 2, '{"masterGrid":"masterGrid"}', 'system');

-- 从表Grid（放在Tab容器内）
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, REF_TABLE_CODE, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'cost-eval', 'detailGrid', 'GRID', 'detailTabs', 1, 'CostEvalDetail', '{"tabLabel":"物料明细","height":300,"editable":true}', 'system');

-- 广播配置：主表 → 从表
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'cost-eval', 'broadcast_master', 'LOGIC_BROADCAST', 'root', 10, 
'{"source":"masterGrid","target":"detailGrid","fields":["apexPl","yield"]}', 'system');

-- 聚合配置：从表 → 主表（原料合计）
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'cost-eval', 'agg_totalYl', 'LOGIC_AGG', 'root', 11, 
'{"source":"detailGrid","target":"masterGrid","sourceField":"costBatch","targetField":"totalYl","algorithm":"SUM","filter":"useFlag==''原料''"}', 'system');

-- 聚合配置：从表 → 主表（辅料合计）
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'cost-eval', 'agg_totalFl', 'LOGIC_AGG', 'root', 12, 
'{"source":"detailGrid","target":"masterGrid","sourceField":"costBatch","targetField":"totalFl","algorithm":"SUM","filter":"useFlag==''辅料''"}', 'system');

-- 聚合配置：从表 → 主表（包材合计）
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'cost-eval', 'agg_totalPack', 'LOGIC_AGG', 'root', 13, 
'{"source":"detailGrid","target":"masterGrid","sourceField":"packCost","targetField":"totalPack","algorithm":"SUM","filter":"useFlag==''包材''"}', 'system');

-- 聚合配置：从表 → 主表（总成本 = 原料 + 辅料 + 包材）
INSERT INTO T_COST_PAGE_COMPONENT (ID, PAGE_CODE, COMPONENT_KEY, COMPONENT_TYPE, PARENT_KEY, SORT_ORDER, COMPONENT_CONFIG, CREATE_BY)
VALUES (SEQ_COST_PAGE_COMPONENT.NEXTVAL, 'cost-eval', 'agg_totalCost', 'LOGIC_AGG', 'root', 14, 
'{"target":"masterGrid","targetField":"totalCost","expression":"totalYl + totalFl + totalPack"}', 'system');

COMMIT;

-- =====================================================
-- 5. 菜单配置
-- =====================================================
DECLARE
    v_parent_id NUMBER;
BEGIN
    SELECT ID INTO v_parent_id FROM T_COST_RESOURCE WHERE RESOURCE_CODE = 'cost-management' AND ROWNUM = 1;
    INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PARENT_ID, ROUTE, PAGE_CODE, ICON, SORT_ORDER, CREATE_BY)
    VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'cost-eval', '评估单', 'PAGE', v_parent_id, '/cost/eval', 'cost-eval', 'i-carbon-calculator', 3, 'system');
    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        INSERT INTO T_COST_RESOURCE (ID, RESOURCE_CODE, RESOURCE_NAME, RESOURCE_TYPE, PARENT_ID, ROUTE, PAGE_CODE, ICON, SORT_ORDER, CREATE_BY)
        VALUES (SEQ_COST_RESOURCE.NEXTVAL, 'cost-eval', '评估单', 'PAGE', NULL, '/cost/eval', 'cost-eval', 'i-carbon-calculator', 3, 'system');
        COMMIT;
END;
/

-- =====================================================
-- 6. 测试数据
-- =====================================================
DECLARE
    v_eval_id NUMBER;
    v_eval_id2 NUMBER;
BEGIN
    SELECT SEQ_COST_EVAL.NEXTVAL INTO v_eval_id FROM DUAL;
    
    INSERT INTO T_COST_EVAL (ID, EVAL_NO, PRODUCT_NAME, APEX_PL, YIELD, OUT_PRICE_RMB, CREATE_BY)
    VALUES (v_eval_id, 'EVAL-2025-001', '阿莫西林胶囊', 100, 98, 35.5, 'system');
    
    -- 原料
    INSERT INTO T_COST_EVAL_DETAIL (ID, EVAL_ID, MATERIAL_NAME, USE_FLAG, PER_HL, PRICE, CREATE_BY)
    VALUES (SEQ_COST_EVAL_DETAIL.NEXTVAL, v_eval_id, '阿莫西林原料', '原料', 125.5, 280, 'system');
    INSERT INTO T_COST_EVAL_DETAIL (ID, EVAL_ID, MATERIAL_NAME, USE_FLAG, PER_HL, PRICE, CREATE_BY)
    VALUES (SEQ_COST_EVAL_DETAIL.NEXTVAL, v_eval_id, '淀粉', '原料', 45.2, 15, 'system');
    
    -- 辅料
    INSERT INTO T_COST_EVAL_DETAIL (ID, EVAL_ID, MATERIAL_NAME, USE_FLAG, PER_HL, PRICE, CREATE_BY)
    VALUES (SEQ_COST_EVAL_DETAIL.NEXTVAL, v_eval_id, '空心胶囊', '辅料', 1050, 0.035, 'system');
    INSERT INTO T_COST_EVAL_DETAIL (ID, EVAL_ID, MATERIAL_NAME, USE_FLAG, PER_HL, PRICE, CREATE_BY)
    VALUES (SEQ_COST_EVAL_DETAIL.NEXTVAL, v_eval_id, '硬脂酸镁', '辅料', 2.5, 45, 'system');
    
    -- 包材
    INSERT INTO T_COST_EVAL_DETAIL (ID, EVAL_ID, MATERIAL_NAME, USE_FLAG, PACK_SPEC, PRICE, CREATE_BY)
    VALUES (SEQ_COST_EVAL_DETAIL.NEXTVAL, v_eval_id, '铝塑板', '包材', '10粒/板', 0.12, 'system');
    INSERT INTO T_COST_EVAL_DETAIL (ID, EVAL_ID, MATERIAL_NAME, USE_FLAG, PACK_SPEC, PRICE, CREATE_BY)
    VALUES (SEQ_COST_EVAL_DETAIL.NEXTVAL, v_eval_id, '纸盒', '包材', '2板/盒', 0.35, 'system');
    
    -- 第二条测试数据
    SELECT SEQ_COST_EVAL.NEXTVAL INTO v_eval_id2 FROM DUAL;
    
    INSERT INTO T_COST_EVAL (ID, EVAL_NO, PRODUCT_NAME, APEX_PL, YIELD, OUT_PRICE_RMB, CREATE_BY)
    VALUES (v_eval_id2, 'EVAL-2025-002', '头孢克肟片', 80, 95, 42.0, 'system');
    
    -- 原料
    INSERT INTO T_COST_EVAL_DETAIL (ID, EVAL_ID, MATERIAL_NAME, USE_FLAG, PER_HL, PRICE, CREATE_BY)
    VALUES (SEQ_COST_EVAL_DETAIL.NEXTVAL, v_eval_id2, '头孢克肟原料', '原料', 200, 450, 'system');
    
    -- 辅料
    INSERT INTO T_COST_EVAL_DETAIL (ID, EVAL_ID, MATERIAL_NAME, USE_FLAG, PER_HL, PRICE, CREATE_BY)
    VALUES (SEQ_COST_EVAL_DETAIL.NEXTVAL, v_eval_id2, '微晶纤维素', '辅料', 80, 25, 'system');
    
    -- 包材
    INSERT INTO T_COST_EVAL_DETAIL (ID, EVAL_ID, MATERIAL_NAME, USE_FLAG, PACK_SPEC, PRICE, CREATE_BY)
    VALUES (SEQ_COST_EVAL_DETAIL.NEXTVAL, v_eval_id2, '铝塑板', '包材', '12粒/板', 0.15, 'system');
    
    COMMIT;
END;
/
