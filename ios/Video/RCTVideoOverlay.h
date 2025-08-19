//
//  RCTVideoOverlay.h
//  ShareVideo
//
//  Created by Sang Lv on 21/8/25.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AVKit/AVKit.h"

@class RCTVideoView;

NS_ASSUME_NONNULL_BEGIN
@interface RCTVideoOverlay : UIView
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, assign) double sharingAnimatedDuration;
@property (nonatomic, assign) AVLayerVideoGravity aVLayerVideoGravity;

@property (nonatomic, strong) CADisplayLink *displayLink;

- (void)applySharingAnimatedDuration:(double)sharingAnimatedDuration;

- (void)moveToOverlay:(CGRect) moveFrame
           tagetFrame:(CGRect) targetFrame
               player:(AVPlayer *)player
  aVLayerVideoGravity:(AVLayerVideoGravity)aVLayerVideoGravity
              bgColor: (UIColor *) bgColor
             onTarget:(nonnull void (^)(void))onTarget
          onCompleted:(nonnull void (^)(void))onCompleted;

- (void)applyAVLayerVideoGravity:(AVLayerVideoGravity)aVLayerVideoGravity;

- (void)unmount;

@end
NS_ASSUME_NONNULL_END
