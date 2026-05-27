#import "MdNativeQQ.h"

#import <React/RCTLog.h>
#import <TencentOpenAPI/QQApiInterface.h>
#import <TencentOpenAPI/QQApiInterfaceObject.h>
#import <TencentOpenAPI/TencentOAuth.h>
#import <TencentOpenAPI/SDKDef.h>

#pragma mark - 工具

static NSData * _Nullable MdQQLoadImageData(NSString * _Nullable urlString) {
  if (urlString.length == 0) return nil;

  if ([urlString hasPrefix:@"http://"] || [urlString hasPrefix:@"https://"]) {
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return nil;
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:&error];
    return error ? nil : data;
  }

  NSString *path = [urlString hasPrefix:@"file://"] ? [urlString substringFromIndex:7] : urlString;
  return [[NSFileManager defaultManager] contentsAtPath:path];
}

static NSString * _Nullable MdQQResolveLocalPath(NSString * _Nullable urlString) {
  if (urlString.length == 0) return nil;
  if ([urlString hasPrefix:@"file://"]) return [urlString substringFromIndex:7];
  if ([urlString hasPrefix:@"http://"] || [urlString hasPrefix:@"https://"]) {
    // 视频 / QZone 发布的本地资源必须先落盘
    NSData *data = MdQQLoadImageData(urlString);
    if (!data) return nil;
    NSString *name = [NSString stringWithFormat:@"qqshare_%lu_%lld",
                      (unsigned long)urlString.hash,
                      (long long)[NSDate date].timeIntervalSince1970];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    [data writeToFile:path atomically:YES];
    return path;
  }
  return urlString;
}

static QQApiSendResultCode MdQQSend(QQApiObject *obj, NSString *scene) {
  if ([scene isEqualToString:@"favorites"]) {
    // kQQAPICtrlFlagQQShareFavorites = 0x08
    obj.cflag = obj.cflag | 0x08;
  }
  SendMessageToQQReq *req = [SendMessageToQQReq reqWithContent:obj];
  if (!req) return EQQAPIMESSAGECONTENTINVALID;

  if ([scene isEqualToString:@"qzone"]) {
    return [QQApiInterface SendReqToQZone:req];
  }
  return [QQApiInterface sendReq:req];
}

#pragma mark - Module

@interface MdNativeQQ ()
@property (nonatomic, assign) BOOL hasListeners;
@property (nonatomic, copy, nullable) NSString *logPrefix;
@property (nonatomic, assign) BOOL logEnabled;
@end

@implementation MdNativeQQ {
  // 临时存放 login callback，等 SDK 异步 delegate 回来再触发
}

RCT_EXPORT_MODULE(MdNativeQQ)

+ (BOOL)requiresMainQueueSetup { return YES; }

- (dispatch_queue_t)methodQueue { return dispatch_get_main_queue(); }

- (NSArray<NSString *> *)supportedEvents {
  return @[@"MdNativeQQ_Response"];
}

- (void)startObserving { self.hasListeners = YES; }
- (void)stopObserving  { self.hasListeners = NO; }

#pragma mark - sharedInstance（URL 回跳要用）

static __weak MdNativeQQ *gSharedInstance = nil;

+ (instancetype)sharedInstance {
  return gSharedInstance;
}

- (instancetype)init {
  if ((self = [super init])) {
    gSharedInstance = self;
  }
  return self;
}

- (void)dealloc {
  if (gSharedInstance == self) gSharedInstance = nil;
}

#pragma mark - 事件

- (void)emitResponse:(NSString *)type
           errorCode:(NSInteger)code
            errorStr:(nullable NSString *)str
                data:(nullable NSDictionary *)data {
  if (!self.hasListeners) return;
  [self sendEventWithName:@"MdNativeQQ_Response"
                     body:@{
                       @"type": type ?: @"",
                       @"errorCode": @(code),
                       @"errorStr": str ?: [NSNull null],
                       @"data": data ?: @{},
                     }];
}

