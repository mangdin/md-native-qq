#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 在宿主 App 的 AppDelegate / SceneDelegate 中调用，用于把 QQ 回跳事件转交给 SDK。
@interface MdNativeQQURLHandler : NSObject

+ (BOOL)handleOpenURL:(NSURL *)url;
+ (BOOL)handleUniversalLink:(NSUserActivity *)userActivity;

@end

NS_ASSUME_NONNULL_END
