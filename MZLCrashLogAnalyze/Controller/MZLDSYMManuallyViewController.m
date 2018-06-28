//
//  MZLDSYMManuallyViewController.m
//  MZLCrashLogAnalyze
//
//  Created by lijin22 on 2018/5/1.
//  Copyright © 2018年 lijin. All rights reserved.
//

#import "MZLDSYMManuallyViewController.h"
#import "MZLAnalyzeHandler.h"
#import "HTMLParser.h"
#import "SSZipArchive.h"

@interface MZLDSYMManuallyViewController ()

@property (weak) IBOutlet NSButton *dsymSelectButton;
@property (weak) IBOutlet NSTextField *dsymPathTextField;
@property (weak) IBOutlet NSButton *ipsSelectButton;
@property (weak) IBOutlet NSTextField *ipsPathTextField;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSTextField *progressLabel;
@property (weak) IBOutlet NSButton *startButton;
@property (weak) IBOutlet NSButton *cancelButton;

@property (nonatomic, copy) NSString *dsymZipPath;
@property (nonatomic, copy) NSString *dsymPath;
@property (nonatomic, copy) NSString *ipsPath;

@property (nonatomic, assign) BOOL isAnalyzeing;
@property (nonatomic, strong) NSURLSession *downloadSession;

@end

@implementation MZLDSYMManuallyViewController

#pragma mark ==================== LifeCycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

#pragma mark ==================== Action

- (IBAction)startAnalyzeAction:(id)sender {
    if ([self checkInputNameValid]) {
        [self startAnalyzeUI];
        [self startAnalyze];
    }
}

- (IBAction)cancelAnalyzeAction:(id)sender {
    [self stopAnalyze];
    [self stopAnalyzeUI];
}

- (IBAction)selectDsymAction:(id)sender {
    WEAKSELF
    [MZLFileHandler handlerWithFileType:MZLCrashFileType_DSYM completion:^(NSString *filePath) {
        if (filePath.length > 0) {
            STRONGSELF
            strongSelf.dsymZipPath = nil;
            strongSelf.dsymPath = nil;
            if ([[filePath pathExtension] isEqualToString:@"zip"]) {
                strongSelf.dsymZipPath = filePath;
            } else if ([[filePath pathExtension] isEqualToString:@"dSYM"]) {
                strongSelf.dsymPath = filePath;
            }
            strongSelf.dsymPathTextField.stringValue = [filePath lastPathComponent];
        }
    }];
}

- (IBAction)selectIpsAction:(id)sender {
    WEAKSELF
    [MZLFileHandler handlerWithFileType:MZLCrashFileType_Ips completion:^(NSString *filePath) {
        if (filePath.length > 0) {
            STRONGSELF
            strongSelf.ipsPath = filePath;
            strongSelf.ipsPathTextField.stringValue = [filePath lastPathComponent];
        }
    }];
}

#pragma mark ==================== UI

- (void)startAnalyzeUI {
    self.isAnalyzeing = YES;
    self.startButton.enabled = NO;
    self.cancelButton.enabled = YES;
    [self.progressIndicator startAnimation:self];
    self.progressLabel.stringValue = @"";
}

- (void)stopAnalyzeUI {
    self.isAnalyzeing = NO;
    WEAKSELF
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        STRONGSELF
        strongSelf.startButton.enabled = YES;
        strongSelf.cancelButton.enabled = NO;
        [strongSelf.progressIndicator stopAnimation:self];
        strongSelf.progressLabel.stringValue = @"";
    });
}

- (void)showProgressTip:(NSString *)tip {
    if ([NSThread isMainThread]) {
        self.progressLabel.stringValue = tip;
    } else {
        WEAKSELF
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            STRONGSELF
            strongSelf.progressLabel.stringValue = tip;
        });
    }
}

#pragma mark ==================== Progress

/**
 检查 ipa 包名是否已输入，ips 日志路径是否已选择
 */
- (BOOL)checkInputNameValid {
    if (self.dsymPath.length <= 0 && self.dsymZipPath.length <= 0) {
        [self showProgressTip:@"请选择 dsym 路径"];
        return NO;
    } else if (self.ipsPath.length <= 0) {
        [self showProgressTip:@"请选择 ips 路径"];
        return NO;
    }
    
    return YES;
}

