//
//  UINavigationController+RNPopHook.m
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
//

#import "UINavigationController+RNPopHook.h"
#import <objc/runtime.h>

@implementation UINavigationController (RNPopHook)

static inline NSString *RNInferReason(UINavigationController *nav) {
  // 1) gesture?
  UIGestureRecognizer *g = nav.interactivePopGestureRecognizer;
  if (g && (g.state == UIGestureRecognizerStateBegan ||
            g.state == UIGestureRecognizerStateChanged ||
            g.state == UIGestureRecognizerStateEnded)) {
    return @"gesture";
  }
  // 2) back button? dựa theo call stack
  for (NSString *s in [NSThread callStackSymbols]) {
    if ([s containsString:@"UINavigationBar"] ||
        [s containsString:@"UIButtonBar"]     ||
        [s containsString:@"UIBarButton"]     ||
        [s containsString:@"_UINavigationBar"]) {
      return @"backButton";
    }
  }
  // 3) còn lại coi như programmatic (navigation.goBack, code gọi pop)
  return @"programmatic";
}

+ (void)rn_enablePopHookOnce {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    Class c = [UINavigationController class];
    Method orig = class_getInstanceMethod(c, @selector(popViewControllerAnimated:));
    Method hook = class_getInstanceMethod(c, @selector(rn_popViewControllerAnimated_:));
    method_exchangeImplementations(orig, hook);
  });
}

- (UIViewController *)rn_popViewControllerAnimated_:(BOOL)animated {
  UIViewController *from = self.topViewController;
  UIViewController *to = (self.viewControllers.count >= 2)
  ? self.viewControllers[self.viewControllers.count - 2] : nil;
  
  NSString *reason = RNInferReason(self);
  [[NSNotificationCenter defaultCenter] postNotificationName:@"RNWillPopViewControllerNotification"
                                                      object:self
                                                    userInfo:@{
    @"nav": self,
    @"from": from ?: [NSNull null],
    @"to":   to   ?: (id)[NSNull null],
    @"reason": reason
  }];
  
  return [self rn_popViewControllerAnimated_:animated];
}

@end
