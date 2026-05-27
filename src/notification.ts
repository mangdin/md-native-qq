import type { MdNativeQQResponse } from './types';

type Handler = (error: Error | null, response: MdNativeQQResponse) => void;

/**
 * 极简事件分发器：原生只会发一个统一的 'MdNativeQQ_Response'，
 * 这里按 response.type 路由到等待具体回执的订阅者。
 */
export default class Notification {
  private listeners = new Map<string, Handler[]>();

  on(type: string, handler: Handler): () => void {
    const list = this.listeners.get(type) ?? [];
    list.push(handler);
    this.listeners.set(type, list);
    return () => {
      const cur = this.listeners.get(type);
      if (!cur) return;
      this.listeners.set(
        type,
        cur.filter(h => h !== handler),
      );
    };
  }

  once(type: string, handler: Handler): () => void {
    const off = this.on(type, (err, resp) => {
      off();
      handler(err, resp);
    });
    return off;
  }

  dispatch(type: string, error: Error | null, response: MdNativeQQResponse): void {
    const list = this.listeners.get(type);
    if (!list || list.length === 0) return;
    // 拷贝一份，避免 handler 内 off() 影响遍历
    [...list].forEach(h => {
      try {
        h(error, response);
      } catch (e) {
        // 单个 handler 失败不影响其他
        if (__DEV__) console.warn('[md-native-qq] handler error', e);
      }
    });
  }
}
