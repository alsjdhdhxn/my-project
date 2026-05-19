# COLUMN_OVERRIDE 废弃迁移方案（v2）

## 目标

将 COLUMN_OVERRIDE 规则中的列属性下沉到 T_COST_COLUMN_METADATA，实现"页面即配置边界"——每个页面拥有独立的表/列元数据，互不影响。

---

## 回滚策略

### 备份方式

使用 CTAS（CREATE TABLE AS SELECT）备份，简单直接，出错后可直接查看备份表数据对比：

```sql
-- ============================================================
-- 第 1 步：备份所有元数据表（以 20260519 结尾）
-- 出问题时 rename 回来 + 回滚代码即可恢复
-- 同时可直接 SELECT 备份表对比数据差异
-- ============================================================

CREATE TABLE T_COST_TABLE_METADATA_20260519 AS SELECT * FROM T_COST_TABLE_METADATA;
CREATE TABLE T_COST_COLUMN_METADATA_20260519 AS SELECT * FROM T_COST_COLUMN_METADATA;
CREATE TABLE T_COST_PAGE_COMPONENT_20260519 AS SELECT * FROM T_COST_PAGE_COMPONENT;
CREATE TABLE T_COST_PAGE_RULE_20260519 AS SELECT * FROM T_COST_PAGE_RULE;
CREATE TABLE T_COST_RESOURCE_20260519 AS SELECT * FROM T_COST_RESOURCE;
CREATE TABLE T_COST_ROLE_PAGE_20260519 AS SELECT * FROM T_COST_ROLE_PAGE;

-- 验证备份行数
SELECT 'T_COST_TABLE_METADATA' AS TBL, COUNT(*) AS CNT FROM T_COST_TABLE_METADATA_20260519
UNION ALL
SELECT 'T_COST_COLUMN_METADATA', COUNT(*) FROM T_COST_COLUMN_METADATA_20260519
UNION ALL
SELECT 'T_COST_PAGE_COMPONENT', COUNT(*) FROM T_COST_PAGE_COMPONENT_20260519
UNION ALL
SELECT 'T_COST_PAGE_RULE', COUNT(*) FROM T_COST_PAGE_RULE_20260519
UNION ALL
SELECT 'T_COST_RESOURCE', COUNT(*) FROM T_COST_RESOURCE_20260519
UNION ALL
SELECT 'T_COST_ROLE_PAGE', COUNT(*) FROM T_COST_ROLE_PAGE_20260519;

-- 同时导出各表完整 DDL（含约束、索引、默认值），保存到文件备查
-- SELECT DBMS_METADATA.GET_DDL('TABLE', 'T_COST_COLUMN_METADATA', 'CMX') FROM DUAL;
```

### 回滚步骤

```
1. 停服务
2. DROP 新表 → RENAME 备份表回来（或 impdp 恢复）
3. 回滚代码 (git revert)
4. 重启服务
```

---

## 迁移顺序（两阶段）

### 核心原则：先拆后写，不动共享数据

```
阶段 1：拆分独立副本
  ① 备份
  ② DDL 加字段
  ③ 按页面+组件复制共享表为独立副本
  ④ 更新 PAGE_COMPONENT 引用到副本

阶段 2：迁移配置
  ⑤ 把每个页面自己的 COLUMN_OVERRIDE 写入对应副本列
  ⑥ 后端改为双读（新字段优先，旧规则兜底）
  ⑦ 前端隐藏"列覆盖"配置入口
  ⑧ 验证所有页面正常
  ⑨ 软删除已迁移的 COLUMN_OVERRIDE
  ⑩ 清理后端旧代码
```

---

## 阶段 1：拆分独立副本

### 步骤 1：备份（见上方回滚策略）

### 步骤 2：DDL — 给 T_COST_COLUMN_METADATA 加字段

