package com.margelo.nitro.mdnativeqq

import android.app.Activity
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Bundle
import android.util.Base64
import com.margelo.nitro.NitroModules
import com.margelo.nitro.core.Promise
import com.tencent.connect.share.QQShare
import com.tencent.connect.share.QzonePublish
import com.tencent.connect.share.QzoneShare
import com.tencent.tauth.IUiListener
import com.tencent.tauth.Tencent
import com.tencent.tauth.UiError
import java.io.File
import java.io.FileOutputStream
import java.net.URL
import java.util.concurrent.atomic.AtomicReference

class HybridMdNativeQQ : HybridMdNativeQQSpec() {

  private var tencent: Tencent? = null
  private var appId: String? = null

  private val context get() = NitroModules.applicationContext
    ?: throw IllegalStateException("Application context 不可用")

  // MARK: - registerApp / utilities

  override fun registerApp(options: QQRegisterOptions): Boolean {
    this.appId = options.appId
    Tencent.setIsPermissionGranted(true)
    this.tencent = Tencent.createInstance(options.appId, context.applicationContext, "${context.packageName}.fileprovider")
    instance.set(this)
    return tencent != null
  }

  override fun isQQInstalled(): Boolean {
    val t = tencent ?: return false
    return t.isQQInstalled(context)
  }

  override fun getApiVersion(): String {
    return Tencent.getSdkVersion() ?: "unknown"
  }

  // MARK: - Login

  override fun login(scopes: String?): Promise<QQLoginResult> {
    val promise = Promise<QQLoginResult>()
    val t = tencent ?: run {
      promise.reject(IllegalStateException("QQ SDK 未初始化，请先 registerApp"))
      return promise
    }
    val activity = currentActivity ?: run {
      promise.reject(IllegalStateException("currentActivity 为空，请在 MainActivity 中通过 MdNativeQQActivityBridge.setCurrentActivity 注入"))
      return promise
    }
    val scope = scopes?.takeIf { it.isNotBlank() } ?: "get_user_info,get_simple_userinfo"

    loginListener.set(IUiListenerAdapter(
      onComplete = { obj ->
        try {
          val json = obj as org.json.JSONObject
          promise.resolve(QQLoginResult(
            openId = json.optString("openid"),
            accessToken = json.optString("access_token"),
            expiresIn = json.optDouble("expires_in", 0.0),
            expirationDate = (System.currentTimeMillis() / 1000.0) + json.optDouble("expires_in", 0.0),
            authCode = null
          ))
        } catch (e: Exception) {
          promise.reject(e)
        }
      },
      onError = { e -> promise.reject(RuntimeException("login error: ${e.errorMessage}")) },
      onCancel = { promise.reject(RuntimeException("用户取消登录")) }
    ))
    activity.runOnUiThread {
      t.login(activity, scope, loginListener.get())
    }
    return promise
  }

  override fun logout() {
    tencent?.logout(context)
  }

  // MARK: - Share helpers

  private fun shareViaQQOnUi(params: Bundle): Promise<Unit> {
    val promise = Promise<Unit>()
    val t = tencent ?: run {
      promise.reject(IllegalStateException("QQ SDK 未初始化"))
      return promise
    }
    val activity = currentActivity ?: run {
      promise.reject(IllegalStateException("currentActivity 为空"))
      return promise
    }
    shareListener.set(IUiListenerAdapter(
      onComplete = { promise.resolve(Unit) },
      onError = { e -> promise.reject(RuntimeException("share error: ${e.errorMessage}")) },
      onCancel = { promise.reject(RuntimeException("用户取消分享")) }
    ))
    activity.runOnUiThread { t.shareToQQ(activity, params, shareListener.get()) }
    return promise
  }

  private fun shareViaQzoneOnUi(params: Bundle): Promise<Unit> {
    val promise = Promise<Unit>()
    val t = tencent ?: run {
      promise.reject(IllegalStateException("QQ SDK 未初始化"))
      return promise
    }
    val activity = currentActivity ?: run {
      promise.reject(IllegalStateException("currentActivity 为空"))
      return promise
    }
    shareListener.set(IUiListenerAdapter(
      onComplete = { promise.resolve(Unit) },
      onError = { e -> promise.reject(RuntimeException("share error: ${e.errorMessage}")) },
      onCancel = { promise.reject(RuntimeException("用户取消分享")) }
    ))
    activity.runOnUiThread { t.shareToQzone(activity, params, shareListener.get()) }
    return promise
  }

  // MARK: - Share APIs

