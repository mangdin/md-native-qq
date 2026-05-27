#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 宿主 App 在 AppDelegate / SceneDelegate 中调用，把 QQ 互联回跳事件
 * 转交给 TencentOpenAPI。两种回跳都要接：
 *
 *   - openURL（mqq:// / tencent[APPID]:// scheme）
 *   - Universal Link（iOS 9+，QQ 互联后台配置）
 */
@interface MdNativeQQURLHandler : NSObject

+ (BOOL)handleOpenURL:(NSURL *)url;
+ (BOOL)handleUniversalLink:(NSUserActivity *)userActivity;

@end

NS_ASSUME_NONNULL_END
