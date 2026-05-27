#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

#import <TencentOpenAPI/QQApiInterface.h>
#import <TencentOpenAPI/TencentOAuth.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 单例（实际上 RN 会保证模块在桥内是单例），URL 回跳通过 sharedInstance
 * 把 self 当作 TencentSessionDelegate / QQApiInterfaceDelegate 派下去。
 */
@interface MdNativeQQ : RCTEventEmitter <RCTBridgeModule, TencentSessionDelegate, QQApiInterfaceDelegate>

@property (nonatomic, copy, nullable) NSString *appId;
@property (nonatomic, copy, nullable) NSString *universalLink;
@property (nonatomic, strong, nullable) TencentOAuth *oauth;

+ (instancetype)sharedInstance;

@end

NS_ASSUME_NONNULL_END
