//
//  UIViewShareController+RNBackLife.h
//  ShareElement
//
//  Created by Sang Le vinh on 9/11/25.
//


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^RNBackBlock)(void);
typedef void (^RNLifecycleBlock)(BOOL animated);

@interface UIViewController (RNBackLife)

@property (nonatomic, copy, nullable) RNBackBlock       rn_onWillPop;
@property (nonatomic, copy, nullable) RNBackBlock       rn_onDidPop;

@property (nonatomic, copy, nullable) RNLifecycleBlock  rn_onWillAppear;
@property (nonatomic, copy, nullable) RNLifecycleBlock  rn_onDidAppear;
@property (nonatomic, copy, nullable) RNLifecycleBlock  rn_onWillDisappear;
@property (nonatomic, copy, nullable) RNLifecycleBlock  rn_onDidDisappear;

- (NSTimeInterval)rn_transitionDuration;

+ (void)rn_swizzleBackLifeIfNeeded;

@end

NS_ASSUME_NONNULL_END