- (void)logFormat:(NSString *)fmt, ... NS_FORMAT_FUNCTION(1, 2) {
  if (!self.logEnabled) return;
  va_list args;
  va_start(args, fmt);
  NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
  va_end(args);
  RCTLogInfo(@"%@%@", self.logPrefix ?: @"[QQ] ", msg);
}

#pragma mark - registerApp

RCT_EXPORT_METHOD(registerApp:(NSDictionary *)params) {
  NSString *appId = params[@"appId"];
  NSString *universalLink = params[@"universalLink"];
  BOOL agreePrivacy = [params[@"agreePrivacy"] boolValue];
  self.logEnabled = [params[@"log"] boolValue];
  self.logPrefix = params[@"logPrefix"];

  if (appId.length == 0) {
    RCTLogError(@"[md-native-qq] registerApp 缺少 appId");
    return;
  }
  self.appId = appId;
  self.universalLink = universalLink;

  // ---- 隐私授权（必须在 init 之前调用）----
  SEL permGranted = NSSelectorFromString(@"setIsPermissionGranted:");
  if ([TencentOAuth respondsToSelector:permGranted]) {
    NSMethodSignature *sig = [TencentOAuth methodSignatureForSelector:permGranted];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = [TencentOAuth class];
    inv.selector = permGranted;
    BOOL flag = agreePrivacy;
    [inv setArgument:&flag atIndex:2];
    [inv invoke];
  }
  SEL userAgreed = NSSelectorFromString(@"setIsUserAgreedAuthorization:");
  if ([TencentOAuth respondsToSelector:userAgreed]) {
    NSMethodSignature *sig = [TencentOAuth methodSignatureForSelector:userAgreed];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = [TencentOAuth class];
    inv.selector = userAgreed;
    BOOL flag = agreePrivacy;
    [inv setArgument:&flag atIndex:2];
    [inv invoke];
  }

  // ---- Universal Link（3.3.x+）----
  if (universalLink.length > 0) {
    SEL setUL = NSSelectorFromString(@"setUniversalLink:");
    if ([TencentOAuth respondsToSelector:setUL]) {
      NSMethodSignature *sig = [TencentOAuth methodSignatureForSelector:setUL];
      NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
      inv.target = [TencentOAuth class];
      inv.selector = setUL;
      [inv setArgument:&universalLink atIndex:2];
      [inv invoke];
    }
  }

  // ---- 构造 TencentOAuth ----
  TencentOAuth *oauth = nil;
  SEL initWithUL = NSSelectorFromString(@"initWithAppId:enableUniveralLink:universalLink:delegate:");
  if (universalLink.length > 0 &&
      [[TencentOAuth alloc] respondsToSelector:initWithUL]) {
    // 新 SDK 一步到位
    oauth = [TencentOAuth alloc];
    NSMethodSignature *sig = [oauth methodSignatureForSelector:initWithUL];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = oauth;
    inv.selector = initWithUL;
    BOOL yes = YES;
    id delegate = self;
    [inv setArgument:&appId atIndex:2];
    [inv setArgument:&yes atIndex:3];
    [inv setArgument:&universalLink atIndex:4];
    [inv setArgument:&delegate atIndex:5];
    [inv invoke];
    void *ret = NULL;
    [inv getReturnValue:&ret];
    oauth = (__bridge TencentOAuth *)ret;
  } else {
    oauth = [[TencentOAuth alloc] initWithAppId:appId andDelegate:self];
  }

  self.oauth = oauth;
  [self logFormat:@"registerApp appId=%@ ul=%@ agreePrivacy=%@",
   appId, universalLink ?: @"(nil)", agreePrivacy ? @"YES" : @"NO"];
}

#pragma mark - 工具方法

RCT_EXPORT_METHOD(isQQInstalled:(RCTResponseSenderBlock)callback) {
  BOOL installed = [QQApiInterface isQQInstalled];
  callback(@[[NSNull null], @(installed)]);
}

RCT_EXPORT_METHOD(getApiVersion:(RCTResponseSenderBlock)callback) {
  NSString *v = [TencentOAuth sdkVersion] ?: @"unknown";
  callback(@[[NSNull null], v]);
}

