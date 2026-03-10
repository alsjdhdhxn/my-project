import { ref, shallowRef } from 'vue';
import type { BatchSelectConfig } from '@/v3/components/BatchSelectDialog.vue';
import { type RowData, ensureRowKey, generateTempId, initRowData } from '@/v3/logic/calc-engine';

export type BatchSelectContext = {
  /** 当前主表选中行的 ID */
  masterId: number | null;
  /** 当前主表选中行的 rowKey */
  masterRowKey: string | null;
  /** 目标从表 tabKey */
  tabKey: string;
};

/**
 * 批量选择弹窗 composable
 * 用于从弹窗选择数据批量添加到从表
 */
export function useBatchSelect(params: {
  /** 明细数据缓存 */
  detailCache: Map<string, Record<string, RowData[]>>;
  /** 从表外键字段映射 */
  detailFkColumnByTab: { value: Record<string, string> } | Record<string, string>;
  /** 从表 Grid API */
  detailGridApisByTab?: { value: Record<string, any> } | Record<string, any>;
  /** 新增行后的回调 */
  afterAddDetailRows?: (masterId: number, tabKey: string, rows: RowData[]) => void;
}) {
  const { detailCache, detailFkColumnByTab, detailGridApisByTab, afterAddDetailRows } = params;

  // 弹窗引用
  const batchSelectDialogRef = shallowRef<any>(null);

  // 当前批量选择的上下文
  const currentBatchSelectContext = ref<BatchSelectContext | null>(null);
  const currentBatchSelectConfig = ref<BatchSelectConfig | null>(null);

  function resolveFkColumn(tabKey: string): string {
    const raw = (detailFkColumnByTab as any)?.value ?? detailFkColumnByTab;
    return raw?.[tabKey] || 'masterId';
  }

  function resolveDetailGridApi(tabKey: string): any {
    const raw = (detailGridApisByTab as any)?.value ?? detailGridApisByTab;
    return raw?.[tabKey];
  }

  /**
   * 打开批量选择弹窗
   * @param config 批量选择配置
   * @param context 上下文（主表ID、rowKey、目标tabKey）
   * @param filterValue 筛选值（可选）
   */
  function openBatchSelect(config: BatchSelectConfig, context: BatchSelectContext, filterValue?: any) {
    if (!context.masterId || !context.masterRowKey || !context.tabKey) {
      console.warn('[useBatchSelect] 缺少必要的上下文信息');
      return;
    }

    currentBatchSelectConfig.value = config;
    currentBatchSelectContext.value = context;

    // 打开弹窗
    batchSelectDialogRef.value?.open(config, filterValue);
  }

  /**
   * 处理批量选择确认
   * 将选中的数据作为新行添加到从表
   */
  function onBatchSelectConfirm(selectedRows: Record<string, any>[]) {
    const ctx = currentBatchSelectContext.value;
    const config = currentBatchSelectConfig.value;

    if (!ctx || !ctx.masterId || !ctx.masterRowKey || !ctx.tabKey) {
      console.warn('[useBatchSelect] 上下文丢失');
      return;
    }

    if (!selectedRows || selectedRows.length === 0) {
      return;
    }

    const { masterId, masterRowKey, tabKey } = ctx;
    const fkColumn = resolveFkColumn(tabKey);

    // 获取或初始化缓存
    let cached = detailCache.get(masterRowKey);
    if (!cached) {
      cached = {};
      detailCache.set(masterRowKey, cached);
    }
    if (!cached[tabKey]) {
      cached[tabKey] = [];
    }

    // 创建新行
    const newRows: RowData[] = selectedRows.map(rowData => {
      const newRow = initRowData(
        {
          id: generateTempId(),
          [fkColumn]: masterId,
          ...rowData
        },
        true
      );
      ensureRowKey(newRow);
      return newRow;
    });

    // 添加到缓存
    cached[tabKey].push(...newRows);

    // 刷新 Grid
    const api = resolveDetailGridApi(tabKey);
    if (api) {
      api.setGridOption?.('rowData', cached[tabKey]);
    }

    // 回调
    afterAddDetailRows?.(masterId, tabKey, newRows);

    // 清理上下文
    currentBatchSelectContext.value = null;
    currentBatchSelectConfig.value = null;

    console.log(`[useBatchSelect] 已添加 ${newRows.length} 行到 ${tabKey}`);
  }

  /**
   * 处理批量选择取消
   */
  function onBatchSelectCancel() {
    currentBatchSelectContext.value = null;
    currentBatchSelectConfig.value = null;
  }

  return {
    batchSelectDialogRef,
    currentBatchSelectConfig,
    currentBatchSelectContext,
    openBatchSelect,
    onBatchSelectConfirm,
    onBatchSelectCancel
  };
}
