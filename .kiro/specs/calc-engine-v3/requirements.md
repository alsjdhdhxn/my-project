# 计算引擎 V2 - 需求规格

## 背景

当前计算引擎存在以下问题：
1. 数据分散：主表在 `masterData`，从表在 Grid 的 `rowData`，通过 `_ctx` 传递
2. 计算分散：行级计算在 `valueGetter` 用 `eval`，聚合在引擎
3. 与 Grid API 紧耦合
4. 使用不安全的 `eval` 解析表达式

## 核心需求

### 1. 无虚拟列
- 所有列都是真实数据库列，保存时写入数据库
- 计算结果实时写入 JSON Store，保存时同步到数据库

### 2. 选中后才计算
- 用户选中主表行之前，不做任何计算，信任数据库数据
- 选中后，数据加载到 JSON Store，开始响应式计算

### 3. JSON Store 单一数据源
```typescript
interface DataStore {
  master: Record<string, any>;      // 当前选中的主表行
  details: Record<string, any>[];   // 从表数据
}
```
- AG Grid 只负责渲染，不持有数据
- 所有编辑、计算都操作 JSON Store

### 4. 模块完全解耦
- 计算引擎、数据存储、Grid 渲染、变更追踪各自独立
- 一个模块出错不影响其他模块
- 每个模块可独立测试

### 5. 用户操作日志（异步）
- 记录：谁、什么时间、IP、修改了什么数据
- 只记录用户直接操作，不记录级联计算
- 异步写入，不阻塞主流程

### 6. 单元格样式区分
- 用户编辑的单元格：绿色背景 `#e6ffe6`
- 级联计算的单元格：黄色背景 `#fffde6`
- 通过 `_changeType: 'user' | 'cascade'` 字段标识

### 7. 布局要求
- 主表/从表各占 50% 屏幕高度
- 内部滚动，页面不滚动

### 8. 组件化可复用
- 所有模块封装为独立 composable
- 可在不同页面复用

### 9. 使用 math.js 替代 eval
```typescript
import { compile } from 'mathjs';
const expr = compile('master.apexPl * perHl / 100');
const result = expr.evaluate({ master: { apexPl: 100 }, perHl: 125.5 });
```

### 10. 元数据驱动的单元格样式
- 通过 `COLUMN_METADATA.RULES_CONFIG` 配置条件样式
- 配置格式：
```json
{
  "style": [
    {
      "condition": { "type": "contains", "pattern": "瓶" },
      "style": { "color": "red" }
    }
  ]
}
```
- 支持的条件类型：
  - `contains`: 包含指定文本
  - `startsWith`: 以指定文本开头
  - `endsWith`: 以指定文本结尾
  - `equals`: 等于指定值
  - `compare`: 数值比较（>, >=, <, <=, ==, !=）
- 编辑后实时更新样式

- [ ] 元数据配置的条件样式正确应用
- [ ] 编辑单元格后样式实时更新

## 验收标准

- [ ] 选中主表行后，从表数据加载到 JSON Store
- [ ] 编辑主表字段，从表计算列自动更新
- [ ] 编辑从表字段，主表聚合字段自动更新
- [ ] 用户编辑单元格显示绿色
- [ ] 级联计算单元格显示黄色
- [ ] 保存时所有数据写入数据库
- [ ] 操作日志异步记录
- [ ] 主从表各占 50% 高度，内部滚动
- [ ] 计算引擎出错不影响 Grid 渲染
