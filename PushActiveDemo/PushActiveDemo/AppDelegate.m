//
//  AppDelegate.m
//  PushActiveDemo
//
//  Created by 提运佳 on 2018/4/11.
//  Copyright © 2018年 提运佳. All rights reserved.
//

#import "AppDelegate.h"

#import <AVFoundation/AVFoundation.h>

// 引入JPush功能所需头文件
#import "JPUSHService.h"
// iOS10注册APNs所需头文件
#ifdef NSFoundationVersionNumber_iOS_9_x_Max
#import <UserNotifications/UserNotifications.h>
#endif

static NSString * appKey = @"b5df1b6e5dc19bf2f161a744";
static NSString * channel = @"Test";
static BOOL isProduction = NO;

@interface AppDelegate ()<JPUSHRegisterDelegate,AVSpeechSynthesizerDelegate>{
    AVSpeechSynthesizer*av;
}
@property (nonatomic, assign) UIBackgroundTaskIdentifier bgTaskId;

@end

@implementation AppDelegate

- (void)playMsgWith:(NSString *)msg {
    //初始化对象
    av = [[AVSpeechSynthesizer alloc]init];
    av.delegate = self;//挂上代理
    AVSpeechSynthesisVoice*voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"zh-CN"];//设置发音，这是中文普通话
    AVSpeechUtterance*utterance = [[AVSpeechUtterance alloc]initWithString:msg];//需要转换的文字
    utterance.rate = 0.6;// 设置语速，范围0-1，注意0最慢，1最快；
    utterance.voice = voice;
    [av speakUtterance:utterance];//开始
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didStartSpeechUtterance:(AVSpeechUtterance *)utterance {
    NSLog(@"开始播报");
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance {
    NSLog(@"结束播报");
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    /**
     添加初始化APNs代码
     */
    //Required
    JPUSHRegisterEntity * entity = [[JPUSHRegisterEntity alloc] init];
    entity.types = JPAuthorizationOptionAlert|JPAuthorizationOptionBadge|JPAuthorizationOptionSound;
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 8.0) {
        // 可以添加自定义categories
        // NSSet<UNNotificationCategory *> *categories for iOS10 or later
        // NSSet<UIUserNotificationCategory *> *categories for iOS8 and iOS9
    }
    [JPUSHService registerForRemoteNotificationConfig:entity delegate:self];
    
    /**
     添加初始化JPush代码
     */
    // Required
    // init Push
    [JPUSHService setupWithOption:launchOptions
                           appKey:appKey
                          channel:channel
                 apsForProduction:isProduction
            advertisingIdentifier:nil];
    
    return YES;
}

/**
 注册APNs成功并上报DeviceToken
 */
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    // Required - 注册 DeviceToken
    [JPUSHService registerDeviceToken:deviceToken];
}

/**
 添加处理APNs通知回调方法
 */
#ifdef NSFoundationVersionNumber_iOS_9_x_Max
#pragma mark- JPUSHRegisterDelegate
// iOS 10 Support
- (void)jpushNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(NSInteger))completionHandler {
    // Required
    NSDictionary * userInfo = notification.request.content.userInfo;
    if([notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
        [JPUSHService handleRemoteNotification:userInfo];
    }
    completionHandler(UNNotificationPresentationOptionAlert); // 需要执行这个方法，选择是否提醒用户，有Badge、Sound、Alert三种类型可以选择设置
}

// iOS 10 Support
- (void)jpushNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)())completionHandler {
    // Required
    NSDictionary * userInfo = response.notification.request.content.userInfo;
    if([response.notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
        [JPUSHService handleRemoteNotification:userInfo];
    }
    completionHandler();  // 系统要求执行这个方法
}
#endif

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    // Required, iOS 7 Support
    [JPUSHService handleRemoteNotification:userInfo];
    NSLog(@"iOS7及以上系统，收到通知:%@", [self logDic:userInfo]);
    [self playMsgWith:@"你大爷你大爷你大爷"];

    completionHandler(UIBackgroundFetchResultNewData);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    NSLog(@"iOS6及以下系统，收到通知:%@", [self logDic:userInfo]);

    // Required,For systems with less than or equal to iOS6
    [JPUSHService handleRemoteNotification:userInfo];
}

//程序失去焦点
-(void)applicationWillResignActive:(UIApplication* )application
{    //开启后台处理多媒体事件
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setActive:YES error:nil];
    //后台播放
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    //这样做，可以在按home键进入后台后 ，播放一段时间，几分钟吧。
    //但是不能持续播放网络歌曲，若需要持续播放网络歌曲，还需要申请后台任务id，具体做法是：
    //其中的_bgTaskId是后台任务UIBackgroundTaskIdentifier _bgTaskId;
    _bgTaskId = [AppDelegate backgroundPlayerID:_bgTaskId];

//    UIApplication *app = [UIApplication sharedApplication];
//    __block UIBackgroundTaskIdentifier backTaskId;
//    backTaskId = [app beginBackgroundTaskWithExpirationHandler:^{
//        NSLog(@"===在额外申请的时间内依然没有完成任务===");
//        [app endBackgroundTask:backTaskId];
//    }];
//    if(backTaskId == UIBackgroundTaskInvalid){
//        NSLog(@"===iOS版本不支持后台运行,后台任务启动失败===");
//        return;
//    }
//
//    dispatch_async(dispatch_get_main_queue(), ^{
//        NSLog(@"===额外申请的后台任务时间为: %f===",app.backgroundTimeRemaining);
//    });
}

//实现一下backgroundPlayerID:这个方法:
+ (UIBackgroundTaskIdentifier)backgroundPlayerID:(UIBackgroundTaskIdentifier)backTaskId
{   //设置并激活音频会话类别
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    [session setActive:YES error:nil];
    //允许应用程序接收远程控制
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    //设置后台任务ID
    UIBackgroundTaskIdentifier newTaskId = UIBackgroundTaskInvalid;
    newTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
    if(newTaskId != UIBackgroundTaskInvalid && backTaskId != UIBackgroundTaskInvalid)
    {
        [[UIApplication sharedApplication] endBackgroundTask:backTaskId];
    }
    
    UIApplication *app = [UIApplication sharedApplication];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"===额外申请的后台任务时间为: %f===",app.backgroundTimeRemaining);
    });
    
    return newTaskId;
}

// log NSSet with UTF8
// if not ,log will be \Uxxx
- (NSString *)logDic:(NSDictionary *)dic {
    if (![dic count]) {
        return nil;
    }
    NSString *tempStr1 =
    [[dic description] stringByReplacingOccurrencesOfString:@"\\u"
                                                 withString:@"\\U"];
    NSString *tempStr2 =
    [tempStr1 stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    NSString *tempStr3 =
    [[@"\"" stringByAppendingString:tempStr2] stringByAppendingString:@"\""];
    NSData *tempData = [tempStr3 dataUsingEncoding:NSUTF8StringEncoding];
    NSString *str =
    [NSPropertyListSerialization propertyListFromData:tempData
                                     mutabilityOption:NSPropertyListImmutable
                                               format:NULL
                                     errorDescription:NULL];
    return str;
}

@end
