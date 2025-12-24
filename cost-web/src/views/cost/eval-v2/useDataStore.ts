/**
 * 数据存储（多 Tab 版）
 * 支持一个主表 + 多个从表（原料/辅料/包材）
 */
import { ref, computed } from 'vue';

export interface MasterData {
  id: number | null;
  evalNo: string;
  productName: string;
  apexPl: number;
  yield: number;
  outPriceRmb: number;
  totalYl: number;      // 原料合计
  totalFl: number;      // 辅料合计
  totalPack: number;    // 包材合计（新增）
  totalCost: number;    // 总成本
  _changeType?: Record<string, 'user' | 'cascade'>;
}

export interface DetailData {
  id: number | null;
  evalId: number | null;
  materialName: string;
  useFlag: string;
  perHl: number;
  price: number;
  batchQty: number;
  costBatch: number;
  // 包材特有字段
  packSpec?: string;    // 包装规格
  packQty?: number;     // 包装数量
  packCost?: number;    // 包装成本
  _changeType?: Record<string, 'user' | 'cascade'>;
}

export type TabKey = 'material' | 'auxiliary' | 'package';

export interface TabConfig {
  key: TabKey;
  title: string;
  filterValue: string;  // useFlag 过滤值
  visible: boolean;
}

export function useDataStore() {
  // 主表数据
  const master = ref<MasterData>({
    id: null,
    evalNo: '',
    productName: '',
    apexPl: 0,
    yield: 100,
    outPriceRmb: 0,
    totalYl: 0,
    totalFl: 0,
    totalPack: 0,
    totalCost: 0
  });

  // 从表数据（按类型分组）
  const details = ref<Record<TabKey, DetailData[]>>({
    material: [],
    auxiliary: [],
    package: []
  });

  // Tab 配置
  const tabs = ref<TabConfig[]>([
    { key: 'material', title: '原料', filterValue: '原料', visible: true },
    { key: 'auxiliary', title: '辅料', filterValue: '辅料', visible: true },
    { key: 'package', title: '包材', filterValue: '包材', visible: true }
  ]);

  const isLoaded = ref(false);

  // 加载主表数据
  function loadMaster(row: Record<string, any>) {
    master.value = {
      id: row.id,
      evalNo: row.evalNo || '',
      productName: row.productName || '',
      apexPl: Number(row.apexPl) || 0,
      yield: Number(row.yield) || 100,
      outPriceRmb: Number(row.outPriceRmb) || 0,
      totalYl: Number(row.totalYl) || 0,
      totalFl: Number(row.totalFl) || 0,
      totalPack: Number(row.totalPack) || 0,
      totalCost: Number(row.totalCost) || 0,
      _changeType: {}
    };
    isLoaded.value = true;
  }

  // 加载从表数据（按 useFlag 分组）
  function loadDetails(rows: Record<string, any>[]) {
    const material: DetailData[] = [];
    const auxiliary: DetailData[] = [];
    const pack: DetailData[] = [];

    rows.forEach(row => {
      const item: DetailData = {
        id: row.id,
        evalId: row.evalId,
        materialName: row.materialName || '',
        useFlag: row.useFlag || '',
        perHl: Number(row.perHl) || 0,
        price: Number(row.price) || 0,
        batchQty: Number(row.batchQty) || 0,
        costBatch: Number(row.costBatch) || 0,
        packSpec: row.packSpec || '',
        packQty: Number(row.packQty) || 0,
        packCost: Number(row.packCost) || 0,
        _changeType: {}
      };

      if (row.useFlag === '原料') {
        material.push(item);
      } else if (row.useFlag === '辅料') {
        auxiliary.push(item);
      } else if (row.useFlag === '包材') {
        pack.push(item);
      }
    });

    details.value = { material, auxiliary, package: pack };
  }

  // 更新主表字段
  function updateMasterField(field: keyof MasterData, value: any) {
    (master.value as any)[field] = value;
  }

  // 更新从表字段
  function updateDetailField(tabKey: TabKey, rowId: number, field: keyof DetailData, value: any) {
    const row = details.value[tabKey].find(r => r.id === rowId);
    if (row) {
      (row as any)[field] = value;
    }
  }

  // 标记主表字段变更类型
  function markMasterChange(field: string, type: 'user' | 'cascade') {
    if (!master.value._changeType) master.value._changeType = {};
    master.value._changeType[field] = type;
  }

  // 标记从表字段变更类型
  function markDetailChange(tabKey: TabKey, rowId: number, field: string, type: 'user' | 'cascade') {
    const row = details.value[tabKey].find(r => r.id === rowId);
    if (row) {
      if (!row._changeType) row._changeType = {};
      row._changeType[field] = type;
    }
  }

  // 切换 Tab 可见性
  function toggleTab(tabKey: TabKey) {
    const tab = tabs.value.find(t => t.key === tabKey);
    if (tab) {
      tab.visible = !tab.visible;
    }
  }

  // 关闭 Tab
  function closeTab(tabKey: TabKey) {
    const tab = tabs.value.find(t => t.key === tabKey);
    if (tab) {
      tab.visible = false;
    }
  }

  // 打开 Tab
  function openTab(tabKey: TabKey) {
    const tab = tabs.value.find(t => t.key === tabKey);
    if (tab) {
      tab.visible = true;
    }
  }

  // 获取可见的 Tab
  const visibleTabs = computed(() => tabs.value.filter(t => t.visible));

  // 重置
  function reset() {
    master.value = {
      id: null,
      evalNo: '',
      productName: '',
      apexPl: 0,
      yield: 100,
      outPriceRmb: 0,
      totalYl: 0,
      totalFl: 0,
      totalPack: 0,
      totalCost: 0
    };
    details.value = { material: [], auxiliary: [], package: [] };
    isLoaded.value = false;
  }

  // 是否有未保存的修改
  const isDirty = computed(() => {
    const masterDirty = Object.keys(master.value._changeType || {}).length > 0;
    const detailsDirty = Object.values(details.value).some(arr =>
      arr.some(d => Object.keys(d._changeType || {}).length > 0)
    );
    return masterDirty || detailsDirty;
  });

  // 获取所有从表数据（扁平化）
  const allDetails = computed(() => [
    ...details.value.material,
    ...details.value.auxiliary,
    ...details.value.package
  ]);

  return {
    master,
    details,
    tabs,
    visibleTabs,
    isLoaded,
    isDirty,
    allDetails,
    loadMaster,
    loadDetails,
    updateMasterField,
    updateDetailField,
    markMasterChange,
    markDetailChange,
    toggleTab,
    closeTab,
    openTab,
    reset
  };
}
