# md-native-qq

腾讯 QQ 互联（QQ Open SDK）的 React Native **Nitro Modules** 封装，提供 QQ 登录、分享到 QQ / QZone、判断 QQ 是否安装等能力。设计与 `native-wechat`、`react-native-alipay-v5` 风格一致，可与之并列使用。

- iOS：基于官方 `TencentOpenAPI`
- Android：基于官方 `com.tencent.tauth:qqopensdk`
- React Native **新架构**（Fabric / TurboModules）原生支持，依赖 [`react-native-nitro-modules`](https://github.com/mrousavy/nitro)
- 全 API Promise 化，TS 类型完整

## 1. 安装

```bash
npm install md-native-qq react-native-nitro-modules
cd ios && bundle exec pod install
```

> 因为这是 Nitro 模块，**首次安装或修改 spec 后必须先生成桥接代码**：
> ```bash
> cd node_modules/md-native-qq && npm run nitrogen
> ```
> 把这一步加到根项目的 `postinstall` 里更稳妥。

## 2. 原生侧接入

### 2.1 iOS

#### Info.plist

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>tencent你的AppID</string>
      <string>QQ你的AppID16进制</string>
      <string>QQLaunch</string>
    </array>
  </dict>
</array>

<key>LSApplicationQueriesSchemes</key>
<array>
  <string>mqq</string>
  <string>mqqapi</string>
  <string>mqqopensdkapiV2</string>
  <string>mqqopensdkapiV3</string>
  <string>mqqopensdkapiV4</string>
  <string>mqqopensdkminiapp</string>
  <string>mqzone</string>
  <string>mqqOpensdkSSoLogin</string>
  <string>wtloginmqq2</string>
</array>

<!-- iOS 9+ ATS（如需 http 资源） -->
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key><true/>
</dict>
```

#### AppDelegate（Swift 示例）

```swift
import MdNativeQQ

func application(_ app: UIApplication, open url: URL, options: [...]) -> Bool {
  if MdNativeQQURLHandler.handleOpenURL(url) { return true }
  return false
}

func application(_ application: UIApplication,
                 continue userActivity: NSUserActivity,
                 restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
  if MdNativeQQURLHandler.handleUniversalLink(userActivity) { return true }
  return false
}
```

> Universal Link 必须在 QQ 互联后台配置一致，否则 iOS 13+ 唤起会失败。

### 2.2 Android

#### AndroidManifest.xml（宿主 App）

```xml
<activity
  android:name="com.tencent.tauth.AuthActivity"
  android:noHistory="true"
  android:launchMode="singleTask"
  android:exported="true">
  <intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="tencent你的AppID"/>
  </intent-filter>
</activity>

<activity
  android:name="com.tencent.connect.common.AssistActivity"
  android:theme="@android:style/Theme.Translucent.NoTitleBar"
  android:configChanges="orientation|keyboardHidden|screenSize"
  android:exported="false"/>

<provider
  android:name="androidx.core.content.FileProvider"
  android:authorities="${applicationId}.fileprovider"
  android:exported="false"
  android:grantUriPermissions="true">
  <meta-data
    android:name="android.support.FILE_PROVIDER_PATHS"
    android:resource="@xml/file_paths"/>
</provider>
```

#### MainActivity

QQ SDK 走的是 `onActivityResult` 回调，需要在 MainActivity 转发：

```kotlin
import com.margelo.nitro.mdnativeqq.MdNativeQQActivityBridge

class MainActivity : ReactActivity() {
  override fun onResume() {
    super.onResume()
    MdNativeQQActivityBridge.setCurrentActivity(this)
  }
  override fun onPause() {
    super.onPause()
    MdNativeQQActivityBridge.setCurrentActivity(null)
  }
  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    super.onActivityResult(requestCode, resultCode, data)
    MdNativeQQActivityBridge.handleResultData(requestCode, resultCode, data)
  }
}
```

> 若 Maven 拉不到 `com.tencent.tauth:qqopensdk`，请在 wiki.connect.qq.com 下载 `open_sdk_xxx.jar` 放入 `android/app/libs/`，并在 `android/build.gradle` 里把对应 implementation 改为 `implementation files('libs/open_sdk_xxx.jar')`。

## 3. JS 使用

```ts
import QQ, { QQScene } from 'md-native-qq';

