//
//  UIViewController+RNBackLife.m
//  ShareVideo
//
//  Created by Sang Lv on 23/8/25.
//

#import "UIViewController+RNBackLife.h"
#import <objc/runtime.h>

static void *kWillKey = &kWillKey;
static void *kDidKey  = &kDidKey;
static BOOL s_swizzled = NO;

@implementation UIViewController (RNBackLife)

- (RNBackBlock)rn_onWillPop { return objc_getAssociatedObject(self, kWillKey); }
- (void)setRn_onWillPop:(RNBackBlock)b { objc_setAssociatedObject(self, kWillKey, b, OBJC_ASSOCIATION_COPY_NONATOMIC); }
- (RNBackBlock)rn_onDidPop { return objc_getAssociatedObject(self, kDidKey); }
- (void)setRn_onDidPop:(RNBackBlock)b { objc_setAssociatedObject(self, kDidKey, b, OBJC_ASSOCIATION_COPY_NONATOMIC); }

+ (void)rn_swizzleBackLifeIfNeeded {
  if (s_swizzled) return; s_swizzled = YES;
  Class c = [UIViewController class];
  
  Method o1 = class_getInstanceMethod(c, @selector(viewWillDisappear:));
  Method s1 = class_getInstanceMethod(c, @selector(rn_viewWillDisappear_back:));
  method_exchangeImplementations(o1, s1);
  
  Method o2 = class_getInstanceMethod(c, @selector(viewDidDisappear:));
  Method s2 = class_getInstanceMethod(c, @selector(rn_viewDidDisappear_back:));
  method_exchangeImplementations(o2, s2);
}

- (void)rn_viewWillDisappear_back:(BOOL)animated {
  [self rn_viewWillDisappear_back:animated]; // original
  // pop/dismiss (không gọi khi push)
  if ((self.isMovingFromParentViewController || self.isBeingDismissed) && self.rn_onWillPop) {
    self.rn_onWillPop();
  }
}

- (void)rn_viewDidDisappear_back:(BOOL)animated {
  [self rn_viewDidDisappear_back:animated]; // original
  // xác nhận rời stack: nav không còn chứa self hoặc self bị dismiss
  UINavigationController *nav = self.navigationController;
  BOOL popped = (nav && ![nav.viewControllers containsObject:self]) || self.isBeingDismissed;
  if (popped && self.rn_onDidPop) {
    self.rn_onDidPop();
  }
}
@end