  override fun shareText(options: QQShareTextOptions): Promise<Unit> {
    val params = Bundle().apply {
      putInt(QQShare.SHARE_TO_QQ_KEY_TYPE, QQShare.SHARE_TO_QQ_TYPE_TEXT)
      putString(QQShare.SHARE_TO_QQ_SUMMARY, options.text)
      options.title?.let { putString(QQShare.SHARE_TO_QQ_TITLE, it) }
    }
    return if (options.scene == QQScene.QZONE) shareViaQzoneOnUi(params) else shareViaQQOnUi(params)
  }

  override fun shareImage(options: QQShareImageOptions): Promise<Unit> {
    val localPath = resolveLocalPath(options.imageUrl)
    val params = Bundle().apply {
      putInt(QQShare.SHARE_TO_QQ_KEY_TYPE, QQShare.SHARE_TO_QQ_TYPE_IMAGE)
      putString(QQShare.SHARE_TO_QQ_IMAGE_LOCAL_URL, localPath)
      options.title?.let { putString(QQShare.SHARE_TO_QQ_TITLE, it) }
      options.description?.let { putString(QQShare.SHARE_TO_QQ_SUMMARY, it) }
    }
    return if (options.scene == QQScene.QZONE) shareViaQzoneOnUi(params) else shareViaQQOnUi(params)
  }

  override fun shareLink(options: QQShareLinkOptions): Promise<Unit> {
    val params = Bundle().apply {
      putInt(QQShare.SHARE_TO_QQ_KEY_TYPE, QQShare.SHARE_TO_QQ_TYPE_DEFAULT)
      putString(QQShare.SHARE_TO_QQ_TITLE, options.title)
      options.description?.let { putString(QQShare.SHARE_TO_QQ_SUMMARY, it) }
      putString(QQShare.SHARE_TO_QQ_TARGET_URL, options.webpageUrl)
      options.thumbImageUrl?.let { putString(QQShare.SHARE_TO_QQ_IMAGE_URL, it) }
    }
    return if (options.scene == QQScene.QZONE) {
      val qzone = Bundle().apply {
        putInt(QzoneShare.SHARE_TO_QZONE_KEY_TYPE, QzoneShare.SHARE_TO_QZONE_TYPE_IMAGE_TEXT)
        putString(QzoneShare.SHARE_TO_QQ_TITLE, options.title)
        options.description?.let { putString(QzoneShare.SHARE_TO_QQ_SUMMARY, it) }
        putString(QzoneShare.SHARE_TO_QQ_TARGET_URL, options.webpageUrl)
        options.thumbImageUrl?.let { putStringArrayList(QzoneShare.SHARE_TO_QQ_IMAGE_URL, arrayListOf(it)) }
      }
      shareViaQzoneOnUi(qzone)
    } else {
      shareViaQQOnUi(params)
    }
  }

  override fun shareMusic(options: QQShareMusicOptions): Promise<Unit> {
    val params = Bundle().apply {
      putInt(QQShare.SHARE_TO_QQ_KEY_TYPE, QQShare.SHARE_TO_QQ_TYPE_AUDIO)
      putString(QQShare.SHARE_TO_QQ_TITLE, options.title)
      options.description?.let { putString(QQShare.SHARE_TO_QQ_SUMMARY, it) }
      putString(QQShare.SHARE_TO_QQ_TARGET_URL, options.webpageUrl)
      putString(QQShare.SHARE_TO_QQ_AUDIO_URL, options.musicUrl)
      options.thumbImageUrl?.let { putString(QQShare.SHARE_TO_QQ_IMAGE_URL, it) }
    }
    return if (options.scene == QQScene.QZONE) shareViaQzoneOnUi(params) else shareViaQQOnUi(params)
  }

  override fun shareMiniProgram(options: QQShareMiniProgramOptions): Promise<Unit> {
    val params = Bundle().apply {
      putInt(QQShare.SHARE_TO_QQ_KEY_TYPE, QQShare.SHARE_TO_QQ_TYPE_MINI_PROGRAM)
      putString(QQShare.SHARE_TO_QQ_TITLE, options.title)
      options.description?.let { putString(QQShare.SHARE_TO_QQ_SUMMARY, it) }
      putString(QQShare.SHARE_TO_QQ_TARGET_URL, options.webpageUrl)
      options.thumbImageUrl?.let { putString(QQShare.SHARE_TO_QQ_IMAGE_URL, it) }
      putString(QQShare.SHARE_TO_QQ_MINI_PROGRAM_APPID, options.miniAppId)
      putString(QQShare.SHARE_TO_QQ_MINI_PROGRAM_PATH, options.miniPath)
      putString(QQShare.SHARE_TO_QQ_MINI_PROGRAM_TYPE, (options.miniProgramType ?: 3.0).toInt().toString())
    }
    return shareViaQQOnUi(params)
  }

