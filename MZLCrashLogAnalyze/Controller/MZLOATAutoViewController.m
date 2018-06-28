//
//  MZLOATAutoViewController.m
//  MZLCrashLogAnalyze
//
//  Created by lijin22 on 2018/5/1.
//  Copyright © 2018年 lijin. All rights reserved.
//

#import "MZLOATAutoViewController.h"
#import "MZLAnalyzeHandler.h"
#import "HTMLParser.h"
#import "SSZipArchive.h"

@interface MZLOATAutoViewController ()

@property (weak) IBOutlet NSTextField *ipaNameTextField;
@property (weak) IBOutlet NSButton *ipsSelectButton;
@property (weak) IBOutlet NSTextField *ipsPathTextField;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSTextField *progressLabel;
@property (weak) IBOutlet NSButton *startButton;
@property (weak) IBOutlet NSButton *cancelButton;

@property (nonatomic, copy) NSString *ipaName;
@property (nonatomic, copy) NSString *ipsPath;
@property (nonatomic, copy) NSString *dsymPath;

@property (nonatomic, assign) BOOL isAnalyzeing;
@property (nonatomic, strong) NSURLSessionDownloadTask *downloadTask;

@end

@implementation MZLOATAutoViewController

#pragma mark ==================== LifeCycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

#pragma mark ==================== Action

- (IBAction)startAnalyzeAction:(id)sender {
    self.ipaName = self.ipaNameTextField.stringValue;
    
    if ([self checkInputNameValid]) {
        [self startAnalyzeUI];
        [self startAnalyze];
    }
}

- (IBAction)cancelAnalyzeAction:(id)sender {
    [self stopAnalyze];
    [self stopAnalyzeUI];
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
    if (self.ipaName.length <= 0) {
        [self showProgressTip:@"请输入 ipa 包名"];
        return NO;
    } else if (self.ipsPath.length <= 0) {
        [self showProgressTip:@"请选择 ips 路径"];
        return NO;
    }
    
    return YES;
}

- (BOOL)checkDsymZipExists {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *dsymZipPath = [[MZLAnalyzeHandler sharedInstance].crashFolderPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.zip", self.ipaName]];
    if ([fileManager fileExistsAtPath:dsymZipPath]) {
        return YES;
    }
    return NO;
}

- (BOOL)checkDsymFileExists {
    self.dsymPath = nil;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *folderPath = [[MZLAnalyzeHandler sharedInstance].crashFolderPath stringByAppendingPathComponent:self.ipaName];
    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtPath:folderPath];
    NSString *path = folderPath;
    while ((path = [enumerator nextObject]) != nil) {
        if ([path hasSuffix:@"SinaNews.app.dSYM"]) {
            self.dsymPath = [folderPath stringByAppendingPathComponent:path];
            return YES;
        }
    }
    return NO;
}

- (void)startAnalyze {
    // 每次解析前检查文件夹
    [[MZLAnalyzeHandler sharedInstance] checkCrashLogDirectory];
    
    if ([self checkDsymZipExists]) {
        // 有 dsym zip 文件
        if ([self checkDsymFileExists]) {
            // 有 dsym 文件 -> 解析
            [self analyze];
        } else {
            // 没有 dsym 文件 -> 解压 & 解析
            [self unzipDsymAndAnalyze];
        }
    } else {
        // 没有 dsym zip 文件 -> 下载
        WEAKSELF
        dispatch_async(dispatch_get_global_queue(0, 0), ^(void) {
            STRONGSELF
            NSString *url = [strongSelf findDsymUrl];
            if (url.length > 0) {
                [strongSelf downloadDsymAndAnalyze:url];
            } else {
                [strongSelf stopAnalyzeUI];
                [MZLAnalyzeHandler showAlertView:@"失败" message:@"OTA 上找不到此 ipa 包名对应的 dsym 下载地址" excuteblock:nil];
            }
        });
    }
}

- (void)stopAnalyze {
    [self stopDownloadDsym];
    [MZLShellScriptHandler stopShellScriptTask];
}

#pragma mark ==================== FindDsym

