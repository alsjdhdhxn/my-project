# Requirements Document

## Introduction

重构成本评估页面（eval-v3 → eval-v4），实现深度解耦的架构：Pinia Store 作为单一数据源，AG Grid 作为纯渲染器，计算逻辑抽离为纯函数。

## Glossary

- **Eval_Store**: Pinia Store，持有所有主从表数据，作为单一数据源
- **Calculator**: 纯 TypeScript 函数，执行行级计算和聚合计算
- **Grid_Adapter**: 适配层，处理 Vue 响应式数据与 AG Grid 的同步
- **Master_Row**: 主表行数据（评估单）
- **Detail_Row**: 从表行数据（物料明细）
- **Cascade_Calc**: 级联计算，A→B→C→D 的链式计算
- **Change_Type**: 变更类型标记，区分用户修改(user)和级联计算(cascade)

## Requirements

### Requirement 1: 单一数据源

**User Story:** As a developer, I want all data stored in Pinia Store, so that I have a single source of truth and predictable state management.

#### Acceptance Criteria

1. WHEN data is loaded from API, THE Eval_Store SHALL store master rows and detail rows in a flat JSON structure
2. WHEN user switches master row, THE Eval_Store SHALL cache current detail data and load new detail data
3. WHEN user edits a cell, THE Eval_Store SHALL update the JSON data directly (not AG Grid)
4. THE Eval_Store SHALL maintain a detail cache map keyed by master ID to preserve unsaved changes

### Requirement 2: 纯渲染器 AG Grid

**User Story:** As a developer, I want AG Grid to be a pure renderer, so that UI and business logic are completely decoupled.

#### Acceptance Criteria

1. THE Grid_Adapter SHALL bind AG Grid rowData to Store's computed data
2. WHEN Store data changes, THE Grid_Adapter SHALL sync changes to AG Grid via Transaction API
3. WHEN user edits a cell in AG Grid, THE Grid_Adapter SHALL emit an event to Store (not modify data directly)
4. WHILE user is editing a cell, THE Grid_Adapter SHALL pause reactive updates to prevent edit conflicts

### Requirement 3: 纯函数计算引擎

**User Story:** As a developer, I want calculation logic as pure functions, so that I can unit test them without Vue or AG Grid dependencies.

#### Acceptance Criteria

1. THE Calculator SHALL be pure TypeScript functions with no Vue/AG Grid imports
2. WHEN calculating row-level fields, THE Calculator SHALL accept row data and context, return calculated values
3. WHEN calculating aggregates, THE Calculator SHALL accept detail rows array, return aggregate results
4. THE Calculator SHALL support cascade calculation (A→B→C→D) in correct dependency order

### Requirement 4: 响应式级联计算

**User Story:** As a developer, I want automatic cascade calculations, so that when field A changes, fields B/C/D update automatically.

#### Acceptance Criteria

1. WHEN master field (apexPl/yield) changes, THE Eval_Store SHALL trigger detail row recalculation via watchEffect
2. WHEN detail field (perHl/price) changes, THE Eval_Store SHALL trigger row-level cascade calculation
3. WHEN detail calculated field (costBatch/packCost) changes, THE Eval_Store SHALL trigger master aggregate recalculation
4. THE Eval_Store SHALL use in-place mutation for performance (not create new objects)

### Requirement 5: 元数据驱动 Tab 配置

**User Story:** As a developer, I want Tab configuration from database supporting both single-table grouping and multi-table modes.

#### Acceptance Criteria

1. WHEN page loads, THE System SHALL read Tab configuration from T_COST_PAGE_COMPONENT.COMPONENT_CONFIG
2. THE Tab configuration SHALL support mode='group' (单表分组模式)
   - THE System SHALL split detail rows by groupField (如 useFlag)
   - EACH Tab SHALL only display rows matching its groupField value
   - WHEN adding new detail row, THE System SHALL set groupField based on current Tab
3. THE Tab configuration SHALL support mode='multi' (多表模式)
   - EACH Tab SHALL have independent tableCode
   - EACH Tab SHALL load data from its own table
   - EACH Tab SHALL have independent column definitions
