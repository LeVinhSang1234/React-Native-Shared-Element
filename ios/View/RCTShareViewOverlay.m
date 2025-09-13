//
//  RCTShareViewOverlay.m
//  ShareElement
//
//  Created by Sang Le vinh on 9/12/25.
//

//
//  RCTShareViewOverlay.m
//  ShareElement
//
//  Created by Sang Le vinh on 9/12/25.
//

#import "RCTShareViewOverlay.h"
#import "RCTVideoHelper.h"
#import <objc/message.h>

/// Default constants
static const double kDefaultSharingDuration   = 0.35;   // seconds
static const double kDefaultCompletionDelay   = 0.15;    // seconds

@interface RCTShareViewOverlay ()
@property (nonatomic, strong, nullable) UIView *overlayContainer; // full-screen overlay
@property (nonatomic, strong, nullable) UIView *ghostView;        // cloned tree
@property (nonatomic, weak,   nullable) UIView *originalView;     // reference to hide/unhide
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

#pragma mark - Public

- (void)moveToOverlay:(CGRect)fromFrame
          targetFrame:(CGRect)toFrame
             fromView:(UIView *)fromView
               toView:(UIView *)toView
             onTarget:(void (^)(void))onTarget
          onCompleted:(void (^)(void))onCompleted
{
  if (_isAnimating) return;
  _isAnimating = YES;
  
  UIWindow *win = [RCTVideoHelper getTargetWindow];
  if (!win) {
    _isAnimating = NO;
    if (onCompleted) onCompleted();
    return;
  }
  
  // Hide original
  self.originalView = fromView;
  
  // Create overlay container
  self.overlayContainer = [[UIView alloc] initWithFrame:win.bounds];
  self.overlayContainer.backgroundColor = [UIColor clearColor];
  [win addSubview:self.overlayContainer];
  
  // Deep clone full tree
  UIView *ghost = [self _deepClone:fromView];
  ghost.frame = fromFrame;
  [self.overlayContainer addSubview:ghost];
  self.ghostView = ghost;
  
  // Animate everything in one block
  [UIView animateWithDuration:self.sharingAnimatedDuration
                        delay:0
                      options:UIViewAnimationOptionCurveEaseInOut
                   animations:^{
    // Animate root
    ghost.frame = toFrame;
    // Animate children recursively
    [self _animateSubviewsFrom:fromView to:toView ghost:ghost];
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

#pragma mark - Deep clone

- (UIView *)_deepClone:(UIView *)view {
  // UILabel chuẩn
  if ([view isKindOfClass:[UILabel class]]) {
    UILabel *orig = (UILabel *)view;
    UILabel *copy = [[UILabel alloc] initWithFrame:orig.frame];
    copy.text = orig.text;
    copy.font = orig.font;
    copy.textColor = orig.textColor;
    copy.numberOfLines = orig.numberOfLines;
    copy.textAlignment = orig.textAlignment;
    copy.lineBreakMode = orig.lineBreakMode;
    return copy;
  }
  // Fabric ParagraphTextView → clone text thay vì snapshot
  else if ([view isKindOfClass:NSClassFromString(@"RCTParagraphTextView")]) {
    UIView *snap = [view snapshotViewAfterScreenUpdates:NO];
    snap.frame = view.frame;
    return snap;
  }
  // UIImageView
  else if ([view isKindOfClass:[UIImageView class]]) {
    UIImageView *orig = (UIImageView *)view;
    UIImageView *copy = [[UIImageView alloc] initWithFrame:orig.frame];
    copy.image = orig.image;
    copy.contentMode = orig.contentMode;
    copy.clipsToBounds = orig.clipsToBounds;
    return copy;
  }
  // Default: container + children
  else {
    UIView *copy = [[UIView alloc] initWithFrame:view.frame];
    copy.backgroundColor = view.backgroundColor;
    copy.layer.cornerRadius = view.layer.cornerRadius;
    copy.clipsToBounds = view.clipsToBounds;
    
    for (UIView *child in view.subviews) {
      UIView *childCopy = [self _deepClone:child];
      if (childCopy) [copy addSubview:childCopy];
    }
    return copy;
  }
}

#pragma mark - Animate subviews

- (UIView *)_findMatchingChildFor:(UIView *)fromChild
                         inParent:(UIView *)toParent
                     usedChildren:(NSMutableSet<UIView *> *)used {
  for (UIView *c in toParent.subviews) {
    if (![used containsObject:c] && [c isKindOfClass:[fromChild class]]) {
      [used addObject:c];
      return c;
    }
  }
  return nil;
}

- (void)_animateSubviewsFrom:(UIView *)fromView
                          to:(UIView *)toView
                       ghost:(UIView *)ghostView
{
  NSMutableSet<UIView *> *used = [NSMutableSet set];
  NSInteger ghostCount = ghostView.subviews.count;
  
  for (NSInteger i = 0; i < fromView.subviews.count && i < ghostCount; i++) {
    UIView *fromChild  = fromView.subviews[i];
    UIView *ghostChild = ghostView.subviews[i];
    UIView *toChild    = [self _findMatchingChildFor:fromChild
                                            inParent:toView
                                        usedChildren:used];
    if (!toChild) continue;
    
    // Animate frame
    ghostChild.frame = fromChild.frame;
    CGRect endFrame  = toChild.frame;
    
    if ([ghostChild isKindOfClass:[UILabel class]]) {
      UILabel *ghostLabel = (UILabel *)ghostChild;
      UILabel *toLabel    = (UILabel *)toChild;

      [UIView animateWithDuration:_sharingAnimatedDuration
                       animations:^{
        ghostChild.frame = endFrame;
        ghostLabel.font = toLabel.font;
        ghostLabel.textColor = toLabel.textColor;
        ghostLabel.textAlignment = toLabel.textAlignment;
      }];
    }
    else if ([ghostChild isKindOfClass:[UIImageView class]]) {
      UIImageView *ghostImg = (UIImageView *)ghostChild;
      UIImageView *toImg    = (UIImageView *)toChild;

      [UIView animateWithDuration:_sharingAnimatedDuration
                       animations:^{
        ghostImg.frame = endFrame;
        ghostImg.layer.cornerRadius = toImg.layer.cornerRadius;
        ghostImg.contentMode = toImg.contentMode;
      }];
    }
    else {
      [UIView animateWithDuration:_sharingAnimatedDuration
                       animations:^{
        ghostChild.frame = endFrame;
      }];
    }
    
    // Recursive nếu có children
    if (fromChild.subviews.count &&
        toChild.subviews.count &&
        ghostChild.subviews.count) {
      [self _animateSubviewsFrom:fromChild to:toChild ghost:ghostChild];
    }
  }
}

#pragma mark - Cleanup

- (void)didUnmount {
  [self.overlayContainer removeFromSuperview];
  self.overlayContainer = nil;
  self.ghostView = nil;
  self.originalView = nil;
  self.isAnimating = NO;
}

@end
