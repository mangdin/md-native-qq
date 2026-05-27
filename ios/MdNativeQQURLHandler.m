#import "MdNativeQQURLHandler.h"
#import "MdNativeQQ.h"
#import <TencentOpenAPI/QQApiInterface.h>
#import <TencentOpenAPI/TencentOAuth.h>

@implementation MdNativeQQURLHandler

+ (BOOL)handleOpenURL:(NSURL *)url {
  id<QQApiInterfaceDelegate, TencentSessionDelegate> delegate =
    (id<QQApiInterfaceDelegate, TencentSessionDelegate>)[MdNativeQQ sharedInstance];

  if ([TencentOAuth CanHandleOpenURL:url]) {
    return [TencentOAuth HandleOpenURL:url];
  }
  return [QQApiInterface handleOpenURL:url delegate:delegate];
}

+ (BOOL)handleUniversalLink:(NSUserActivity *)userActivity {
  if (!userActivity.webpageURL) return NO;
  NSURL *url = userActivity.webpageURL;

  id<QQApiInterfaceDelegate, TencentSessionDelegate> delegate =
    (id<QQApiInterfaceDelegate, TencentSessionDelegate>)[MdNativeQQ sharedInstance];

  // 3.3.x 起的 Universal Link 接口。用 respondsToSelector 兼容老版本。
  SEL canUL = NSSelectorFromString(@"CanHandleUniversalLink:");
  SEL handleUL = NSSelectorFromString(@"HandleUniversalLink:");
  if ([TencentOAuth respondsToSelector:canUL] &&
      [TencentOAuth respondsToSelector:handleUL]) {
    NSMethodSignature *sig = [TencentOAuth methodSignatureForSelector:canUL];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = [TencentOAuth class];
    inv.selector = canUL;
    [inv setArgument:&url atIndex:2];
    [inv invoke];
    BOOL canHandle = NO;
    [inv getReturnValue:&canHandle];
    if (canHandle) {
      NSMethodSignature *sig2 = [TencentOAuth methodSignatureForSelector:handleUL];
      NSInvocation *inv2 = [NSInvocation invocationWithMethodSignature:sig2];
      inv2.target = [TencentOAuth class];
      inv2.selector = handleUL;
      [inv2 setArgument:&url atIndex:2];
      [inv2 invoke];
      BOOL ok = NO;
      [inv2 getReturnValue:&ok];
      return ok;
    }
  }

  SEL ulShare = NSSelectorFromString(@"handleOpenUniversallink:delegate:");
  if ([QQApiInterface respondsToSelector:ulShare]) {
    NSMethodSignature *sig = [QQApiInterface methodSignatureForSelector:ulShare];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = [QQApiInterface class];
    inv.selector = ulShare;
    [inv setArgument:&url atIndex:2];
    id d = delegate;
    [inv setArgument:&d atIndex:3];
    [inv invoke];
    BOOL ok = NO;
    [inv getReturnValue:&ok];
    return ok;
  }

  return NO;
}

@end
