import { NativeEventEmitter, NativeModules, Platform } from 'react-native';
import NativeModule from './NativeMdNativeQQ';
import Notification from './notification';
import { promisifyNativeFunction } from './utils';
import type {
  MdNativeQQResponse,
  QQLoginResult,
  QQPublishImageTextRequest,
  QQRegisterOptions,
  QQShareImageRequest,
  QQShareLinkRequest,
  QQShareMiniProgramRequest,
  QQShareMusicRequest,
  QQShareTextRequest,
  QQShareVideoRequest,
  QQUniversalLinkCheckResponse,
} from './types';

export * from './types';

const notification = new Notification();
let registered = false;
let eventSubscription: { remove(): void } | null = null;

const assertRegistered = (name: string) => {
  if (!registered) {
    throw new Error(`[md-native-qq] 请先调用 registerApp 再使用 ${name}`);
  }
};

/**
 * 初始化 QQ Open SDK。**必须在任何其它 API 之前调用。**
 *
 * 注意：根据《工信部信管函〔2021〕169 号》要求，调用方必须在弹出隐私协议并取得用户同意后，
 * 把 `agreePrivacy: true` 传入；否则原生 SDK 不会发起任何联网请求。
 *
 * @returns 移除原生事件监听的 disposer。一般 App 整个生命周期保留即可。
 */
export const registerApp = (options: QQRegisterOptions): (() => void) => {
  if (!registered) {
    NativeModule.registerApp({
      appId: options.appId,
      universalLink: options.universalLink,
      agreePrivacy: options.agreePrivacy ?? false,
      log: options.log ?? false,
      logPrefix: options.logPrefix ?? '[QQ] ',
    });
    registered = true;
  }

  // 防止重复注册多个监听
  eventSubscription?.remove();
  const emitter = new NativeEventEmitter(NativeModules.MdNativeQQ);
  eventSubscription = emitter.addListener(
    'MdNativeQQ_Response',
    (response: MdNativeQQResponse) => {
      const err = response.errorCode
        ? new Error(`[md-native-qq] (${response.errorCode}) ${response.errorStr ?? ''}`)
        : null;
      notification.dispatch(response.type, err, response);
    },
  );

  return () => {
    eventSubscription?.remove();
    eventSubscription = null;
  };
};

/** iOS 专用：检查 Universal Link 是否在 QQ 互联后台配置正确。Android 直接 resolve(空)。 */
export const checkUniversalLinkReady = (): Promise<QQUniversalLinkCheckResponse> => {
  if (Platform.OS !== 'ios') {
    return Promise.resolve({ suggestion: '', errorInfo: '' });
  }
  return promisifyNativeFunction<QQUniversalLinkCheckResponse>(
    NativeModule.checkUniversalLinkReady,
  )();
};

export const isQQInstalled = (): Promise<boolean> =>
  promisifyNativeFunction<boolean>(NativeModule.isQQInstalled)();

export const getApiVersion = (): Promise<string> =>
  promisifyNativeFunction<string>(NativeModule.getApiVersion)();

/** 拉起 QQ 登录授权，resolve 出 token。 */
export const login = (scopes?: string): Promise<QQLoginResult> => {
  assertRegistered('login');
  return new Promise<QQLoginResult>((resolve, reject) => {
    promisifyNativeFunction<void>(NativeModule.login)({ scopes }).catch(reject);

    notification.once('AuthResp', (error, response) => {
      if (error) return reject(error);
      resolve(response.data as unknown as QQLoginResult);
    });
  });
};

export const logout = (): void => {
  if (!registered) return;
  NativeModule.logout();
};

const sendShareReq = <T>(method: keyof typeof NativeModule, req: T): Promise<void> => {
  const fn = NativeModule[method] as (
    r: unknown,
    cb: (error: boolean, payload?: unknown) => void,
  ) => void;
  return new Promise<void>((resolve, reject) => {
    promisifyNativeFunction(fn)(req).catch(reject);

    notification.once('ShareResp', (error, _response) => {
      if (error) return reject(error);
      resolve();
    });
  });
};

export const shareText = (request: QQShareTextRequest): Promise<void> => {
  assertRegistered('shareText');
  return sendShareReq('shareText', request);
};

export const shareImage = (request: QQShareImageRequest): Promise<void> => {
  assertRegistered('shareImage');
  return sendShareReq('shareImage', request);
};

export const shareLink = (request: QQShareLinkRequest): Promise<void> => {
  assertRegistered('shareLink');
  return sendShareReq('shareLink', request);
};

export const shareMusic = (request: QQShareMusicRequest): Promise<void> => {
  assertRegistered('shareMusic');
  return sendShareReq('shareMusic', request);
};

export const shareMiniProgram = (request: QQShareMiniProgramRequest): Promise<void> => {
  assertRegistered('shareMiniProgram');
  return sendShareReq('shareMiniProgram', request);
};

export const shareVideo = (request: QQShareVideoRequest): Promise<void> => {
  assertRegistered('shareVideo');
  return sendShareReq('shareVideo', request);
};

export const publishToQzone = (request: QQPublishImageTextRequest): Promise<void> => {
  assertRegistered('publishToQzone');
  return new Promise<void>((resolve, reject) => {
    promisifyNativeFunction(NativeModule.publishToQzone)(request).catch(reject);

    notification.once('PublishResp', (error, _response) => {
      if (error) return reject(error);
      resolve();
    });
  });
};

/** 默认导出对象，方便 `import QQ from 'md-native-qq'; QQ.login(...)` 的风格。 */
const QQ = {
  registerApp,
  checkUniversalLinkReady,
  isQQInstalled,
  getApiVersion,
  login,
  logout,
  shareText,
  shareImage,
  shareLink,
  shareMusic,
  shareMiniProgram,
  shareVideo,
  publishToQzone,
};

export default QQ;