```sql
-- ============================================================
-- 新增列属性字段
-- 注意：COLUMN_NAME 字段名不改，沿用现有命名
-- ============================================================

ALTER TABLE T_COST_COLUMN_METADATA ADD (
  VISIBLE       NUMBER(1),
  EDITABLE      NUMBER(1),
  REQUIRED      NUMBER(1),
  SEARCHABLE    NUMBER(1),
  WIDTH         NUMBER(5),
  PINNED        VARCHAR2(10),
  CELL_EDITOR   VARCHAR2(64),
  DEFAULT_VALUE VARCHAR2(1000),
  RULES_CONFIG  CLOB,
  MIGRATED      NUMBER(1) DEFAULT 0
);

COMMENT ON COLUMN T_COST_COLUMN_METADATA.VISIBLE IS '是否显示 1=是 0=否（迁移前为null）';
COMMENT ON COLUMN T_COST_COLUMN_METADATA.EDITABLE IS '是否可编辑 1=是 0=否（迁移前为null）';
COMMENT ON COLUMN T_COST_COLUMN_METADATA.REQUIRED IS '是否必填 1=是 0=否（迁移前为null）';
COMMENT ON COLUMN T_COST_COLUMN_METADATA.SEARCHABLE IS '是否可搜索 1=是 0=否（迁移前为null）';
COMMENT ON COLUMN T_COST_COLUMN_METADATA.WIDTH IS '列宽(px)';
COMMENT ON COLUMN T_COST_COLUMN_METADATA.PINNED IS '固定列方向 left/right/null';
COMMENT ON COLUMN T_COST_COLUMN_METADATA.CELL_EDITOR IS '编辑器类型';
COMMENT ON COLUMN T_COST_COLUMN_METADATA.DEFAULT_VALUE IS '默认值（支持 JSON 格式）';
COMMENT ON COLUMN T_COST_COLUMN_METADATA.RULES_CONFIG IS '扩展配置JSON(format/precision/trimZeros/roundMode/cellEditorParams/aggFunc/lookup等)';
COMMENT ON COLUMN T_COST_COLUMN_METADATA.MIGRATED IS '迁移状态 0=未迁移 1=已迁移（双读兜底判断依据）';
```

**注意**：如果 RULES_CONFIG 字段已存在则跳过该列的 ADD。执行前先查：
```sql
SELECT COLUMN_NAME FROM DBA_TAB_COLUMNS
WHERE TABLE_NAME = 'T_COST_COLUMN_METADATA' AND COLUMN_NAME = 'RULES_CONFIG';
```

**DDL 幂等性要求**：所有新增列都必须做"存在则跳过"的 PL/SQL 包装，脚本要能重复执行：
```sql
-- 示例：安全加列（所有新增字段都用这个模式）
DECLARE
  v_cnt NUMBER;
BEGIN
  SELECT COUNT(1) INTO v_cnt FROM USER_TAB_COLUMNS
  WHERE TABLE_NAME = 'T_COST_COLUMN_METADATA' AND COLUMN_NAME = 'VISIBLE';
  IF v_cnt = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE T_COST_COLUMN_METADATA ADD (VISIBLE NUMBER(1))';
  END IF;
  -- ... 每个字段同理
END;
/
```

### 步骤 3：识别共享表

```sql
-- 查出哪些 TABLE_CODE 被多个页面引用
-- 注意：要同时检查 REF_TABLE_CODE 和 componentConfig JSON 中的 tabs[].tableCode

SELECT REF_TABLE_CODE AS TABLE_CODE,
       LISTAGG(PAGE_CODE, ', ') WITHIN GROUP (ORDER BY PAGE_CODE) AS PAGES,
       COUNT(DISTINCT PAGE_CODE) AS PAGE_COUNT
FROM T_COST_PAGE_COMPONENT
WHERE REF_TABLE_CODE IS NOT NULL AND DELETED = 0
GROUP BY REF_TABLE_CODE
HAVING COUNT(DISTINCT PAGE_CODE) > 1;
```

### 步骤 4：按页面复制独立副本（Java 迁移程序）

**不能用简单 SQL 做**，因为需要：
- 解析 componentConfig JSON 中 tabs 的 tableCode
- 生成新 TABLE_CODE（规则见下方）
- 复制 TABLE_METADATA + 所有 COLUMN_METADATA
- 更新 PAGE_COMPONENT 的引用

#### TABLE_CODE 生成规则