- (BOOL)checkDsymZipExists {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *dsymZipPath = self.dsymZipPath;
    if ([fileManager fileExistsAtPath:dsymZipPath]) {
        return YES;
    }
    return NO;
}

- (BOOL)checkDsymFileExists {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (self.dsymPath.length > 0) {
        if ([fileManager fileExistsAtPath:self.dsymPath]) {
            return YES;
        }
    } else if (self.dsymZipPath.length > 0) {
        self.dsymPath = nil;
        NSString *folderPath = [self.dsymZipPath stringByDeletingPathExtension];
        NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtPath:folderPath];
        NSString *path = folderPath;
        while ((path = [enumerator nextObject]) != nil) {
            if ([path hasSuffix:@"SinaNews.app.dSYM"]) {
                self.dsymPath = [folderPath stringByAppendingPathComponent:path];
                return YES;
            }
        }
    }
    
    return NO;
}

- (void)startAnalyze {
    // 每次解析前检查文件夹
    [[MZLAnalyzeHandler sharedInstance] checkCrashLogDirectory];
    
    if ([self checkDsymFileExists]) {
        // 有 dsym 文件 -> 解析
        [self analyze];
    } else {
        // 没有 dsym 文件
        if ([self checkDsymZipExists]) {
            // 有 dsym zip 文件 -> 解压 & 解析
            [self unzipDsymAndAnalyze];
        } else {
            [self stopAnalyzeUI];
            [MZLAnalyzeHandler showAlertView:@"失败" message:@"找不到 dsym 文件" excuteblock:nil];
        }
    }
}

- (void)stopAnalyze {
    [MZLShellScriptHandler stopShellScriptTask];
}

#pragma mark ==================== Unzip

- (void)unzipDsymAndAnalyze {
    if (!self.isAnalyzeing) {
        return;
    }
    
    [self showProgressTip:@"解压下载的 dsym zip 文件"];
    
    NSString *dsymZipPath = self.dsymZipPath;
    NSString *dsymFilePath = [self.dsymZipPath stringByDeletingLastPathComponent];
    [self unZipFile:dsymZipPath destination:dsymFilePath];
}

- (void)unZipFile:(NSString *)zipPath destination:(NSString *)destinationPath {
    if (!self.isAnalyzeing) {
        return;
    }
    
    WEAKSELF
    dispatch_async(dispatch_get_global_queue(0, 0), ^(void) {
        STRONGSELF
        NSError *error;
        BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:destinationPath overwrite:YES password:nil error:&error delegate:nil];
        if (success && !error && [strongSelf checkDsymFileExists]) {
            [strongSelf analyze];
        } else if (self.isAnalyzeing) {
            [strongSelf stopAnalyzeUI];
            [MZLAnalyzeHandler showAlertView:@"失败" message:@"解压 dsym zip 失败" excuteblock:nil];
        }
    });
}

#pragma mark ==================== Analyze

- (void)analyze {
    if (!self.isAnalyzeing) {
        return;
    }
    
    [self showProgressTip:@"解析 crash log"];
    
    NSString *dsymPath = self.dsymPath;
    NSString *fileName = [[self.ipsPath lastPathComponent] stringByDeletingPathExtension];
    NSString *outputPath = [[[MZLAnalyzeHandler sharedInstance].crashFolderPath stringByAppendingPathComponent:fileName] stringByAppendingFormat:@".crash"];
    WEAKSELF
    [MZLAnalyzeHandler analyzeCrashLog:self.ipsPath dsymPath:dsymPath outputPath:outputPath completion:^(BOOL success) {
        STRONGSELF
        if (success) {
            [strongSelf showAnalyzeFinishAlert:outputPath];
        } else {
            [MZLAnalyzeHandler showAlertView:@"失败" message:@"解析失败" excuteblock:nil];
        }
        [strongSelf stopAnalyzeUI];
    }];
}

- (void)showAnalyzeFinishAlert:(NSString *)outputPath {
    if (!self.isAnalyzeing) {
        return;
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [MZLAnalyzeHandler showAlertView:@"解析完成" message:[NSString stringWithFormat:@"解析出的文件路径为:%@", outputPath] excuteblock:^{
            [MZLAnalyzeHandler openCrashLog:outputPath];
        }];
    });
}

@end
