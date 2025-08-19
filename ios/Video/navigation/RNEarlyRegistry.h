//
//  RNEarlyRegistry.h
//  ShareVideo
//
//  Created by Sang Lv on 23/8/25.
//

#import <UIKit/UIKit.h>
@interface RNEarlyRegistry : NSObject
+ (instancetype)shared;
- (void)addView:(UIView *)v;
- (void)removeView:(UIView *)v;
- (void)notifyNav;
@end
