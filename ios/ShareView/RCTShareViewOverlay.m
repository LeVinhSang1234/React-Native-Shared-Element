//
//  RCTShareViewOverlay.m
//  ShareVideo
//
//  Created by Sang Le vinh on 9/4/25.
//

#import "RCTShareViewOverlay.h"
#import "RCTVideoHelper.h"

/// Default constants
static const double kDefaultSharingDuration = 0.35; // giây
static const double kDefaultCompletionDelay = 0.1;  // giây

@interface RCTShareViewOverlay ()
@property (nonatomic, strong) UIView *snapshotView;
@end

@implementation RCTShareViewOverlay

- (instancetype)init {
  if (self = [super init]) {
    _sharingAnimatedDuration = kDefaultSharingDuration;
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = YES;
  }
  return self;
}

#pragma mark - Config

- (void)applySharingAnimatedDuration:(double)durationMs {
  double duration = (durationMs <= 0) ? kDefaultSharingDuration : durationMs / 1000.0;
  if (duration != _sharingAnimatedDuration) {
    _sharingAnimatedDuration = duration;
  }
}

#pragma mark - Animate

- (void)moveToOverlay:(CGRect)fromFrame
           tagetFrame:(CGRect)toFrame
              content:(UIView *)contentView
sharingAnimatedDuration:(double)sharingAnimatedDuration
              bgColor:(nullable UIColor *)bgColor
             onTarget:(nullable dispatch_block_t)onTarget
          onCompleted:(nullable dispatch_block_t)onCompleted
{
  UIWindow *win = [RCTVideoHelper getTargetWindow];
  if (!win || !contentView) return;
  
  // Tạo snapshot từ contentView để tránh distort khi scale
  UIView *snapshot = [contentView snapshotViewAfterScreenUpdates:NO];
  if (!snapshot) return;
  snapshot.frame = fromFrame;
  snapshot.backgroundColor = bgColor ?: contentView.backgroundColor;
  
  [win addSubview:snapshot];
  [win bringSubviewToFront:snapshot];
  self.snapshotView = snapshot;
  
  double dur = sharingAnimatedDuration > 0 ? sharingAnimatedDuration : _sharingAnimatedDuration;
  
  [UIView animateWithDuration:dur
                        delay:0
                      options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                   animations:^{
    snapshot.frame = toFrame;
  } completion:^(BOOL finished) {
    if (finished) {
      if (onTarget) onTarget();
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                   (int64_t)(kDefaultCompletionDelay * NSEC_PER_SEC)),
                     dispatch_get_main_queue(), ^{
        [snapshot removeFromSuperview];
        self.snapshotView = nil;
        if (onCompleted) onCompleted();
      });
    }
  }];
}

#pragma mark - Cleanup

- (void)didUnmount {
  if (_snapshotView) {
    [_snapshotView removeFromSuperview];
    _snapshotView = nil;
  }
  [self removeFromSuperview];
}

@end
