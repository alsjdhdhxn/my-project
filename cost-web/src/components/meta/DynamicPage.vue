<template>
  <div class="dynamic-page">
    <!-- 顶部工具栏 -->
    <div class="dynamic-page-toolbar">
      <NSpace>
        <NButton type="primary" size="small" :disabled="!isDirty" @click="handleSave">
          <template #icon><span class="i-carbon-save" /></template>
          保存
        </NButton>
        <NButton size="small" :disabled="!isDirty" @click="handleCancel">
          <template #icon><span class="i-carbon-close" /></template>
          取消
        </NButton>
      </NSpace>
      <span v-if="isDirty" class="dirty-tip">* 有未保存的修改</span>
    </div>

    <NSpin :show="loading" class="flex-1">
      <template v-if="components.length">
        <MetaComponent
          v-for="comp in components"
          :key="comp.componentKey"
          :config="comp"
          :page-context="pageContext"
        />
      </template>
      <NEmpty v-else-if="!loading" description="页面配置为空" />
    </NSpin>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, provide, computed } from 'vue';
import { NSpin, NEmpty, NButton, NSpace, useMessage, useDialog } from 'naive-ui';
import { fetchPageComponents, fetchTableMetadata, saveDynamicData } from '@/service/api';
import MetaComponent from './MetaComponent.vue';
import { useChangeTracker } from './useChangeTracker';
import { useCalcEngine, type CalcEngineConfig, type BroadcastConfig, type AggConfig } from './useCalcEngine';

const props = defineProps<{
  pageCode: string;
}>();

const message = useMessage();
const dialog = useDialog();

const loading = ref(false);
const components = ref<Api.Metadata.PageComponent[]>([]);

// 变更追踪
const changeTracker = useChangeTracker();
const isDirty = computed(() => changeTracker.isDirty.value);

// 计算引擎配置
const calcEngineConfig = ref<CalcEngineConfig>({ broadcasts: [], aggregates: [] });

// 计算引擎实例（延迟初始化）
let calcEngine: ReturnType<typeof useCalcEngine> | null = null;

const pageContext = reactive({
  pageCode: props.pageCode,
  metadata: {} as Record<string, Api.Metadata.TableMetadata>,
  data: {} as Record<string, any>,
  selectedRows: {} as Record<string, any[]>,
  refresh: {} as Record<string, () => void>,
  // 变更追踪相关
  changeTracker,
  // 当前选中的主表行
  currentMasterId: null as number | null,
  // 计算引擎（由 initCalcEngine 填充）
  calcEngine: null as ReturnType<typeof useCalcEngine> | null
});

provide('pageContext', pageContext);

/** 从组件树解析计算配置 */
function parseCalcConfig(comps: Api.Metadata.PageComponent[]): CalcEngineConfig {
  const broadcasts: BroadcastConfig[] = [];
  const aggregates: AggConfig[] = [];

  function traverse(items: Api.Metadata.PageComponent[]) {
    for (const item of items) {
      if (item.componentType === 'LOGIC_BROADCAST' || item.componentType === 'LOGIC_AGG') {
        try {
          const cfg = JSON.parse(item.componentConfig || '{}');
          
          if (item.componentType === 'LOGIC_BROADCAST') {
            broadcasts.push({
              source: cfg.source,
              target: cfg.target,
              fields: cfg.fields || []
            });
          } else if (item.componentType === 'LOGIC_AGG') {
            aggregates.push({
              source: cfg.source,
              target: cfg.target,
              sourceField: cfg.sourceField,
              targetField: cfg.targetField,
              algorithm: cfg.algorithm || 'SUM',
              filter: cfg.filter,
              postProcess: cfg.postProcess
            });
          }
        } catch (e) {
          console.warn('[DynamicPage] 解析计算配置失败:', item.componentKey, e);
        }
      }
      
      if (item.children?.length) {
        traverse(item.children);
      }
    }
  }

  traverse(comps);
  return { broadcasts, aggregates };
}

/** 初始化计算引擎 */
function initCalcEngine() {
  if (calcEngineConfig.value.broadcasts.length === 0 && calcEngineConfig.value.aggregates.length === 0) {
    console.log('[DynamicPage] 无计算配置，跳过引擎初始化');
    return;
  }

  calcEngine = useCalcEngine(calcEngineConfig.value);
  pageContext.calcEngine = calcEngine;
  
  console.log('[DynamicPage] 计算引擎初始化完成', calcEngineConfig.value);
}

async function loadPage() {
  loading.value = true;
  try {
    const { data, error } = await fetchPageComponents(props.pageCode);
    if (!error && data) {
      components.value = data;
      await preloadMetadata(data);
      
      // 解析计算配置并初始化引擎
      calcEngineConfig.value = parseCalcConfig(data);
      initCalcEngine();
    }
  } finally {
    loading.value = false;
  }
}

async function preloadMetadata(list: Api.Metadata.PageComponent[]) {
  const tableCodes = new Set<string>();
  function collect(items: Api.Metadata.PageComponent[]) {
    items.forEach(item => {
      if (item.refTableCode) tableCodes.add(item.refTableCode);
      if (item.children?.length) collect(item.children);
    });
  }
  collect(list);

  await Promise.all(
    Array.from(tableCodes).map(async code => {
      const { data } = await fetchTableMetadata(code);
      if (data) pageContext.metadata[code] = data;
    })
  );
}

// 保存
async function handleSave() {
  const param = changeTracker.getSaveParam();
  if (!param.master) {
    message.warning('没有需要保存的数据');
    return;
  }

  loading.value = true;
  try {
    const { error } = await saveDynamicData(param);
    if (!error) {
      message.success('保存成功');
      changeTracker.reset();
      // 刷新数据
      Object.values(pageContext.refresh).forEach(fn => fn?.());
    }
  } finally {
    loading.value = false;
  }
}

// 取消
function handleCancel() {
  if (!isDirty.value) return;
  
  dialog.warning({
    title: '确认取消',
    content: '有未保存的修改，确定要放弃吗？',
    positiveText: '确定',
    negativeText: '取消',
    onPositiveClick: () => {
      changeTracker.reset();
      // 刷新数据
      Object.values(pageContext.refresh).forEach(fn => fn?.());
    }
  });
}

onMounted(loadPage);
</script>

<style scoped>
.dynamic-page {
  height: 100%;
  padding: 8px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.dynamic-page-toolbar {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 4px 0;
  border-bottom: 1px solid #e8e8e8;
}
.dirty-tip {
  color: #f5222d;
  font-size: 12px;
}
</style>
