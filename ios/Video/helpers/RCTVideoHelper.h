//
//  RCTVideoHelper.h
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RCTVideoHelper : NSObject

/// Tạo URL phát video (tự bật proxy + prefetch nếu là http/https)
+ (nullable NSURL *)createVideoURL:(NSString *)source;

/// Tạo URL poster (cache file 1 ngày nếu là http/https)
+ (nullable NSURL *)createPosterURL:(NSString *)source;

/// Lấy frame của chính view trong toạ độ RNSScreen (ổn định, không phụ thuộc animation)
+ (CGRect)frameInScreenStable:(UIView *)view;

/// Lấy window đang hiển thị (multi-scene an toàn)
+ (UIWindow * _Nullable)getTargetWindow;

+ (nullable UIViewController *)getRootViewController;

+ (void)applyMaxSizeCache:(NSUInteger)maxSizeMB;

+ (UIInterfaceOrientation)currentInterfaceOrientation;

@end

NS_ASSUME_NONNULL_END
