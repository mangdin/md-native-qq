package com.mangdin.mdnativeqq

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Callback
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.tencent.connect.common.Constants
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

class MdNativeQQModule(private val reactCtx: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactCtx) {

  override fun getName(): String = "MdNativeQQ"

  private var tencent: Tencent? = null
  private var logEnabled = false
  private var logPrefix = "[QQ] "

  // ---- NativeEventEmitter 兼容 ----
  @ReactMethod fun addListener(eventName: String) { /* no-op */ }
  @ReactMethod fun removeListeners(count: Int) { /* no-op */ }

  // ---- registerApp ----

  @ReactMethod
  fun registerApp(options: ReadableMap) {
    val appId = options.getString("appId")
      ?: throw IllegalArgumentException("[md-native-qq] registerApp 缺少 appId")
    val agreePrivacy = options.hasKey("agreePrivacy") && options.getBoolean("agreePrivacy")
    logEnabled = options.hasKey("log") && options.getBoolean("log")
    if (options.hasKey("logPrefix") && options.getString("logPrefix") != null) {
      logPrefix = options.getString("logPrefix")!!
    }

    // 必须在 createInstance 之前
    Tencent.setIsPermissionGranted(agreePrivacy)

    val authority = "${reactCtx.applicationContext.packageName}.mdqq.fileprovider"
    tencent = Tencent.createInstance(appId, reactCtx.applicationContext, authority)

    instance.set(this)
    log("registerApp appId=$appId agreePrivacy=$agreePrivacy fileProvider=$authority")
  }

  // ---- 工具方法 ----

  @ReactMethod
  fun isQQInstalled(callback: Callback) {
    val t = tencent
    val installed = t?.isQQInstalled(reactCtx) ?: false
    callback.invoke(null, installed)
  }

  @ReactMethod
  fun getApiVersion(callback: Callback) {
    // 全量版 QQ SDK 有 Tencent.getSdkVersion()，lite 版去掉了，这里 reflect 兼容两者
    val v = runCatching {
      val m = Tencent::class.java.getDeclaredMethod("getSdkVersion")
      m.invoke(null) as? String
    }.getOrNull() ?: "unknown"
    callback.invoke(null, v)
  }

  /** Android 不需要 Universal Link，直接 resolve 空。 */
  @ReactMethod
  fun checkUniversalLinkReady(callback: Callback) {
    callback.invoke(null, Arguments.createMap().apply {
      putString("suggestion", "")
      putString("errorInfo", "")
    })
  }

  // ---- Login ----

  @ReactMethod
  fun login(params: ReadableMap, callback: Callback) {
    val t = tencent ?: run {
      callback.invoke("QQ SDK 未初始化，请先 registerApp"); return
    }
    val activity = activeActivity ?: run {
      callback.invoke("activity 为空，请在 MainActivity 中调用 MdNativeQQActivityBridge.setCurrentActivity，或确认 RN 已正确跟踪 Activity 生命周期")
      return
    }
    val scopes = if (params.hasKey("scopes") && params.getString("scopes")?.isNotBlank() == true) {
      params.getString("scopes")
    } else {
      "get_user_info,get_simple_userinfo"
    }
    loginListener.set(AuthListener(this))
    activity.runOnUiThread {
      val rc = t.login(activity, scopes, loginListener.get())
      if (rc == -1) {
        callback.invoke("authorize 调起失败，请确认 AppID")
      } else {
        callback.invoke(null)
      }
    }
  }

  @ReactMethod
  fun logout() {
    tencent?.logout(reactCtx)
  }

  // ---- Share helpers ----

  private fun resolveLocalPath(url: String): String? {
    if (url.isEmpty()) return null
    if (!url.startsWith("http://") && !url.startsWith("https://")) {
      return if (url.startsWith("file://")) url.removePrefix("file://") else url
    }
    return try {
      val name = "qqshare_${url.hashCode()}_${System.currentTimeMillis()}"
      val outFile = File(reactCtx.cacheDir, name)
      URL(url).openStream().use { input ->
        FileOutputStream(outFile).use { output -> input.copyTo(output) }
      }
      outFile.absolutePath
    } catch (e: Exception) {
      log("resolveLocalPath fail $url: ${e.message}")
      null
    }
  }

  private fun runShareToQQ(params: Bundle, callback: Callback) {
    val t = tencent ?: run { callback.invoke("QQ SDK 未初始化"); return }
    val activity = activeActivity ?: run { callback.invoke("activity 为空"); return }
    shareListener.set(ShareListener(this))
    activity.runOnUiThread { t.shareToQQ(activity, params, shareListener.get()) }
    callback.invoke(null)
  }

