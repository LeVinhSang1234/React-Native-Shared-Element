//
//  RCTVideoOverlay.h
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AVKit/AVKit.h"

@class RCTVideoView;

NS_ASSUME_NONNULL_BEGIN
@interface RCTVideoOverlay : UIView
@property (nonatomic, assign) double sharingAnimatedDuration;

- (void)applySharingAnimatedDuration:(double)sharingAnimatedDuration;

- (void)moveToOverlay:(CGRect)fromFrame
           tagetFrame:(CGRect)toFrame
               player:(AVPlayer *)player
  aVLayerVideoGravity:(AVLayerVideoGravity)gravity
          fromBgColor:(UIColor *)fromBgColor
            toBgColor:(UIColor *)toBgColor
             willMove:(void (^)(void))willMove
             onTarget:(void (^)(void))onTarget
          onCompleted:(void (^)(void))onCompleted;

- (void)unmount;

@end
NS_ASSUME_NONNULL_END
