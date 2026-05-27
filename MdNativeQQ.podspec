require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))
folly_compiler_flags = '-DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1'

Pod::Spec.new do |s|
  s.name         = "MdNativeQQ"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "13.0" }
  s.source       = { :git => package["repository"]["url"].sub(/^git\+/, ''), :tag => "#{s.version}" }

  s.source_files = [
    "ios/**/*.{swift}",
    "ios/**/*.{m,mm}",
    "ios/**/*.{h}"
  ]

  s.exclude_files = [
    "ios/MdNativeQQ-Bridging-Header.h",
    "ios/TencentOpenAPI.xcframework/**",
    "ios/TencentOpenApi_IOS_Bundle.bundle/**"
  ]

  # TencentOpenAPI.xcframework + bundle 随包内置，无需额外 pod 依赖
  s.vendored_frameworks = "ios/TencentOpenAPI.xcframework"
  s.resources           = "ios/TencentOpenApi_IOS_Bundle.bundle"

  s.pod_target_xcconfig = {
    "SWIFT_VERSION"                       => "5.0",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS" => "$(inherited)",
    "HEADER_SEARCH_PATHS"                 => "$(inherited) ${PODS_ROOT}/RCT-Folly",
    "GCC_PREPROCESSOR_DEFINITIONS"        => "$(inherited) FOLLY_NO_CONFIG FOLLY_MOBILE=1 FOLLY_USE_LIBCPP=1 FOLLY_CFG_NO_COROUTINES",
    "OTHER_CPLUSPLUSFLAGS"                => "$(inherited) #{folly_compiler_flags}",
    "PRODUCT_MODULE_NAME"                 => "MdNativeQQ",
    "OTHER_LDFLAGS"                       => "$(inherited) -ObjC"
  }

  s.frameworks = "Security", "SystemConfiguration", "CoreGraphics", "CoreTelephony", "WebKit"
  s.libraries  = "iconv", "sqlite3", "stdc++", "z"

  s.dependency "React-Core"
  s.dependency "React-jsi"
  s.dependency "React-callinvoker"

  load File.join(__dir__, 'nitrogen/generated/ios/MdNativeQQ+autolinking.rb')
  add_nitrogen_files(s)

  install_modules_dependencies(s)
end
