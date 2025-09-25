//
//  RCTVideoHelper.m
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
//

#import "RCTVideoHelper.h"
#import "RCTVideoCache.h"
#import <UIKit/UIKit.h>

#pragma mark - Config (switch strategy at runtime if needed)

typedef NS_ENUM(NSUInteger, RCTFrameStrategy) {
  // Cách 1: convert trực tiếp sang UIWindow (khuyến nghị)
  RCTFrameStrategyDirectWindow = 1,
  // Cách 2: convert vào RNSScreen/RNSScreenStack rồi tự cộng header
  RCTFrameStrategyRNSPlusHeader = 2,
};

static RCTFrameStrategy g_frameStrategy = RCTFrameStrategyDirectWindow;

@implementation RCTVideoHelper

+ (void)setFrameStrategyDirectWindow {
  g_frameStrategy = RCTFrameStrategyDirectWindow;
}
+ (void)setFrameStrategyRNSPlusHeader {
  g_frameStrategy = RCTFrameStrategyRNSPlusHeader;
}

#pragma mark - Constants

static NSString * const kPosterCacheDirName = @"video_posters";
static NSTimeInterval const kPosterMaxAge   = 6 * 60 * 60; // 6h

#pragma mark - Video Cache

+ (void)applyMaxSizeCache:(NSUInteger)sizeMB {
  [RCTVideoCache VC_ConfigureCache:sizeMB];
}

#pragma mark - Video URL

+ (nullable NSURL *)createVideoURL:(NSString *)source {
  if (source.length == 0) return nil;

  // Remote
  if ([source hasPrefix:@"http"]) {
    NSURL *url = [NSURL URLWithString:source];
    if (!url) return nil;

    [RCTVideoCache VC_StartProxy];
    [RCTVideoCache trimCacheIfNeeded];
    [RCTVideoCache VC_PrefetchHead:url seconds:5.0 bitratebps:10e6];

    return [RCTVideoCache proxyURLWithOriginalURL:url];
  }

  // File://
  if ([source hasPrefix:@"file://"]) {
    return [NSURL URLWithString:source];
  }

  // Local path
  return [NSURL fileURLWithPath:source];
}

#pragma mark - Poster URL

