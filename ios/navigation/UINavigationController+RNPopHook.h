//
//  UINavigationController+RNPopHook.h
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
//

#import <UIKit/UIKit.h>

@interface UINavigationController (RNPopHook)
// Gọi 1 lần để bật hook (swizzle popViewControllerAnimated:)
+ (void)rn_enablePopHookOnce;
@end
