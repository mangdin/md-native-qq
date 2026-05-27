package com.mangdin.mdnativeqq

import android.app.Activity
import android.content.Intent

/**
 * QQ Open SDK 的登录 / 分享回执依赖宿主 Activity#onActivityResult。
 * 宿主 App 需要在 MainActivity 转发：
 *
 *   override fun onResume() {
 *     super.onResume()
 *     MdNativeQQActivityBridge.setCurrentActivity(this)
 *   }
 *   override fun onPause() {
 *     super.onPause()
 *     MdNativeQQActivityBridge.setCurrentActivity(null)
 *   }
 *   override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
 *     super.onActivityResult(requestCode, resultCode, data)
 *     MdNativeQQActivityBridge.handleResultData(requestCode, resultCode, data)
 *   }
 */
object MdNativeQQActivityBridge {
  @JvmStatic
  fun setCurrentActivity(activity: Activity?) {
    MdNativeQQModule.currentActivity = activity
  }

  @JvmStatic
  fun handleResultData(requestCode: Int, resultCode: Int, data: Intent?) {
    MdNativeQQModule.handleActivityResult(requestCode, resultCode, data)
  }
}