  private fun runShareToQzone(params: Bundle, callback: Callback) {
    val t = tencent ?: run { callback.invoke("QQ SDK 未初始化"); return }
    val activity = activeActivity ?: run { callback.invoke("activity 为空"); return }
    shareListener.set(ShareListener(this))
    activity.runOnUiThread { t.shareToQzone(activity, params, shareListener.get()) }
    callback.invoke(null)
  }

  private fun runPublishToQzone(params: Bundle, callback: Callback) {
    val t = tencent ?: run { callback.invoke("QQ SDK 未初始化"); return }
    val activity = activeActivity ?: run { callback.invoke("activity 为空"); return }
    publishListener.set(PublishListener(this))
    activity.runOnUiThread { t.publishToQzone(activity, params, publishListener.get()) }
    callback.invoke(null)
  }

  private fun isQzone(map: ReadableMap): Boolean =
    map.hasKey("scene") && map.getString("scene") == "qzone"

  // ---- Share APIs ----

  @ReactMethod
  fun shareText(options: ReadableMap, callback: Callback) {
    // QQ Open SDK lite 版（3.5.x 之后官方推送的版本）移除了纯文本类型，
    // 全量版 jar 才有 SHARE_TO_QQ_TYPE_TEXT(=6)。这里 reflect 探测，没有就友好报错。
    val textType = runCatching {
      QQShare::class.java.getField("SHARE_TO_QQ_TYPE_TEXT").getInt(null)
    }.getOrNull()
    if (textType == null) {
      callback.invoke("当前 QQ Open SDK（lite 版）不支持纯文本分享，请使用 shareLink 替代")
      return
    }
    val params = Bundle().apply {
      putInt(QQShare.SHARE_TO_QQ_KEY_TYPE, textType)
      putString(QQShare.SHARE_TO_QQ_SUMMARY, options.getString("text"))
      if (options.hasKey("title")) putString(QQShare.SHARE_TO_QQ_TITLE, options.getString("title"))
    }
    if (isQzone(options)) runShareToQzone(params, callback) else runShareToQQ(params, callback)
  }

  @ReactMethod
  fun shareImage(options: ReadableMap, callback: Callback) {
    val local = resolveLocalPath(options.getString("imageUrl") ?: "")
      ?: run { callback.invoke("无法解析图片路径"); return }
    val params = Bundle().apply {
      putInt(QQShare.SHARE_TO_QQ_KEY_TYPE, QQShare.SHARE_TO_QQ_TYPE_IMAGE)
      putString(QQShare.SHARE_TO_QQ_IMAGE_LOCAL_URL, local)
      if (options.hasKey("title")) putString(QQShare.SHARE_TO_QQ_TITLE, options.getString("title"))
      if (options.hasKey("description")) putString(QQShare.SHARE_TO_QQ_SUMMARY, options.getString("description"))
    }
    if (isQzone(options)) runShareToQzone(params, callback) else runShareToQQ(params, callback)
  }

  @ReactMethod
  fun shareLink(options: ReadableMap, callback: Callback) {
    if (isQzone(options)) {
      val params = Bundle().apply {
        putInt(QzoneShare.SHARE_TO_QZONE_KEY_TYPE, QzoneShare.SHARE_TO_QZONE_TYPE_IMAGE_TEXT)
        putString(QzoneShare.SHARE_TO_QQ_TITLE, options.getString("title"))
        if (options.hasKey("description")) putString(QzoneShare.SHARE_TO_QQ_SUMMARY, options.getString("description"))
        putString(QzoneShare.SHARE_TO_QQ_TARGET_URL, options.getString("webpageUrl"))
        if (options.hasKey("thumbImageUrl") && options.getString("thumbImageUrl") != null) {
          putStringArrayList(QzoneShare.SHARE_TO_QQ_IMAGE_URL, arrayListOf(options.getString("thumbImageUrl")!!))
        }
      }
      runShareToQzone(params, callback)
    } else {
      val params = Bundle().apply {
        putInt(QQShare.SHARE_TO_QQ_KEY_TYPE, QQShare.SHARE_TO_QQ_TYPE_DEFAULT)
        putString(QQShare.SHARE_TO_QQ_TITLE, options.getString("title"))
        if (options.hasKey("description")) putString(QQShare.SHARE_TO_QQ_SUMMARY, options.getString("description"))
        putString(QQShare.SHARE_TO_QQ_TARGET_URL, options.getString("webpageUrl"))
        if (options.hasKey("thumbImageUrl")) putString(QQShare.SHARE_TO_QQ_IMAGE_URL, options.getString("thumbImageUrl"))
      }
      runShareToQQ(params, callback)
    }
  }

