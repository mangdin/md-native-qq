# 放置腾讯 QQ Open SDK Android 文件

从 https://wiki.connect.qq.com/sdk下载 下载最新 Android SDK，
解压后将 `open_sdk_xxx.jar`（或 `open_sdk_xxx.aar`）重命名放到此目录：

```
android/libs/open_sdk.jar    ← jar 格式
# 或
android/libs/open_sdk.aar    ← aar 格式（如提供）
```

build.gradle 已配置为优先使用本目录内的文件，无需其他修改。