4. THE Tab configuration SHALL define: title, visible columns, sum field, sum target
5. THE Visible columns SHALL differ by Tab (material uses perHl/batchQty, package uses packSpec/packQty)
6. BOTH modes SHALL support all features: calculation, aggregation, validation, change tracking

### Requirement 6: 变更追踪与保存

**User Story:** As a user, I want to save my changes, so that my edits are persisted to database.

#### Acceptance Criteria

1. THE Eval_Store SHALL track change type for each field: 'user' (用户修改) or 'cascade' (级联计算)
2. THE Eval_Store SHALL maintain original values snapshot for each row to detect actual changes
3. THE Eval_Store SHALL track row state: _isNew (新增), _isDeleted (删除), _changeType (字段变更)
4. WHEN user saves, THE System SHALL only send rows with actual changes (comparing current vs original)
5. WHEN save succeeds, THE Eval_Store SHALL clear change flags and update original values snapshot
6. WHEN user navigates away with unsaved changes, THE System SHALL prompt for confirmation

### Requirement 7: 简化的组件结构

**User Story:** As a developer, I want a simplified page component, so that the view layer only handles layout and events.

#### Acceptance Criteria

1. THE Page component SHALL be less than 150 lines of code
2. THE Page component SHALL only handle: layout rendering, event binding, lifecycle hooks
3. THE Page component SHALL NOT contain calculation logic or data transformation

### Requirement 8: 工具栏功能

**User Story:** As a user, I want toolbar operations, so that I can search, filter, and manage data efficiently.

#### Acceptance Criteria

1. THE Toolbar SHALL provide quick search input for filtering master rows
2. THE Toolbar SHALL provide refresh button to reload data from API
3. THE Toolbar SHALL provide Tab visibility toggles to show/hide detail tabs
4. THE Toolbar SHALL be positioned fixed on the right side, support collapsed/expanded state
5. THE Toolbar SHALL be draggable vertically to adjust position

### Requirement 9: 主从表交互

**User Story:** As a user, I want to manage master-detail relationship, so that I can edit evaluation data with related materials.

#### Acceptance Criteria

1. WHEN user selects a master row, THE System SHALL load corresponding detail rows
2. WHEN user adds a new master row, THE System SHALL generate temporary ID and default values
3. WHEN user deletes a master row, THE System SHALL also delete cached detail data
4. THE System SHALL support multi-selection in detail grids with checkbox column

### Requirement 10: 数据验证

**User Story:** As a user, I want data validation before save, so that I don't submit invalid data.

#### Acceptance Criteria

1. WHEN user saves, THE System SHALL validate rows against validation rules from COLUMN_METADATA.RULES_CONFIG
2. THE Validator SHALL support: required, notZero, min, max, pattern rules
3. THE Validation rules SHALL be executed in order specified by 'order' field
4. IF validation fails, THE System SHALL show error message and prevent save

### Requirement 11: 可拖动分隔布局

**User Story:** As a user, I want to resize master and detail areas, so that I can adjust the view based on my needs.

#### Acceptance Criteria

1. THE Layout SHALL use NSplit component with vertical direction
2. THE User SHALL be able to drag the splitter to resize master/detail areas
3. THE Split ratio SHALL have min 0.2 and max 0.8 constraints

### Requirement 12: 元数据驱动列定义与计算

**User Story:** As a developer, I want column definitions and calculation rules from metadata, so that I don't hardcode them.

#### Acceptance Criteria

1. THE System SHALL fetch column metadata from API (loadTableMeta)
2. THE Column metadata SHALL include: field, headerText, dataType, editable, width, rulesConfig
3. THE Calculation rules SHALL be extracted from COLUMN_METADATA.RULES_CONFIG.calculate
4. THE Rules SHALL define: expression (mathjs syntax), triggerFields (dependencies)
5. THE Calculator SHALL support context variables (apexPl, yield from master row)

### Requirement 13: 聚合规则从页面组件加载

**User Story:** As a developer, I want aggregation rules from page components, so that I don't hardcode SUM formulas.

