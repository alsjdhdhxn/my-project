-- ============================================================
-- LOOKUP 规则迁移到 COLUMN_OVERRIDE
-- 将 LOOKUP 类型的 PAGE_RULE 中的 lookupCode + mapping 配置
-- 合并到对应 componentKey 的 COLUMN_OVERRIDE 规则中
-- 
-- 迁移后，前端从 COLUMN_OVERRIDE 中读取 cellEditor='lookup' 的配置
-- 原 LOOKUP 规则软删除（DELETED=1），保留向后兼容
-- ============================================================

-- 1. 备份 LOOKUP 规则
CREATE TABLE T_COST_PAGE_RULE_LOOKUP_BAK AS
SELECT * FROM T_COST_PAGE_RULE WHERE RULE_TYPE = 'LOOKUP' AND DELETED = 0;

-- 2. 迁移：对每条 LOOKUP 规则，将其内容合并到 COLUMN_OVERRIDE
-- 策略：
--   a) 如果该 pageCode+componentKey 已有 COLUMN_OVERRIDE，在其 JSON 数组末尾追加 lookup 项
--   b) 如果没有 COLUMN_OVERRIDE，新建一条
DECLARE
  v_lookup_rules   CLOB;
  v_override_rules CLOB;
  v_override_id    NUMBER;
  v_new_items      CLOB;
  v_count          NUMBER;
BEGIN
  FOR rec IN (
    SELECT ID, PAGE_CODE, COMPONENT_KEY, RULES
    FROM T_COST_PAGE_RULE
    WHERE RULE_TYPE = 'LOOKUP' AND DELETED = 0
  ) LOOP
    v_lookup_rules := rec.RULES;
    IF v_lookup_rules IS NULL OR DBMS_LOB.GETLENGTH(v_lookup_rules) < 3 THEN
      CONTINUE;
    END IF;

    -- 将 LOOKUP 数组中每个 item 转为 COLUMN_OVERRIDE 格式
    -- 原始: [{"field":"xxx","lookupCode":"yyy","mapping":{...},"noFillback":true,...}]
    -- 目标: [{"field":"xxx","cellEditor":"lookup","cellEditorParams":{"lookupCode":"yyy","mapping":{...},...}}]
    v_new_items := '';
    FOR item IN (
      SELECT jt.field_val, jt.item_json
      FROM JSON_TABLE(v_lookup_rules, '$[*]'
        COLUMNS (
          field_val VARCHAR2(200) PATH '$.field',
          item_json CLOB FORMAT JSON PATH '$'
        )
      ) jt
      WHERE jt.field_val IS NOT NULL
    ) LOOP
      IF v_new_items IS NOT NULL AND LENGTH(v_new_items) > 0 THEN
        v_new_items := v_new_items || ',';
      END IF;
      v_new_items := v_new_items ||
        '{"field":"' || item.field_val || '","cellEditor":"lookup","cellEditorParams":' || item.item_json || '}';
    END LOOP;

    IF v_new_items IS NULL OR LENGTH(v_new_items) = 0 THEN
      CONTINUE;
    END IF;

    -- 查找对应的 COLUMN_OVERRIDE
    v_override_id := NULL;
    v_override_rules := NULL;
    BEGIN
      SELECT ID, RULES INTO v_override_id, v_override_rules
      FROM T_COST_PAGE_RULE
      WHERE PAGE_CODE = rec.PAGE_CODE
        AND COMPONENT_KEY = rec.COMPONENT_KEY
        AND RULE_TYPE = 'COLUMN_OVERRIDE'
        AND DELETED = 0
        AND ROWNUM = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_override_id := NULL;
    END;

    IF v_override_id IS NOT NULL THEN
      -- 已有 COLUMN_OVERRIDE，在数组末尾追加
      -- 去掉末尾的 ']'，追加新项，再加 ']'
      IF v_override_rules IS NULL OR DBMS_LOB.GETLENGTH(v_override_rules) < 3 THEN
        v_override_rules := '[' || v_new_items || ']';
      ELSE
        v_override_rules := RTRIM(v_override_rules);
        -- 去掉末尾 ]
        v_override_rules := SUBSTR(v_override_rules, 1, LENGTH(v_override_rules) - 1);
        v_override_rules := v_override_rules || ',' || v_new_items || ']';
      END IF;
      UPDATE T_COST_PAGE_RULE SET RULES = v_override_rules, UPDATE_TIME = SYSTIMESTAMP WHERE ID = v_override_id;
    ELSE
      -- 没有 COLUMN_OVERRIDE，新建
      INSERT INTO T_COST_PAGE_RULE (ID, PAGE_CODE, COMPONENT_KEY, RULE_TYPE, RULES, SORT_ORDER, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY)
      VALUES (SEQ_COST_PAGE_RULE.NEXTVAL, rec.PAGE_CODE, rec.COMPONENT_KEY, 'COLUMN_OVERRIDE',
              '[' || v_new_items || ']', 0, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system');
    END IF;

    -- 软删除原 LOOKUP 规则
    UPDATE T_COST_PAGE_RULE SET DELETED = 1, UPDATE_TIME = SYSTIMESTAMP WHERE ID = rec.ID;
  END LOOP;

  COMMIT;
END;
/

-- 3. 验证迁移结果
-- 检查是否还有未迁移的 LOOKUP 规则（应为 0）
SELECT COUNT(*) AS remaining_lookup FROM T_COST_PAGE_RULE WHERE RULE_TYPE = 'LOOKUP' AND DELETED = 0;

-- 查看迁移后包含 lookup 的 COLUMN_OVERRIDE
SELECT PAGE_CODE, COMPONENT_KEY, RULES
FROM T_COST_PAGE_RULE
WHERE RULE_TYPE = 'COLUMN_OVERRIDE' AND DELETED = 0
AND RULES LIKE '%"lookup"%';

-- 查看备份数据量
SELECT COUNT(*) AS backup_count FROM T_COST_PAGE_RULE_LOOKUP_BAK;