- (NSString *)findDsymUrl {
    [self showProgressTip:@"根据包名获取 OTA 上对应的 pkg_type"];
    
    NSString *packageType = [[self.ipaName componentsSeparatedByString:@"_"] lastObject];
    if (packageType.length > 0) {
        // Debug 包默认 pkg_type = 1
        NSInteger type = 1;
        if ([packageType isEqualToString:@"Inhouse"]) {
            type = 0;
        } else if ([packageType isEqualToString:@"Internal"]) {
            type = 2;
        } else if ([packageType isEqualToString:@"Release"]) {
            type = 99;
        }
        
        [self showProgressTip:@"在 OTA 上查找 ipa 包名对应的 dsym 下载路径"];
        for (NSInteger page = 0; page <= 15; page++) {
            if (!self.isAnalyzeing) {
                break;
            }
            
            NSString *url = [self findDsymUrl:page type:type];
            if (url) {
                return url;
            }
        }
    }
    return nil;
}

- (NSString *)findDsymUrl:(NSInteger)page type:(NSInteger)type {
    NSError *error = nil;
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://ota.client.weibo.cn/ios/gpackages/com.sina.sinanews?page=%d&pkg_type=%d", (int)page, (int)type]];
    NSString *html = [[NSString alloc] initWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
    HTMLParser *parser = [[HTMLParser alloc] initWithString:html error:&error];
    
    if (error) {
        return nil;
    }
    
    HTMLNode *bodyNode = [parser body];
    NSArray *aNodes = [bodyNode findChildTags:@"a"];
    for (HTMLNode *aNode in aNodes) {
        NSString *href = [aNode getAttributeNamed:@"href"];
        if ([href hasSuffix:@"dsym.zip"] && [href containsString:self.ipaName]) {
            return href;
        }
    }
    return nil;
}

#pragma mark ==================== Download

- (void)downloadDsymAndAnalyze:(NSString *)url {
    [self showProgressTip:@"下载 dsym zip 文件"];
    
    WEAKSELF
    [self startDownloadDsym:url completion:^(BOOL success) {
        STRONGSELF
        if (success && [strongSelf checkDsymZipExists]) {
            // 下载成功 -> 解压 & 解析
            [strongSelf unzipDsymAndAnalyze];
        } else if (self.isAnalyzeing) {
            // 下载失败
            [strongSelf stopAnalyzeUI];
            [MZLAnalyzeHandler showAlertView:@"失败" message:@"下载 dsym zip 失败" excuteblock:nil];
        }
    }];
}

- (void)startDownloadDsym:(NSString *)url completion:(void (^)(BOOL success))completion {
    if (!self.isAnalyzeing) {
        return;
    }
    
    [self stopDownloadDsym];
    
    WEAKSELF
    self.downloadTask = [[NSURLSession sharedSession] downloadTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        STRONGSELF
        if (location && response && !error) {
            NSString *zipPath = [[MZLAnalyzeHandler sharedInstance].crashFolderPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.zip", strongSelf.ipaName]];
            BOOL success = [[NSFileManager defaultManager] moveItemAtURL:location toURL:[NSURL fileURLWithPath:zipPath] error:nil];
            if (completion) {
                completion(success);
            }
        } else if (![error.localizedDescription isEqualToString:@"cancelled"]) {
            if (completion) {
                completion(NO);
            }
        }
    }];
    [self.downloadTask resume];
}

- (void)stopDownloadDsym {
    if (self.downloadTask) {
        if (self.downloadTask.state == NSURLSessionTaskStateRunning ||
            self.downloadTask.state == NSURLSessionTaskStateSuspended) {
            [self.downloadTask cancel];
        }
        self.downloadTask = nil;
    }
}

#pragma mark ==================== Unzip

- (void)unzipDsymAndAnalyze {
    if (!self.isAnalyzeing) {
        return;
    }
    
    [self showProgressTip:@"解压下载的 dsym zip 文件"];
    
    NSString *dsymZipPath = [[MZLAnalyzeHandler sharedInstance].crashFolderPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.zip", self.ipaName]];
    NSString *dsymFilePath = [[MZLAnalyzeHandler sharedInstance].crashFolderPath stringByAppendingPathComponent:self.ipaName];
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
