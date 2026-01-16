import { useBaseRuntime } from '@/composables/meta-v2/runtime';

type NotifyFn = (message: string) => void;

export function useMetaRuntime(params: {
  pageCode: string;
  notifyInfo: NotifyFn;
  notifyError: NotifyFn;
  notifySuccess: NotifyFn;
}) {
  return useBaseRuntime(params);
}
