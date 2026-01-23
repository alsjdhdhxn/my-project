# V3 功能缺失清单（相对 V2）

> 对比范围：`cost-web` 前端的 Meta 驱动页面（V2 vs V3）
> 
> 对比依据：本仓库代码与文档中的 V2/V3 实现（见下方"证据"中的文件路径）。

## 结论概览
V2 具备的"通用组件渲染 + 灵活页面布局 + 组件级错误隔离"的体系，在 V3 里没有对应实现；V3 目前只提供固定的主从明细布局（`MasterDetailLayoutV3`），因此 V2 的多组件页面、布局容器、表单/按钮组件、分屏明细等能力在 V3 中不可用或未接入。

## 详细缺失项

### 1) 通用组件渲染体系（MetaPageRenderer + RendererRegistry）
- **V2 有**：`MetaPageRenderer` 动态渲染组件树，并通过 `RendererBoundary` 做组件级错误隔离；渲染器通过 `renderers.ts` 自动注册。
  - 证据：`cost-web/src/components/meta-v2/renderers/MetaPageRenderer.vue`、`cost-web/src/components/meta-v2/renderers/renderers.ts`、`cost-web/src/composables/meta-v2/component-renderer-registry.ts`
- **V3 无**：页面入口直接使用固定布局 `MasterDetailLayoutV3`，未使用通用渲染器注册与组件树渲染。
  - 证据：`cost-web/src/v3/components/MasterDetailPageV3.vue`、`cost-web/src/views/_builtin/dynamic-v3/index.vue`
- **影响**：V3 无法像 V2 那样按组件树渲染多种组件，也无法通过注册渲染器扩展新组件类型。
- **改造方案**：
  - **方案A（渐进式兼容）**：新增 `MetaPageRendererV3`，沿用 V2 renderer registry 机制，通过 `<component :is="...">` 动态渲染组件；`dynamic-v3` 根据页面元数据或开关选择 `MetaPageRendererV3` 或现有 `MasterDetailLayoutV3`，确保老页面不受影响。
  - **方案B（统一渲染入口）**：将 `MasterDetailLayoutV3` 也做成 renderer（如组件类型 `MASTER_DETAIL`），由组件树驱动布局，统一扩展入口。
  - **选型结论**：采用统一渲染入口（`MASTER_DETAIL` 作为 renderer），后续逐步收敛到单入口。
  - **工程细节**：renderer 允许按需异步加载，配合 `<Suspense>` 与 `<KeepAlive>` 处理加载与缓存，减少切换抖动。
- **实施里程碑（粗略人天）**：
  - M1 方案选型与组件树契约对齐（1-2 人天）
  - M2 实现 `MetaPageRendererV3` + registry + 边界处理（5-7 人天）
  - M3 路由/开关接入与回归测试（2-3 人天）
  - **依赖/风险**：页面配置差异导致渲染不一致；异步 renderer 可能产生闪烁，需要 `<Suspense>` 与 `keep-alive` 配合。

### 2) LAYOUT 容器组件（布局方向/间距/对齐/子组件）
- **V2 有**：`LAYOUT` 组件支持 `direction/gap/align/justify/flex/width/height/fill` 等配置并递归渲染子组件。
  - 证据：`cost-web/src/components/meta-v2/renderers/LayoutRenderer.vue`
- **V3 无**：没有对应的布局容器渲染器或组件树渲染入口。
  - 证据：`cost-web/src/v3/components` 仅包含固定布局相关组件
- **影响**：V3 无法按元数据配置多区域/多块布局，页面结构固定。
- **改造方案**：
  - **复用方案**：直接移植 V2 `LayoutRenderer` 到 `v3`，保持 `componentConfig` 协议不变（direction/gap/align/justify/flex/width/height/fill）。
  - **进阶方案**：扩展 `layout.type = flex | grid`，在复杂场景引入 CSS Grid 分区；允许 `className/style` 透传，提升样式自由度。
  - **工程细节**：在 registry 注册 `LAYOUT`，并确保 children 依据 `sortOrder` 渲染。
- **实施里程碑（粗略人天）**：
  - M1 迁移 `LayoutRenderer` 并注册（1 人天）
  - M2 增强 grid/flex 与样式透传（2-3 人天）
  - M3 典型页面验证与样式回归（1-2 人天）
  - **依赖/风险**：旧页面 `componentConfig` 异常值；布局高度/嵌套滚动冲突。

### 3) FORM 表单组件（自定义渲染器/占位）
- **V2 有**：`MetaForm` 支持自定义 renderer 与占位提示，依赖运行时状态。
  - 证据：`cost-web/src/components/meta-v2/renderers/MetaForm.vue`
- **V3 无**：无表单组件渲染实现。
  - 证据：`cost-web/src/v3/components` 中无对应组件
