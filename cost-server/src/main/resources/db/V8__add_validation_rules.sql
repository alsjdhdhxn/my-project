-- =====================================================
-- 验证规则 + 执行器支持
-- 流程：前端验证1→2 → 后端验证1→执行器1 → 后端验证2→执行器2 → 后端验证3→执行器3
-- =====================================================

-- 1. 给 TABLE_METADATA 添加后端验证规则字段
ALTER TABLE T_COST_TABLE_METADATA ADD (
    VALIDATION_RULES CLOB  -- JSON: [{order, name, sql, condition, message, action:{sql, description}}]
);

-- 2. 创建销售记录表（用于测试执行器）
CREATE TABLE T_COST_SALES (
    ID              NUMBER(19)      PRIMARY KEY,
    EVAL_ID         NUMBER(19)      NOT NULL,
    EVAL_NO         VARCHAR2(32)    NOT NULL,
    PRODUCT_NAME    VARCHAR2(128)   NOT NULL,
    TOTAL_COST      NUMBER(18,2)    DEFAULT 0,
    DELETED         NUMBER(1)       DEFAULT 0,
    CREATE_TIME     TIMESTAMP       DEFAULT SYSTIMESTAMP,
    UPDATE_TIME     TIMESTAMP       DEFAULT SYSTIMESTAMP,
    CREATE_BY       VARCHAR2(64),
    UPDATE_BY       VARCHAR2(64)
);
CREATE SEQUENCE SEQ_COST_SALES START WITH 1 INCREMENT BY 1;

-- 3. 给 CostEval 表添加后端验证规则（3个，每个可带执行器）
UPDATE T_COST_TABLE_METADATA 
SET VALIDATION_RULES = '[
  {
    "order": 1,
    "name": "evalNoUnique",
    "sql": "SELECT COUNT(*) FROM T_COST_EVAL WHERE EVAL_NO = :evalNo AND ID != NVL(:id, -1) AND DELETED = 0",
    "condition": "result == 0",
    "message": "评估单号已存在"
  },
  {
    "order": 2,
    "name": "apexPlPositive",
    "sql": "SELECT CASE WHEN :apexPl > 0 THEN 1 ELSE 0 END FROM DUAL",
    "condition": "result == 1",
    "message": "批量必须大于0"
  },
  {
    "order": 3,
    "name": "costReasonable",
    "sql": "SELECT CASE WHEN :totalCost <= NVL(:outPriceRmb, 0) * :apexPl * 10000 THEN 1 ELSE 0 END FROM DUAL",
    "condition": "result == 1",
    "message": "总成本超出合理范围",
    "action": {
      "enabled": false,
      "sql": "INSERT INTO T_COST_SALES (ID, EVAL_ID, EVAL_NO, PRODUCT_NAME, TOTAL_COST, CREATE_BY) VALUES (SEQ_COST_SALES.NEXTVAL, :id, :evalNo, :productName, :totalCost, ''system'')",
      "description": "创建销售记录"
    }
  }
]'
WHERE TABLE_CODE = 'CostEval';

-- 4. 给从表 price 字段添加前端验证规则（2个验证器）
-- 验证器1: 单价不能为0
-- 验证器2: 单价不能为负数
UPDATE T_COST_COLUMN_METADATA 
SET RULES_CONFIG = '{"validate":[{"order":1,"type":"notZero","message":"单价不能为0"},{"order":2,"type":"min","value":0,"message":"单价不能为负数"}]}'
WHERE TABLE_METADATA_ID = (SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE = 'CostEvalDetail')
AND FIELD_NAME = 'price';

COMMIT;
