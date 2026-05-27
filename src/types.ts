export type QQScene = 'qq' | 'qzone' | 'favorites';

export interface QQRegisterOptions {
  appId: string;
  /** iOS Universal Link，必须在 QQ 互联后台配置；Android 忽略。 */
  universalLink?: string;
  /**
   * 是否同意《QQ 互联用户隐私协议》。
   * 应当在宿主 App 弹出并确认隐私授权弹窗后传入 true，否则 SDK 会拒绝联网。
   */
  agreePrivacy?: boolean;
  /** 调试日志开关。 */
  log?: boolean;
  logPrefix?: string;
}

export interface QQLoginRequest {
  /** 逗号分隔的 scope，例如 'get_user_info,get_simple_userinfo'。 */
  scopes?: string;
}

export interface QQLoginResult {
  openId: string;
  accessToken: string;
  /** 单位：秒。 */
  expiresIn: number;
  /** 失效时刻的 Unix 时间戳（秒）。 */
  expirationDate: number;
  /** QQ 互联 PC 端授权码模式时下发；移动端通常为空。 */
  authCode?: string;
}

export interface QQShareTextRequest {
  scene: QQScene;
  text: string;
  title?: string;
}

export interface QQShareImageRequest {
  scene: QQScene;
  /** 本地路径 / file:// 或 http(s) 链接。 */
  imageUrl: string;
  title?: string;
  description?: string;
}

export interface QQShareLinkRequest {
  scene: QQScene;
  title: string;
  description?: string;
  webpageUrl: string;
  thumbImageUrl?: string;
}

export interface QQShareMusicRequest {
  scene: QQScene;
  title: string;
  description?: string;
  /** 点击落地页。 */
  webpageUrl: string;
  /** 音频流地址。 */
  musicUrl: string;
  thumbImageUrl?: string;
}

export interface QQShareMiniProgramRequest {
  scene: QQScene;
  title: string;
  description?: string;
  webpageUrl: string;
  thumbImageUrl?: string;
  miniAppId: string;
  miniPath: string;
  /** 0=正式 3=体验 4=开发。默认 3。 */
  miniProgramType?: number;
}

export interface QQShareVideoRequest {
  /** 仅支持 'qzone'，其它会被忽略。 */
  scene: QQScene;
  /** 本地路径或 file://。 */
  videoUrl: string;
  title?: string;
  description?: string;
  thumbImageUrl?: string;
}

export interface QQPublishImageTextRequest {
  text: string;
  /** 本地路径或 http(s)。 */
  imageUrls: string[];
}

export interface QQUniversalLinkCheckResponse {
  suggestion: string;
  errorInfo: string;
}

/** 原生回调统一形态。 */
export interface MdNativeQQResponse<T = Record<string, unknown>> {
  /** 'AuthResp' | 'ShareResp' | 'PublishResp' | 'LoginResp' ... */
  type: string;
  errorCode: number;
  errorStr: string | null;
  data: T;
}
