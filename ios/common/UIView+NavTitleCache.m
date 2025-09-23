//
//  UIView+NavTitleCache.m
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
//

#import "UIView+NavTitleCache.h"
#import <objc/runtime.h>

@implementation UIView (NavTitleCache)

static char kCachedNavTitleKey;

- (void)setRn_cachedNavTitle:(NSString * _Nullable)title {
  objc_setAssociatedObject(self, &kCachedNavTitleKey, title, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)rn_cachedNavTitle {
  return objc_getAssociatedObject(self, &kCachedNavTitleKey);
}

- (void)rn_updateCachedNavTitle {
  // tìm nearest VC
  UIResponder *responder = self;
  UIViewController *vc = nil;
  while (responder) {
    responder = responder.nextResponder;
    if ([responder isKindOfClass:[UIViewController class]]) {
      vc = (UIViewController *)responder;
      break;
    }
  }
  if (vc) {
    NSString *title = vc.navigationItem.title ?: vc.title;
    if (title.length > 0) {
      self.rn_cachedNavTitle = title;
    }
  }
}

- (NSString *)rn_currentNavTitle {
  if (self.rn_cachedNavTitle.length > 0) {
    return self.rn_cachedNavTitle;
  }
  [self rn_updateCachedNavTitle];
  return self.rn_cachedNavTitle ?: @"<no-title>";
}

@end
