package com.mangdin.mdnativeqq

import androidx.core.content.FileProvider

/**
 * 独立子类，避免与宿主自定义的 FileProvider 撞 authority。
 * authority 由 AndroidManifest 中以 `${applicationId}.mdqq.fileprovider` 注册。
 */
class MdNativeQQFileProvider : FileProvider()
