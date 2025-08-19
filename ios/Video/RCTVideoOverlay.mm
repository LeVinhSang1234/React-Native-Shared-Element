//
//  RCTVideoOverlay.m
//  ShareVideo
//
//  Created by Sang Lv on 21/8/25.
//
#import "RCTVideoOverlay.h"
#import "RCTVideoHelper.h"

@implementation RCTVideoOverlay

- (instancetype) init {
  if(self = [super init]) {
    _sharingAnimatedDuration = 0.35;
  };
  _aVLayerVideoGravity = AVLayerVideoGravityResizeAspect;
  return self;
}

- (void)applyAVLayerVideoGravity:(AVLayerVideoGravity)aVLayerVideoGravity {
  if(aVLayerVideoGravity) _aVLayerVideoGravity = aVLayerVideoGravity;
}

// -------- Sharing Animated Duration --------- //
- (void)applySharingAnimatedDuration:(double)sharingAnimatedDuration {
  double duration = sharingAnimatedDuration;
  if(duration < 0) {
    duration = 0.35;
  } else duration = duration / 1000;
  if(duration != _sharingAnimatedDuration){
    _sharingAnimatedDuration = duration;
  }
}

- (void)startTicking {
  if (_displayLink) return;
  _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_onTick)];
  [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopTicking {
  [self.displayLink invalidate];
  _displayLink = nil;
}

- (void)_onTick {
  
  CALayer *pl = (CALayer *)self.layer.presentationLayer;
  if (!pl) return;
  
  CGRect liveBounds = pl.bounds;
  
  [CATransaction setDisableActions:YES];
  _playerLayer.frame = (CGRect){CGPointZero, liveBounds.size};
  [CATransaction commit];
}

// -------- Sharing Animated Duration --------- //
- (void)moveToOverlay:(CGRect)fromFrame
           tagetFrame:(CGRect)toFrame
               player:(AVPlayer *)player
  aVLayerVideoGravity:(AVLayerVideoGravity)gravity
              bgColor:(UIColor *)bgColor
             onTarget:(void (^)(void))onTarget
          onCompleted:(void (^)(void))onCompleted
{
  UIWindow *win = [RCTVideoHelper getTargetWindow];
  if (!win) return;
  
  [self unmount];
  
  self.frame = fromFrame;
  if(bgColor) self.backgroundColor = bgColor;
  self.clipsToBounds = YES;
  
  _playerLayer = [AVPlayerLayer playerLayerWithPlayer:player];
  _playerLayer.videoGravity = gravity ?: AVLayerVideoGravityResizeAspect;
  _playerLayer.actions = @{@"bounds":NSNull.null, @"position":NSNull.null, @"frame":NSNull.null};
  _playerLayer.frame = self.bounds;
  [self.layer addSublayer:_playerLayer];
  
  [win addSubview:self];
  [win bringSubviewToFront:self];

  [self startTicking];
  __weak RCTVideoOverlay *weakSelf = self;
  [UIView animateWithDuration:_sharingAnimatedDuration
                        delay:0
                      options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                   animations:^{
    weakSelf.frame = toFrame;
  } completion:^(BOOL finished) {
    if(finished) {
      [weakSelf _onTick];
      [weakSelf stopTicking];
      
      if (onTarget) onTarget();
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (onCompleted) onCompleted();
        [weakSelf unmount];
      });
    }
  }];
}


- (void)unmount {
  if(_playerLayer) {
    [_playerLayer removeFromSuperlayer];
    _playerLayer = nil;
  }
  [self removeFromSuperview];
  [self stopTicking];
}
@end

