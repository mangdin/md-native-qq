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

  # ---- 宿主 App 链接配置（自动下发，无需用户改 Podfile）----
  #
  # 1) -ObjC: 腾讯 SDK 文档要求，否则 SDK 内部 category 不会被强制加载
  # 2) -ld_classic: 强制回退到老 linker
  #    新 linker ld_prime（Xcode 15+ 默认）在处理 TencentOpenAPI.xcframework 的
  #    alias 符号布局时会触发 Layout.cpp:2899 断言：
  #      "alias and its target must be located in the same section"
  #    这是 LLVM linker 的已知 bug（llvm-project#64157），
  #    在腾讯发布新工具链编出来的 xcframework 之前只能 workaround。
  #    待将来腾讯 SDK 更新后可考虑去掉这个 flag。
  s.user_target_xcconfig = {
    "OTHER_LDFLAGS" => "$(inherited) -ObjC -ld_classic"
  }

  install_modules_dependencies(s)
end
