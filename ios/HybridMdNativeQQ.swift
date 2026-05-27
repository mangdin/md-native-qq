import Foundation
import UIKit
import TencentOpenAPI
import NitroModules

private enum QQError: Error, CustomStringConvertible {
  case notRegistered
  case loginFailed(String)
  case shareFailed(String)
  case invalidImage(String)

  var description: String {
    switch self {
    case .notRegistered: return "QQ SDK 未初始化，请先调用 registerApp"
    case .loginFailed(let msg): return "QQ 登录失败：\(msg)"
    case .shareFailed(let msg): return "QQ 分享失败：\(msg)"
    case .invalidImage(let url): return "无法加载图片：\(url)"
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
    let universalLink = options.universalLink ?? ""
    let delegate = QQLoginDelegate()
    self.loginDelegate = delegate
    let oauth = TencentOAuth(appId: options.appId,
                             andUniversalLink: universalLink,
                             andDelegate: delegate)
    self.oauth = oauth
    delegate.oauth = oauth

    let share = QQShareDelegate()
    self.shareDelegate = share
    QQApiInterface.registerApp(options.appId, withUniversalLink: universalLink)

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
        promise.reject(withError: QQError.loginFailed("authorize 调起失败，请确认 AppID / UniversalLink"))
      }
    }
    return promise
  }

  func logout() throws {
    self.oauth?.logout(nil)
  }

  // MARK: - Share helpers

  private func send(_ req: SendMessageToQQReq, scene: QQScene) -> Promise<Void> {
    let promise = Promise<Void>()
    let code: QQApiSendResultCode = (scene == .qzone)
      ? QQApiInterface.sendReq(toQZone: req)
      : QQApiInterface.send(req)
    if code == EQQAPISENDSUCESS {
      promise.resolve(withResult: ())
    } else {
      promise.reject(withError: QQError.shareFailed("code=\(code.rawValue)"))
    }
    return promise
  }

  // MARK: - Share APIs

  func shareText(options: QQShareTextOptions) throws -> Promise<Void> {
    let obj = QQApiTextObject(text: options.text)
    return send(SendMessageToQQReq(content: obj), scene: options.scene)
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
                               description: options.description ?? "")
    return send(SendMessageToQQReq(content: obj), scene: options.scene)
  }

  func shareLink(options: QQShareLinkOptions) throws -> Promise<Void> {
    let thumb = options.thumbImageUrl.flatMap { loadImageData(from: $0) }
    let obj = QQApiNewsObject(url: URL(string: options.webpageUrl),
                              title: options.title,
                              description: options.description ?? "",
                              previewImageData: thumb,
                              targetContentType: QQApiURLTargetTypeNews)
    return send(SendMessageToQQReq(content: obj), scene: options.scene)
  }

  func shareMusic(options: QQShareMusicOptions) throws -> Promise<Void> {
    let thumb = options.thumbImageUrl.flatMap { loadImageData(from: $0) }
    let obj = QQApiAudioObject(url: URL(string: options.webpageUrl),
                               title: options.title,
                               description: options.description ?? "",
                               previewImageData: thumb,
                               targetContentType: QQApiURLTargetTypeAudio)
    obj.flashURL = URL(string: options.musicUrl)
    return send(SendMessageToQQReq(content: obj), scene: options.scene)
  }

  func shareMiniProgram(options: QQShareMiniProgramOptions) throws -> Promise<Void> {
    let thumb = options.thumbImageUrl.flatMap { loadImageData(from: $0) }
    let mini = QQApiMiniProgramObject()
    mini.miniAppID = options.miniAppId
    mini.miniPath = options.miniPath
    mini.webpageUrl = options.webpageUrl
    mini.miniProgramType = MiniProgramType(
      rawValue: UInt(options.miniProgramType ?? 3)
    ) ?? .online
    mini.qqApiObject = QQApiNewsObject(url: URL(string: options.webpageUrl),
                                       title: options.title,
                                       description: options.description ?? "",
                                       previewImageData: thumb,
                                       targetContentType: QQApiURLTargetTypeNews)
    return send(SendMessageToQQReq(miniContent: mini), scene: options.scene)
  }

  func shareVideo(options: QQShareVideoOptions) throws -> Promise<Void> {
    let obj = QQApiVideoForQZoneObject(assetURL: options.videoUrl,
                                       title: options.title,
                                       extMap: nil)
    obj.previewImageData = options.thumbImageUrl.flatMap { loadImageData(from: $0) }
    return send(SendMessageToQQReq(content: obj), scene: options.scene)
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
    let obj = QQApiImageArrayForQZonePublishObject(imageDataArray: images,
                                                   title: options.text,
                                                   extMap: nil)
    let code = QQApiInterface.sendReq(toQZone: SendMessageToQQReq(content: obj))
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
      authCode: oauth.authCode
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
