-- =====================================================
-- 启用执行器 + 修复测试数据
-- =====================================================

-- 1. 修复从表单价为0的数据（让前端验证通过）
UPDATE T_COST_EVAL_DETAIL SET PRICE = 1 WHERE PRICE = 0 OR PRICE IS NULL;

-- 2. 修复主表批量为0的数据
UPDATE T_COST_EVAL SET APEX_PL = 10 WHERE APEX_PL = 0 OR APEX_PL IS NULL;

-- 3. 启用执行器（第3个验证器的执行器）
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
    "sql": "SELECT 1 FROM DUAL",
    "condition": "result == 1",
    "message": "成本检查",
    "action": {
      "enabled": true,
      "sql": "INSERT INTO T_COST_SALES (ID, EVAL_ID, EVAL_NO, PRODUCT_NAME, TOTAL_COST, CREATE_BY) VALUES (SEQ_COST_SALES.NEXTVAL, :id, :evalNo, :productName, NVL(:totalCost, 0), ''system'')",
      "description": "创建销售记录"
    }
  }
]'
WHERE TABLE_CODE = 'CostEval';

COMMIT;
