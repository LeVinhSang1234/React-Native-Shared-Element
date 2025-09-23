//
//  RCTVideoHelper.m
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
//

#import "RCTVideoHelper.h"
#import "RCTVideoCache.h"

#pragma mark - Constants

static NSString * const kPosterCacheDirName = @"video_posters";
static NSTimeInterval const kPosterMaxAge   = 6 * 60 * 60; // 6h

@implementation RCTVideoHelper

#pragma mark - Video URL / Poster

+ (void)applyMaxSizeCache:(NSUInteger)sizeMB {
  [RCTVideoCache VC_ConfigureCache:sizeMB];
}

+ (nullable NSURL *)createVideoURL:(NSString *)source {
  if (source.length == 0) return nil;
  
  if ([source hasPrefix:@"http"]) {
    NSURL *url = [NSURL URLWithString:source];
    if (!url) return nil;
    
    [RCTVideoCache VC_StartProxy];
    [RCTVideoCache trimCacheIfNeeded];
    [RCTVideoCache VC_PrefetchHead:url seconds:5.0 bitratebps:10e6];
    
    return [RCTVideoCache proxyURLWithOriginalURL:url];
  }
  
  if ([source hasPrefix:@"file://"]) {
    return [NSURL URLWithString:source];
  }
  
  return [NSURL fileURLWithPath:source];
}

+ (nullable NSURL *)createPosterURL:(NSString *)source {
  if (source.length == 0) return nil;
  
  if ([source hasPrefix:@"http"]) {
    NSString *cacheDir = [NSTemporaryDirectory() stringByAppendingPathComponent:kPosterCacheDirName];
    [[NSFileManager defaultManager] createDirectoryAtPath:cacheDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    
    NSString *fileName = [source.lastPathComponent stringByAppendingFormat:@"_%lu", (unsigned long)source.hash];
    NSString *filePath = [cacheDir stringByAppendingPathComponent:fileName];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
    NSDate *modDate = attrs[NSFileModificationDate];
    BOOL expired = modDate ? ([[NSDate date] timeIntervalSinceDate:modDate] > kPosterMaxAge) : YES;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath] && !expired) {
      return fileURL;
    }
    
    NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:source]];
    if (imageData) {
      [imageData writeToFile:filePath atomically:YES];
      return fileURL;
    }
    return [NSURL URLWithString:source];
  }
  
  if ([source hasPrefix:@"file://"]) {
    return [NSURL URLWithString:source];
  }
  
  return [NSURL fileURLWithPath:source];
}

#pragma mark - RNSScreen frame

+ (nullable UIView *)p_findRNSScreenViewFrom:(UIView *)view {
  if (!view) return nil;
  Class ScreenCls = NSClassFromString(@"RNSScreenView");
  UIView *p = view;
  while (p) {
    if ([p isKindOfClass:ScreenCls]) return p;
    p = p.superview;
  }
  return nil;
}

+ (CGRect)frameInScreenStable:(UIView *)view {
  if (!view) return CGRectZero;
  CALayer *presentation = view.layer.presentationLayer;
  if (presentation) {
    CGRect presFrame = presentation.frame;
    UIWindow *win = view.window;
    if (win) return [view.superview convertRect:presFrame toView:win];
    return presFrame;
  }

  UIView *screen = [self p_findRNSScreenViewFrom:view];
  if (screen) {
    [screen layoutIfNeeded];
    return [view convertRect:view.bounds toView:screen];
  }
  UIView *root = view;
  while (root.superview) root = root.superview;
  [root layoutIfNeeded];
  return [view convertRect:view.bounds toView:root];
}

#pragma mark - Window (multi-scene safe)

+ (UIWindow * _Nullable)getTargetWindow {
  UIWindow *win = nil;
  if (@available(iOS 13.0, *)) {
    for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
      if (scene.activationState == UISceneActivationStateForegroundActive) {
        for (UIWindow *w in scene.windows) {
          if (w.isKeyWindow) { win = w; break; }
        }
        if (!win && scene.windows.firstObject) {
          win = scene.windows.firstObject;
        }
      }
    }
  } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    win = UIApplication.sharedApplication.keyWindow ?: UIApplication.sharedApplication.windows.firstObject;
#pragma clang diagnostic pop
  }
  return win;
}

+ (nullable UIViewController *)getRootViewController {
  UIWindow *win = nil;
  if (@available(iOS 13.0, *)) {
    for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
      if (scene.activationState == UISceneActivationStateForegroundActive) {
        for (UIWindow *w in scene.windows) {
          if (w.isKeyWindow) {
            win = w;
            break;
          }
        }
        if (!win && scene.windows.firstObject) {
          win = scene.windows.firstObject;
        }
      }
    }
  } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    win = UIApplication.sharedApplication.keyWindow ?: UIApplication.sharedApplication.windows.firstObject;
#pragma clang diagnostic pop
  }
  return win.rootViewController;
}

@end
