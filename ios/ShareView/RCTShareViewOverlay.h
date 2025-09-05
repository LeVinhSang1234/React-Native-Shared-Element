//
//  RCTShareViewOverlay.h
//  ShareVideo
//
//  Created by Sang Le vinh on 9/4/25.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RCTShareViewOverlay : UIView

/// Thời gian animate khi share element (giây)
@property (nonatomic, assign) double sharingAnimatedDuration;

/// Update duration (ms). Nếu < 0 thì fallback default
- (void)applySharingAnimatedDuration:(double)durationMs;

/// Animate chuyển shared element từ `fromFrame` sang `toFrame`.
/// - Parameters:
///   - fromFrame: CGRect tuyệt đối của view bắt đầu
///   - toFrame: CGRect tuyệt đối của view đích
///   - sharingAnimatedDuration: thời gian animate (ms, convert sang giây trong hàm)
///   - bgColor: background của snapshot
///   - onTarget: block gọi ngay khi snapshot đạt target
///   - onCompleted: block gọi sau khi animation hoàn tất và cleanup
- (void)moveToOverlay:(CGRect)fromFrame
           tagetFrame:(CGRect)toFrame
              content:(UIView *)contentView
sharingAnimatedDuration:(double)sharingAnimatedDuration
              bgColor:(nullable UIColor *)bgColor
             onTarget:(nullable dispatch_block_t)onTarget
          onCompleted:(nullable dispatch_block_t)onCompleted;

- (void)didUnmount;

@end

NS_ASSUME_NONNULL_END