- **影响**：V3 无法通过元数据配置"表单组件"渲染。
- **改造方案**：
  - **复用方案**：新增 `MetaFormV3`，先复用 V2 `MetaForm` 逻辑；在 runtime 的 `buildStates/applyExtensions` 中为 `FORM` 组件填充 `FormState.renderer/placeholder`。
  - **扩展方案**：引入“表单 renderer registry”，根据 `rendererKey/variantKey` 选择不同表单实现；可逐步引入 schema-driven 表单（更成熟、易配置）。
  - **异常兜底**：表单渲染异常时用 `onErrorCaptured/reportComponentError` 写入状态并回落 placeholder。
- **实施里程碑（粗略人天）**：
  - M1 `MetaFormV3` 基础实现与占位兜底（2-3 人天）
  - M2 renderer registry/variant 适配（2-4 人天）
  - M3 schema-form POC（可选，3-5 人天）
  - **依赖/风险**：表单元数据来源不统一；校验规则与现有 `VALIDATION` 兼容。

### 4) BUTTON 按钮组件（动作路由/执行）
- **V2 有**：`MetaButton` 支持按钮配置（text/type/size/action）并触发 runtime action。
  - 证据：`cost-web/src/components/meta-v2/renderers/MetaButton.vue`
- **V3 无**：无按钮组件渲染实现。
  - 证据：`cost-web/src/v3/components` 中无对应组件
- **影响**：V3 无法通过元数据配置"按钮组件"。
- **改造方案**：
  - **安全执行链**：新增 action registry（actionCode -> handler），`MetaButtonV3` 只执行白名单 action；与权限/角色规则联动。
  - **交互增强**：支持 confirm/undo/批处理，统一返回结果 → notify + reload。
  - **兼容策略**：保留 `runtime.executeAction` 作为后备通道，逐步迁移到 registry。
- **实施里程碑（粗略人天）**：
  - M1 action registry + `MetaButtonV3`（2-3 人天）
  - M2 权限/确认/回滚交互（2-3 人天）
  - M3 现有按钮迁移与回归（1-2 人天）
  - **依赖/风险**：action code 与后端接口不一致；权限规则缺失导致误操作。

### 5) 组件级错误隔离/占位渲染
- **V2 有**：`RendererBoundary` 捕获渲染错误并写入组件状态；`MetaGrid/MetaForm/MetaButton` 有 loading/error 占位。
  - 证据：`cost-web/src/components/meta-v2/renderers/MetaPageRenderer.vue`、`cost-web/src/components/meta-v2/renderers/MetaGrid.vue`
- **V3 无**：仅页面级错误/加载态；无组件级边界与占位渲染。
  - 证据：`cost-web/src/v3/components/MasterDetailPageV3.vue`
- **影响**：V3 发生组件级异常时无法做到"局部失败、整体可用"的渲染隔离。
- **改造方案**：
  - **组件级边界**：在 `MetaPageRendererV3` 中使用 `onErrorCaptured` 捕获渲染/事件/生命周期错误并更新 `componentState`，避免重新渲染原失败内容造成循环。
  - **第三方库选型**：
    - 推荐 `@kong-ui-public/error-boundary`（发布时间以 npm 页面为准），支持 fallback slot、tags 标记、嵌套边界，更适合企业级长期维护。
    - 备选 `vue-error-boundary`（发布时间以 npm 页面为准），维护活跃度一般，但功能够用。
  - **官方范式**：Vue 3 提供 `app.config.errorHandler` 作为全局兜底，可统一上报异常与日志；生产环境 `info` 可能是短码，需结合错误码映射定位。
  - **UI 兜底**：为 `MetaGridV3/MetaFormV3/MetaButtonV3` 提供 loading/error 占位。
- **实施里程碑（粗略人天）**：
  - M1 `RendererBoundary` + `reportComponentError` 统一接入（1-2 人天）
  - M2 全局错误处理与日志格式统一（1 人天）
  - M3 UI 兜底与错误提示规范化（1-2 人天）
  - **依赖/风险**：生产环境 `info` 为短码，需要错误码映射表辅助定位。

### 6) 主从分屏布局（Split 模式）
- **V2 有**：支持 `detailType = split`，通过 `NSplit` 同屏展示主表 + 明细 Tabs 面板。
  - 证据：`cost-web/src/components/meta-v2/renderers/MasterDetailLayoutRenderer.vue`（`NSplit`、`detailLayoutMode`、`detailSplitConfig`）
- **V3 无**：V3 支持 Tab 模式和堆叠模式，但没有分屏模式。固定为"主表行展开 + 详情行渲染"，未使用 `detailLayoutMode/detailSplitConfig`。
  - 证据：`cost-web/src/v3/components/MasterDetailLayoutV3.vue`、`cost-web/src/v3/components/detail/DetailPanelV3.vue`
