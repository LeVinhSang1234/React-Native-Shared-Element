//
//  RCTVideoHelper.m
//  ShareVideo
//
//  Created by Sang Lv on 20/8/25.
//
#import "RCTVideoHelper.h"
#import "RCTVideoCache.h"
#import "KTVHTTPCache/KTVHTTPCache.h"

@implementation RCTVideoHelper

-(instancetype)init {
  self = [super init];
  return self;
}

+(nullable NSURL *)createVideoURL:(NSString *)source {
  if ([source hasPrefix:@"http"] || [source hasPrefix:@"https"]) {
    NSURL *url = [NSURL URLWithString:source];
    if (!url) return nil;
    
    // khởi động proxy và prefetch ~3s
    //VC_StartProxyOnce(500 * 1024 * 1024);     // giới hạn cache 500MB (tuỳ chỉnh)
    [RCTVideoCache VC_StartProxy];
    // 5s @ 2 Mbps (có thể điều chỉnh sau)
    [RCTVideoCache VC_PrefetchHead:url seconds:5.0 bitratebps:10e6];
    
    // phát qua proxy URL (sẽ dùng bytes đã prefetch nếu có)
    NSURL *proxyURL = [KTVHTTPCache proxyURLWithOriginalURL:url];
    return proxyURL ?: url;
  } else if ([source hasPrefix:@"file://"]) {
    return [NSURL URLWithString:source];
  } else {
    return [NSURL fileURLWithPath:source];
  }
}

+(nullable NSURL *)createPosterURL:(NSString *)source {
  if ([source hasPrefix:@"http"] || [source hasPrefix:@"https"]) {
    NSString *cacheDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"video_posters"];
    [[NSFileManager defaultManager] createDirectoryAtPath:cacheDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *fileName = [source.lastPathComponent stringByAppendingFormat:@"_%lu", (unsigned long)source.hash];
    NSString *filePath = [cacheDir stringByAppendingPathComponent:fileName];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    
    // Kiểm tra file cache và thời gian sửa đổi
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
    NSDate *modDate = attrs[NSFileModificationDate];
    NSTimeInterval maxAge = 24 * 60 * 60; // 1 ngày
    BOOL expired = modDate ? ([[NSDate date] timeIntervalSinceDate:modDate] > maxAge) : YES;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath] && !expired) {
      return fileURL;
    }
    
    // Tải lại ảnh nếu chưa có hoặc đã hết hạn
    NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:source]];
    if (imageData) {
      [imageData writeToFile:filePath atomically:YES];
      return fileURL;
    }
    return [NSURL URLWithString:source];
  } else if ([source hasPrefix:@"file://"]) {
    return [NSURL URLWithString:source];
  } else {
    return [NSURL fileURLWithPath:source];
  }
}

+ (UIWindow *) getTargetWindow {
  UIWindow *win = nil;
  if (!win) {
    if (@available(iOS 13.0, *)) {
      for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
          if (scene.windows.firstObject) { win = scene.windows.firstObject; break; }
        }
      }
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      win = UIApplication.sharedApplication.keyWindow ?: UIApplication.sharedApplication.windows.firstObject;
#pragma clang diagnostic pop
    }
  }
  return win;
}

@end
