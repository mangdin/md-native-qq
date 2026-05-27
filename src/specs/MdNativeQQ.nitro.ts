import type { HybridObject } from 'react-native-nitro-modules';

export type QQScene = 'qq' | 'qzone' | 'favorites';

export interface QQRegisterOptions {
  appId: string;
  universalLink?: string;
}

export interface QQLoginResult {
  openId: string;
  accessToken: string;
  expiresIn: number;
  expirationDate: number;
  authCode?: string;
}

export interface QQShareTextOptions {
  scene: QQScene;
  text: string;
  title?: string;
}

export interface QQShareImageOptions {
  scene: QQScene;
  imageUrl: string;
  title?: string;
  description?: string;
}

export interface QQShareLinkOptions {
  scene: QQScene;
  title: string;
  description?: string;
  webpageUrl: string;
  thumbImageUrl?: string;
}

export interface QQShareMusicOptions {
  scene: QQScene;
  title: string;
  description?: string;
  webpageUrl: string;
  musicUrl: string;
  thumbImageUrl?: string;
}

export interface QQShareMiniProgramOptions {
  scene: QQScene;
  title: string;
  description?: string;
  webpageUrl: string;
  thumbImageUrl?: string;
  miniAppId: string;
  miniPath: string;
  miniProgramType?: number;
}

export interface QQShareVideoOptions {
  scene: QQScene;
  videoUrl: string;
  title?: string;
  description?: string;
  thumbImageUrl?: string;
}

export interface QQPublishImageTextOptions {
  text: string;
  imageUrls: string[];
}

export interface MdNativeQQ
  extends HybridObject<{ ios: 'swift'; android: 'kotlin' }> {
  registerApp(options: QQRegisterOptions): boolean;
  isQQInstalled(): boolean;
  getApiVersion(): string;

  login(scopes?: string): Promise<QQLoginResult>;
  logout(): void;

  shareText(options: QQShareTextOptions): Promise<void>;
  shareImage(options: QQShareImageOptions): Promise<void>;
  shareLink(options: QQShareLinkOptions): Promise<void>;
  shareMusic(options: QQShareMusicOptions): Promise<void>;
  shareMiniProgram(options: QQShareMiniProgramOptions): Promise<void>;
  shareVideo(options: QQShareVideoOptions): Promise<void>;

  publishToQzone(options: QQPublishImageTextOptions): Promise<void>;
}
