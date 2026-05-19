-- ============================================================
-- 步骤 2：DDL — 给 T_COST_COLUMN_METADATA 和 T_COST_TABLE_METADATA 加字段
-- 幂等：可重复执行，已存在的字段自动跳过
-- ============================================================

-- T_COST_COLUMN_METADATA 新增列属性字段
DECLARE
  PROCEDURE safe_add_column(p_table VARCHAR2, p_column VARCHAR2, p_definition VARCHAR2) IS
    v_cnt NUMBER;
  BEGIN
    SELECT COUNT(1) INTO v_cnt FROM USER_TAB_COLUMNS
    WHERE TABLE_NAME = p_table AND COLUMN_NAME = p_column;
    IF v_cnt = 0 THEN
      EXECUTE IMMEDIATE 'ALTER TABLE ' || p_table || ' ADD (' || p_column || ' ' || p_definition || ')';
      DBMS_OUTPUT.PUT_LINE('Added: ' || p_table || '.' || p_column);
    ELSE
      DBMS_OUTPUT.PUT_LINE('Exists: ' || p_table || '.' || p_column);
    END IF;
  END;
BEGIN
  -- T_COST_COLUMN_METADATA 新增字段
  safe_add_column('T_COST_COLUMN_METADATA', 'VISIBLE',       'NUMBER(1)');
  safe_add_column('T_COST_COLUMN_METADATA', 'EDITABLE',      'NUMBER(1)');
  safe_add_column('T_COST_COLUMN_METADATA', 'REQUIRED',      'NUMBER(1)');
  safe_add_column('T_COST_COLUMN_METADATA', 'SEARCHABLE',    'NUMBER(1)');
  safe_add_column('T_COST_COLUMN_METADATA', 'WIDTH',         'NUMBER(5)');
  safe_add_column('T_COST_COLUMN_METADATA', 'PINNED',        'VARCHAR2(10)');
  safe_add_column('T_COST_COLUMN_METADATA', 'CELL_EDITOR',   'VARCHAR2(64)');
  safe_add_column('T_COST_COLUMN_METADATA', 'DEFAULT_VALUE',  'VARCHAR2(1000)');
  safe_add_column('T_COST_COLUMN_METADATA', 'RULES_CONFIG',  'CLOB');
  safe_add_column('T_COST_COLUMN_METADATA', 'MIGRATED',      'NUMBER(1) DEFAULT 0');

  -- T_COST_TABLE_METADATA 新增归属字段
  safe_add_column('T_COST_TABLE_METADATA', 'PAGE_CODE',          'VARCHAR2(64)');
  safe_add_column('T_COST_TABLE_METADATA', 'COMPONENT_KEY',      'VARCHAR2(64)');
  safe_add_column('T_COST_TABLE_METADATA', 'SOURCE_TABLE_CODE',  'VARCHAR2(64)');
END;
/

-- 加注释
COMMENT ON COLUMN T_COST_COLUMN_METADATA.VISIBLE IS '是否显示 1=是 0=否（迁移前为null）';
COMMENT ON COLUMN T_COST_COLUMN_METADATA.EDITABLE IS '是否可编辑 1=是 0=否（迁移前为null）';
COMMENT ON COLUMN T_COST_COLUMN_METADATA.REQUIRED IS '是否必填 1=是 0=否（迁移前为null）';
COMMENT ON COLUMN T_COST_COLUMN_METADATA.SEARCHABLE IS '是否可搜索 1=是 0=否（迁移前为null）';
COMMENT ON COLUMN T_COST_COLUMN_METADATA.WIDTH IS '列宽(px)';
COMMENT ON COLUMN T_COST_COLUMN_METADATA.PINNED IS '固定列方向 left/right/null';
COMMENT ON COLUMN T_COST_COLUMN_METADATA.CELL_EDITOR IS '编辑器类型';
COMMENT ON COLUMN T_COST_COLUMN_METADATA.DEFAULT_VALUE IS '默认值（支持JSON，超长放RULES_CONFIG）';
COMMENT ON COLUMN T_COST_COLUMN_METADATA.RULES_CONFIG IS '扩展配置JSON(format/precision/trimZeros/roundMode/cellEditorParams/aggFunc/lookup等)';
COMMENT ON COLUMN T_COST_COLUMN_METADATA.MIGRATED IS '迁移状态 0=未迁移 1=已迁移';
COMMENT ON COLUMN T_COST_TABLE_METADATA.PAGE_CODE IS '归属页面编码';
COMMENT ON COLUMN T_COST_TABLE_METADATA.COMPONENT_KEY IS '归属组件标识';
COMMENT ON COLUMN T_COST_TABLE_METADATA.SOURCE_TABLE_CODE IS '拆分前原始表编码';