- **影响**：V3 无法实现"主表与明细同屏分区"交互，只能使用行展开明细（Tab 或堆叠模式）。
- **改造方案**：
  - **Split 模式**：在 `MasterDetailLayoutV3` 增加 `detailLayoutMode === "split"` 分支（`NSplit` + `DetailPanelV3`），采用 selection 驱动加载明细。
  - **行展开保留**：保留 `masterDetail` 行展开作为默认；切换 split 时关闭展开逻辑，避免双重渲染。
  - **可行性/性能**：AG Grid Master/Detail 对主表 row model 有限制（需参考官方文档核对具体版本支持情况）；SSRM 下动态行高与缓存有约束（需参考官方文档核对 `maxBlocksInCache` 与动态行高的兼容性）。
  - **现状说明**：V3 当前使用 `masterDetail` + `detailCellRenderer`（非 `fullWidthCellRenderer`），行展开模式下仅配置了 `keepDetailRows`，未设置 `keepDetailRowsCount`。
  - **数据保留**：明细不丢失依赖双层机制：`keepDetailRows` 保留 UI 行，`detailCache` 保留数据。
  - **内存控制**：若保留行展开，可用 `keepDetailRows/keepDetailRowsCount` 控制缓存；若 Split 模式改为外部详情面板并关闭 `masterDetail`，则该配置不适用，需要自管缓存/销毁策略。
- **实施里程碑（粗略人天）**：
  - M1 Split UI 分支 + selection 驱动明细（3-5 人天）
  - M2 SSRM 行高/缓存策略调整（2-3 人天）
  - M3 大数据量场景回归与性能评估（1-2 人天）
  - **依赖/风险**：Master/Detail 的 row model 支持情况需参考官方文档核对；动态行高与 `maxBlocksInCache` 的兼容性需参考官方文档；`keepDetailRows` 需评估内存。

### 7) 组件扩展机制（renderer 扩展）
- **V2 有**：新增组件类型只需注册渲染器并写入 `componentStateByKey`。
  - 证据：`cost-web/src/components/meta-v2/renderers/renderers.ts`、`cost-web/src/composables/meta-v2/component-renderer-registry.ts`
- **V3 无**：存在 registry 代码但无渲染入口与默认 renderers；扩展机制未打通。
  - 证据：`cost-web/src/v3/composables/meta-v3/component-renderer-registry.ts`（未被使用）
- **影响**：V3 扩展新组件类型成本高，需要修改固定布局代码。
- **改造方案**：
  - **统一注册**：补齐 `v3/components/meta-v3/renderers` 与 `renderers.ts` 自动注册流程，沿用 `registerComponentRenderer` + `match` 机制。
  - **插件化**：对外暴露注册 API，支持业务模块自注册 renderer，降低核心改动频次。
  - **性能优化**：renderer 支持按需异步加载，结合 `<component :is>` + `<Suspense>` 回退；必要时配合 `keep-alive` 做状态缓存。
- **实施里程碑（粗略人天）**：
  - M1 自动注册与目录规范（1-2 人天）
  - M2 插件化注册 API 与冲突检测（1-2 人天）
  - M3 异步加载与缓存策略（1-2 人天）
  - **依赖/风险**：renderer key 冲突；按需加载导致首屏抖动。

## 备注
- V3 仍保留部分与 V2 相同的规则解析（`CALC/AGGREGATE/LOOKUP/VALIDATION/CONTEXT_MENU` 等）与运行时能力，但其 UI 层没有通用组件渲染框架，因此"组件/布局类能力"在 V3 中表现为缺失。
- 若需要把这些能力迁移到 V3，可优先补齐：`MetaPageRenderer` + renderer registry 的渲染入口，以及 `LAYOUT/FORM/BUTTON` 等组件实现，再考虑接入 `split` 视图。

## 优先级建议（资源有限）
- **P0**：第1点（渲染体系）+ 第7点（扩展机制）
- **P1**：第2点（LAYOUT）+ 第5点（错误隔离）
- **P2**：第3点（FORM）+ 第4点（BUTTON）
- **P3**：第6点（Split 模式）

## 技术方案评审模板（轻量版）

> 适用于内部评审，建议 1-3 页；如需更完整版本可按需扩展。

### 1. 背景与目标
- 现状问题、目标收益
- 非目标

### 2. 方案概述
- 核心思路
- 关键改动点

### 3. 影响面与兼容
- 影响模块/页面
- 兼容与回滚策略

### 4. 风险与对策
- 技术/业务风险
- 缓解措施

### 5. 计划与排期
- 里程碑与人天
- 资源需求

### 6. 验收与测试
- 关键验收标准
- 测试范围

## 参考资料（外部）

```
# Vue 3 官方文档
https://vuejs.org/api/built-in-special-elements
https://vuejs.org/guide/built-ins/keep-alive
https://vuejs.org/guide/built-ins/suspense
https://vuejs.org/api/application.html
https://vuejs.org/error-reference/

# AG Grid Master/Detail
https://www.ag-grid.com/javascript-data-grid/master-detail/
https://www.ag-grid.com/vue-data-grid/master-detail/
https://www.ag-grid.com/react-data-grid/server-side-model-master-detail/

# Vue School 相关文章（更新日期以页面为准）
https://vueschool.io/articles/vuejs-tutorials/what-is-a-vue-js-error-boundary-component/
https://vueschool.io/articles/vuejs-tutorials/suspense-everything-you-need-to-know/

# 第三方 Error Boundary 库（发布信息以 npm 页面为准）
https://www.npmjs.com/package/@kong-ui-public/error-boundary
https://www.npmjs.com/package/vue-error-boundary
```
