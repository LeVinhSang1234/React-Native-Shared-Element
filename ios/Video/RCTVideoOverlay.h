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
@property (nonatomic, assign) double sharingAnimatedDuration;

- (void)applySharingAnimatedDuration:(double)sharingAnimatedDuration;

- (void)moveToOverlay:(CGRect) moveFrame
           tagetFrame:(CGRect) targetFrame
               player:(AVPlayer *)player
  aVLayerVideoGravity:(AVLayerVideoGravity)aVLayerVideoGravity
              bgColor: (UIColor *) bgColor
             onTarget:(nonnull void (^)(void))onTarget
          onCompleted:(nonnull void (^)(void))onCompleted;

- (void)didUnmount;

@end
NS_ASSUME_NONNULL_END
