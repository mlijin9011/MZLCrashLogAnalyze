//
//  MZLAnalyzeHandler.m
//  MZLCrashLogAnalyze
//
//  Created by lijin22 on 2018/5/1.
//  Copyright © 2018年 lijin. All rights reserved.
//

#import "MZLAnalyzeHandler.h"

@interface MZLAnalyzeHandler ()

@property (nonatomic, copy) NSString *symbolicatecrash;

@end

@implementation MZLAnalyzeHandler

+ (instancetype)sharedInstance {
    static MZLAnalyzeHandler *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self checkCrashLogDirectory];
    }
    return self;
}

- (void)checkCrashLogDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES);
    if (paths && paths.count > 0) {
        NSString *desktopPath = paths[0];
        if (desktopPath.length > 0) {
            NSFileManager *fileManager = [NSFileManager defaultManager];
            BOOL isDir;
            if ([fileManager fileExistsAtPath:desktopPath isDirectory:&isDir]) {
                _crashFolderPath = [desktopPath stringByAppendingPathComponent:@"CrashLog"];
                _symbolicatecrash = [_crashFolderPath stringByAppendingPathComponent:@"symbolicatecrash"];
                if (![fileManager fileExistsAtPath:_crashFolderPath isDirectory:&isDir]) {
                    [fileManager createDirectoryAtPath:_crashFolderPath withIntermediateDirectories:YES attributes:nil error:nil];
                }
            }
        }
    }
    if (_symbolicatecrash.length > 0) {
        [self findSymbolicatePath];
    }
}

- (void)findSymbolicatePath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir;
    if ([fileManager fileExistsAtPath:_symbolicatecrash isDirectory:&isDir]) {
        return;
    }
    // 复制 symbolicatecrash 到 CrashLog 文件夹
    [MZLShellScriptHandler executeShellScript:@"findSymbolicatecrash" args:nil completion:nil];
}

+ (void)analyzeCrashLog:(NSString *)ipsPath dsymPath:(NSString *)dsymPath outputPath:(NSString *)outputPath completion:(void (^)(BOOL success))completion {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        NSString *arg1 = [MZLAnalyzeHandler sharedInstance].symbolicatecrash;
        NSString *arg2 = ipsPath;
        NSString *arg3 = dsymPath;
        NSString *arg4 = outputPath;
        
        if (arg1.length > 0 && arg2.length > 0 && arg3.length > 0 && arg4.length > 0) {
            [MZLShellScriptHandler executeShellScript:@"analyzeCrashLog" args:@[arg1, arg2, arg3, arg4] completion:^(BOOL success) {
                if (completion) {
                    completion(success);
                }
            }];
        } else {
            if (completion) {
                completion(NO);
            }
        }
    });
}

+ (void)openCrashLog:(NSString *)logPath {
    NSAppleEventDescriptor *eventDescriptor = nil;
    NSAppleScript *script = nil;
    NSString *scriptSource = [NSString stringWithFormat:@"tell application \"Console\"\r"
                              //                              "activate\r"
                              "open \"%@\"\r"
                              "end tell", logPath];
    
    if (scriptSource)
    {
        script = [[NSAppleScript alloc] initWithSource:scriptSource];
        if (script)
        {
            eventDescriptor = [script executeAndReturnError:nil];
            if (eventDescriptor)
            {
                NSLog(@"%@", [eventDescriptor stringValue]);
            }
        }
    }
}

+ (void)showAlertView:(NSString *)title message:(NSString *)msg excuteblock:(dispatch_block_t)block {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        NSAlert *alert = [[NSAlert alloc] init];
        if (block) {
            [alert addButtonWithTitle:@"直接打开"];
        }
        [alert addButtonWithTitle:@"知道了~"];
        [alert setMessageText:title];
        [alert setInformativeText:msg];
        [alert setAlertStyle:NSAlertStyleInformational];
        [alert beginSheetModalForWindow:[NSApplication sharedApplication].keyWindow completionHandler:^(NSInteger returnCode) {
            if (returnCode == 1000) {
                if (block) {
                    block();
                }
            }
        }];
    });
}

@end
