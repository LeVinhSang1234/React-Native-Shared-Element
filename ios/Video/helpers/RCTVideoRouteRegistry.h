// RCTVideoRouteRegistry.h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class RCTVideoView;

NS_ASSUME_NONNULL_BEGIN

@interface RCTVideoRouteRegistry : NSObject

+ (instancetype)shared;

/// Đăng ký 1 view vào route theo tag + screenKey
- (void)registerView:(RCTVideoView *)view
                 tag:(NSString *)tag
           screenKey:(NSString *)screenKey;

/// Gỡ đăng ký
- (void)unregisterView:(RCTVideoView *)view
                   tag:(NSString *)tag
             screenKey:(NSString *)screenKey;

/// Đặt “pending target tag” cho 1 tag nguồn (tuỳ chọn)
- (void)setPendingTargetTag:(nullable NSString *)targetTag
                     forTag:(NSString *)tag;

/// Resolve otherView cho 1 view theo nguyên tắc:
/// 1) Ưu tiên khác màn (dựa trên thứ tự màn gần nhất)
/// 2) Fallback: cùng màn, chọn view khác chính nó
- (nullable RCTVideoView *)resolveShareTargetForView:(RCTVideoView *)view
                                                 tag:(NSString *)tag;

/// Ghi nhận cạnh share (from→to), cập nhật owner màn hiện tại
- (void)commitShareFromView:(RCTVideoView *)fromView
                     toView:(RCTVideoView *)toView
                        tag:(NSString *)tag;

/// Lấy danh sách các cạnh (lịch sử) của 1 tag
- (NSArray<NSDictionary *> *)edgesForTag:(NSString *)tag;

/// Tạo screenKey ổn định từ view (dựa trên địa chỉ VC)
- (nullable NSString *)screenKeyOfView:(UIView *)view;

@end

NS_ASSUME_NONNULL_END
