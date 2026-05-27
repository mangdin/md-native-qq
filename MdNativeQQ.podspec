require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "MdNativeQQ"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.description  = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "13.0" }
  s.source       = { :git => package["repository"]["url"].sub(/^git\+/, ''), :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm}"

  # ---- 强校验 vendored 的 TencentOpenAPI ----
  framework_path = File.join(__dir__, "ios", "TencentOpenAPI.xcframework")
  bundle_path    = File.join(__dir__, "ios", "TencentOpenApi_IOS_Bundle.bundle")
  unless File.exist?(framework_path) && File.exist?(bundle_path)
    raise <<~MSG

      [md-native-qq] 未找到 TencentOpenAPI.xcframework / TencentOpenApi_IOS_Bundle.bundle。

      请前往 https://wiki.connect.qq.com/sdk下载 下载最新版 iOS SDK，把
        TencentOpenAPI.xcframework
        TencentOpenApi_IOS_Bundle.bundle
      两件套放入：
        #{File.join(__dir__, 'ios')}

      详见 ios/PLACE_SDK_HERE.md
    MSG
  end

  s.vendored_frameworks = "ios/TencentOpenAPI.xcframework"
  s.resources           = "ios/TencentOpenApi_IOS_Bundle.bundle"

  # 腾讯 SDK 官方文档要求的链接器选项 / 系统框架
  s.frameworks = "Security", "SystemConfiguration", "CoreGraphics", "CoreTelephony", "WebKit"
  s.libraries  = "iconv", "sqlite3", "stdc++", "z"

  s.pod_target_xcconfig = {
    "OTHER_LDFLAGS" => "$(inherited) -ObjC"
  }

  install_modules_dependencies(s)
end
