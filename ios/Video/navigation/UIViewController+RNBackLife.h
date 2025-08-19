//
//  UIViewController+RNBackLife.h
//  ShareVideo
//
//  Created by Sang Lv on 23/8/25.
//

#import <UIKit/UIKit.h>
typedef void (^RNBackBlock)(void);

@interface UIViewController (RNBackLife)
@property (nonatomic, copy) RNBackBlock rn_onWillPop;
@property (nonatomic, copy) RNBackBlock rn_onDidPop;
+ (void)rn_swizzleBackLifeIfNeeded;
@end
