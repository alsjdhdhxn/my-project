/**
 * 保存参数构建器
 * 构建符合后端接口规范的保存参数
 */

// ==================== 类型定义 ====================

/** 行数据（含内部状态） */
export interface RowData {
  id: number | null;
  _isNew?: boolean;
  _isDeleted?: boolean;
  _changeType?: Record<string, 'user' | 'cascade'>;
  _originalValues?: Record<string, any>;
  [key: string]: any;
}

/** 变更记录 */
export interface ChangeRecord {
  field: string;
  oldValue: any;
  newValue: any;
  changeType: 'user' | 'cascade';
}

/** 单条记录保存参数 */
export interface RecordItem {
  id: number | null;
  status: 'added' | 'modified' | 'deleted' | 'unchanged';
  data: Record<string, any>;
  changes?: ChangeRecord[];
  updateTime?: string;
}

/** 保存参数 */
export interface SaveParams {
  pageCode: string;
  master: RecordItem;
  details?: Record<string, RecordItem[]>;
}

// ==================== 构建函数 ====================

/**
 * 构建保存参数（支持嵌套结构）
 */
export function buildSaveParams(
  pageCode: string,
  masterRows: MasterRowData[],
  masterTableCode: string,
  detailTableCode: string,
  parentFkColumn: string
): SaveParams[] {
  const result: SaveParams[] = [];

  for (const masterRow of masterRows) {
    const detailRows = masterRow._details?.rows || [];
    const masterChanged = isRowChanged(masterRow);
    const detailsChanged = detailRows.some(isRowChanged);

    // 主表或从表有变更才需要保存
    if (!masterChanged && !detailsChanged) continue;

    const param = buildSingleSaveParam(
      pageCode,
      masterRow,
      detailRows,
      masterTableCode,
      detailTableCode,
      parentFkColumn
    );

    if (param) {
      result.push(param);
    }
  }

  return result;
}

/** 主表行（含从表数据） */
export interface MasterRowData extends RowData {
  _details?: { loaded: boolean; rows: RowData[] } | null;
}

/**
 * 构建单个主从保存参数
 */
function buildSingleSaveParam(
  pageCode: string,
  masterRow: RowData,
  detailRows: RowData[],
  masterTableCode: string,
  detailTableCode: string,
  parentFkColumn: string
): SaveParams | null {
  const masterItem = buildRecordItem(masterRow, masterTableCode);

  const changedDetails = detailRows.filter(isRowChanged);
  const detailItems = changedDetails.map(row =>
    buildRecordItem(row, detailTableCode, masterRow.id, parentFkColumn)
  );

  const param: SaveParams = {
    pageCode,
    master: masterItem
  };

  if (detailItems.length > 0) {
    param.details = { [detailTableCode]: detailItems };
  }

  return param;
}

/**
 * 构建单条记录参数
 */
export function buildRecordItem(
  row: RowData,
  tableCode: string,
  parentId?: number | null,
  parentFkColumn?: string
): RecordItem {
  const isNew = row._isNew === true;
  const isDeleted = row._isDeleted === true;
  const changeType = row._changeType || {};
  const originalValues = row._originalValues || {};
  const hasChanges = Object.keys(changeType).length > 0;

  // 确定状态
  let status: RecordItem['status'];
  if (isDeleted) {
    status = 'deleted';
  } else if (isNew) {
    status = 'added';
  } else if (hasChanges) {
    status = 'modified';
  } else {
    status = 'unchanged';
  }

  // 构建数据（排除内部字段，添加 tableCode）
  const data: Record<string, any> = { _tableCode: tableCode };
  for (const [key, value] of Object.entries(row)) {
    if (!key.startsWith('_')) {
      data[key] = value;
    }
  }

  // 新增行设置外键
  if (isNew && parentId && parentFkColumn) {
    data[parentFkColumn] = parentId;
  }

  // 构建变更记录
  const changes: ChangeRecord[] = [];
  for (const [field, type] of Object.entries(changeType)) {
    changes.push({
      field,
      oldValue: originalValues[field] ?? null,
      newValue: row[field],
      changeType: type
    });
  }

  return {
    id: isNew ? null : row.id,
    status,
    data,
    changes: changes.length > 0 ? changes : undefined,
    updateTime: row.updateTime
  };
}

/**
 * 判断行是否有变更
 */
export function isRowChanged(row: RowData): boolean {
  return (
    row._isNew === true ||
    row._isDeleted === true ||
    Object.keys(row._changeType || {}).length > 0
  );
}

/**
 * 生成临时 ID（负数，避免与数据库 ID 冲突）
 */
let tempIdCounter = 0;
export function generateTempId(): number {
  return -(Date.now() * 1000 + tempIdCounter++);
}

/**
 * 初始化行数据（添加内部状态字段）
 */
export function initRowData(row: Record<string, any>, isNew = false): RowData {
  // 过滤内部字段创建原始值快照
  const originalValues: Record<string, any> = {};
  for (const [key, value] of Object.entries(row)) {
    if (!key.startsWith('_')) {
      originalValues[key] = value;
    }
  }

  return {
    ...row,
    id: row.id ?? null,
    _isNew: isNew,
    _isDeleted: false,
    _changeType: {},
    _originalValues: isNew ? {} : originalValues
  };
}

/**
 * 清除行的变更标记（保存成功后调用）
 */
export function clearRowChanges(row: RowData): RowData {
  const originalValues: Record<string, any> = {};
  for (const [key, value] of Object.entries(row)) {
    if (!key.startsWith('_')) {
      originalValues[key] = value;
    }
  }

  return {
    ...row,
    id: row.id,
    _isNew: false,
    _isDeleted: false,
    _changeType: {},
    _originalValues: originalValues
  };
}