  @ReactMethod
  fun shareMusic(options: ReadableMap, callback: Callback) {
    val params = Bundle().apply {
      putInt(QQShare.SHARE_TO_QQ_KEY_TYPE, QQShare.SHARE_TO_QQ_TYPE_AUDIO)
      putString(QQShare.SHARE_TO_QQ_TITLE, options.getString("title"))
      if (options.hasKey("description")) putString(QQShare.SHARE_TO_QQ_SUMMARY, options.getString("description"))
      putString(QQShare.SHARE_TO_QQ_TARGET_URL, options.getString("webpageUrl"))
      putString(QQShare.SHARE_TO_QQ_AUDIO_URL, options.getString("musicUrl"))
      if (options.hasKey("thumbImageUrl")) putString(QQShare.SHARE_TO_QQ_IMAGE_URL, options.getString("thumbImageUrl"))
    }
    if (isQzone(options)) runShareToQzone(params, callback) else runShareToQQ(params, callback)
  }

  @ReactMethod
  fun shareMiniProgram(options: ReadableMap, callback: Callback) {
    // lite 版常量是 SHARE_TO_QQ_MINI_PROGRAM (=7)，全量版是 SHARE_TO_QQ_TYPE_MINI_PROGRAM，
    // 名字不一样数值一样。先按 lite 版常量名取，没有再 reflect 兜底。
    val miniType = runCatching {
      QQShare::class.java.getField("SHARE_TO_QQ_MINI_PROGRAM").getInt(null)
    }.getOrNull() ?: runCatching {
      QQShare::class.java.getField("SHARE_TO_QQ_TYPE_MINI_PROGRAM").getInt(null)
    }.getOrNull() ?: 7
    val params = Bundle().apply {
      putInt(QQShare.SHARE_TO_QQ_KEY_TYPE, miniType)
      putString(QQShare.SHARE_TO_QQ_TITLE, options.getString("title"))
      if (options.hasKey("description")) putString(QQShare.SHARE_TO_QQ_SUMMARY, options.getString("description"))
      putString(QQShare.SHARE_TO_QQ_TARGET_URL, options.getString("webpageUrl"))
      if (options.hasKey("thumbImageUrl")) putString(QQShare.SHARE_TO_QQ_IMAGE_URL, options.getString("thumbImageUrl"))
      putString(QQShare.SHARE_TO_QQ_MINI_PROGRAM_APPID, options.getString("miniAppId"))
      putString(QQShare.SHARE_TO_QQ_MINI_PROGRAM_PATH, options.getString("miniPath"))
      val type = if (options.hasKey("miniProgramType")) options.getInt("miniProgramType") else 3
      putString(QQShare.SHARE_TO_QQ_MINI_PROGRAM_TYPE, type.toString())
    }
    runShareToQQ(params, callback)
  }

  @ReactMethod
  fun shareVideo(options: ReadableMap, callback: Callback) {
    val local = resolveLocalPath(options.getString("videoUrl") ?: "")
      ?: run { callback.invoke("无法解析 video 路径"); return }
    val params = Bundle().apply {
      putInt(QzonePublish.PUBLISH_TO_QZONE_KEY_TYPE, QzonePublish.PUBLISH_TO_QZONE_TYPE_PUBLISHVIDEO)
      putString(QzonePublish.PUBLISH_TO_QZONE_VIDEO_PATH, local)
      if (options.hasKey("title")) putString(QzonePublish.PUBLISH_TO_QZONE_SUMMARY, options.getString("title"))
    }
    runPublishToQzone(params, callback)
  }

  @ReactMethod
  fun publishToQzone(options: ReadableMap, callback: Callback) {
    val urls = options.getArray("imageUrls") ?: run { callback.invoke("imageUrls 不能为空"); return }
    val paths = ArrayList<String>(urls.size())
    for (i in 0 until urls.size()) {
      val p = resolveLocalPath(urls.getString(i) ?: "")
        ?: run { callback.invoke("无法解析图片：${urls.getString(i)}"); return }
      paths.add(p)
    }
    val params = Bundle().apply {
      putInt(QzonePublish.PUBLISH_TO_QZONE_KEY_TYPE, QzonePublish.PUBLISH_TO_QZONE_TYPE_PUBLISHMOOD)
      putString(QzonePublish.PUBLISH_TO_QZONE_SUMMARY, options.getString("text"))
      putStringArrayList(QzonePublish.PUBLISH_TO_QZONE_IMAGE_URL, paths)
    }
    runPublishToQzone(params, callback)
  }

  // ---- 事件发射 ----

  private fun emit(type: String, errorCode: Int, errorStr: String?, data: WritableMap?) {
    val body = Arguments.createMap().apply {
      putString("type", type)
      putInt("errorCode", errorCode)
      if (errorStr == null) putNull("errorStr") else putString("errorStr", errorStr)
      putMap("data", data ?: Arguments.createMap())
    }
    reactCtx
      .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
      .emit("MdNativeQQ_Response", body)
  }