```
所有页面都复制独立副本，原始共享表不再被任何页面直接引用。

规则：
  新 TABLE_CODE = 原 TABLE_CODE + '_P' + pageCode 的 hash 后缀（4位hex）

示例：
  原共享 TABLE_CODE: CostPinggu
  页面 A 副本: CostPinggu_PA3F2
  页面 B 副本: CostPinggu_PB7E1

  原始 CostPinggu 表元数据保留，标记为 SOURCE（不被任何 PAGE_COMPONENT 引用）。
  所有页面都使用自己的副本，迁移后不存在任何页面指向原始 code。

不共享的表（只有一个页面引用）：
  直接在原表上标记归属（PAGE_CODE/COMPONENT_KEY），TABLE_CODE 不变。
  因为只有一个使用者，无需复制。

防重：生成后查重，冲突时递增后缀。
长度限制：TABLE_CODE VARCHAR2(64)，原 code + 6 字符后缀不会超。
```

#### 给表元数据增加归属字段（可选但推荐）

```sql
ALTER TABLE T_COST_TABLE_METADATA ADD (
  PAGE_CODE      VARCHAR2(64),
  COMPONENT_KEY  VARCHAR2(64),
  SOURCE_TABLE_CODE VARCHAR2(64)
);

COMMENT ON COLUMN T_COST_TABLE_METADATA.PAGE_CODE IS '归属页面编码（页面独有后必填）';
COMMENT ON COLUMN T_COST_TABLE_METADATA.COMPONENT_KEY IS '归属组件标识';
COMMENT ON COLUMN T_COST_TABLE_METADATA.SOURCE_TABLE_CODE IS '原始表编码（拆分前的共享 code）';
```

#### 迁移逻辑伪代码

```java
// 复用 MetaConfigService.listTablesByPageCode() 的逻辑解析页面关联表
// 而不是简单只查 REF_TABLE_CODE

for (PageComponent comp : 所有非 LAYOUT 组件) {
    List<String> tableCodes = extractTableCodes(comp); // REF_TABLE_CODE + JSON tabs

    for (String tableCode : tableCodes) {
        if (已被该页面独占) continue;
        if (被其他页面引用) {
            // 复制副本
            String newTableCode = generateUniqueCode(tableCode, comp);
            TableMetadata copy = copyTableMetadata(tableCode, newTableCode, comp.getPageCode(), comp.getComponentKey());
            copyAllColumns(originalTableId, copy.getId());

            // 更新组件引用
            updateComponentRef(comp, tableCode, newTableCode);
        } else {
            // 不共享，直接标记归属
            updateTableMetadataOwnership(tableCode, comp.getPageCode(), comp.getComponentKey());
        }
    }
}
```

### 步骤 5：验证拆分结果

**必须用 Java 验证程序，不能只查 REF_TABLE_CODE**（因为 tabs JSON 中的表引用查不到）。

```java
// 验证脚本：复用 listTablesByPageCode() 的完整解析逻辑
// 输出格式：tableCode -> [引用它的 pageCode/componentKey 列表]

Map<String, List<String>> tableUsage = new LinkedHashMap<>();

for (String pageCode : allPageCodes) {
    List<String> tableCodes = resolveAllTableCodes(pageCode); // 复用 listTablesByPageCode 逻辑
    for (String tc : tableCodes) {
        tableUsage.computeIfAbsent(tc, k -> new ArrayList<>()).add(pageCode);
    }
}

// 输出仍然共享的表（期望：0 个）
tableUsage.entrySet().stream()
    .filter(e -> e.getValue().size() > 1)
    .forEach(e -> log.error("仍然共享: {} -> {}", e.getKey(), e.getValue()));
```

验证通过条件：**所有 tableCode 只被 1 个 pageCode 引用**。

---

## 阶段 2：迁移 COLUMN_OVERRIDE 配置

### 步骤 6：写入列属性（Java 迁移程序）

