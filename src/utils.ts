/**
 * 把"调用即触发，结果通过 callback(err, data) 回流"的原生方法包成 Promise。
 * 沿用 native-wechat 的约定：
 *   - callback 第一个参数为 truthy 时视为失败
 *   - 失败时第二个参数若是 string 则作为 message
 */
export function promisifyNativeFunction<T = unknown>(
  fn: (...args: any[]) => void,
): (...args: any[]) => Promise<T> {
  return (...args: any[]) =>
    new Promise<T>((resolve, reject) => {
      fn(...args, (error: any, payload: T) => {
        if (error) {
          if (typeof error === 'string') return reject(new Error(error));
          if (typeof payload === 'string') return reject(new Error(payload));
          return reject(new Error(`[md-native-qq] 调用失败 code=${String(error)}`));
        }
        resolve(payload);
      });
    });
}
