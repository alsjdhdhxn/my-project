# COLUMN_OVERRIDE 清理方案

## 前置检查

在执行任何清理操作前，必须在生产库确认以下 3 条 SQL 全部为 0：

```sql
-- 1. 是否还有未迁移的列（期望：0）
SELECT COUNT(*) FROM T_COST_COLUMN_METADATA WHERE DELETED = 0 AND NVL(MIGRATED, 0) <> 1;

-- 2. 是否还有属性为 null 的列（期望：0）
SELECT COUNT(*) FROM T_COST_COLUMN_METADATA WHERE DELETED = 0 
AND (VISIBLE IS NULL OR EDITABLE IS NULL OR REQUIRED IS NULL OR SEARCHABLE IS NULL);

-- 3. 还有多少未删除的 COLUMN_OVERRIDE 规则（记录数量，准备清理）
SELECT COUNT(*) FROM T_COST_PAGE_RULE WHERE RULE_TYPE = 'COLUMN_OVERRIDE' AND DELETED = 0;
```

如果 1 或 2 不为 0，先跑 `migrateColumnOverrides()` + `markUnmigratedTables()` 补齐。
如果 3 不为 0，确认这些规则已不再被依赖后执行软删除。

---

## 清理步骤（按顺序执行）

### 步骤 1：软删除残留的 COLUMN_OVERRIDE 规则

```sql
-- 备份后软删除
UPDATE T_COST_PAGE_RULE SET DELETED = 1 
WHERE RULE_TYPE = 'COLUMN_OVERRIDE' AND DELETED = 0;

-- 验证
SELECT COUNT(*) FROM T_COST_PAGE_RULE WHERE RULE_TYPE = 'COLUMN_OVERRIDE' AND DELETED = 0;
-- 期望：0
```

### 步骤 2：关闭旧入口 — 移除"页面管理"Tab

**文件：** `cost-web/src/views/_builtin/meta-config/index.vue`

移除 PagePanel 的 import 和 NTabPane，只保留一体化配置 + Lookup管理。

### 步骤 3：删除后端双读逻辑

**文件：** `cost-server/.../MetadataService.java`

改动：
- 删除 `loadColumnOverrides()` 方法
- 删除 `applyColumnOverrides()` 方法
- 删除 `parseColumnOverrides()` 方法
- 删除 `ColumnOverride` record
- 删除 `ColumnOverrideIndex` record
- `getTableMetadataWithPermission()` 中移除双读判断，直接用列自身属性

改后的 `getTableMetadataWithPermission()`：
```java
public TableMetadataDTO getTableMetadataWithPermission(...) {
    TableMetadataDTO base = getTableMetadata(tableCode);
    List<ColumnMetadataDTO> columns = base.columns();
    // 直接使用列自身的 visible/editable（不再走 COLUMN_OVERRIDE）
    columns = applyPermission(columns, permission, gridKey);
    if (applyUserPreferences) {
        columns = applyUserPreferences(columns, userId, pageCode, gridKey);
    }
    return base.withColumns(columns);
}
```

### 步骤 4：清理权限页的 COLUMN_OVERRIDE 依赖

**文件：** `cost-server/.../RoleManageService.java`

改动：
- `listPageColumns()` 方法中，移除 `resolveOverrideRules()` + `parseColumnOverrideSettings()` + `applyOverrideRestrictions()` 的调用
- 基线 visible/editable 已经从 `loadBaseColumnsByTableCode()` 的 SQL 直接读取（步骤 3 之前已改好）
- 删除 `ColumnOverrideSetting` / `ColumnOverrideSettingIndex` 等内部类

### 步骤 5：删除迁移相关代码

**删除文件：**
- `ColumnOverrideMigrationService.java`
- `ColumnOverrideMigrationRunner.java`

**删除接口（MetaConfigController.java）：**
- `GET /migration/split-tables`
- `GET /migration/migrate-overrides`
- `GET /migration/mark-unmigrated`
- `GET /migration/verify`

### 步骤 6：删除前端列覆盖相关组件（可选，不急）

**可删除文件：**
- `panels/ColumnOverrideDialog.vue`（如果确认没有其他地方引用）

**SectionBehavior.vue 中已经去掉了列覆盖入口，无需再改。**

### 步骤 7：补加 DEFAULT 约束

迁移已全部完成，给新字段补上默认值约束，让后续新建列自动有值：

```sql
ALTER TABLE T_COST_COLUMN_METADATA MODIFY VISIBLE DEFAULT 1;
ALTER TABLE T_COST_COLUMN_METADATA MODIFY EDITABLE DEFAULT 1;
ALTER TABLE T_COST_COLUMN_METADATA MODIFY REQUIRED DEFAULT 0;
ALTER TABLE T_COST_COLUMN_METADATA MODIFY SEARCHABLE DEFAULT 0;
ALTER TABLE T_COST_COLUMN_METADATA MODIFY MIGRATED DEFAULT 1;
```

---

## 风险与回滚

| 步骤 | 风险 | 回滚方式 |
|------|------|---------|
| 步骤 1 | 软删除规则后如果有漏网页面还依赖 | `UPDATE SET DELETED=0 WHERE ...` 恢复 |
| 步骤 3 | 删除双读后万一有未迁移列 | 前置检查确保 0 未迁移；如果出事回滚代码 |
| 步骤 4 | 权限页展示异常 | 已提前改好 SQL 读新字段，风险极低 |
| 步骤 5 | 无风险（迁移代码不影响业务） | — |

---

## 执行检查清单

- [ ] 前置检查 3 条 SQL 全部为 0
- [ ] 步骤 1：COLUMN_OVERRIDE 规则已软删除
- [ ] 步骤 2：页面管理 Tab 已移除
- [ ] 步骤 3：后端双读逻辑已删除，所有页面正常
- [ ] 步骤 4：权限页列配置正常展示
- [ ] 步骤 5：迁移代码已删除
- [ ] 步骤 7：DEFAULT 约束已补加
- [ ] 全量页面回归测试通过
