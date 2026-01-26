# SSRM 无感增删改改造计划（_rowKey 方案）

## 背景

当前系统使用 AG Grid 企业版 v35.0.0，主表采用 Server-Side Row Model (SSRM) 模式。

**当前问题**：
1. 新增数据保存后，行位置发生变化
2. ID映射逻辑复杂，需要同步更新多处缓存
3. `masterRows`、`masterRowMap`、Grid内部存储三处数据需要同步

## 核心思路

**用 `_rowKey` 替代 `id` 作为 Grid 行标识**，实现 Grid 世界和业务世界的解耦：

```
┌─────────────────────────────────────┐
│           row 对象（内存中）          │
│  ┌─────────────┬─────────────────┐  │
│  │ _rowKey     │ "abc123"        │  │  ← Grid用这个（永不变）
│  │ id          │ -1 → 1001       │  │  ← 业务用这个（会变）
│  └─────────────┴─────────────────┘  │
└─────────────────────────────────────┘
         │                    │
         ▼                    ▼
    Grid.getRowNode      后端保存/更新
    ("abc123")           WHERE id=1001
```

## 改造内容

### 1. 新增 `_rowKey` 生成逻辑

**文件**：`cost-web/src/v3/logic/calc-engine/index.ts`

```typescript
// 生成 _rowKey
export function ensureRowKey(row: RowData): string {
  if (!row._rowKey) {
    if (row.id != null && row.id > 0) {
      // 已有数据库ID，用ID生成（保证同一记录多次加载_rowKey一致）
      row._rowKey = `db_${row.id}`;
    } else {
      // 新增行，用UUID
      row._rowKey = crypto.randomUUID();
    }
  }
  return row._rowKey;
}

// 修改 initRowData
export function initRowData(data: Record<string, any>, isNew = false): RowData {
  const row = { ...data, _isNew: isNew, _isDeleted: false };
  ensureRowKey(row);  // 确保有 _rowKey
  return row;
}
```

### 2. 修改 Grid 的 getRowId

**文件**：`cost-web/src/v3/composables/meta-v3/useMasterGridBindings.ts`

```typescript
// 改前
getRowId: (params) => String(params.data?.id)

// 改后
getRowId: (params) => {
  ensureRowKey(params.data);
  return params.data._rowKey;
}
```

### 3. 简化 useMasterDetailData.ts

**删除**：
- `masterRows` 响应式数组
- `masterRowMap` Map缓存
- `resetMasterCache()` 方法
- `mergeMasterCache()` 方法

**保留**：
- `detailCache`（改用 `_rowKey` 做键）

**修改后结构**：

```typescript
export function useMasterDetailData(params) {
  // 只保留从表缓存，用 _rowKey 做键
  const detailCache = new Map<string, Record<string, RowData[]>>();

  // 从 Grid 获取主表行
  function getMasterRowByRowKey(rowKey: string): RowData | null {
    let found: RowData | null = null;
    masterGridApi.value?.forEachNode((node: any) => {
      if (node.data?._rowKey === rowKey) {
        found = node.data;
      }
    });
    return found;
  }

  // 从 Grid 获取主表行（通过数据库ID）
  function getMasterRowById(id: number): RowData | null {
    let found: RowData | null = null;
    masterGridApi.value?.forEachNode((node: any) => {
      if (node.data?.id === id) {
        found = node.data;
      }
    });
    return found;
  }

  // SSRM 数据源
  createServerSideDataSource: () => ({
    getRows: async (params) => {
      // ... 请求数据 ...
      const rows = data.list.map(row => initRowData(row));  // 自动生成 _rowKey
      params.success({ rowData: rows, rowCount: total });
    }
  })

  // 新增主表行
  function addMasterRow() {
    const newRow = initRowData({ id: generateTempId() }, true);
    // newRow._rowKey 已自动生成（UUID）
    
    api.applyServerSideTransaction({
      route: [],
      add: [newRow],
      addIndex: insertIndex
    });
  }

  // 加载从表数据（用 _rowKey 做缓存键）
  async function loadDetailData(masterRowKey: string, masterId: number) {
    // ... 请求从表数据 ...
    detailCache.set(masterRowKey, grouped);  // 用 _rowKey 做键
  }

  return {
    detailCache,
    getMasterRowByRowKey,
    getMasterRowById,
    addMasterRow,
    loadDetailData,
    // ...
  };
}
```

### 4. 简化 useSave.ts 的 ID 映射逻辑

**改前**（复杂）：
```typescript
function applyIdMapping(idMapping: Map<number, number>) {
  // 更新 masterRows.value
  // 更新 masterRowMap 的键
  // 更新 detailCache 的键
  // 更新从表外键
  // ... 50多行代码
}
```

