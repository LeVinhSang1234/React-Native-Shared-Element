//
//  UINavigationController+RNPopHook.h
//  ShareVideo
//
//  Created by Sang Lv on 23/8/25.
//

#import <UIKit/UIKit.h>

@interface UINavigationController (RNPopHook)
// Gọi 1 lần để bật hook (swizzle popViewControllerAnimated:)
+ (void)rn_enablePopHookOnce;
@end