```java
// 现在每个表都是页面独有的，不会互相覆盖

for (PageRule rule : 所有 COLUMN_OVERRIDE 规则, DELETED=0) {
    String pageCode = rule.getPageCode();
    String componentKey = rule.getComponentKey();

    // 找到该组件当前引用的 TABLE_CODE（已拆分后的）
    PageComponent comp = findComponent(pageCode, componentKey);
    String tableCode = comp.getRefTableCode(); // 或从 JSON 解析
    TableMetadata table = findByTableCode(tableCode);

    // 解析 COLUMN_OVERRIDE JSON
    JsonArray items = parseJson(rule.getRules());

    for (JsonObject item : items) {
        String columnName = item.getString("columnName");
        Long columnId = item.getLong("columnId");

        // 找到对应列
        ColumnMetadata col = findColumn(table.getId(), columnId, columnName);
        if (col == null) continue; // 可能已被删除的列

        // 写入基础属性
        if (item.has("visible"))    col.setVisible(item.getBoolean("visible") ? 1 : 0);
        if (item.has("editable"))   col.setEditable(item.getBoolean("editable") ? 1 : 0);
        if (item.has("required"))   col.setRequired(item.getBoolean("required") ? 1 : 0);
        if (item.has("searchable")) col.setSearchable(item.getBoolean("searchable") ? 1 : 0);
        if (item.has("width"))      col.setWidth(item.getInt("width"));
        if (item.has("pinned"))     col.setPinned(item.getString("pinned"));
        if (item.has("cellEditor")) col.setCellEditor(item.getString("cellEditor"));
        if (item.has("defaultValue")) col.setDefaultValue(stringify(item.get("defaultValue")));

        // 合并复杂配置到 RULES_CONFIG
        JsonObject rulesConfig = parseExistingRulesConfig(col.getRulesConfig());
        if (item.has("format"))          rulesConfig.set("format", item.get("format"));
        if (item.has("precision"))       rulesConfig.put("precision", item.getInt("precision"));
        if (item.has("trimZeros"))       rulesConfig.put("trimZeros", item.getBoolean("trimZeros"));
        if (item.has("roundMode"))       rulesConfig.put("roundMode", item.getString("roundMode"));
        if (item.has("cellEditorParams"))rulesConfig.set("cellEditorParams", item.get("cellEditorParams"));
        if (item.has("aggFunc"))         rulesConfig.put("aggFunc", item.getString("aggFunc"));
        col.setRulesConfig(serialize(rulesConfig));

        // 保存
        columnMetadataMapper.updateById(col);
    }

    // 迁移完成后，标记该表所有列为已迁移
    // UPDATE T_COST_COLUMN_METADATA SET MIGRATED = 1 WHERE TABLE_METADATA_ID = table.getId()
    markColumnsMigrated(table.getId());

    // 标记该规则为已迁移（不删除）
    rule.setDescription("[已迁移] " + rule.getDescription());
    pageRuleMapper.updateById(rule);
}

// ============================================================
// 补充：无 COLUMN_OVERRIDE 的表也要标记已迁移
// 某些表本来就没有 COLUMN_OVERRIDE 规则，拆分后仍是 MIGRATED=0
// 需要给这些表的列设默认值并标记为已迁移
// ============================================================

for (TableMetadata table : 所有页面独有表, MIGRATED=0 的) {
    // 检查是否有对应的 COLUMN_OVERRIDE 规则
    boolean hasOverride = existsColumnOverride(table.getPageCode(), table.getComponentKey());
    if (!hasOverride) {
        // 没有 COLUMN_OVERRIDE，直接用默认值标记为已迁移
        String sql = "UPDATE T_COST_COLUMN_METADATA SET " +
            "VISIBLE = 1, EDITABLE = 1, REQUIRED = 0, SEARCHABLE = 0, MIGRATED = 1 " +
            "WHERE TABLE_METADATA_ID = " + table.getId() + " AND MIGRATED = 0";
        dynamicMapper.update(sql);
    }
}
```

### 步骤 7：后端改为双读模式

```java
// MetadataService.getTableMetadataWithPermission() 改动：

public TableMetadataDTO getTableMetadataWithPermission(...) {
    TableMetadataDTO base = getTableMetadata(tableCode);
    List<ColumnMetadataDTO> columns = base.columns();

    // 双读兜底：按 MIGRATED 字段判断，不按 visible 是否 null
    // MIGRATED=1 表示已迁移完成，直接用列自身属性
    // MIGRATED=0 或 null 表示未迁移，仍走旧 COLUMN_OVERRIDE 合并
    boolean allMigrated = columns.stream().allMatch(c -> Integer.valueOf(1).equals(c.migrated()));

    if (!allMigrated) {
        // 旧逻辑：从 COLUMN_OVERRIDE 合并（兜底）
        columns = applyColumnOverrides(columns, loadColumnOverrides(pageCode, gridKey));
    }

    // 权限合并（保留）
    columns = applyPermission(columns, permission, gridKey);

    // 用户偏好（保留）
    if (applyUserPreferences) {
        columns = applyUserPreferences(columns, userId, pageCode, gridKey);
    }

    return base.withColumns(columns);
}
```

