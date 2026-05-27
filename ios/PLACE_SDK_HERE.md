# 放置腾讯 QQ Open SDK iOS 文件

本目录托管 **TencentOpenAPI.xcframework**（iOS 端 QQ 互联 SDK），出于体积和许可考虑不随 npm 包发布。

## 步骤

1. 前往 <https://wiki.connect.qq.com/sdk%e4%b8%8b%e8%bd%bd> 下载最新 iOS SDK（截至 2026 大版本仍为 3.5.x，文件名形如 `iOS_V3.5.x_SDK.zip`）。
2. 解压后把 **两件套** 放到本目录（与本文件同级）：

   ```
   ios/TencentOpenAPI.xcframework        ← 静态库
   ios/TencentOpenApi_IOS_Bundle.bundle  ← 资源 bundle（错误页 / icon）
   ```

3. 重新执行 `cd ios && bundle exec pod install`，podspec 会自动把这两个产物以 `vendored_frameworks` + `resources` 形式打入宿主工程。

## 校验

- 拖入后 `MdNativeQQ.podspec` 不需要任何修改。
- 若 Pod 安装时报 `TencentOpenAPI.xcframework not found`，说明这一步未完成。
- 模拟器只能在 `ios-arm64-simulator` slice 存在的情况下运行，老版本 SDK 仅提供 device slice，建议下载最新版本以同时支持 Apple Silicon 模拟器。

## 不要做的事

- 不要把这两个产物纳入 git 仓库（已在 `.gitignore` 默认忽略），避免污染 PR diff。
- 不要混用不同版本的 `xcframework` 和 `bundle`，二者必须来自同一份下载包。
