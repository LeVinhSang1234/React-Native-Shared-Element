//
//  RCTShareViewRouteRegistry.h
//  ShareVideo
//
//  Created by Sang Le vinh on 9/4/25.
//

#import <Foundation/Foundation.h>

@class RCTShareView;

NS_ASSUME_NONNULL_BEGIN

@interface RCTShareViewRouteRegistry : NSObject

+ (instancetype)shared;

/// Đăng ký view với tag + screenKey
- (void)registerView:(RCTShareView *)view
                 tag:(NSString *)tag
           screenKey:(NSString *)screenKey;

/// Huỷ đăng ký view
- (void)unregisterView:(RCTShareView *)view
                   tag:(NSString *)tag
             screenKey:(NSString *)screenKey;

/// Resolve target view để share
- (nullable RCTShareView *)resolveShareTargetForView:(RCTShareView *)view
                                                 tag:(NSString *)tag;

/// Commit sau khi share xong (từ fromView sang toView)
- (void)commitShareFromView:(RCTShareView *)fromView
                     toView:(RCTShareView *)toView
                        tag:(NSString *)tag;

/// Lấy screenKey theo view (thường là nearest UIViewController)
- (nullable NSString *)screenKeyOfView:(RCTShareView *)view;

@end

NS_ASSUME_NONNULL_END
