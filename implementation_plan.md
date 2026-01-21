# 自定义 SQL 导出功能实现计划

## 需求描述

支持用户在后台定义导出 SQL，配置列顺序、列名、是否显示等，前端通过名称选择导出配置，支持"导出当前"和"导出所有"两种模式。

## 核心设计

### 导出模式

| 模式 | 说明 |
|------|------|
| 导出所有 | 直接执行配置的 SQL |
| 导出当前 | 根据页面筛选条件，拼接 EXISTS 子句过滤数据 |

### SQL 拼接逻辑

**假设条件：**
- 页面 tableCode: `CostGoodsPrice`，视图: `T_COST_GOODS_PRICE_V`
- 页面筛选条件: `price > 0`
- 导出配置的主表 SQL: `SELECT a.* FROM T_PINGGU a`
- 主表别名: `a`，主键列: `a.GOODSID`

**导出当前 - 主表拼接后：**
```sql
SELECT a.* FROM T_PINGGU a
WHERE EXISTS (
    SELECT 1 FROM T_COST_GOODS_PRICE_V p
    WHERE p.GOODSID = a.GOODSID  -- 关联字段
    AND p.PRICE > 0              -- 页面筛选条件
    AND p.DELETED = 0
)
```

**导出当前 - 从表拼接后：**
```sql
SELECT d.* FROM T_PINGGU a
JOIN T_PINGGU_DTL d ON a.DOCID = d.DOCID  -- 原始从表 SQL
WHERE EXISTS (
    SELECT 1 FROM T_COST_GOODS_PRICE_V p
    WHERE p.GOODSID = a.GOODSID
    AND p.PRICE > 0
    AND p.DELETED = 0
)
```

---

## Proposed Changes

### 数据库

#### [NEW] T_COST_EXPORT_CONFIG (导出配置主表)

```sql
CREATE TABLE T_COST_EXPORT_CONFIG (
    ID NUMBER PRIMARY KEY,
    EXPORT_CODE VARCHAR2(100) NOT NULL,       -- 导出配置编码（唯一）
    EXPORT_NAME VARCHAR2(200) NOT NULL,       -- 导出名称（显示给用户）
    PAGE_CODE VARCHAR2(100) NOT NULL,         -- 关联页面
    
    -- 主表 SQL 配置
    MASTER_SQL CLOB NOT NULL,                 -- 主表查询 SQL
    MASTER_TABLE_ALIAS VARCHAR2(50),          -- 主表别名（用于 EXISTS 拼接）
    PK_COLUMN VARCHAR2(100),                  -- 主表主键列（关联页面视图）
    PAGE_VIEW_ALIAS VARCHAR2(50) DEFAULT 'p', -- 页面视图别名
    PAGE_FK_COLUMN VARCHAR2(100),             -- 页面视图中的关联字段
    
    -- 列配置
    COLUMNS CLOB,                             -- 主表列配置 JSON
    -- 格式: [{"field":"goodsid","header":"产品ID","order":1,"visible":true}, ...]
    
    -- Sheet 配置
    MASTER_SHEET_NAME VARCHAR2(100) DEFAULT 'master',
    
    DISPLAY_ORDER NUMBER DEFAULT 0,
    DELETED NUMBER DEFAULT 0,
    CREATE_BY VARCHAR2(100),
    CREATE_TIME TIMESTAMP DEFAULT SYSTIMESTAMP,
    UPDATE_BY VARCHAR2(100),
    UPDATE_TIME TIMESTAMP
);

CREATE UNIQUE INDEX UK_EXPORT_CONFIG_CODE ON T_COST_EXPORT_CONFIG(EXPORT_CODE);
CREATE INDEX IDX_EXPORT_CONFIG_PAGE ON T_COST_EXPORT_CONFIG(PAGE_CODE);
CREATE SEQUENCE SEQ_COST_EXPORT_CONFIG START WITH 1;
```

#### [NEW] T_COST_EXPORT_CONFIG_DETAIL (导出配置从表)

```sql
CREATE TABLE T_COST_EXPORT_CONFIG_DETAIL (
    ID NUMBER PRIMARY KEY,
    EXPORT_CONFIG_ID NUMBER NOT NULL,         -- 关联主表
    TAB_KEY VARCHAR2(100),                    -- 从表标识
    SHEET_NAME VARCHAR2(100),                 -- Excel Sheet 名称
    
    -- 从表 SQL 配置
    DETAIL_SQL CLOB NOT NULL,                 -- 从表查询 SQL（需包含主表关联）
    MASTER_TABLE_ALIAS VARCHAR2(50),          -- SQL 中主表的别名
    DETAIL_TABLE_ALIAS VARCHAR2(50),          -- SQL 中从表的别名
    
    -- 列配置
    COLUMNS CLOB,                             -- 从表列配置 JSON
    
    DISPLAY_ORDER NUMBER DEFAULT 0,
    
    CONSTRAINT FK_EXPORT_DTL_CONFIG FOREIGN KEY (EXPORT_CONFIG_ID)
        REFERENCES T_COST_EXPORT_CONFIG(ID)
);

CREATE INDEX IDX_EXPORT_DTL_CONFIG ON T_COST_EXPORT_CONFIG_DETAIL(EXPORT_CONFIG_ID);
CREATE SEQUENCE SEQ_COST_EXPORT_CONFIG_DTL START WITH 1;
```

