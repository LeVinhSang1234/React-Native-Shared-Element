//
//  RCTShareRouteRegistry.h
//  ShareElement
//
//  Created by Sang Le vinh on 9/11/25.
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class RCTShareView;

NS_ASSUME_NONNULL_BEGIN

@interface RCTShareRouteRegistry : NSObject

+ (instancetype)shared;

/// Đăng ký 1 view vào route theo tag + screenKey
- (void)registerView:(RCTShareView *)view
                 tag:(NSString *)tag
           screenKey:(NSString *)screenKey;

/// Gỡ đăng ký
- (void)unregisterView:(RCTShareView *)view
                   tag:(NSString *)tag
             screenKey:(NSString *)screenKey;

/// Đặt “pending target tag” cho 1 tag nguồn (optional)
- (void)setPendingTargetTag:(nullable NSString *)targetTag
                     forTag:(NSString *)tag;

/// Resolve otherView cho 1 view theo nguyên tắc:
/// 1) Ưu tiên khác màn (dựa trên thứ tự màn gần nhất)
/// 2) Fallback: cùng màn, chọn view khác chính nó
- (nullable RCTShareView *)resolveShareTargetForView:(RCTShareView *)view
                                                 tag:(NSString *)tag;

/// Ghi nhận cạnh share (from→to), cập nhật owner màn hiện tại
- (void)commitShareFromView:(RCTShareView *)fromView
                     toView:(RCTShareView *)toView
                        tag:(NSString *)tag;

/// Lấy danh sách các cạnh (lịch sử) của 1 tag
- (NSArray<NSDictionary *> *)edgesForTag:(NSString *)tag;

/// Tạo screenKey ổn định từ view (dựa trên địa chỉ VC)
- (nullable NSString *)screenKeyOfView:(UIView *)view;

@end

NS_ASSUME_NONNULL_END
