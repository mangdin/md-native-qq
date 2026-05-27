#import "MdNativeQQURLHandler.h"
#import <TencentOpenAPI/QQApiInterface.h>
#import <TencentOpenAPI/TencentOAuth.h>

@implementation MdNativeQQURLHandler

+ (BOOL)handleOpenURL:(NSURL *)url {
  if ([TencentOAuth CanHandleOpenURL:url]) {
    return [TencentOAuth HandleOpenURL:url];
  }
  return [QQApiInterface handleOpenURL:url delegate:nil];
}

+ (BOOL)handleUniversalLink:(NSUserActivity *)userActivity {
  // This SDK version does not support Universal Link callbacks
  return NO;
}

@end