// 1. 初始化（在 App 启动入口调一次）
QQ.registerApp({
  appId: '102xxxxxx',
  universalLink: 'https://app.example.com/qq/',  // iOS 必填
});

// 2. 检测
QQ.isQQInstalled();    // boolean
QQ.getApiVersion();    // string

// 3. 登录
const { openId, accessToken, expiresIn } = await QQ.login('get_user_info,get_simple_userinfo');

// 4. 分享给 QQ 好友
await QQ.shareLink({
  scene: 'qq',
  title: '招聘信息',
  description: '海员急招，月薪 2 万起',
  webpageUrl: 'https://newseaman.com/job/123',
  thumbImageUrl: 'https://newseaman.com/cover.jpg',
});

// 5. 分享到 QZone（图文动态）
await QQ.publishToQzone({
  text: '今天上船啦~',
  imageUrls: ['/sdcard/DCIM/1.jpg', '/sdcard/DCIM/2.jpg'],
});
```

## 4. 在 newseaman 中替换 ShareAlertDialog

`js/pages/common/ShareAlertDialog.js` 中已有 QQ 按钮，把注释打开并改为：

```js
import QQ from 'md-native-qq';

componentDidMount() {
  QQ.registerApp({
    appId: 'YOUR_APP_ID',
    universalLink: 'https://app.newseaman.com/qq/',
  });
}

_qq() {
  QQ.shareLink({
    scene: 'qq',
    title: this.props.title,
    description: this.props.desc,
    webpageUrl: this.props.url,
    thumbImageUrl: this.props.thumb,
  }).catch(err => Toast.show({ type: 'error', text1: String(err) }));
}
```

## 5. API 速查

| 方法 | 说明 |
| --- | --- |
| `registerApp({ appId, universalLink? })` | 初始化，必须最先调用 |
| `isQQInstalled()` | 是否安装手机 QQ |
| `getApiVersion()` | 当前 SDK 版本 |
| `login(scopes?)` | OAuth 授权，返回 `{ openId, accessToken, expiresIn, expirationDate, authCode? }` |
| `logout()` | 清除登录态 |
| `shareText({ scene, text, title? })` | 纯文本（仅好友/收藏） |
| `shareImage({ scene, imageUrl, title?, description? })` | 图片，本地路径或 http(s) |
| `shareLink({ scene, title, description?, webpageUrl, thumbImageUrl? })` | 图文链接 |
| `shareMusic({ scene, title, webpageUrl, musicUrl, ... })` | 音乐 |
| `shareMiniProgram({ ... })` | QQ 小程序 |
| `shareVideo({ scene: 'qzone', videoUrl, ... })` | QZone 视频发布 |
| `publishToQzone({ text, imageUrls })` | QZone 图文动态 |

`scene` 取值：`'qq' | 'qzone' | 'favorites'`。

## 6. 开发

```bash
npm install                   # 安装依赖
npm run nitrogen              # 生成 Nitro 桥接代码
npm run build                 # 输出 lib/
npm run typecheck
```

## 7. 已知限制

- iOS 端 `TencentOpenAPI` 由腾讯发布在 CocoaPods，但版本更新不频繁。如果集成失败，可手工把 `TencentOpenAPI.framework` 放到 `ios/Frameworks/` 并修改 podspec 的 `s.vendored_frameworks`。
- Android `qqopensdk` 在 Maven Central 历史上不稳定，国内推荐用 [腾讯 Maven 仓库](https://maven.tencent.com) 或本地 jar 引入。
- QQ Open Platform 政策要求接入隐私合规弹窗，本库通过 `Tencent.setIsPermissionGranted(true)` 显式声明已获得用户同意，**调用方必须在弹出隐私同意后再 `registerApp`**。
