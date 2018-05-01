//
//  MZLShellScriptHandler.h
//  MZLCrashLogAnalyze
//
//  Created by lijin22 on 2018/5/1.
//  Copyright © 2018年 lijin. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MZLShellScriptHandler : NSObject

+ (instancetype)sharedInstance;

/**
 执行shell脚本
 
 @param shellName 脚本名称
 @param args 参数
 @param completion 脚本运行完成回调
 */
+ (void)executeShellScript:(NSString *)shellName
                      args:(NSArray<NSString *> *)args
                completion:(void (^)(BOOL success))completion;

/**
 停止执行中的 shell task
 */
+ (void)stopShellScriptTask;

@end
