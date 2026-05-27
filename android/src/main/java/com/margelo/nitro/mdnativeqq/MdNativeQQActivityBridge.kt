package com.margelo.nitro.mdnativeqq

import android.app.Activity
import android.content.Intent
import com.tencent.tauth.Tencent

/**
 * QQ SDK 的登录 / 分享回调依赖 Activity#onActivityResult，
 * 宿主 App 需要在 MainActivity#onActivityResult 中调用这里两个静态方法。
 *
 * 例：
 *   override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
 *     super.onActivityResult(requestCode, resultCode, data)
 *     MdNativeQQActivityBridge.handleResultData(requestCode, resultCode, data)
 *   }
 */
object MdNativeQQActivityBridge {
  @JvmStatic
  fun handleResultData(requestCode: Int, resultCode: Int, data: Intent?) {
    HybridMdNativeQQ.handleActivityResult(requestCode, resultCode, data)
  }

  @JvmStatic
  fun setCurrentActivity(activity: Activity?) {
    HybridMdNativeQQ.currentActivity = activity
  }

  @JvmStatic
  fun handleQzoneShareResult(intent: Intent?) {
    intent?.let { Tencent.handleResultData(it, HybridMdNativeQQ.uiListenerForShare) }
  }
}
