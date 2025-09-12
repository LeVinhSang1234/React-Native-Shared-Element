//
//  UINavigationController+RNPopHook.m
//  ShareVideo
//
//  Created by Sang Lv on 23/8/25.
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
    
    // 1) popViewControllerAnimated:
    //    - Trả về VC top bị pop ra khỏi stack (thường dùng khi user bấm back hoặc navigation.goBack()).
    //    - Đây là case phổ biến nhất → bạn chắc chắn cần hook.
    Method orig = class_getInstanceMethod(c, @selector(popViewControllerAnimated:));
    Method hook = class_getInstanceMethod(c, @selector(rn_popViewControllerAnimated_:));
    method_exchangeImplementations(orig, hook);
    
    // 2) popToViewController:animated:
    //    - Pop nhiều VC cùng lúc, giữ lại 1 VC chỉ định trong stack.
    //    - Ví dụ stack [A, B, C, D], gọi popToViewController:B → remove C và D.
    //    - Hook để biết khi user hoặc code nhảy lùi nhiều màn hình.
    // Method orig2 = class_getInstanceMethod(c, @selector(popToViewController:animated:));
    // Method hook2 = class_getInstanceMethod(c, @selector(rn_popToViewController_:animated:));
    // method_exchangeImplementations(orig2, hook2);
    
    // 3) popToRootViewControllerAnimated:
    //    - Pop toàn bộ stack về root.
    //    - Ví dụ [A, B, C, D] → chỉ còn A.
    //    - Hook để catch trường hợp user hoặc code gọi back to root.
    // Method orig3 = class_getInstanceMethod(c, @selector(popToRootViewControllerAnimated:));
    // Method hook3 = class_getInstanceMethod(c, @selector(rn_popToRootViewControllerAnimated_:));
    // method_exchangeImplementations(orig3, hook3);
    
    // 4) setViewControllers:animated:
    //    - Thay toàn bộ stack mới, có thể loại bỏ nhiều VC mà không gọi popXXX.
    //    - Ví dụ stack [A, B, C], gọi setViewControllers:@[A, D] → B và C bị bỏ, D thêm vào.
    //    - Hook để xử lý khi React Navigation reset stack hoặc replace.
    //    Method orig4 = class_getInstanceMethod(c, @selector(setViewControllers:));
    //    Method hook4 = class_getInstanceMethod(c, @selector(rn_setViewControllers_:));
    //    method_exchangeImplementations(orig4, hook4);
  });
}

// sequence để phân biệt mỗi lần pop (chống log/trùng handler)

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
