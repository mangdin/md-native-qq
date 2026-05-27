import { NativeModules } from 'react-native';

const LINKING_ERROR =
  `[md-native-qq] 找不到原生模块 'MdNativeQQ'。\n` +
  ` - iOS: 请确认已执行 'cd ios && pod install'，并且把最新版 TencentOpenAPI.xcframework 放入 node_modules/md-native-qq/ios/。\n` +
  ` - Android: 请确认已把 open_sdk_x.jar 放入 node_modules/md-native-qq/android/libs/，并重新编译。\n` +
  ` - 不支持 Expo Go，必须使用 prebuild / bare workflow。`;

const NativeModule = NativeModules.MdNativeQQ
  ? NativeModules.MdNativeQQ
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      },
    );

export default NativeModule as {
  registerApp(options: {
    appId: string;
    universalLink?: string;
    agreePrivacy?: boolean;
    log?: boolean;
    logPrefix?: string;
  }): void;

  checkUniversalLinkReady(
    callback: (error: boolean, payload: { suggestion: string; errorInfo: string }) => void,
  ): void;

  isQQInstalled(callback: (error: null, installed: boolean) => void): void;
  getApiVersion(callback: (error: null, version: string) => void): void;

  login(
    request: { scopes?: string },
    callback: (error: boolean, payload?: unknown) => void,
  ): void;
  logout(): void;

  shareText(req: unknown, callback: (error: boolean, payload?: unknown) => void): void;
  shareImage(req: unknown, callback: (error: boolean, payload?: unknown) => void): void;
  shareLink(req: unknown, callback: (error: boolean, payload?: unknown) => void): void;
  shareMusic(req: unknown, callback: (error: boolean, payload?: unknown) => void): void;
  shareMiniProgram(req: unknown, callback: (error: boolean, payload?: unknown) => void): void;
  shareVideo(req: unknown, callback: (error: boolean, payload?: unknown) => void): void;
  publishToQzone(req: unknown, callback: (error: boolean, payload?: unknown) => void): void;

  addListener(eventName: string): void;
  removeListeners(count: number): void;
};