RCT_EXPORT_METHOD(checkUniversalLinkReady:(RCTResponseSenderBlock)callback) {
  SEL check = NSSelectorFromString(@"CheckUniversalLinkReady:");
  if (![TencentOAuth respondsToSelector:check]) {
    callback(@[@YES, @{
      @"suggestion": @"当前 TencentOpenAPI 不支持 Universal Link 自检，请升级到 3.3.x 以上版本",
      @"errorInfo": @"CheckUniversalLinkReady not available",
    }]);
    return;
  }
  __block BOOL replied = NO;
  void (^block)(NSInteger step, id result) = ^(NSInteger step, id result) {
    if (replied) return;
    BOOL success = [[result valueForKey:@"success"] boolValue];
    if (success) {
      // 全部步骤成功才算通过；这里到 final 才回
      if (step == 2 /* WXULCheckStepFinal 等效 */) {
        replied = YES;
        callback(@[[NSNull null], @{@"suggestion": @"", @"errorInfo": @""}]);
      }
      return;
    }
    replied = YES;
    NSString *suggestion = [result valueForKey:@"suggestion"] ?: @"";
    NSString *errorInfo = [result valueForKey:@"errorInfo"] ?: @"";
    callback(@[@YES, @{@"suggestion": suggestion, @"errorInfo": errorInfo}]);
  };

  NSMethodSignature *sig = [TencentOAuth methodSignatureForSelector:check];
  NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
  inv.target = [TencentOAuth class];
  inv.selector = check;
  [inv setArgument:&block atIndex:2];
  [inv invoke];
}

#pragma mark - Login