  override fun shareVideo(options: QQShareVideoOptions): Promise<Unit> {
    val params = Bundle().apply {
      putInt(QzonePublish.PUBLISH_TO_QZONE_KEY_TYPE, QzonePublish.PUBLISH_TO_QZONE_TYPE_PUBLISHVIDEO)
      putString(QzonePublish.PUBLISH_TO_QZONE_VIDEO_PATH, resolveLocalPath(options.videoUrl))
      options.title?.let { putString(QzonePublish.PUBLISH_TO_QZONE_SUMMARY, it) }
    }
    val promise = Promise<Unit>()
    val t = tencent ?: run {
      promise.reject(IllegalStateException("QQ SDK 未初始化"))
      return promise
    }
    val activity = currentActivity ?: run {
      promise.reject(IllegalStateException("currentActivity 为空"))
      return promise
    }
    shareListener.set(IUiListenerAdapter(
      onComplete = { promise.resolve(Unit) },
      onError = { e -> promise.reject(RuntimeException("share error: ${e.errorMessage}")) },
      onCancel = { promise.reject(RuntimeException("用户取消分享")) }
    ))
    activity.runOnUiThread { t.publishToQzone(activity, params, shareListener.get()) }
    return promise
  }

  override fun publishToQzone(options: QQPublishImageTextOptions): Promise<Unit> {
    val params = Bundle().apply {
      putInt(QzonePublish.PUBLISH_TO_QZONE_KEY_TYPE, QzonePublish.PUBLISH_TO_QZONE_TYPE_PUBLISHMOOD)
      putString(QzonePublish.PUBLISH_TO_QZONE_SUMMARY, options.text)
      val paths = ArrayList(options.imageUrls.map { resolveLocalPath(it) })
      putStringArrayList(QzonePublish.PUBLISH_TO_QZONE_IMAGE_URL, paths)
    }
    val promise = Promise<Unit>()
    val t = tencent ?: run {
      promise.reject(IllegalStateException("QQ SDK 未初始化"))
      return promise
    }
    val activity = currentActivity ?: run {
      promise.reject(IllegalStateException("currentActivity 为空"))
      return promise
    }
    shareListener.set(IUiListenerAdapter(
      onComplete = { promise.resolve(Unit) },
      onError = { e -> promise.reject(RuntimeException("publish error: ${e.errorMessage}")) },
      onCancel = { promise.reject(RuntimeException("用户取消")) }
    ))
    activity.runOnUiThread { t.publishToQzone(activity, params, shareListener.get()) }
    return promise
  }

  // MARK: - 工具方法

  /** http(s) 链接会被下载到 cacheDir 后返回本地路径；file:// 与裸路径直接返回。 */
  private fun resolveLocalPath(url: String): String {
    if (!url.startsWith("http://") && !url.startsWith("https://")) {
      return if (url.startsWith("file://")) url.removePrefix("file://") else url
    }
    val name = "qqshare_${url.hashCode()}_${System.currentTimeMillis()}"
    val outFile = File(context.cacheDir, name)
    URL(url).openStream().use { input ->
      FileOutputStream(outFile).use { output -> input.copyTo(output) }
    }
    return outFile.absolutePath
  }

  // MARK: - 静态：处理 Activity 回跳

  companion object {
    var currentActivity: Activity? = null
    private val instance = AtomicReference<HybridMdNativeQQ?>()
    private val loginListener = AtomicReference<IUiListener?>()
    private val shareListener = AtomicReference<IUiListener?>()
    val uiListenerForShare: IUiListener? get() = shareListener.get()

    @JvmStatic
    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
      val listener = when (requestCode) {
        com.tencent.connect.common.Constants.REQUEST_LOGIN,
        com.tencent.connect.common.Constants.REQUEST_OLD_LOGIN -> loginListener.get()
        com.tencent.connect.common.Constants.REQUEST_QQ_SHARE,
        com.tencent.connect.common.Constants.REQUEST_QZONE_SHARE -> shareListener.get()
        else -> null
      } ?: return
      Tencent.onActivityResultData(requestCode, resultCode, data, listener)
    }
  }
}

private class IUiListenerAdapter(
  val onComplete: (Any?) -> Unit,
  val onError: (UiError) -> Unit,
  val onCancel: () -> Unit
) : IUiListener {
  override fun onComplete(any: Any?) { onComplete.invoke(any) }
  override fun onError(error: UiError) { onError.invoke(error) }
  override fun onCancel() { onCancel.invoke() }
  override fun onWarning(code: Int) {}
}
