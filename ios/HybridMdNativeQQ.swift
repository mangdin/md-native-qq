import Foundation
import UIKit
import TencentOpenAPI
import NitroModules

private enum QQError: Error, CustomStringConvertible {
  case notRegistered
  case loginFailed(String)
  case shareFailed(String)
  case invalidImage(String)
  case unsupported(String)

  var description: String {
    switch self {
    case .notRegistered: return "QQ SDK 未初始化，请先调用 registerApp"
    case .loginFailed(let msg): return "QQ 登录失败：\(msg)"
    case .shareFailed(let msg): return "QQ 分享失败：\(msg)"
    case .invalidImage(let url): return "无法加载图片：\(url)"
    case .unsupported(let msg): return "不支持的操作：\(msg)"
    }
  }
}

private func loadImageData(from urlString: String) -> Data? {
  if urlString.hasPrefix("http://") || urlString.hasPrefix("https://"),
     let url = URL(string: urlString),
     let data = try? Data(contentsOf: url) {
    return data
  }
  let path = urlString.hasPrefix("file://")
    ? String(urlString.dropFirst(7))
    : urlString
  return FileManager.default.contents(atPath: path)
}

class HybridMdNativeQQ: HybridMdNativeQQSpec {
  private var oauth: TencentOAuth?
  private var loginDelegate: QQLoginDelegate?
  private var shareDelegate: QQShareDelegate?

  // MARK: - registerApp / utilities

  func registerApp(options: QQRegisterOptions) throws -> Bool {
    let delegate = QQLoginDelegate()
    self.loginDelegate = delegate
    // Old SDK init — universalLink is not supported; use appId + delegate only
    let oauth = TencentOAuth(appId: options.appId, andDelegate: delegate)
    self.oauth = oauth
    delegate.oauth = oauth

    let share = QQShareDelegate()
    self.shareDelegate = share

    return oauth != nil
  }

  func isQQInstalled() throws -> Bool {
    return QQApiInterface.isQQInstalled()
  }

  func getApiVersion() throws -> String {
    return TencentOAuth.sdkVersion() ?? "unknown"
  }

  // MARK: - Login

  func login(scopes: String?) throws -> Promise<QQLoginResult> {
    let promise = Promise<QQLoginResult>()
    guard let oauth = self.oauth, let delegate = self.loginDelegate else {
      promise.reject(withError: QQError.notRegistered)
      return promise
    }

    let scopeList: [String]
    if let scopes = scopes, !scopes.isEmpty {
      scopeList = scopes.split(separator: ",").map {
        String($0).trimmingCharacters(in: .whitespaces)
      }
    } else {
      scopeList = ["get_user_info", "get_simple_userinfo"]
    }

    delegate.resolve = { promise.resolve(withResult: $0) }
    delegate.reject = { promise.reject(withError: $0) }

    DispatchQueue.main.async {
      let ok = oauth.authorize(scopeList)
      if !ok {
        promise.reject(withError: QQError.loginFailed("authorize 调起失败，请确认 AppID"))
      }
    }
    return promise
  }

  func logout() throws {
    self.oauth?.logout(nil)
  }

  // MARK: - Share helpers

  private func send(_ obj: QQApiObject, scene: QQScene) -> Promise<Void> {
    let promise = Promise<Void>()
    if scene == .favorites {
      obj.cflag = obj.cflag | 0x08  // kQQAPICtrlFlagQQShareFavorites
    }
    guard let req = SendMessageToQQReq.req(withContent: obj) else {
      promise.reject(withError: QQError.shareFailed("创建请求失败"))
      return promise
    }
    let code: QQApiSendResultCode = (scene == .qzone)
      ? QQApiInterface.sendReqToQZone(req)
      : QQApiInterface.sendReq(req)
    if code == EQQAPISENDSUCESS {
      promise.resolve(withResult: ())
    } else {
      promise.reject(withError: QQError.shareFailed("code=\(code.rawValue)"))
    }
    return promise
  }

  // MARK: - Share APIs

  func shareText(options: QQShareTextOptions) throws -> Promise<Void> {
    let obj = QQApiTextObject(text: options.text)!
    return send(obj, scene: options.scene)
  }