#### Acceptance Criteria

1. THE Aggregation rules SHALL be extracted from T_COST_PAGE_COMPONENT with type LOGIC_AGG
2. THE Rules SHALL define: source, target, sourceField, targetField, algorithm, filter
3. THE Supported algorithms SHALL include: SUM, AVG, COUNT, MAX, MIN
4. THE Filter SHALL support expression like "useFlag=='原料'"

### Requirement 14: 选中状态保持

**User Story:** As a user, I want my selection preserved after operations, so that I don't lose my context.

#### Acceptance Criteria

1. WHEN save succeeds, THE System SHALL remember and re-select current master row
2. WHEN Grid data refreshes, THE System SHALL preserve current row selection
3. WHEN refreshing single row, THE System SHALL use AG Grid Transaction API for performance

### Requirement 15: 条件样式与变更可视化

**User Story:** As a user, I want visual feedback for data state, so that I can track changes and identify important data.

#### Acceptance Criteria

1. WHEN cell is modified by user, THE Cell SHALL have green background (#e6ffe6)
2. WHEN cell is modified by cascade calculation, THE Cell SHALL have yellow background (#fffde6)
3. WHEN cell value returns to original, THE System SHALL remove the change marker
4. THE Style rules SHALL be loaded from COLUMN_METADATA.RULES_CONFIG.style
5. THE System SHALL inject dynamic CSS rules from metadata

### Requirement 16: Lookup 弹窗选择

**User Story:** As a user, I want to select values from a lookup popup, so that I can quickly fill related fields.

#### Acceptance Criteria

1. WHEN column has lookup config in RULES_CONFIG, THE Cell SHALL display as clickable link style
2. WHEN user clicks a lookup cell, THE System SHALL open MetaLookup popup with search
3. WHEN user selects a row (double-click or confirm), THE System SHALL fill mapped fields
4. AFTER lookup selection, THE System SHALL trigger calculation for affected fields

### Requirement 17: 键盘快捷键

**User Story:** As a user, I want keyboard shortcuts, so that I can work efficiently without mouse.

#### Acceptance Criteria

1. WHEN user presses Ctrl+Enter in Grid container, THE System SHALL add a new row
2. WHEN user presses Delete with row selected (not editing), THE System SHALL delete selected rows
3. WHEN user presses Ctrl+S anywhere, THE System SHALL trigger save operation
4. AFTER adding new row, THE System SHALL focus on firstEditableField and start editing

### Requirement 18: 默认值与数值处理

**User Story:** As a developer, I want proper default values and numeric handling, so that new rows and calculations work correctly.

#### Acceptance Criteria

1. THE Default values SHALL be extracted from column metadata (number→0, text→'')
2. WHEN adding new master row, THE System SHALL apply defaults plus generated evalNo
3. WHEN adding new detail row, THE System SHALL apply defaults plus evalId and useFlag
4. WHEN column dataType is 'number', THE Cell SHALL parse input and handle NaN as 0

### Requirement 19: 保存参数构建

**User Story:** As a developer, I want proper save parameter structure, so that backend can process changes correctly.

#### Acceptance Criteria

1. THE Save params SHALL include: pageCode, master record, details map
2. EACH Record SHALL have: id, status (added/modified/deleted), data, changes array
3. THE Changes array SHALL include: field, oldValue, newValue, changeType
4. FOR new detail rows, THE System SHALL set foreign key (evalId) to master ID
5. THE System SHALL handle case where only details changed but master unchanged

### Requirement 20: API 数据加载

**User Story:** As a developer, I want standardized API calls, so that data loading is consistent.

#### Acceptance Criteria

1. THE System SHALL load master list via fetchDynamicData('CostEval', {})
2. THE System SHALL load detail list via fetchDynamicData('CostEvalDetail', { EVAL_ID: masterId })
3. THE System SHALL load table metadata via fetchTableMetadata(tableCode)
4. THE System SHALL load page components via fetchPageComponents(pageCode)
5. THE System SHALL save data via saveDynamicData({ pageCode, master, details })
