//
//  RCTShareViewOverlay.h
//  ShareElement
//
//  Created by Sang Le vinh on 9/12/25.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AVKit/AVKit.h"

@class RCTShareView;

NS_ASSUME_NONNULL_BEGIN
@interface RCTShareViewOverlay : UIView
@property (nonatomic, assign) double sharingAnimatedDuration;

- (void)applySharingAnimatedDuration:(double)sharingAnimatedDuration;

- (void)moveToOverlay:(CGRect)fromFrame
           targetFrame:(CGRect)toFrame
             fromView:(UIView *)fromView
               toView:(UIView *)toView
              onTarget:(void (^)(void))onTarget
           onCompleted:(void (^)(void))onCompleted;

- (void)didUnmount;

@end
NS_ASSUME_NONNULL_END