  func shareImage(options: QQShareImageOptions) throws -> Promise<Void> {
    let promise = Promise<Void>()
    guard let data = loadImageData(from: options.imageUrl) else {
      promise.reject(withError: QQError.invalidImage(options.imageUrl))
      return promise
    }
    let obj = QQApiImageObject(data: data,
                               previewImageData: data,
                               title: options.title ?? "",
                               description: options.description ?? "")!
    return send(obj, scene: options.scene)
  }

  func shareLink(options: QQShareLinkOptions) throws -> Promise<Void> {
    let thumb = options.thumbImageUrl.flatMap { loadImageData(from: $0) }
    let obj = QQApiNewsObject(url: URL(string: options.webpageUrl),
                              title: options.title,
                              description: options.description ?? "",
                              previewImageData: thumb,
                              targetContentType: QQApiURLTargetTypeNews)!
    return send(obj, scene: options.scene)
  }

  func shareMusic(options: QQShareMusicOptions) throws -> Promise<Void> {
    let thumb = options.thumbImageUrl.flatMap { loadImageData(from: $0) }
    let obj = QQApiAudioObject(url: URL(string: options.webpageUrl),
                               title: options.title,
                               description: options.description ?? "",
                               previewImageData: thumb,
                               targetContentType: QQApiURLTargetTypeAudio)!
    obj.flashURL = URL(string: options.musicUrl)
    return send(obj, scene: options.scene)
  }

  func shareMiniProgram(options: QQShareMiniProgramOptions) throws -> Promise<Void> {
    let promise = Promise<Void>()
    promise.reject(withError: QQError.unsupported("当前 SDK 版本不支持分享小程序"))
    return promise
  }

  func shareVideo(options: QQShareVideoOptions) throws -> Promise<Void> {
    let obj = QQApiVideoForQZoneObject(assetURL: options.videoUrl,
                                       title: options.title ?? "",
                                       extMap: nil)!
    return send(obj, scene: options.scene)
  }

  func publishToQzone(options: QQPublishImageTextOptions) throws -> Promise<Void> {
    let promise = Promise<Void>()
    var images: [Data] = []
    for url in options.imageUrls {
      guard let data = loadImageData(from: url) else {
        promise.reject(withError: QQError.invalidImage(url))
        return promise
      }
      images.append(data)
    }
    let obj = QQApiImageArrayForQZoneObject(imageArrayData: images,
                                            title: options.text,
                                            extMap: nil)!
    guard let req = SendMessageToQQReq.req(withContent: obj) else {
      promise.reject(withError: QQError.shareFailed("创建请求失败"))
      return promise
    }
    let code = QQApiInterface.sendReqToQZone(req)
    if code == EQQAPISENDSUCESS {
      promise.resolve(withResult: ())
    } else {
      promise.reject(withError: QQError.shareFailed("code=\(code.rawValue)"))
    }
    return promise
  }
}

// MARK: - Delegates

private final class QQLoginDelegate: NSObject, TencentSessionDelegate {
  weak var oauth: TencentOAuth?
  var resolve: ((QQLoginResult) -> Void)?
  var reject: ((Error) -> Void)?

  func tencentDidLogin() {
    guard let oauth = oauth else {
      reject?(NSError(domain: "MdNativeQQ", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "oauth 为空"]))
      return clear()
    }
    let result = QQLoginResult(
      openId: oauth.openId ?? "",
      accessToken: oauth.accessToken ?? "",
      expiresIn: oauth.expirationDate?.timeIntervalSinceNow ?? 0,
      expirationDate: oauth.expirationDate?.timeIntervalSince1970 ?? 0,
      authCode: nil
    )
    resolve?(result)
    clear()
  }

  func tencentDidNotLogin(_ cancelled: Bool) {
    let msg = cancelled ? "用户取消登录" : "登录失败"
    let code = cancelled ? -2 : -3
    reject?(NSError(domain: "MdNativeQQ", code: code,
                    userInfo: [NSLocalizedDescriptionKey: msg]))
    clear()
  }

  func tencentDidNotNetWork() {
    reject?(NSError(domain: "MdNativeQQ", code: -4,
                    userInfo: [NSLocalizedDescriptionKey: "网络不可用"]))
    clear()
  }

  private func clear() {
    resolve = nil
    reject = nil
  }
}

private final class QQShareDelegate: NSObject, QQApiInterfaceDelegate {
  func onReq(_ req: QQBaseReq!) {}
  func onResp(_ resp: QQBaseResp!) {}
  func isOnlineResponse(_ response: [AnyHashable: Any]!) {}
}
