# md-native-qq

腾讯 QQ 互联（QQ Open SDK）的 React Native 封装。提供 QQ 登录、分享到 QQ / QZone、判断 QQ 是否安装等能力。

- 底层：**NativeModules + NativeEventEmitter**（无 Nitro / 无 TurboModule 强依赖，新旧架构都能跑）
- 全 API Promise 化，TypeScript 类型完整
- iOS：基于官方 **TencentOpenAPI**（手动 vendor 最新 xcframework）
- Android：基于官方 **com.tencent.tauth:qqopensdk**（本地 `libs/open_sdk_*.jar`）
- 完整支持 iOS Universal Link
- 显式隐私授权 API，符合工信部信管函〔2021〕169 号要求

---

## 1. 安装

```bash
npm install md-native-qq
cd ios && bundle exec pod install
```

> Expo Go 不支持，必须 `npx expo prebuild` 后使用，或直接在 bare RN 工程里使用。

### 1.1 放置原生 SDK（必须）

出于体积 & 腾讯许可考虑，原生 SDK 不随 npm 包发布。安装后请按以下两份文件指引手动放置：

- iOS：`node_modules/md-native-qq/ios/PLACE_SDK_HERE.md`
- Android：`node_modules/md-native-qq/android/libs/PLACE_SDK_HERE.md`

落不到位时，`pod install` 或 `gradle sync` 会直接抛错并打印放置说明，不会偷偷过掉。

---

## 2. iOS 接入

### 2.1 Info.plist

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>tencent你的AppID</string>     <!-- 例：tencent102xxxxxx -->
      <string>QQ你的AppID16进制</string>   <!-- 例：QQ06FAxxxx，大写无前导零 -->
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

<!-- 隐私政策必填项（应用上架时审核会查） -->
<key>NSPhotoLibraryUsageDescription</key>
<string>用于在分享时选择图片</string>
```

### 2.2 Universal Link

1. 在 [QQ 互联后台](https://connect.qq.com/) 应用详情页 → "Universal Links 配置"，填入形如 `https://app.example.com/qq/` 的链接。
2. 把腾讯下发的 `apple-app-site-association`（**不要带 `.json` 后缀**）部署到该域名根目录 `/.well-known/`，HTTPS 必须正常。
3. Xcode 工程 Signing & Capabilities 添加 **Associated Domains**：`applinks:app.example.com`。
4. App 首次启动调 `checkUniversalLinkReady()` 可以做自检。

### 2.3 AppDelegate

`AppDelegate.mm`（默认模板）：

```objc
#import "MdNativeQQURLHandler.h"

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
  if ([MdNativeQQURLHandler handleOpenURL:url]) return YES;
  return [RCTLinkingManager application:application openURL:url options:options];
}

- (BOOL)application:(UIApplication *)application
continueUserActivity:(NSUserActivity *)userActivity
 restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler {
  if ([MdNativeQQURLHandler handleUniversalLink:userActivity]) return YES;
  return [RCTLinkingManager application:application continueUserActivity:userActivity restorationHandler:restorationHandler];
}
```

Swift 版本同理：

```swift
import MdNativeQQ

func application(_ app: UIApplication, open url: URL,
                 options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
  if MdNativeQQURLHandler.handleOpen(url) { return true }
  return RCTLinkingManager.application(app, open: url, options: options)
}

func application(_ application: UIApplication,
                 continue userActivity: NSUserActivity,
                 restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
  if MdNativeQQURLHandler.handleUniversalLink(userActivity) { return true }
  return RCTLinkingManager.application(application,
                                       continue: userActivity,
                                       restorationHandler: restorationHandler)
}
```

---

## 3. Android 接入

### 3.1 manifestPlaceholders

`android/app/build.gradle`：

```groovy
android {
  defaultConfig {
    manifestPlaceholders = [
      qqAppId: "102xxxxxx"   // 与 JS 侧 registerApp 的 appId 完全一致
    ]
  }
}
```

> 库自带的 `AndroidManifest.xml` 已经声明了 `AuthActivity` / `AssistActivity` / `MdNativeQQFileProvider`，**宿主无需再写**，只要注入 `qqAppId` 即可。

### 3.2 MainActivity 转发

```kotlin
import com.mangdin.mdnativeqq.MdNativeQQActivityBridge

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

### 3.3 注册 ReactPackage

老架构 / `MainApplication.kt`：

```kotlin
override fun getPackages(): List<ReactPackage> =
  PackageList(this).packages.apply {
    add(MdNativeQQPackage())
  }
```

新架构（autolinking）会自动接管，不需要手动加。

---

## 4. JS 使用

```ts
import QQ, { registerApp, login, shareLink, publishToQzone } from 'md-native-qq';

// 1. 隐私协议弹窗确认 → registerApp
await showPrivacyDialog();   // 你自己的弹窗
registerApp({
  appId: '102xxxxxx',
  universalLink: 'https://app.example.com/qq/',   // iOS 必填
  agreePrivacy: true,                              // 关键：用户同意后必须为 true
  log: __DEV__,
});

// 2. 自检（仅 iOS 有意义）
const { suggestion, errorInfo } = await QQ.checkUniversalLinkReady();
if (errorInfo) console.warn('UL 配置异常：', suggestion);

// 3. 检测
await QQ.isQQInstalled();
await QQ.getApiVersion();

