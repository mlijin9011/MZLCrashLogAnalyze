//
//  MZLShellScriptHandler.m
//  MZLCrashLogAnalyze
//
//  Created by lijin22 on 2018/5/1.
//  Copyright © 2018年 lijin. All rights reserved.
//

#import "MZLShellScriptHandler.h"

@interface MZLShellScriptHandler ()

@property (nonatomic, strong) NSTask *shellTask;

@end

@implementation MZLShellScriptHandler

+ (instancetype)sharedInstance {
    static MZLShellScriptHandler *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

+ (NSString *)shellPath:(NSString *)shellName {
    return [[NSBundle mainBundle] pathForResource:shellName ofType:@"sh"];
}

/**
 执行shell脚本
 
 @param shellName 脚本名称
 @param args 参数
 @param completion 脚本运行完成回调
 */
+ (void)executeShellScript:(NSString *)shellName
                      args:(NSArray<NSString *> *)args
                completion:(void (^)(BOOL success))completion {
    NSCParameterAssert(shellName);
    
    [[MZLShellScriptHandler sharedInstance] executeShellScript:shellName args:args completion:completion];
}

- (void)executeShellScript:(NSString *)shellName
                      args:(NSArray<NSString *> *)args
                completion:(void (^)(BOOL success))completion {
    [self stopShellScriptTask];
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSString *shellPath = [MZLShellScriptHandler shellPath:shellName];
        NSError *error;
        self.shellTask = [NSTask launchedTaskWithExecutableURL:[NSURL fileURLWithPath:shellPath] arguments:[NSArray arrayWithArray:args] error:&error terminationHandler:^(NSTask * _Nonnull task) {
            BOOL success = ([task terminationStatus] == 0);
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                if (completion) {
                    completion(success);
                }
            });
        }];
        [self.shellTask waitUntilExit];
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (completion) {
                completion(error == nil);
            }
        });
    });
}

/**
 停止执行中的 shell task
 */
+ (void)stopShellScriptTask {
    [[MZLShellScriptHandler sharedInstance] stopShellScriptTask];
}

- (void)stopShellScriptTask {
    if (self.shellTask) {
        if (self.shellTask.isRunning) {
            [self.shellTask terminate];
        }
        self.shellTask = nil;
    }
}

@end