**改后**（简单）：
```typescript
function applyIdMapping(idMapping: Map<number, number>) {
  if (idMapping.size === 0) return;

  // 1. 更新主表行的 id（_rowKey 不变，Grid 行位置不变）
  masterGridApi.value?.forEachNode((node: any) => {
    const row = node.data;
    if (!row) return;
    const newId = idMapping.get(row.id);
    if (newId) {
      row.id = newId;
    }
  });

  // 2. 更新从表外键
  for (const [, tabData] of detailCache) {
    for (const [tabKey, rows] of Object.entries(tabData)) {
      const fkColumn = detailFkColumnByTab.value[tabKey] || 'masterId';
      for (const row of rows) {
        const newFk = idMapping.get(row[fkColumn]);
        if (newFk) {
          row[fkColumn] = newFk;
        }
        // 从表行自己的ID也要更新
        const newRowId = idMapping.get(row.id);
        if (newRowId) {
          row.id = newRowId;
        }
      }
    }
  }
  
  // 不需要更新任何缓存的键！因为用的是 _rowKey
}
```

### 5. 保存后的处理流程

```typescript
async function save() {
  // 1. 从 Grid 收集脏数据
  const dirtyMaster: RowData[] = [];
  masterGridApi.value?.forEachNode((node: any) => {
    const row = node.data;
    if (row && (row._isNew || row._isDeleted || row._dirtyFields)) {
      dirtyMaster.push(row);
    }
  });

  // 2. 验证 & 保存（不变）
  // ...

  // 3. 保存成功后
  const mapping = normalizeIdMapping(data?.idMapping);
  applyIdMapping(mapping);  // 简化后的ID映射

  // 4. 处理删除行
  const deletedRows: RowData[] = [];
  masterGridApi.value?.forEachNode((node: any) => {
    if (node.data?._isDeleted) {
      deletedRows.push(node.data);
    }
  });
  if (deletedRows.length > 0) {
    masterGridApi.value?.applyServerSideTransaction({
      route: [],
      remove: deletedRows
    });
  }

  // 5. 清除脏标记
  masterGridApi.value?.forEachNode((node: any) => {
    if (node.data) {
      clearRowFlags(node.data);
    }
  });

  // 6. 刷新显示（不重新请求数据）
  masterGridApi.value?.refreshCells({ force: true });
}
```

### 6. 主从计算适配

**广播计算**（主表 → 从表）：
```typescript
async function broadcastToDetail(masterRowKey: string, masterRow: RowData) {
  // 用 _rowKey 获取从表缓存
  let cached = detailCache.get(masterRowKey);
  if (!cached) {
    await loadDetailData(masterRowKey, masterRow.id);
    cached = detailCache.get(masterRowKey);
  }
  // ... 执行广播计算
}
```

**聚合计算**（从表 → 主表）：
```typescript
function recalcAggregates(masterRowKey: string) {
  const masterRow = getMasterRowByRowKey(masterRowKey);
  const cached = detailCache.get(masterRowKey);
  if (!masterRow || !cached) return;
  // ... 执行聚合计算
}
```

## 改动文件清单

| 文件 | 改动 |
|------|------|
| `calc-engine/index.ts` | 新增 `ensureRowKey()`，修改 `initRowData()` |
| `useMasterGridBindings.ts` | 修改 `getRowId` 返回 `_rowKey` |
| `useMasterDetailData.ts` | 删除 `masterRows`/`masterRowMap`，改用 `_rowKey`；`loadDetailData` 增加 `masterRowKey` 参数 |
| `useNestedDetailParams.ts` | `getDetailRowData` 分离 `_rowKey`（缓存键）和 `id`（查询条件） |
| `useSave.ts` | 简化 `applyIdMapping()`，简化保存后处理 |
| `useCalcBroadcast.ts` | 适配 `_rowKey` 参数 |
| `useLookupDialog.ts` | 适配 `_rowKey` 参数 |

## 删除的代码

| 删除项 | 原因 |
|--------|------|
| `masterRows` 响应式数组 | 直接从 Grid 获取 |
| `masterRowMap` Map | 不需要了 |
| `resetMasterCache()` | 不需要了 |
| `mergeMasterCache()` | 不需要了 |
| `detailCache` 键更新逻辑 | 用 `_rowKey` 做键，不变 |

## 代码量变化

| 模块 | 改前 | 改后 | 减少 |
|------|------|------|------|
| useMasterDetailData.ts | ~350行 | ~220行 | -130行 |
| useSave.ts applyIdMapping | ~50行 | ~20行 | -30行 |
| **总计** | | | **-160行** |

## 验证清单

- [x] 代码编译通过，无类型错误
- [ ] 新增行 → 保存 → 行位置不变
- [ ] 新增行 → 保存 → 继续修改 → 再保存 → 正常
- [ ] 修改行 → 保存 → 数据正确
- [ ] 删除行 → 保存 → 行消失
- [ ] 主表修改 → 广播到从表 → 从表数据正确
- [ ] 从表修改 → 聚合到主表 → 主表数据正确
- [ ] 从表未展开 → 主表修改 → 广播正常
- [ ] 刷新页面 → 数据正常加载
- [ ] 主表展开从表 → SQL 条件正确（不是 NULL）
- [ ] 展开新主表 → 旧从表保持展开状态

## 已知问题及修复

### 问题1：展开从表时 SQL 条件传 NULL