+ (nullable NSURL *)createPosterURL:(NSString *)source {
  if (source.length == 0) return nil;

  if ([source hasPrefix:@"http"]) {
    NSString *cacheDir = [NSTemporaryDirectory() stringByAppendingPathComponent:kPosterCacheDirName];
    [[NSFileManager defaultManager] createDirectoryAtPath:cacheDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    NSString *fileName = [source.lastPathComponent stringByAppendingFormat:@"_%lu",
                          (unsigned long)source.hash];
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

#pragma mark - Helpers: Window / VC / RNS

+ (UIWindow * _Nullable)getTargetWindow {
  UIWindow *win = nil;
  if (@available(iOS 13.0, *)) {
    for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
      if (scene.activationState == UISceneActivationStateForegroundActive &&
          [scene isKindOfClass:UIWindowScene.class]) {
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
          if (w.isKeyWindow) { win = w; break; }
        }
        if (!win && ((UIWindowScene *)scene).windows.firstObject) {
          win = ((UIWindowScene *)scene).windows.firstObject;
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

+ (nullable UIViewController *)p_nearestViewControllerFrom:(UIView *)view {
  UIResponder *r = view;
  while (r) {
    if ([r isKindOfClass:UIViewController.class]) return (UIViewController *)r;
    r = r.nextResponder;
  }
  return nil;
}

+ (nullable UIView *)p_findAncestorOfClassNames:(NSArray<NSString *> *)classNames from:(UIView *)view {
  UIView *p = view;
  while (p) {
    for (NSString *name in classNames) {
      Class cls = NSClassFromString(name);
      if (cls && [p isKindOfClass:cls]) return p;
    }
    p = p.superview;
  }
  return nil;
}

+ (nullable UIView *)p_findRNSScreenViewFrom:(UIView *)view {
  Class ScreenCls = NSClassFromString(@"RNSScreenView");
  if (!ScreenCls) return nil;
  UIView *p = view;
  while (p) {
    if ([p isKindOfClass:ScreenCls]) return p;
    p = p.superview;
  }
  return nil;
}

+ (CGFloat)p_navHeaderHeightForVC:(UIViewController *)vc {
  if (!vc) return 0;

  UINavigationController *nav = vc.navigationController;
  BOOL navVisible = (nav && !nav.navigationBarHidden && !nav.navigationBar.isHidden);
  CGFloat navH = navVisible ? nav.navigationBar.bounds.size.height : 0;

  CGFloat statusH = 0;
  if (@available(iOS 13.0, *)) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
      if (scene.activationState == UISceneActivationStateForegroundActive &&
          [scene isKindOfClass:UIWindowScene.class]) {
        UIStatusBarManager *mgr = ((UIWindowScene *)scene).statusBarManager;
        if (mgr) { statusH = mgr.statusBarFrame.size.height; break; }
      }
    }
  } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    statusH = UIApplication.sharedApplication.statusBarFrame.size.height;
#pragma clang diagnostic pop
  }

  // safeAreaInsets.top có thể = 0 khi chưa attach window
  CGFloat safeTop = vc.view.safeAreaInsets.top;
  if (safeTop <= 0) safeTop = statusH;

  // Với nav bar không translucent, safeTop đã ở dưới nav bar → không cộng navH.
  // Với nav bar translucent (mặc định), nội dung có thể nằm dưới nav → cộng navH.
  BOOL translucent = nav ? nav.navigationBar.isTranslucent : NO;
  return translucent ? (safeTop + navH) : safeTop;
}

+ (CGFloat)p_rnsHeaderHeightInsideStack:(UIView *)stack {
  Class HeaderCls = NSClassFromString(@"RNSScreenStackHeaderSubview");
  if (!HeaderCls) return 0;
  for (UIView *sub in stack.subviews) {
    if ([sub isKindOfClass:HeaderCls]) {
      [sub layoutIfNeeded];
      return sub.bounds.size.height;
    }
  }
  return 0;
}

#pragma mark - Strategy 1: Direct-to-Window (khuyến nghị)

+ (CGRect)p_frameInWindow_Direct:(UIView *)view {
  // 1) Nếu đang animate → presentationLayer
  CALayer *presentation = view.layer.presentationLayer;
  if (presentation && view.superview && view.window) {
    return [view.superview convertRect:presentation.frame toView:view.window];
  }

  // 2) Có window → convert thẳng sang window
  if (view.window) {
    [view.window layoutIfNeeded];
    return [view convertRect:view.bounds toView:view.window];
  }

  // 3) Không có window → dùng nearest VC (nếu có) rồi convert sang window của VC
  UIViewController *vc = [self p_nearestViewControllerFrom:view];
  if (vc) {
    [vc.view.superview layoutIfNeeded];
    [vc.view layoutIfNeeded];

    CGRect inVC = [view convertRect:view.bounds toView:vc.view];
    if (vc.view.window) {
      return [vc.view convertRect:inVC toView:vc.view.window];
    }

    // chưa attach window → trả về theo hệ quy chiếu VC.view
    return inVC;
  }

  // 4) Fallback root
  UIView *root = view;
  while (root.superview) root = root.superview;
  [root layoutIfNeeded];
  return [view convertRect:view.bounds toView:root];
}

#pragma mark - Strategy 2: RNS + add header

+ (CGRect)p_frameInWindow_RNSPlusHeader:(UIView *)view {
  // 1) Presentation
  CALayer *presentation = view.layer.presentationLayer;
  if (presentation && view.superview && view.window) {
    return [view.superview convertRect:presentation.frame toView:view.window];
  }

  // 2) Ưu tiên RNSScreenStackView (header là "chị em")
  UIView *stack = [self p_findAncestorOfClassNames:@[@"RNSScreenStackView", @"RNSScreenStack"] from:view];
  if (stack) {
    [stack.superview layoutIfNeeded];
    [stack layoutIfNeeded];

    CGRect r = [view convertRect:view.bounds toView:stack];

    // cộng header nếu tồn tại
    CGFloat headerH = [self p_rnsHeaderHeightInsideStack:stack];
    if (headerH <= 0) {
      // fallback qua navBar + safeArea của nearest VC
      UIViewController *vc = [self p_nearestViewControllerFrom:stack];
      headerH = [self p_navHeaderHeightForVC:vc];
    }
    r.origin.y += headerH;

    if (view.window) return [stack convertRect:r toView:view.window];
    return r;
  }

  // 3) RNSScreenView
  UIView *screen = [self p_findRNSScreenViewFrom:view];
  if (screen) {
    [screen.superview layoutIfNeeded];
    [screen layoutIfNeeded];

    CGRect r = [view convertRect:view.bounds toView:screen];
    UIViewController *vc = [self p_nearestViewControllerFrom:screen];
    r.origin.y += [self p_navHeaderHeightForVC:vc];

    if (view.window) return [screen convertRect:r toView:view.window];
    return r;
  }

  // 4) Fallback root
  UIView *root = view;
  while (root.superview) root = root.superview;
  [root layoutIfNeeded];

  CGRect r = [view convertRect:view.bounds toView:root];
  if (view.window) return [root convertRect:r toView:view.window];
  return r;
}

#pragma mark - Public API

+ (CGRect)frameInScreenStable:(UIView *)view {
  if (!view) return CGRectZero;

  switch (g_frameStrategy) {
    case RCTFrameStrategyDirectWindow:
      return [self p_frameInWindow_Direct:view];
    case RCTFrameStrategyRNSPlusHeader:
      return [self p_frameInWindow_RNSPlusHeader:view];
  }
  return [self p_frameInWindow_Direct:view];
}

+ (nullable UIViewController *)getRootViewController {
  UIWindow *win = [self getTargetWindow];
  return win.rootViewController;
}

+ (UIInterfaceOrientation)currentInterfaceOrientation {
  if (@available(iOS 13.0, *)) {
    for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
      if (scene.activationState == UISceneActivationStateForegroundActive &&
          [scene isKindOfClass:UIWindowScene.class]) {
        return scene.interfaceOrientation;
      }
    }
    return UIInterfaceOrientationPortrait;
  } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return UIApplication.sharedApplication.statusBarOrientation;
#pragma clang diagnostic pop
  }
}

@end
