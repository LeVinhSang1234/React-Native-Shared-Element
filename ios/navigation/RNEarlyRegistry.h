//
//  RNEarlyRegistry.h
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
//

#import <UIKit/UIKit.h>
@interface RNEarlyRegistry : NSObject
+ (instancetype)shared;
- (void)addView:(UIView *)v;
- (void)removeView:(UIView *)v;
- (void)notifyNav;
@end
