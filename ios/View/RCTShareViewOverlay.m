//
//  RCTShareViewOverlay.m
//  ShareElement
//
//  Created by Sang Le vinh on 9/12/25.
//

#import "RCTShareViewOverlay.h"
#import "RCTVideoHelper.h"

/// Default constants
static const double kDefaultSharingDuration = 0.35; // seconds
static const double kDefaultCompletionDelay   = 0.15;    // seconds

@interface RCTShareViewOverlay ()
// Private properties (internal only)
@property (nonatomic, strong, nullable) UIView *overlayContainer;
@property (nonatomic, strong, nullable) UIView *ghostView;
@property (nonatomic, weak,   nullable) UIView *originalView;
@property (nonatomic, assign) BOOL isAnimating;
@end

@implementation RCTShareViewOverlay

- (instancetype)init {
  if (self = [super init]) {
    _sharingAnimatedDuration = kDefaultSharingDuration;
  }
  return self;
}

- (void)applySharingAnimatedDuration:(double)durationMs {
  double duration = (durationMs <= 0) ? kDefaultSharingDuration : durationMs / 1000.0;
  _sharingAnimatedDuration = duration;
}

- (void)moveToOverlay:(CGRect)fromFrame
           targetFrame:(CGRect)toFrame
                 view:(UIView *)view
             onTarget:(void (^)(void))onTarget
          onCompleted:(void (^)(void))onCompleted
{
  UIWindow *win = [RCTVideoHelper getTargetWindow];
  if (!win) {
    if (onTarget) onTarget();
    if (onCompleted) onCompleted();
    return;
  }

  // Hide original
  self.originalView = view;

  // Create overlay container
  self.overlayContainer = [[UIView alloc] initWithFrame:win.bounds];
  self.overlayContainer.backgroundColor = [UIColor clearColor];
  [win addSubview:self.overlayContainer];

  // Clone view using snapshot
  UIView *ghost = [self _deepClone:view];
  if (!ghost) {
    [self didUnmount];
    if (onTarget) onTarget();
    if (onCompleted) onCompleted();
    return;
  }

  ghost.frame = fromFrame;
  [self.overlayContainer addSubview:ghost];
  self.ghostView = ghost;

  // Animate
  [UIView animateWithDuration:self.sharingAnimatedDuration
                        delay:0
                      options:UIViewAnimationOptionCurveEaseInOut
                   animations:^{
    ghost.frame = toFrame;
  } completion:^(BOOL finished) {
    if (onTarget) onTarget();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(kDefaultCompletionDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      [ghost removeFromSuperview];
      [self didUnmount];
      if (onCompleted) onCompleted();
    });
  }];
}

- (UIView *)_deepClone:(UIView *)view {
  NSString *className = NSStringFromClass([view class]);
  NSLog(@"Cloning: %@", className);

  if ([view isKindOfClass:[UIImageView class]]) {
    UIImageView *orig = (UIImageView *)view;
    UIImageView *copy = [[UIImageView alloc] initWithFrame:orig.bounds];
    copy.image = orig.image;
    copy.contentMode = orig.contentMode;
    copy.clipsToBounds = orig.clipsToBounds;
    return copy;
  }
  else if ([className containsString:@"ParagraphTextView"]) {
    // Fabric text node → snapshot để giữ nguyên glyph
    UIView *copy = [view snapshotViewAfterScreenUpdates:NO];
    copy.frame = view.bounds;
    return copy;
  }
  else if ([className containsString:@"ParagraphComponentView"]) {
    UIView *copy = [[UIView alloc] initWithFrame:view.bounds];
    for (UIView *child in view.subviews) {
      UIView *childCopy = [self _deepClone:child];
      if (childCopy) {
        childCopy.frame = child.frame;
        [copy addSubview:childCopy];
      }
    }
    return copy;
  }
  else if ([view isKindOfClass:[UILabel class]]) {
    UILabel *orig = (UILabel *)view;
    UILabel *copy = [[UILabel alloc] initWithFrame:orig.bounds];
    copy.text = orig.text;
    copy.font = orig.font;
    copy.textColor = orig.textColor;
    copy.numberOfLines = orig.numberOfLines;
    copy.textAlignment = orig.textAlignment;
    copy.lineBreakMode = orig.lineBreakMode;
    return copy;
  }
  else {
    UIView *copy = [[UIView alloc] initWithFrame:view.bounds];
    copy.backgroundColor = view.backgroundColor;
    copy.layer.cornerRadius = view.layer.cornerRadius;
    copy.clipsToBounds = view.clipsToBounds;

    for (UIView *child in view.subviews) {
      UIView *childCopy = [self _deepClone:child];
      if (childCopy) {
        childCopy.frame = child.frame;
        [copy addSubview:childCopy];
      }
    }
    return copy;
  }
}

- (void)didUnmount {
  [self.overlayContainer removeFromSuperview];
  self.overlayContainer = nil;
  self.ghostView = nil;
  self.originalView = nil;
  self.isAnimating = NO;
}

@end
