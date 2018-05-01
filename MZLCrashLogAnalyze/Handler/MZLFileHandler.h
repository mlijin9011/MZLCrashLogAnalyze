//
//  MZLFileHandler.h
//  MZLCrashLogAnalyze
//
//  Created by lijin22 on 2018/5/1.
//  Copyright © 2018年 lijin. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*! 文件类型*/
typedef NS_OPTIONS(NSUInteger, MZLCrashFileType) {
    MZLCrashFileType_All = 0,
    MZLCrashFileType_DSYM,
    MZLCrashFileType_Ips,
    MZLCrashFileType_Crash,
};

@interface MZLFileHandler : NSObject

+ (void)handlerWithFileType:(MZLCrashFileType)type completion:(void (^)(NSString *filePath))completion;

@end
