# 成本管理系统技术栈清单

> 基于 MyBatis-Plus 动态查询方案，元数据驱动架构

---

## 1. 全景技术栈

### 1.1 前端技术栈

**基础框架**：[Soybean Admin](https://github.com/soybeanjs/soybean-admin)（开箱即用的 Vue3 后台模板）

| 分层 | 技术 | 版本 | 选型理由 |
|------|------|------|---------|
| 基础模板 | **Soybean Admin** | 最新 | 开箱即用，内置权限/路由/布局，与技术栈完美匹配 |
| 框架 | Vue 3 + TypeScript | 3.4+ | 组合式 API 适合编写通用渲染器逻辑，TS 对动态类型友好 |
| 构建 | Vite | 5.x | 极速构建，开发体验好 |
| 表格 | AG Grid Vue | 31.x | 企业级表格，支持虚拟滚动，columnDefs JSON 配置控制列 |
| UI 组件库 | Naive UI | 最新 | 配置驱动设计，无主题依赖，适合动态渲染（Soybean 内置） |
| 状态管理 | Pinia | 2.x | Vue 3 官方推荐，轻量级（Soybean 内置） |
| HTTP 客户端 | Axios | 1.x | 成熟稳定（Soybean 内置封装） |

**前端初始化步骤**：

```bash
# 1. 克隆 Soybean Admin
git clone https://github.com/soybeanjs/soybean-admin.git cost-web
cd cost-web

# 2. 安装依赖
pnpm install

# 3. 安装 AG Grid
pnpm add ag-grid-vue3 ag-grid-community

# 4. 启动开发
pnpm dev
```

### 1.2 后端技术栈

**构建方式**：IDEA Spring Initializr

| 分层 | 技术 | 版本 | 选型理由 |
|------|------|------|---------|
| 框架 | Spring Boot | 3.2.x | 约定大于配置的基石 |
| 安全框架 | Spring Security | 6.x | 认证授权、权限注解、CORS/CSRF 防护 |
| 持久层 | **MyBatis-Plus** | 3.5.5+ | **核心组件**，支持 Map 操作 + QueryWrapper 防注入 |
| 数据库 | Oracle | 19c/21c | 企业级数据库 |
| 连接池 | Druid | 1.2.x | SQL 监控 + WallFilter 防火墙，防注入第二道防线 |
| 认证 | JWT (jjwt) | 0.12.x | 无状态 Token，配合 Spring Security 使用 |
| 工具库 | Hutool | 5.8.x | Map/Bean/驼峰转换神器 |
| 日志追踪 | TLog | 1.5.x | 轻量级，自动打印 TraceId |
| API 文档 | Knife4j | 4.x | 基于 Swagger，方便调试动态接口 |

**后端初始化步骤（IDEA Spring Initializr）**：

1. IDEA → File → New → Project → Spring Initializr
2. 配置项目信息：
   - Group: `com.cost`
   - Artifact: `cost-server`
   - Type: Maven
   - Java: 17
   - Spring Boot: 3.5.8
3. 勾选依赖（Initializr 可直接选择）：
   - Spring Web
   - Spring Security（Security 分类下）
   - Lombok
   - Validation
   - Oracle Driver（SQL 分类下）
4. 手动添加 pom.xml 依赖（Initializr 不提供）：

```xml
<!-- MyBatis-Plus（Initializr 只有 MyBatis，没有 Plus） -->
<dependency>
    <groupId>com.baomidou</groupId>
    <artifactId>mybatis-plus-spring-boot3-starter</artifactId>
    <version>3.5.5</version>
</dependency>

<!-- Druid 连接池（Initializr 默认 HikariCP） -->
<dependency>
    <groupId>com.alibaba</groupId>
    <artifactId>druid-spring-boot-3-starter</artifactId>
    <version>1.2.21</version>
</dependency>

<!-- Knife4j API 文档 -->
<dependency>
    <groupId>com.github.xiaoymin</groupId>
    <artifactId>knife4j-openapi3-jakarta-spring-boot-starter</artifactId>
    <version>4.4.0</version>
</dependency>

<!-- Hutool 工具库 -->
<dependency>
    <groupId>cn.hutool</groupId>
    <artifactId>hutool-all</artifactId>
    <version>5.8.25</version>
</dependency>

<!-- JWT -->
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-api</artifactId>
    <version>0.12.3</version>
</dependency>
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-impl</artifactId>
    <version>0.12.3</version>
    <scope>runtime</scope>
</dependency>
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-jackson</artifactId>
    <version>0.12.3</version>
    <scope>runtime</scope>
</dependency>

<!-- TLog 日志追踪 -->
<dependency>
    <groupId>com.yomahub</groupId>
    <artifactId>tlog-spring-boot-starter</artifactId>
    <version>1.5.2</version>
</dependency>
```

---

## 2. 核心方案：MP @Select + QueryWrapper 动态查询

### 2.1 为什么选择这个方案？

| 对比项 | AnyLine | MP @Select + QueryWrapper |
|--------|---------|--------------------------|
| 文档质量 | ❌ 官网证书过期，文档差 | ✅ 文档完善，社区活跃 |
| 团队熟悉度 | ❌ 小众框架 | ✅ 主流框架，大家都会 |
| 动态表名 | ✅ 原生支持 | ✅ @Select 支持 |
| 链式条件 | ✅ condition() | ✅ QueryWrapper |
| 防 SQL 注入 | ✅ 内部处理 | ✅ 值预编译 + 白名单校验 |
| 生态 | ❌ 单一 | ✅ 丰富（分页、代码生成等） |

### 2.2 核心实现

#### 2.2.1 DynamicMapper 接口

```java
package com.cost.metadata.mapper;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import org.apache.ibatis.annotations.*;

import java.util.List;
import java.util.Map;

/**
 * 动态数据 Mapper
 * 支持任意表的 CRUD 操作
 */
@Mapper
public interface DynamicMapper {

    /**
     * 动态查询（返回 Map 列表）
     * 
     * @param tableName 表名/视图名（必须经过白名单校验）
     * @param ew        QueryWrapper 条件
     * @return Map 列表
     */
    @Select("SELECT * FROM ${tableName} ${ew.customSqlSegment}")
    List<Map<String, Object>> selectByTable(
        @Param("tableName") String tableName,
        @Param("ew") QueryWrapper<?> ew
    );

    /**
     * 动态查询单条
     */
    @Select("SELECT * FROM ${tableName} WHERE ID = #{id}")
    Map<String, Object> selectById(
        @Param("tableName") String tableName,
        @Param("id") Long id
    );

    /**
     * 动态统计
     */
    @Select("SELECT COUNT(*) FROM ${tableName} ${ew.customSqlSegment}")
    Long countByTable(
        @Param("tableName") String tableName,
        @Param("ew") QueryWrapper<?> ew
    );

    /**
     * 动态插入
     * 注意：columns 和 values 必须经过白名单校验
     */
    @Insert("INSERT INTO ${tableName} (${columns}) VALUES (${values})")
    int dynamicInsert(
        @Param("tableName") String tableName,
        @Param("columns") String columns,
        @Param("values") String values
    );

    /**
     * 动态更新
     */
    @Update("UPDATE ${tableName} SET ${setSql} WHERE ID = #{id}")
    int dynamicUpdate(
        @Param("tableName") String tableName,
        @Param("setSql") String setSql,
        @Param("id") Long id
    );

    /**
     * 软删除
     */
    @Update("UPDATE ${tableName} SET ENABLED = 0, UPDATE_TIME = SYSDATE WHERE ID = #{id}")
    int softDelete(
        @Param("tableName") String tableName,
        @Param("id") Long id
    );
}
```

#### 2.2.2 DynamicDataService 服务层

```java
package com.cost.metadata.service;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.cost.core.exception.BusinessException;
import com.cost.metadata.dto.SearchCondition;
import com.cost.metadata.entity.ColumnMetadata;
import com.cost.metadata.entity.TableMetadata;
import com.cost.metadata.mapper.DynamicMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DynamicDataService {

    private final DynamicMapper dynamicMapper;
    private final TableMetadataService tableMetadataService;
    private final ColumnMetadataService columnMetadataService;

    // ==================== 查询操作 ====================

    /**
     * 查询列表
     */
    public List<Map<String, Object>> list(String tableCode) {
        TableMetadata meta = validateAndGetMeta(tableCode);
        
        QueryWrapper<?> wrapper = new QueryWrapper<>();
        wrapper.eq("ENABLED", 1);
        wrapper.orderByDesc("CREATE_TIME");
        
        List<Map<String, Object>> result = dynamicMapper.selectByTable(meta.getQueryView(), wrapper);
        return transformKeysToCamel(result);
    }

    /**
     * 高级查询（带条件）
     */
    public List<Map<String, Object>> search(String tableCode, List<SearchCondition> conditions) {
        TableMetadata meta = validateAndGetMeta(tableCode);
        Set<String> validColumns = getValidColumns(tableCode);
        
        QueryWrapper<?> wrapper = new QueryWrapper<>();
        wrapper.eq("ENABLED", 1);
        
        // 构建查询条件
        if (conditions != null) {
            for (SearchCondition cond : conditions) {
                // 【安全校验】字段必须在元数据中定义
                String dbColumn = StrUtil.toUnderlineCase(cond.getField()).toUpperCase();
                if (!validColumns.contains(dbColumn)) {
                    throw new BusinessException("非法字段: " + cond.getField());
                }
                
                buildCondition(wrapper, dbColumn, cond);
            }
        }
        
        wrapper.orderByDesc("CREATE_TIME");
        
        List<Map<String, Object>> result = dynamicMapper.selectByTable(meta.getQueryView(), wrapper);
        return transformKeysToCamel(result);
    }

    /**
     * 查询单条
     */
    public Map<String, Object> getById(String tableCode, Long id) {
        TableMetadata meta = validateAndGetMeta(tableCode);
        Map<String, Object> result = dynamicMapper.selectById(meta.getQueryView(), id);
        return result != null ? transformKeyToCamel(result) : null;
    }

    // ==================== 写入操作 ====================

    /**
     * 新增
     */
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> create(String tableCode, Map<String, Object> data) {
        TableMetadata meta = validateAndGetMeta(tableCode);
        Set<String> validColumns = getValidColumns(tableCode);
        
        // 生成 ID
        Long id = getNextId(meta.getSequenceName());
        data.put("id", id);
        data.put("enabled", 1);
        data.put("createTime", LocalDateTime.now());
        // data.put("createBy", SecurityUtils.getCurrentUserId());
        
        // 构建 INSERT SQL
        StringBuilder columns = new StringBuilder();
        StringBuilder values = new StringBuilder();
        List<Object> params = new ArrayList<>();
        
        for (Map.Entry<String, Object> entry : data.entrySet()) {
            String dbColumn = StrUtil.toUnderlineCase(entry.getKey()).toUpperCase();
            
            // 【安全校验】
            if (!validColumns.contains(dbColumn) && !isSystemColumn(dbColumn)) {
                continue; // 跳过非法字段
            }
            
            if (columns.length() > 0) {
                columns.append(", ");
                values.append(", ");
            }
            columns.append(dbColumn);
            values.append(formatValue(entry.getValue()));
        }
        
        dynamicMapper.dynamicInsert(meta.getTargetTable(), columns.toString(), values.toString());
        
        return getById(tableCode, id);
    }

    /**
     * 更新（字段级更新，只更新传入的字段）
     */
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> update(String tableCode, Long id, Map<String, Object> data) {
        TableMetadata meta = validateAndGetMeta(tableCode);
        Set<String> validColumns = getValidColumns(tableCode);
        
        data.put("updateTime", LocalDateTime.now());
        // data.put("updateBy", SecurityUtils.getCurrentUserId());
        
        // 构建 SET 子句
        StringBuilder setSql = new StringBuilder();
        
        for (Map.Entry<String, Object> entry : data.entrySet()) {
            if ("id".equalsIgnoreCase(entry.getKey())) continue;
            
            String dbColumn = StrUtil.toUnderlineCase(entry.getKey()).toUpperCase();
            
            // 【安全校验】
            if (!validColumns.contains(dbColumn) && !isSystemColumn(dbColumn)) {
                continue;
            }
            
            if (setSql.length() > 0) {
                setSql.append(", ");
            }
            setSql.append(dbColumn).append(" = ").append(formatValue(entry.getValue()));
        }
        
        dynamicMapper.dynamicUpdate(meta.getTargetTable(), setSql.toString(), id);
        
        return getById(tableCode, id);
    }

    /**
     * 删除（软删除）
     */
    @Transactional(rollbackFor = Exception.class)
    public void delete(String tableCode, Long id) {
        TableMetadata meta = validateAndGetMeta(tableCode);
        dynamicMapper.softDelete(meta.getTargetTable(), id);
    }

    // ==================== 私有方法 ====================

    /**
     * 校验并获取表元数据（白名单校验）
     */
    private TableMetadata validateAndGetMeta(String tableCode) {
        TableMetadata meta = tableMetadataService.getByTableCode(tableCode);
        if (meta == null) {
            throw new BusinessException("非法表编码: " + tableCode);
        }
        return meta;
    }

    /**
     * 获取有效列名集合（白名单）
     */
    private Set<String> getValidColumns(String tableCode) {
        List<ColumnMetadata> columns = columnMetadataService.getByTableCode(tableCode);
        return columns.stream()
            .map(c -> StrUtil.toUnderlineCase(c.getFieldName()).toUpperCase())
            .collect(Collectors.toSet());
    }

    /**
     * 构建查询条件
     */
    private void buildCondition(QueryWrapper<?> wrapper, String column, SearchCondition cond) {
        Object value = cond.getValue();
        if (value == null) return;
        
        switch (cond.getOperator().toLowerCase()) {
            case "eq" -> wrapper.eq(column, value);
            case "ne" -> wrapper.ne(column, value);
            case "gt" -> wrapper.gt(column, value);
            case "ge" -> wrapper.ge(column, value);
            case "lt" -> wrapper.lt(column, value);
            case "le" -> wrapper.le(column, value);
            case "like" -> wrapper.like(column, value);
            case "likeleft" -> wrapper.likeLeft(column, value);
            case "likeright" -> wrapper.likeRight(column, value);
            case "in" -> wrapper.in(column, (Collection<?>) value);
            case "notin" -> wrapper.notIn(column, (Collection<?>) value);
            case "between" -> wrapper.between(column, value, cond.getValue2());
            case "isnull" -> wrapper.isNull(column);
            case "isnotnull" -> wrapper.isNotNull(column);
            default -> wrapper.eq(column, value);
        }
    }

    /**
     * Oracle 大写 Key 转驼峰
     */
    private List<Map<String, Object>> transformKeysToCamel(List<Map<String, Object>> list) {
        return list.stream()
            .map(this::transformKeyToCamel)
            .collect(Collectors.toList());
    }

    private Map<String, Object> transformKeyToCamel(Map<String, Object> row) {
        Map<String, Object> camelRow = new LinkedHashMap<>();
        row.forEach((k, v) -> camelRow.put(StrUtil.toCamelCase(k.toLowerCase()), v));
        return camelRow;
    }

    /**
     * 格式化值（用于拼接 SQL）
     */
    private String formatValue(Object value) {
        if (value == null) {
            return "NULL";
        } else if (value instanceof Number) {
            return value.toString();
        } else if (value instanceof LocalDateTime) {
            return "TO_TIMESTAMP('" + value + "', 'YYYY-MM-DD HH24:MI:SS.FF')";
        } else {
            // 字符串需要转义单引号，防止 SQL 注入
            String str = value.toString().replace("'", "''");
            return "'" + str + "'";
        }
    }

    /**
     * 判断是否系统字段
     */
    private boolean isSystemColumn(String column) {
        return Set.of("ID", "ENABLED", "CREATE_BY", "CREATE_TIME", "UPDATE_BY", "UPDATE_TIME")
            .contains(column);
    }

    /**
     * 获取序列下一个值
     */
    private Long getNextId(String sequenceName) {
        // 这里需要实现获取 Oracle 序列值的逻辑
        // 可以用 @Select("SELECT ${seq}.NEXTVAL FROM DUAL")
        return System.currentTimeMillis(); // 临时实现
    }
}
```

#### 2.2.3 SearchCondition DTO

```java
package com.cost.metadata.dto;

import lombok.Data;

@Data
public class SearchCondition {
    /**
     * 字段名（驼峰格式，如 costDate）
     */
    private String field;
    
    /**
     * 操作符：eq, ne, gt, ge, lt, le, like, in, between, isNull, isNotNull
     */
    private String operator;
    
    /**
     * 值
     */
    private Object value;
    
    /**
     * 第二个值（between 时使用）
     */
    private Object value2;
}
```

#### 2.2.4 DynamicDataController

```java
package com.cost.metadata.controller;

import com.cost.core.result.Result;
import com.cost.metadata.dto.SearchCondition;
import com.cost.metadata.service.DynamicDataService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@Tag(name = "通用数据接口")
@RestController
@RequestMapping("/api/data")
@RequiredArgsConstructor
public class DynamicDataController {

    private final DynamicDataService dynamicDataService;

    @Operation(summary = "查询列表")
    @GetMapping("/{tableCode}")
    public Result<List<Map<String, Object>>> list(@PathVariable String tableCode) {
        return Result.success(dynamicDataService.list(tableCode));
    }

    @Operation(summary = "高级查询")
    @PostMapping("/{tableCode}/search")
    public Result<List<Map<String, Object>>> search(
            @PathVariable String tableCode,
            @RequestBody(required = false) List<SearchCondition> conditions) {
        return Result.success(dynamicDataService.search(tableCode, conditions));
    }

    @Operation(summary = "查询单条")
    @GetMapping("/{tableCode}/{id}")
    public Result<Map<String, Object>> getById(
            @PathVariable String tableCode,
            @PathVariable Long id) {
        return Result.success(dynamicDataService.getById(tableCode, id));
    }

    @Operation(summary = "新增")
    @PostMapping("/{tableCode}")
    public Result<Map<String, Object>> create(
            @PathVariable String tableCode,
            @RequestBody Map<String, Object> data) {
        return Result.success(dynamicDataService.create(tableCode, data));
    }

    @Operation(summary = "更新")
    @PutMapping("/{tableCode}/{id}")
    public Result<Map<String, Object>> update(
            @PathVariable String tableCode,
            @PathVariable Long id,
            @RequestBody Map<String, Object> data) {
        return Result.success(dynamicDataService.update(tableCode, id, data));
    }

    @Operation(summary = "删除")
    @DeleteMapping("/{tableCode}/{id}")
    public Result<Void> delete(
            @PathVariable String tableCode,
            @PathVariable Long id) {
        dynamicDataService.delete(tableCode, id);
        return Result.success(null);
    }
}
```

---

## 3. 安全防护：三道防线

### 3.1 第一道防线：元数据白名单

```java
// 表名校验
TableMetadata meta = tableMetadataService.getByTableCode(tableCode);
if (meta == null) {
    throw new BusinessException("非法表编码");
}

// 列名校验
Set<String> validColumns = getValidColumns(tableCode);
if (!validColumns.contains(dbColumn)) {
    throw new BusinessException("非法字段");
}
```

### 3.2 第二道防线：QueryWrapper 预编译

```java
// QueryWrapper 的值会使用 PreparedStatement 预编译
// 防止值注入
wrapper.eq("STATUS", userInput);  // userInput 会被预编译，安全
```

### 3.3 第三道防线：Druid WallFilter

```yaml
# application.yml
spring:
  datasource:
    druid:
      filter:
        wall:
          enabled: true
          config:
            # 禁止多语句执行
            multi-statement-allow: false
            # 禁止删除表
            drop-table-allow: false
            # 禁止 truncate
            truncate-allow: false
```

---

## 4. 前端调用示例

### 4.1 查询列表

```typescript
// GET /api/data/CostMaster
const response = await axios.get('/api/data/CostMaster');
const list = response.data.data;
```

### 4.2 高级查询

```typescript
// POST /api/data/CostMaster/search
const conditions = [
  { field: 'status', operator: 'eq', value: 'DRAFT' },
  { field: 'costDate', operator: 'between', value: '2024-01-01', value2: '2024-12-31' },
  { field: 'productName', operator: 'like', value: '钢材' }
];

const response = await axios.post('/api/data/CostMaster/search', conditions);
```

### 4.3 新增

```typescript
// POST /api/data/CostMaster
const data = {
  costNo: 'COST-2024-001',
  costDate: '2024-01-15',
  productName: '钢材A',
  quantity: 100,
  unitPrice: 5000
};

const response = await axios.post('/api/data/CostMaster', data);
```

### 4.4 更新（字段级）

```typescript
// PUT /api/data/CostMaster/123
// 只传需要更新的字段
const data = {
  status: 'SUBMITTED',
  remark: '已提交审批'
};

const response = await axios.put('/api/data/CostMaster/123', data);
```

---

## 5. 与 AnyLine 方案对比

| 方面 | AnyLine | MP @Select + QueryWrapper |
|------|---------|--------------------------|
| 查询 | `anyline.querys(table, condition())` | `mapper.selectByTable(table, wrapper)` |
| 条件构建 | `condition().and().like()` | `wrapper.eq().like()` |
| 文档 | ❌ 官网证书过期 | ✅ 完善 |
| 社区 | ❌ 小众 | ✅ 活跃 |
| 学习成本 | 中 | 低 |
| 维护性 | 中 | 高 |

---

## 6. 总结

本方案使用 **MyBatis-Plus @Select + QueryWrapper** 实现动态表名查询：

1. **表名**：通过 `${tableName}` 传入，必须经过元数据白名单校验
2. **条件**：通过 `QueryWrapper` 构建，值自动预编译防注入
3. **列名**：转换为大写下划线格式，必须在元数据中定义
4. **返回值**：Oracle 大写 Key 自动转驼峰

**优势**：
- 团队熟悉 MyBatis-Plus，维护成本低
- 文档完善，遇到问题好查
- 三道防线保证安全
