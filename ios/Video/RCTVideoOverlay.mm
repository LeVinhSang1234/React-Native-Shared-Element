//
//  RCTVideoOverlay.m
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
//

#import "RCTVideoOverlay.h"
#import "RCTVideoHelper.h"

/// Default constants
static const double kDefaultSharingDuration   = 0.35;   // seconds
static const double kDefaultCompletionDelay   = 0.15;    // seconds
static NSString * const kDefaultVideoGravity  = AVLayerVideoGravityResizeAspect;

@interface RCTVideoOverlay ()
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) AVLayerVideoGravity videoGravity;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@end

@implementation RCTVideoOverlay

- (instancetype)init {
  if (self = [super init]) {
    _sharingAnimatedDuration = kDefaultSharingDuration;
    _videoGravity = kDefaultVideoGravity;
  }
  return self;
}

#pragma mark - Apply props

- (void)applyAVLayerVideoGravity:(AVLayerVideoGravity)gravity {
  if (gravity) {
    _videoGravity = gravity;
  }
}

- (void)applySharingAnimatedDuration:(double)durationMs {
  double duration = (durationMs <= 0) ? kDefaultSharingDuration : durationMs / 1000.0;
  if (duration != _sharingAnimatedDuration) {
    _sharingAnimatedDuration = duration;
  }
}

#pragma mark - CADisplayLink ticking

- (void)startTicking {
  if (_displayLink) return;
  _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_onTick)];
  [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopTicking {
  [_displayLink invalidate];
  _displayLink = nil;
}

- (void)_onTick {
  CALayer *presentation = self.layer.presentationLayer;
  if (!presentation) return;
  
  CGRect liveBounds = presentation.bounds;
  [CATransaction begin];
  [CATransaction setDisableActions:YES];
  _playerLayer.frame = (CGRect){CGPointZero, liveBounds.size};
  [CATransaction commit];
}

#pragma mark - Overlay animation

- (void)moveToOverlay:(CGRect)fromFrame
           tagetFrame:(CGRect)toFrame
               player:(AVPlayer *)player
  aVLayerVideoGravity:(AVLayerVideoGravity)gravity
              bgColor:(UIColor *)bgColor
             willMove:(void (^)(void))willMove
             onTarget:(void (^)(void))onTarget
          onCompleted:(void (^)(void))onCompleted
{
  UIWindow *win = [RCTVideoHelper getTargetWindow];
  if (!win) return;
  [self unmount];
  self.frame = fromFrame;
  self.clipsToBounds = YES;
  
  _playerLayer = [AVPlayerLayer playerLayerWithPlayer:player];
  _playerLayer.videoGravity = gravity ?: _videoGravity;
  _playerLayer.frame = self.bounds;
  [self.layer addSublayer:_playerLayer];
  self.backgroundColor = bgColor ?: UIColor.clearColor;

  [win addSubview:self];
  [win bringSubviewToFront:self];
  
  [self startTicking];
  
  if(willMove) willMove();
  __weak __typeof__(self) weakSelf = self;
  [UIView animateWithDuration:_sharingAnimatedDuration
                        delay:0
                      options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                   animations:^{
    weakSelf.frame = toFrame;
  } completion:^(BOOL finished) {
    __strong __typeof__(weakSelf) self = weakSelf;
    if (!self || !finished) return;
    
    [self _onTick];
    [self stopTicking];
    
    if (onTarget) onTarget();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(kDefaultCompletionDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      if (onCompleted) onCompleted();
      [self unmount];
    });
  }];
}

#pragma mark - Cleanup

- (void)unmount {
  if (_playerLayer) {
    [_playerLayer removeFromSuperlayer];
    _playerLayer = nil;
  }
  [self removeFromSuperview];
  [self stopTicking];
}

@end