// 4. 登录
const { openId, accessToken, expiresIn } = await login(
  'get_user_info,get_simple_userinfo'
);

// 5. 分享到 QQ 好友
await shareLink({
  scene: 'qq',
  title: '招聘信息',
  description: '海员急招，月薪 2 万起',
  webpageUrl: 'https://newseaman.com/job/123',
  thumbImageUrl: 'https://newseaman.com/cover.jpg',
});

// 6. 发布到 QZone
await publishToQzone({
  text: '今天上船啦~',
  imageUrls: ['/sdcard/DCIM/1.jpg', '/sdcard/DCIM/2.jpg'],
});
```

---

## 5. API 速查

| 方法 | 说明 |
| --- | --- |
| `registerApp({ appId, universalLink?, agreePrivacy?, log?, logPrefix? })` | 初始化。`agreePrivacy` 必须在弹完隐私弹窗后才设 true，否则 SDK 不允许联网 |
| `checkUniversalLinkReady()` | iOS Universal Link 自检；Android 直接 resolve 空 |
| `isQQInstalled()` | `Promise<boolean>` |
| `getApiVersion()` | `Promise<string>` |
| `login(scopes?)` | 拉起授权，`Promise<QQLoginResult>` |
| `logout()` | 清登录态 |
| `shareText({ scene, text, title? })` | 文本，仅 `'qq'` / `'favorites'` 真正生效 |
| `shareImage({ scene, imageUrl, title?, description? })` | 图片，本地路径或 http(s) |
| `shareLink({ scene, title, description?, webpageUrl, thumbImageUrl? })` | 图文链接 |
| `shareMusic({ scene, title, description?, webpageUrl, musicUrl, thumbImageUrl? })` | 音乐 |
| `shareMiniProgram({ scene, title, description?, webpageUrl, thumbImageUrl?, miniAppId, miniPath, miniProgramType? })` | QQ 小程序，需要 SDK ≥ 3.5.x |
| `shareVideo({ scene: 'qzone', videoUrl, title?, description?, thumbImageUrl? })` | QZone 视频发布 |
| `publishToQzone({ text, imageUrls })` | QZone 图文动态 |

`scene` 取值：`'qq' | 'qzone' | 'favorites'`。

`QQLoginResult`：

```ts
{
  openId: string;
  accessToken: string;
  expiresIn: number;        // 秒
  expirationDate: number;   // Unix timestamp (秒)
  authCode?: string;
}
```

---

## 6. 隐私授权 — 关于 `agreePrivacy`

QQ 互联 SDK 在 2021 年后强制要求接入方先弹出隐私协议弹窗并取得用户同意，才能调用任何会联网的方法。本库的对应实现：

- iOS：`registerApp` 调用前会按 `agreePrivacy` 值调用 `TencentOAuth.setIsPermissionGranted:` 和 `setIsUserAgreedAuthorization:`（runtime 探测，老 SDK 无此 API 时自动跳过）。
- Android：调用 `Tencent.setIsPermissionGranted(agreePrivacy)`。

**错误用法**：在用户尚未确认隐私弹窗前就 `registerApp({ agreePrivacy: true })`——这等同于伪造同意，应用市场审核会驳回。

**正确用法**：

```ts
// App.tsx
async function bootstrap() {
  const agreed = await ensurePrivacyConsent();   // 自己弹窗 + 持久化
  registerApp({ appId, universalLink, agreePrivacy: agreed });
}
```

---

## 7. 从 0.1.x（Nitro 版）升级

| 0.1.x | 0.2.x |
| --- | --- |
| `import QQ from 'md-native-qq'` + `NitroModules.createHybridObject` | 同名导出，**API 形状不变** |
| `MdNativeQQActivityBridge` 在 `com.margelo.nitro.mdnativeqq` | 换包到 `com.mangdin.mdnativeqq` |
| `MdNativeQQURLHandler.handleUniversalLink` 直接 `return NO` | 真实接入 Universal Link |
| 需 `react-native-nitro-modules` peer dep | 已移除 |
| 安装后必须跑 `npm run nitrogen` | 不再需要 |
| `registerApp({ appId, universalLink })` | `registerApp({ appId, universalLink, agreePrivacy })`（**新增 agreePrivacy，必传**） |

迁移步骤：

```bash
# 1. 删旧
npm uninstall react-native-nitro-modules

# 2. 升级
npm install md-native-qq@^0.2

# 3. Android 改 import
#    com.margelo.nitro.mdnativeqq.MdNativeQQActivityBridge
# → com.mangdin.mdnativeqq.MdNativeQQActivityBridge

# 4. iOS 重装
cd ios && bundle exec pod install
```

---

## 8. 已知限制

- iOS 端 `TencentOpenAPI.xcframework` 必须自己下载（podspec 没有声明 CocoaPods 依赖，这是有意为之，避免 trunk 上版本滞后）。
- Android `qqopensdk` 同样必须自己下载。维护成本是手动升级，收益是构建可控、出问题不用等腾讯发版。
- 模拟器调试只能验证 SDK 加载和 JS 桥；登录 / 分享必须真机+真 QQ。
- `shareMiniProgram` 在 iOS 端依赖 `QQApiMiniProgramObject`，仅 3.5.x 以上 SDK 提供；老版本会同步 reject。