  internal fun emitAuth(payload: Bundle?) {
    val data = Arguments.createMap()
    payload?.let {
      data.putString("openId", it.getString("openid", ""))
      data.putString("accessToken", it.getString("access_token", ""))
      val expiresIn = it.getString("expires_in")?.toDoubleOrNull() ?: 0.0
      data.putDouble("expiresIn", expiresIn)
      data.putDouble("expirationDate", System.currentTimeMillis() / 1000.0 + expiresIn)
    }
    emit("AuthResp", 0, null, data)
  }

  internal fun emitAuthError(code: Int, msg: String) {
    emit("AuthResp", code, msg, null)
  }

  internal fun emitShareSuccess() = emit("ShareResp", 0, null, null)
  internal fun emitShareError(code: Int, msg: String) = emit("ShareResp", code, msg, null)

  internal fun emitPublishSuccess() = emit("PublishResp", 0, null, null)
  internal fun emitPublishError(code: Int, msg: String) = emit("PublishResp", code, msg, null)

  private fun log(s: String) {
    if (logEnabled) Log.d("MdNativeQQ", "$logPrefix$s")
  }

  // ---- Activity 解析 ----
  //
  // 优先用 host 通过 MdNativeQQActivityBridge.setCurrentActivity 显式注入的 Activity；
  // 没有注入时回退到 ReactContextBaseJavaModule.getCurrentActivity()（多数 RN 工程已自动跟踪）。
  // 注意：不能把 companion 的字段命名为 currentActivity，否则 @JvmStatic 生成的
  // getCurrentActivity() 会与父类同签名方法触发 "Accidental override" 编译错误。
  private val activeActivity: Activity?
    get() = hostActivity ?: getCurrentActivity()  // 显式调父类方法，不依赖 Kotlin 的 Java getter 属性合成

  // ---- 静态：处理 Activity 回跳 ----

  companion object {
    @JvmStatic
    internal var hostActivity: Activity? = null

    private val instance = AtomicReference<MdNativeQQModule?>()
    private val loginListener = AtomicReference<IUiListener?>()
    private val shareListener = AtomicReference<IUiListener?>()
    private val publishListener = AtomicReference<IUiListener?>()

    @JvmStatic
    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
      // lite 版只剩 REQUEST_LOGIN（全量版还有 REQUEST_OLD_LOGIN），其它 share 用的 code 两版一致。
      // REQUEST_OLD_SHARE / REQUEST_OLD_QZSHARE 是 SDK 内部 fallback 路径，顺手一起接住。
      val listener = when (requestCode) {
        Constants.REQUEST_LOGIN -> loginListener.get()
        Constants.REQUEST_QQ_SHARE, Constants.REQUEST_OLD_SHARE -> shareListener.get()
        Constants.REQUEST_QZONE_SHARE, Constants.REQUEST_OLD_QZSHARE ->
          publishListener.get() ?: shareListener.get()
        Constants.REQUEST_QQ_FAVORITES -> shareListener.get()
        else -> null
      } ?: return
      Tencent.onActivityResultData(requestCode, resultCode, data, listener)
    }
  }

  // ---- IUiListener 适配器 ----

  private class AuthListener(val owner: MdNativeQQModule) : IUiListener {
    override fun onComplete(any: Any?) {
      val json = any as? org.json.JSONObject
      if (json == null) {
        owner.emitAuthError(-5, "登录回执非法")
        return
      }
      val bundle = Bundle().apply {
        putString("openid", json.optString("openid"))
        putString("access_token", json.optString("access_token"))
        putString("expires_in", json.optString("expires_in"))
      }
      owner.emitAuth(bundle)
    }
    override fun onError(e: UiError) { owner.emitAuthError(e.errorCode, e.errorMessage ?: "登录失败") }
    override fun onCancel() { owner.emitAuthError(-2, "用户取消登录") }
    override fun onWarning(code: Int) {}
  }

  private class ShareListener(val owner: MdNativeQQModule) : IUiListener {
    override fun onComplete(any: Any?) { owner.emitShareSuccess() }
    override fun onError(e: UiError) { owner.emitShareError(e.errorCode, e.errorMessage ?: "分享失败") }
    override fun onCancel() { owner.emitShareError(-2, "用户取消分享") }
    override fun onWarning(code: Int) {}
  }

  private class PublishListener(val owner: MdNativeQQModule) : IUiListener {
    override fun onComplete(any: Any?) { owner.emitPublishSuccess() }
    override fun onError(e: UiError) { owner.emitPublishError(e.errorCode, e.errorMessage ?: "发布失败") }
    override fun onCancel() { owner.emitPublishError(-2, "用户取消发布") }
    override fun onWarning(code: Int) {}
  }
}