**现象**：主表展开明细后，传的 SQL 是 `WHERE CUSTOMID IS NULL`，而不是正确的主表 ID。

**原因**：`getRowId` 改为返回 `_rowKey` 后，`useNestedDetailParams.ts` 中的 `getDetailRowData` 通过 `params.data?.id` 获取主表 ID 时，如果 `params.data` 是从 Grid 内部通过 rowId 查找的，可能出现问题。

**修复方案**：在 `getDetailRowData` 中，确保直接从行数据获取 `id` 字段：

```typescript
// useNestedDetailParams.ts - getDetailRowData
getDetailRowData: async (params: any) => {
  // params.data 是主表行数据，直接取 id 字段（数据库ID）
  const masterRow = params.data;
  const masterId = masterRow?.id;
  
  if (masterId == null || masterId < 0) {
    // 新增行（临时ID为负数）暂不加载从表
    params.successCallback([]);
    return;
  }
  
  // 用 _rowKey 作为缓存键
  const rowKey = masterRow?._rowKey;
  let cached = rowKey ? detailCache.get(rowKey) : null;
  
  if (!cached) {
    await loadDetailData(rowKey, masterId);  // 传入 rowKey 和 masterId
    cached = rowKey ? detailCache.get(rowKey) : null;
  }
  // ...
}
```

**同时修改 `loadDetailData` 签名**：

```typescript
// useMasterDetailData.ts
async function loadDetailData(masterRowKey: string, masterId: number) {
  // masterId 用于查询数据库
  // masterRowKey 用于缓存键
  const tabs = pageConfig.value?.tabs || [];
  const grouped: Record<string, RowData[]> = {};

  for (const tab of tabs) {
    const tableCode = tab.tableCode || pageConfig.value?.detailTableCode;
    const fkColumn = detailFkColumnByTab.value[tab.key] || 'masterId';
    if (!tableCode) continue;

    const { data, error } = await searchDynamicData(tableCode, {
      pageCode,
      conditions: [{ field: fkColumn, operator: 'eq', value: masterId }]  // 用数据库ID查询
    });
    // ...
  }

  detailCache.set(masterRowKey, grouped);  // 用 _rowKey 做缓存键
}
```

---

### 问题2：展开新主表时旧从表自动关闭

**现象**：主表展开后，如果有其它从表展开了，展开新主表时旧从表会自动关闭。期望行为是保持旧从表打开。

**原因**：AG Grid 的 `keepDetailRows: true` 依赖 `getRowId` 返回稳定的值。当 `getRowId` 从返回 `id` 改为返回 `_rowKey` 后，如果 `_rowKey` 在某些情况下不稳定（如重新渲染时重新生成），会导致 Grid 认为是不同的行，从而关闭旧的 detail。

**修复方案**：

1. **确保 `_rowKey` 稳定性**：对于已有数据库 ID 的行，`_rowKey` 必须基于 ID 生成，保证同一记录多次加载时 `_rowKey` 一致：

```typescript
// calc-engine/index.ts
export function ensureRowKey(row: RowData): string {
  if (!row._rowKey) {
    if (row.id != null && row.id > 0) {
      // 已有数据库ID，用ID生成（保证稳定）
      row._rowKey = `db_${row.id}`;
    } else {
      // 新增行，用UUID（保存后会更新ID，但_rowKey不变）
      row._rowKey = crypto.randomUUID();
    }
  }
  return row._rowKey;
}
```

2. **检查 SSRM 数据源的 `mergeMasterCache` 逻辑**：确保分页加载时，已存在的行不会被新对象替换：

```typescript
// useMasterDetailData.ts - mergeMasterCache
function mergeMasterCache(rows: RowData[]) {
  const merged: RowData[] = [];
  for (const row of rows) {
    const rowKey = row._rowKey;
    if (rowKey && masterRowMap.has(rowKey)) {
      // 已存在的行，复用原对象（保持引用稳定）
      merged.push(masterRowMap.get(rowKey)!);
      continue;
    }
    if (rowKey) {
      masterRowMap.set(rowKey, row);
    }
    masterRows.value.push(row);
    merged.push(row);
  }
  return merged;
}
```

3. **确保 `detailRowAutoHeight` 和 `keepDetailRows` 配置正确**：

```typescript
// useNestedDetailParams.ts
summaryDetailParams.detailGridOptions = {
  // ...
  masterDetail: true,
  keepDetailRows: true,        // 保持从表展开状态
  detailRowAutoHeight: true,
  // ...
}
```

---

## 风险评估

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| `_rowKey` 生成重复 | Grid 行为异常 | UUID + `db_` 前缀保证唯一 |
| 刷新后 `_rowKey` 变化 | 无影响 | 刷新后 Grid 重新渲染 |
| `forEachNode` 性能 | 大数据量时略慢 | SSRM 分页加载，内存中行数有限 |
| 展开从表时 ID 为 NULL | SQL 查询失败 | `loadDetailData` 分离 rowKey 和 masterId 参数 |
| 从表自动关闭 | 用户体验差 | 确保 `_rowKey` 稳定 + `keepDetailRows: true` |
