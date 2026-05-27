#import "MdNativeQQURLHandler.h"
#import <TencentOpenAPI/QQApiInterface.h>
#import <TencentOpenAPI/TencentOAuth.h>

@implementation MdNativeQQURLHandler

+ (BOOL)handleOpenURL:(NSURL *)url {
  if ([TencentOAuth CanHandleOpenURL:url]) {
    return [TencentOAuth HandleOpenURL:url];
  }
  if ([QQApiInterface canHandleUrl:url]) {
    return [QQApiInterface handleOpenURL:url delegate:nil];
  }
  return NO;
}

+ (BOOL)handleUniversalLink:(NSUserActivity *)userActivity {
  if ([TencentOAuth CanHandleUniversalLink:userActivity.webpageURL]) {
    return [TencentOAuth HandleUniversalLink:userActivity.webpageURL];
  }
  if ([QQApiInterface canHandleUniversallink:userActivity.webpageURL]) {
    return [QQApiInterface handleOpenUniversallink:userActivity.webpageURL delegate:nil];
  }
  return NO;
}

@end
