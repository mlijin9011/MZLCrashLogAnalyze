//
//  MZLFileHandler.m
//  MZLCrashLogAnalyze
//
//  Created by lijin22 on 2018/5/1.
//  Copyright © 2018年 lijin. All rights reserved.
//

#import "MZLFileHandler.h"

@implementation MZLFileHandler

+ (void)handlerWithFileType:(MZLCrashFileType)type completion:(void (^)(NSString *filePath))completion {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.showsHiddenFiles     = NO;
    openPanel.canChooseDirectories = NO;
    openPanel.canChooseFiles       = YES;
    openPanel.allowedFileTypes     = [self allowFileTypes:type];
    
    NSWindow *mainWindow = [NSApplication sharedApplication].mainWindow;
    [openPanel beginSheetModalForWindow:mainWindow completionHandler:^(NSInteger result) {
        NSString *path = nil;
        if (result == NSModalResponseOK) {
            path = openPanel.URL.path;
        }
        if (completion) {
            completion(path);
        }
    }];
}

+ (NSArray *)allowFileTypes:(MZLCrashFileType)type {
    NSMutableArray *fileTypesArray = [NSMutableArray array];
    switch (type) {
        case MZLCrashFileType_DSYM:
            [fileTypesArray addObject:@"dSYM"];
            [fileTypesArray addObject:@"zip"];
            break;
        case MZLCrashFileType_Ips:
            [fileTypesArray addObject:@"ips"];
            [fileTypesArray addObject:@"crash"];
            break;
        case MZLCrashFileType_Crash:
            [fileTypesArray addObject:@"crash"];
            break;
        default:
            break;
    }
    return fileTypesArray;
}

@end
