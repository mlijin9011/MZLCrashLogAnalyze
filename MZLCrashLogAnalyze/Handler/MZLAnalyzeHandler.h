//
//  MZLAnalyzeHandler.h
//  MZLCrashLogAnalyze
//
//  Created by lijin22 on 2018/5/1.
//  Copyright © 2018年 lijin. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MZLShellScriptHandler.h"
#import "MZLFileHandler.h"

#define WeakSelf(weakSelf)  __weak __typeof(&*self)weakSelf                       = self;
#define StrongSelf(strongSelf, weakSelf)  __strong __typeof(&*weakSelf)strongSelf = weakSelf;

#define WEAKSELF                          WeakSelf(weakSelf)
#define STRONGSELF StrongSelf(strongSelf, weakSelf)

@interface MZLAnalyzeHandler : NSObject

@property (nonatomic, copy) NSString *crashFolderPath;  // ~/Download/CrashLog

+ (instancetype)sharedInstance;

/**
 每次解析前检查文件夹
 */
- (void)checkCrashLogDirectory;

/**
 日志解析
 
 @param ipsPath    ipsPath
 @param dsymPath   dsymPath
 @param outputPath outputPath
 @param completion completion
 */
+ (void)analyzeCrashLog:(NSString *)ipsPath dsymPath:(NSString *)dsymPath outputPath:(NSString *)outputPath completion:(void (^)(BOOL success))completion;

/**
 打开解析完的日志
 @param logPath  logPath
 */
+ (void)openCrashLog:(NSString *)logPath;

/**
 Show Alert

 @param title title
 @param msg   message
 @param block click handler block
 */
+ (void)showAlertView:(NSString *)title message:(NSString *)msg excuteblock:(dispatch_block_t)block;

@end