RCT_EXPORT_METHOD(login:(NSDictionary *)params
                  callback:(RCTResponseSenderBlock)callback) {
  if (!self.oauth) {
    callback(@[@"QQ SDK 未初始化，请先 registerApp"]);
    return;
  }
  NSString *scopesStr = params[@"scopes"];
  NSArray<NSString *> *scopes = nil;
  if ([scopesStr isKindOfClass:[NSString class]] && scopesStr.length > 0) {
    NSArray *raw = [scopesStr componentsSeparatedByString:@","];
    NSMutableArray *trimmed = [NSMutableArray arrayWithCapacity:raw.count];
    for (NSString *s in raw) {
      NSString *t = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
      if (t.length > 0) [trimmed addObject:t];
    }
    scopes = trimmed;
  } else {
    scopes = @[kOPEN_PERMISSION_GET_USER_INFO, kOPEN_PERMISSION_GET_SIMPLE_USER_INFO];
  }

  BOOL ok = [self.oauth authorize:scopes];
  if (!ok) {
    callback(@[@"authorize 调起失败，请确认 AppID / Info.plist URL Scheme / Universal Link 配置"]);
    return;
  }
  callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(logout) {
  [self.oauth logout:nil];
}

#pragma mark - 分享

RCT_EXPORT_METHOD(shareText:(NSDictionary *)params
                  callback:(RCTResponseSenderBlock)callback) {
  NSString *text = params[@"text"];
  NSString *scene = params[@"scene"] ?: @"qq";
  if (text.length == 0) { callback(@[@"text 不能为空"]); return; }
  QQApiTextObject *obj = [QQApiTextObject objectWithText:text];
  QQApiSendResultCode code = MdQQSend(obj, scene);
  if (code == EQQAPISENDSUCESS) {
    callback(@[[NSNull null]]);
  } else {
    callback(@[[NSString stringWithFormat:@"send code=%d", (int)code]]);
  }
}

RCT_EXPORT_METHOD(shareImage:(NSDictionary *)params
                  callback:(RCTResponseSenderBlock)callback) {
  NSString *imageUrl = params[@"imageUrl"];
  NSString *scene = params[@"scene"] ?: @"qq";
  NSData *data = MdQQLoadImageData(imageUrl);
  if (!data) { callback(@[[NSString stringWithFormat:@"无法加载图片：%@", imageUrl]]); return; }
  QQApiImageObject *obj = [QQApiImageObject objectWithData:data
                                          previewImageData:data
                                                     title:params[@"title"] ?: @""
                                               description:params[@"description"] ?: @""];
  QQApiSendResultCode code = MdQQSend(obj, scene);
  if (code == EQQAPISENDSUCESS) callback(@[[NSNull null]]);
  else callback(@[[NSString stringWithFormat:@"send code=%d", (int)code]]);
}

RCT_EXPORT_METHOD(shareLink:(NSDictionary *)params
                  callback:(RCTResponseSenderBlock)callback) {
  NSString *scene = params[@"scene"] ?: @"qq";
  NSData *thumb = MdQQLoadImageData(params[@"thumbImageUrl"]);
  QQApiNewsObject *obj = [QQApiNewsObject
                          objectWithURL:[NSURL URLWithString:params[@"webpageUrl"] ?: @""]
                          title:params[@"title"] ?: @""
                          description:params[@"description"] ?: @""
                          previewImageData:thumb];
  obj.targetContentType = QQApiURLTargetTypeNews;
  QQApiSendResultCode code = MdQQSend(obj, scene);
  if (code == EQQAPISENDSUCESS) callback(@[[NSNull null]]);
  else callback(@[[NSString stringWithFormat:@"send code=%d", (int)code]]);
}

RCT_EXPORT_METHOD(shareMusic:(NSDictionary *)params
                  callback:(RCTResponseSenderBlock)callback) {
  NSString *scene = params[@"scene"] ?: @"qq";
  NSData *thumb = MdQQLoadImageData(params[@"thumbImageUrl"]);
  QQApiAudioObject *obj = [QQApiAudioObject
                           objectWithURL:[NSURL URLWithString:params[@"webpageUrl"] ?: @""]
                           title:params[@"title"] ?: @""
                           description:params[@"description"] ?: @""
                           previewImageData:thumb];
  obj.targetContentType = QQApiURLTargetTypeAudio;
  obj.flashURL = [NSURL URLWithString:params[@"musicUrl"] ?: @""];
  QQApiSendResultCode code = MdQQSend(obj, scene);
  if (code == EQQAPISENDSUCESS) callback(@[[NSNull null]]);
  else callback(@[[NSString stringWithFormat:@"send code=%d", (int)code]]);
}

RCT_EXPORT_METHOD(shareMiniProgram:(NSDictionary *)params
                  callback:(RCTResponseSenderBlock)callback) {
  NSString *scene = params[@"scene"] ?: @"qq";
  Class miniCls = NSClassFromString(@"QQApiMiniProgramObject");
  if (!miniCls) {
    callback(@[@"当前 TencentOpenAPI 版本不支持 QQApiMiniProgramObject，请升级到 3.5.x+"]);
    return;
  }
  NSData *thumb = MdQQLoadImageData(params[@"thumbImageUrl"]);
  QQApiNewsObject *fallback = [QQApiNewsObject
                               objectWithURL:[NSURL URLWithString:params[@"webpageUrl"] ?: @""]
                               title:params[@"title"] ?: @""
                               description:params[@"description"] ?: @""
                               previewImageData:thumb];
  fallback.targetContentType = QQApiURLTargetTypeNews;
  id miniObj = [[miniCls alloc] init];
  if ([miniObj respondsToSelector:@selector(setMiniAppID:)])    [miniObj setValue:params[@"miniAppId"] forKey:@"miniAppID"];
  if ([miniObj respondsToSelector:@selector(setMiniPath:)])     [miniObj setValue:params[@"miniPath"] forKey:@"miniPath"];
  if ([miniObj respondsToSelector:@selector(setWebpageUrl:)])   [miniObj setValue:params[@"webpageUrl"] forKey:@"webpageUrl"];
  if ([miniObj respondsToSelector:@selector(setMiniprogramType:)]) {
    NSNumber *t = params[@"miniProgramType"] ?: @(3);
    [miniObj setValue:t forKey:@"miniprogramType"];
  }
  if ([miniObj respondsToSelector:@selector(setQqApiObject:)])  [miniObj setValue:fallback forKey:@"qqApiObject"];

  QQApiSendResultCode code = MdQQSend(miniObj, scene);
  if (code == EQQAPISENDSUCESS) callback(@[[NSNull null]]);
  else callback(@[[NSString stringWithFormat:@"send code=%d", (int)code]]);
}

RCT_EXPORT_METHOD(shareVideo:(NSDictionary *)params
                  callback:(RCTResponseSenderBlock)callback) {
  NSString *videoUrl = MdQQResolveLocalPath(params[@"videoUrl"]);
  if (videoUrl.length == 0) { callback(@[@"video 路径无效"]); return; }
  QQApiVideoForQZoneObject *obj = [QQApiVideoForQZoneObject
                                   objectWithAssetURL:videoUrl
                                   title:params[@"title"] ?: @""
                                   extMap:nil];
  SendMessageToQQReq *req = [SendMessageToQQReq reqWithContent:obj];
  QQApiSendResultCode code = [QQApiInterface SendReqToQZone:req];
  if (code == EQQAPISENDSUCESS) callback(@[[NSNull null]]);
  else callback(@[[NSString stringWithFormat:@"send code=%d", (int)code]]);
}

RCT_EXPORT_METHOD(publishToQzone:(NSDictionary *)params
                  callback:(RCTResponseSenderBlock)callback) {
  NSArray<NSString *> *urls = params[@"imageUrls"];
  NSMutableArray<NSData *> *images = [NSMutableArray arrayWithCapacity:urls.count];
  for (NSString *u in urls) {
    NSData *d = MdQQLoadImageData(u);
    if (!d) { callback(@[[NSString stringWithFormat:@"无法加载图片：%@", u]]); return; }
    [images addObject:d];
  }
  QQApiImageArrayForQZoneObject *obj = [QQApiImageArrayForQZoneObject
                                        objectWithimageDataArray:images
                                        title:params[@"text"] ?: @""
                                        extMap:nil];
  SendMessageToQQReq *req = [SendMessageToQQReq reqWithContent:obj];
  QQApiSendResultCode code = [QQApiInterface SendReqToQZone:req];
  if (code == EQQAPISENDSUCESS) callback(@[[NSNull null]]);
  else callback(@[[NSString stringWithFormat:@"send code=%d", (int)code]]);
}

#pragma mark - TencentSessionDelegate

- (void)tencentDidLogin {
  TencentOAuth *o = self.oauth;
  NSDictionary *payload = @{
    @"openId": o.openId ?: @"",
    @"accessToken": o.accessToken ?: @"",
    @"expiresIn": @(o.expirationDate ? [o.expirationDate timeIntervalSinceNow] : 0),
    @"expirationDate": @(o.expirationDate ? [o.expirationDate timeIntervalSince1970] : 0),
  };
  [self emitResponse:@"AuthResp" errorCode:0 errorStr:nil data:payload];
}

- (void)tencentDidNotLogin:(BOOL)cancelled {
  [self emitResponse:@"AuthResp"
           errorCode:(cancelled ? -2 : -3)
            errorStr:(cancelled ? @"用户取消登录" : @"登录失败")
                data:nil];
}

- (void)tencentDidNotNetWork {
  [self emitResponse:@"AuthResp" errorCode:-4 errorStr:@"网络不可用" data:nil];
}

#pragma mark - QQApiInterfaceDelegate

- (void)onReq:(QQBaseReq *)req {
  // 收到第三方对外发起的请求，本场景用不到
}

- (void)onResp:(QQBaseResp *)resp {
  NSInteger code = [resp.result integerValue];
  NSString *errStr = (code == 0) ? nil : (resp.errorDescription ?: @"分享失败");

  NSString *type = @"ShareResp";
  if ([resp isKindOfClass:NSClassFromString(@"SendMessageToQQResp")]) {
    type = @"ShareResp";
  }
  [self emitResponse:type errorCode:code errorStr:errStr data:@{}];
}

- (void)isOnlineResponse:(NSDictionary *)response {
  // 不处理
}

@end