这样：
- 已迁移的页面：走新逻辑，直接从列读取
- 未迁移的页面：自动 fallback 到旧逻辑
- 可以逐步迁移，不用一次性全部完成

### 步骤 8：前端改动

| 改动 | 说明 |
|------|------|
| SectionTables.vue 变为可编辑 | 加 visible/editable/width/cellEditor 等可编辑列 |
| SectionBehavior.vue 隐藏"列覆盖"行 | 已迁移的页面不显示；未迁移的页面仍显示（fallback） |
| 向导生成 | 不再创建 COLUMN_OVERRIDE，直接写列属性 |

### 步骤 9：逐页面验证

```
对每个页面：
1. 打开页面，确认列的显示/隐藏/可编辑状态与迁移前一致
2. 在一体化配置中确认列属性正确
3. 修改某列属性（如 visible），刷新页面确认生效
```

### 步骤 10：清理（第二个版本，不和迁移同版本发布）

**不在迁移同一版本清理旧代码。** 先上线双读模式，稳定运行一段时间后再做清理。

第一版上线内容：双读模式 + 前端隐藏列覆盖入口
第二版上线内容（稳定 1-2 周后）：

```sql
-- 软删除已迁移的 COLUMN_OVERRIDE 规则
UPDATE T_COST_PAGE_RULE SET DELETED = 1
WHERE RULE_TYPE = 'COLUMN_OVERRIDE' AND DESCRIPTION LIKE '[已迁移]%';

-- 给未迁移列补默认值（所有列已迁移后执行）
UPDATE T_COST_COLUMN_METADATA SET VISIBLE = 1 WHERE VISIBLE IS NULL;
UPDATE T_COST_COLUMN_METADATA SET EDITABLE = 1 WHERE EDITABLE IS NULL;
UPDATE T_COST_COLUMN_METADATA SET REQUIRED = 0 WHERE REQUIRED IS NULL;
UPDATE T_COST_COLUMN_METADATA SET SEARCHABLE = 0 WHERE SEARCHABLE IS NULL;

-- 补加 DEFAULT 约束（新建列元数据时自动有默认值）
ALTER TABLE T_COST_COLUMN_METADATA MODIFY VISIBLE DEFAULT 1;
ALTER TABLE T_COST_COLUMN_METADATA MODIFY EDITABLE DEFAULT 1;
ALTER TABLE T_COST_COLUMN_METADATA MODIFY REQUIRED DEFAULT 0;
ALTER TABLE T_COST_COLUMN_METADATA MODIFY SEARCHABLE DEFAULT 0;
ALTER TABLE T_COST_COLUMN_METADATA MODIFY MIGRATED DEFAULT 1;
```

后端清理（第二版）：
- 移除 `loadColumnOverrides()` 方法
- 移除 `applyColumnOverrides()` 方法
- 移除 `ColumnOverride` record
- 移除 `ColumnOverrideIndex` record
- 移除前端 ColumnOverrideDialog 组件

---

## T_COST_COLUMN_METADATA 最终字段清单

