//
//  RCTShareViewOverlay.m
//  ShareVideo
//
//  Created by Sang Le Vinh on 9/4/25.
//

#import "RCTShareViewOverlay.h"
#import "RCTVideoHelper.h"

/// Default constants
static const double kDefaultSharingDuration = 0.35; // giây
static const double kDefaultCompletionDelay = 0.1;  // giây

@interface RCTShareViewOverlay ()
@property (nonatomic, strong) CALayer *ghostLayer;
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
  _sharingAnimatedDuration = duration;
}

#pragma mark - Clone CALayer tree

- (CALayer *)cloneLayer:(CALayer *)layer {
  CALayer *copy = [[CALayer alloc] init];
  copy.frame = layer.frame;
  copy.bounds = layer.bounds;
  copy.position = layer.position;
  copy.anchorPoint = layer.anchorPoint;
  copy.cornerRadius = layer.cornerRadius;
  copy.backgroundColor = layer.backgroundColor;
  copy.opacity = layer.opacity;
  copy.masksToBounds = layer.masksToBounds;
  copy.contentsGravity = layer.contentsGravity;
  copy.contentsScale = layer.contentsScale;
  
  if (layer.contents) {
    copy.contents = layer.contents; // Giữ nguyên image bitmap
  }
  
  if ([layer isKindOfClass:[CATextLayer class]]) {
    CATextLayer *src = (CATextLayer *)layer;
    CATextLayer *dst = (CATextLayer *)copy;
    dst.string = src.string;
    dst.font = src.font;
    dst.fontSize = src.fontSize;
    dst.foregroundColor = src.foregroundColor;
    dst.alignmentMode = src.alignmentMode;
    dst.wrapped = src.wrapped;
    dst.truncationMode = src.truncationMode;
    dst.contentsScale = src.contentsScale;
  }
  
  NSMutableArray *subCopies = [NSMutableArray array];
  for (CALayer *sub in layer.sublayers) {
    CALayer *subCopy = [self cloneLayer:sub];
    if (subCopy) {
      [subCopies addObject:subCopy];
    }
  }
  copy.sublayers = subCopies;
  
  return copy;
}

#pragma mark - Animate

- (void)moveToOverlay:(CGRect)fromFrame
           tagetFrame:(CGRect)toFrame
              content:(UIView *)contentView
sharingAnimatedDuration:(double)sharingAnimatedDuration
             onTarget:(nullable dispatch_block_t)onTarget
          onCompleted:(nullable dispatch_block_t)onCompleted
{
  UIWindow *win = [RCTVideoHelper getTargetWindow];
  if (!win || !contentView) return;

  // Clone toàn bộ layer tree
  CALayer *ghost = [self cloneLayer:contentView.layer];
  ghost.frame = fromFrame;

  [win.layer addSublayer:ghost];
  self.ghostLayer = ghost;

  double dur = sharingAnimatedDuration > 0 ? sharingAnimatedDuration : _sharingAnimatedDuration;

  // Animation cho position
  CABasicAnimation *posAnim = [CABasicAnimation animationWithKeyPath:@"position"];
  posAnim.fromValue = [NSValue valueWithCGPoint:CGPointMake(CGRectGetMidX(fromFrame), CGRectGetMidY(fromFrame))];
  posAnim.toValue   = [NSValue valueWithCGPoint:CGPointMake(CGRectGetMidX(toFrame),   CGRectGetMidY(toFrame))];
  posAnim.duration  = dur;
  posAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

  // Animation cho bounds
  CABasicAnimation *boundsAnim = [CABasicAnimation animationWithKeyPath:@"bounds"];
  boundsAnim.fromValue = [NSValue valueWithCGRect:CGRectMake(0,0,fromFrame.size.width,fromFrame.size.height)];
  boundsAnim.toValue   = [NSValue valueWithCGRect:CGRectMake(0,0,toFrame.size.width,toFrame.size.height)];
  boundsAnim.duration  = dur;
  boundsAnim.timingFunction = posAnim.timingFunction;

  [CATransaction begin];
  [CATransaction setCompletionBlock:^{
    if (onTarget) onTarget();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDefaultCompletionDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      [ghost removeFromSuperlayer];
      self.ghostLayer = nil;
      if (onCompleted) onCompleted();
    });
  }];

  [ghost addAnimation:posAnim forKey:@"positionAnim"];
  [ghost addAnimation:boundsAnim forKey:@"boundsAnim"];

  // Set trạng thái cuối
  ghost.position = CGPointMake(CGRectGetMidX(toFrame), CGRectGetMidY(toFrame));
  ghost.bounds   = CGRectMake(0,0,toFrame.size.width,toFrame.size.height);

  [CATransaction commit];
}

#pragma mark - Cleanup

- (void)didUnmount {
  if (_ghostLayer) {
    [_ghostLayer removeFromSuperlayer];
    _ghostLayer = nil;
  }
  [self removeFromSuperview];
}

@end
