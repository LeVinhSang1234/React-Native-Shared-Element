//
//  UIViewController+RNBackLife.h
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^RNBackBlock)(void);
typedef void (^RNLifecycleBlock)(BOOL animated);

@interface UIViewController (RNBackLife)

// Pop events
@property (nonatomic, strong, readonly) NSMutableArray<RNBackBlock> *rn_onWillPopBlocks;
@property (nonatomic, strong, readonly) NSMutableArray<RNBackBlock> *rn_onDidPopBlocks;

// Lifecycle events
@property (nonatomic, strong, readonly) NSMutableArray<RNLifecycleBlock> *rn_onWillAppearBlocks;
@property (nonatomic, strong, readonly) NSMutableArray<RNLifecycleBlock> *rn_onDidAppearBlocks;
@property (nonatomic, strong, readonly) NSMutableArray<RNLifecycleBlock> *rn_onWillDisappearBlocks;
@property (nonatomic, strong, readonly) NSMutableArray<RNLifecycleBlock> *rn_onDidDisappearBlocks;

// Duration of current transition
- (NSTimeInterval)rn_transitionDuration;

// Swizzle once
+ (void)rn_swizzleBackLifeIfNeeded;

@end

NS_ASSUME_NONNULL_END