| 字段 | 类型 | 说明 | 状态 |
|------|------|------|------|
| ID | NUMBER(19) | 主键 | 原有 |
| TABLE_METADATA_ID | NUMBER(19) | 外键 | 原有 |
| COLUMN_NAME | VARCHAR2(64) | 数据库列名 | 原有（不改名） |
| QUERY_COLUMN | VARCHAR2(128) | 查询表达式 | 原有 |
| TARGET_COLUMN | VARCHAR2(64) | 写入目标列 | 原有 |
| HEADER_TEXT | VARCHAR2(128) | 列标题 | 原有 |
| DATA_TYPE | VARCHAR2(32) | 数据类型 | 原有 |
| DISPLAY_ORDER | NUMBER(5) | 显示顺序 | 原有 |
| SORTABLE | NUMBER(1) | 是否可排序 | 原有 |
| FILTERABLE | NUMBER(1) | 是否可筛选 | 原有 |
| IS_VIRTUAL | NUMBER(1) | 是否虚拟列 | 原有 |
| DICT_TYPE | VARCHAR2(64) | 字典类型 | 原有 |
| DELETED | NUMBER(1) | 软删除 | 原有 |
| **VISIBLE** | **NUMBER(1) DEFAULT 1** | **是否显示** | **新增** |
| **EDITABLE** | **NUMBER(1) DEFAULT 1** | **是否可编辑** | **新增** |
| **REQUIRED** | **NUMBER(1) DEFAULT 0** | **是否必填** | **新增** |
| **SEARCHABLE** | **NUMBER(1) DEFAULT 0** | **是否可搜索** | **新增** |
| **WIDTH** | **NUMBER(5)** | **列宽(px)** | **新增** |
| **PINNED** | **VARCHAR2(10)** | **固定方向** | **新增** |
| **CELL_EDITOR** | **VARCHAR2(64)** | **编辑器类型** | **新增** |
| **DEFAULT_VALUE** | **VARCHAR2(1000)** | **默认值（支持 JSON）** | **新增** |
| **RULES_CONFIG** | **CLOB** | **扩展配置 JSON** | **新增（如已存在则保留）** |
| **MIGRATED** | **NUMBER(1) DEFAULT 0** | **迁移状态标记** | **新增** |

> **DEFAULT_VALUE 超长策略**：超过 1000 字符或非简单标量的 defaultValue（对象/数组/表达式），放入 RULES_CONFIG.defaultValue 字段中。迁移程序在写入时检查长度，超长则自动转存。

## T_COST_TABLE_METADATA 新增归属字段

| 字段 | 类型 | 说明 | 状态 |
|------|------|------|------|
| PAGE_CODE | VARCHAR2(64) | 归属页面 | 新增 |
| COMPONENT_KEY | VARCHAR2(64) | 归属组件 | 新增 |
| SOURCE_TABLE_CODE | VARCHAR2(64) | 拆分前原始 code | 新增 |

---

## 风险与应对

| 风险 | 等级 | 应对 |
|------|------|------|
| 迁移顺序错误导致配置覆盖 | 高 | 严格按"先拆后写"顺序，不动共享数据 |
| componentConfig JSON 中的表引用漏掉 | 中 | 复用现有 `listTablesByPageCode` 解析逻辑 |
| TABLE_CODE 生成冲突 | 低 | 生成后查重，冲突时递增后缀 |
| RULES_CONFIG 字段不存在 | 低 | DDL 执行前检查，已存在则跳过 |
| 某些页面未迁移时功能异常 | 低 | 双读模式兜底，MIGRATED=0/null 时走旧 COLUMN_OVERRIDE 逻辑 |
| 回滚时约束/索引丢失 | 中 | 用 Data Pump 或同时备份 DDL |

---

## 预计工作量

| 阶段 | 内容 | 工作量 |
|------|------|--------|
| 1 | 备份 + DDL | 0.5 天 |
| 2 | 共享表识别 + 拆分程序 | 1.5 天 |
| 3 | COLUMN_OVERRIDE 写入迁移程序 | 1 天 |
| 4 | 后端双读模式 + Entity/DTO 改动 | 1 天 |
| 5 | 前端 SectionTables 可编辑 | 1 天 |
| 6 | 向导适配 + 前端清理 | 0.5 天 |
| 7 | 逐页面验证 | 1 天 |
| **合计** | | **6.5 天** |

---

## 执行检查清单

- [ ] Data Pump 备份完成，验证可恢复
- [ ] DDL 执行成功，字段已加
- [ ] 共享表查询结果确认，明确要拆几张
- [ ] 拆分程序跑完，验证 0 共享
- [ ] 迁移程序跑完，每页列属性与迁移前一致
- [ ] 后端双读模式部署，所有页面功能正常
- [ ] 前端一体化配置列可编辑，保存生效
- [ ] 向导创建新页面，不再生成 COLUMN_OVERRIDE
- [ ] 全量页面回归测试通过
- [ ] 无 COLUMN_OVERRIDE 的页面表已补默认值并标记 MIGRATED=1
- [ ] 软删除旧规则
- [ ] 第二版 DEFAULT 约束已补加
- [ ] 清理旧代码