---

### 后端

#### [NEW] entity/ExportConfig.java

- 导出配置实体类
- 字段映射 T_COST_EXPORT_CONFIG

#### [NEW] entity/ExportConfigDetail.java

- 导出配置从表实体类
- 字段映射 T_COST_EXPORT_CONFIG_DETAIL

#### [NEW] dto/ExportConfigDTO.java

- 包含主表配置 + 从表配置列表
- columns 解析为 `List<ColumnConfig>`

#### [NEW] mapper/ExportConfigMapper.java

```java
@Select("SELECT * FROM T_COST_EXPORT_CONFIG WHERE PAGE_CODE = #{pageCode} AND DELETED = 0 ORDER BY DISPLAY_ORDER")
List<ExportConfig> findByPageCode(String pageCode);

@Select("SELECT * FROM T_COST_EXPORT_CONFIG WHERE EXPORT_CODE = #{exportCode} AND DELETED = 0")
ExportConfig findByCode(String exportCode);
```

#### [NEW] mapper/ExportConfigDetailMapper.java

```java
@Select("SELECT * FROM T_COST_EXPORT_CONFIG_DETAIL WHERE EXPORT_CONFIG_ID = #{configId} ORDER BY DISPLAY_ORDER")
List<ExportConfigDetail> findByConfigId(Long configId);
```

#### [NEW] service/CustomExportService.java

**核心方法：**

```java
// 获取页面可用的导出配置列表
List<ExportConfigDTO> getExportConfigs(String pageCode);

// 执行导出
void export(String exportCode, ExportMode mode, List<QueryCondition> conditions, HttpServletResponse response);

// 构建 EXISTS 子句（核心逻辑）
String buildExistsClause(ExportConfig config, String pageView, List<QueryCondition> conditions);
```

**SQL 拼接逻辑：**

```java
private String buildExportSql(ExportConfig config, ExportMode mode, 
                               String pageView, List<QueryCondition> conditions) {
    String baseSql = config.getMasterSql();
    
    if (mode == ExportMode.ALL) {
        return baseSql;
    }
    
    // 导出当前：添加 EXISTS 子句
    String existsClause = String.format(
        "EXISTS (SELECT 1 FROM %s %s WHERE %s.%s = %s.%s AND %s.DELETED = 0 %s)",
        pageView,                           // T_COST_GOODS_PRICE_V
        config.getPageViewAlias(),          // p
        config.getPageViewAlias(),          // p
        config.getPageFkColumn(),           // GOODSID
        config.getMasterTableAlias(),       // a
        config.getPkColumn(),               // GOODSID
        config.getPageViewAlias(),          // p
        buildWhereClause(conditions)        // AND PRICE > 0
    );
    
    // 判断原始 SQL 是否有 WHERE
    if (baseSql.toUpperCase().contains(" WHERE ")) {
        return baseSql + " AND " + existsClause;
    } else {
        return baseSql + " WHERE " + existsClause;
    }
}
```

#### [MODIFY] controller/ExportController.java

新增接口：

```java
// 获取页面导出配置列表
@GetMapping("/api/export/{pageCode}/configs")
Result<List<ExportConfigDTO>> getExportConfigs(@PathVariable String pageCode);

// 执行自定义导出
@PostMapping("/api/export/{exportCode}/custom")
void customExport(@PathVariable String exportCode,
                  @RequestBody CustomExportRequest request,
                  HttpServletResponse response);
```

---

### 前端

#### [MODIFY] useContextMenu.ts

右键菜单增加"自定义导出"子菜单：

```typescript
{
  name: '自定义导出',
  subMenu: exportConfigs.map(config => ({
    name: config.exportName,
    action: () => showExportDialog(config.exportCode)
  }))
}
```

#### [NEW] CustomExportDialog.vue

- 选择导出模式：导出当前 / 导出所有
- 确认后调用接口

---

## Verification Plan

### 测试场景

1. **导出所有**
   - 配置主表 SQL，从表 SQL
   - 验证直接执行 SQL，无筛选条件

2. **导出当前**
   - 页面设置筛选条件（如 price > 0）
   - 验证 EXISTS 子句正确拼接
   - 验证主表和从表都正确过滤

3. **列配置测试**
   - 验证列顺序、列名、可见性正确应用

### 验证 SQL

```sql
-- 插入测试配置
INSERT INTO T_COST_EXPORT_CONFIG (
    ID, EXPORT_CODE, EXPORT_NAME, PAGE_CODE,
    MASTER_SQL, MASTER_TABLE_ALIAS, PK_COLUMN,
    PAGE_FK_COLUMN, COLUMNS
) VALUES (
    SEQ_COST_EXPORT_CONFIG.NEXTVAL,
    'goods-price-pinggu',
    '产品价格-评估关联导出',
    'goods-price-manage',
    'SELECT a.DOCID, a.GOODSNAME, a.APEX_PL FROM T_COST_PINGGU a',
    'a',
    'GOODSID',
    'GOODSID',
    '[{"field":"docid","header":"单据ID","order":1,"visible":true},{"field":"goodsname","header":"产品名称","order":2,"visible":true}]'
);
```
