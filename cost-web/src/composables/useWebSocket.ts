import { onUnmounted, ref } from 'vue';
import { getToken } from '@/store/modules/auth/shared';

export type WsMessage = {
  type: string;
  payload: Record<string, any>;
};

type Listener = (payload: Record<string, any>) => void;

let ws: WebSocket | null = null;
let reconnectTimer: ReturnType<typeof setTimeout> | null = null;
let heartbeatTimer: ReturnType<typeof setInterval> | null = null;
const listeners = new Map<string, Set<Listener>>();
const connected = ref(false);
let refCount = 0;

const HEARTBEAT_INTERVAL = 30_000;
const RECONNECT_DELAY = 3_000;

function getWsUrl() {
  const token = getToken();
  if (!token) return null;
  const base = import.meta.env.VITE_SERVICE_BASE_URL || `${window.location.protocol}//${window.location.host}`;
  const wsBase = base.replace(/^http/, 'ws');
  return `${wsBase}/ws?token=${token}`;
}

function startHeartbeat() {
  stopHeartbeat();
  heartbeatTimer = setInterval(() => {
    if (ws?.readyState === WebSocket.OPEN) {
      ws.send('ping');
    }
  }, HEARTBEAT_INTERVAL);
}

function stopHeartbeat() {
  if (heartbeatTimer) {
    clearInterval(heartbeatTimer);
    heartbeatTimer = null;
  }
}

function connect() {
  if (ws?.readyState === WebSocket.OPEN || ws?.readyState === WebSocket.CONNECTING) return;

  const url = getWsUrl();
  if (!url) return;

  ws = new WebSocket(url);

  ws.onopen = () => {
    connected.value = true;
    startHeartbeat();
    console.log('[WS] 已连接');
  };

  ws.onmessage = event => {
    const data = event.data;
    if (data === 'pong') return;
    try {
      const msg: WsMessage = JSON.parse(data);
      const typeListeners = listeners.get(msg.type);
      if (typeListeners) {
        typeListeners.forEach(fn => fn(msg.payload));
      }
    } catch {
      // ignore non-JSON messages
    }
  };

  ws.onclose = () => {
    connected.value = false;
    stopHeartbeat();
    if (refCount > 0) {
      reconnectTimer = setTimeout(connect, RECONNECT_DELAY);
    }
  };

  ws.onerror = () => {
    ws?.close();
  };
}

function disconnect() {
  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }
  stopHeartbeat();
  ws?.close();
  ws = null;
  connected.value = false;
}

/**
 * 订阅 WebSocket 消息。组件 unmount 时自动取消订阅。
 * 首次调用时自动建立连接，最后一个订阅者取消时自动断开。
 */
export function useWebSocket() {
  refCount++;
  if (refCount === 1) connect();

  // 记录当前组件注册的所有 listener，unmount 时统一清理
  const localSubs: Array<() => void> = [];

  function subscribe(type: string, callback: Listener) {
    if (!listeners.has(type)) listeners.set(type, new Set());
    listeners.get(type)!.add(callback);

    const unsub = () => {
      listeners.get(type)?.delete(callback);
      if (listeners.get(type)?.size === 0) listeners.delete(type);
    };
    localSubs.push(unsub);
    return unsub;
  }

  onUnmounted(() => {
    // 清理当前组件的所有订阅
    localSubs.forEach(unsub => unsub());
    localSubs.length = 0;

    refCount--;
    if (refCount <= 0) {
      refCount = 0;
      disconnect();
    }
  });

  return { connected, subscribe };
}

/** 手动重连（如登录后调用） */
export function reconnectWebSocket() {
  disconnect();
  if (refCount > 0) connect();
}
