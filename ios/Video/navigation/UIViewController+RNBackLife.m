//
//  UIViewController+RNBackLife.m
//  ShareVideo
//
//  Created by Sang Lv on 23/8/25.
//  Refactored: compact AO props, full lifecycle + pop hooks, double-fire guards
//

#import "UIViewController+RNBackLife.h"
#import <objc/runtime.h>

/// Nếu header định nghĩa:
/// typedef void (^RNBackBlock)(void);
/// typedef void (^RNLifecycleBlock)(BOOL animated);

#pragma mark - AO Keys

static void *kWillKey          = &kWillKey;
static void *kDidKey           = &kDidKey;
static void *kWillAppearKey    = &kWillAppearKey;
static void *kDidAppearKey     = &kDidAppearKey;
static void *kWillDisappearKey = &kWillDisappearKey;
static void *kDidDisappearKey  = &kDidDisappearKey;

// Guards chống bắn lặp
static void *kDidPopFiredKey   = &kDidPopFiredKey;   // BOOL
static void *kWillPopFiredKey  = &kWillPopFiredKey;  // BOOL

#pragma mark - Swizzle once

@implementation UIViewController (RNBackLife)

+ (void)rn_swizzleBackLifeIfNeeded
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    Class c = [UIViewController class];

    Method o1 = class_getInstanceMethod(c, @selector(viewWillAppear:));
    Method s1 = class_getInstanceMethod(c, @selector(rn_viewWillAppear_back:));
    method_exchangeImplementations(o1, s1);

    Method o2 = class_getInstanceMethod(c, @selector(viewDidAppear:));
    Method s2 = class_getInstanceMethod(c, @selector(rn_viewDidAppear_back:));
    method_exchangeImplementations(o2, s2);

    Method o3 = class_getInstanceMethod(c, @selector(viewWillDisappear:));
    Method s3 = class_getInstanceMethod(c, @selector(rn_viewWillDisappear_back:));
    method_exchangeImplementations(o3, s3);

    Method o4 = class_getInstanceMethod(c, @selector(viewDidDisappear:));
    Method s4 = class_getInstanceMethod(c, @selector(rn_viewDidDisappear_back:));
    method_exchangeImplementations(o4, s4);
  });
}

#pragma mark - AO helpers

#define RN_ASSOC_BLOCK(PROPNAME, SETTER, KEYVAR, BLOCKTYPE) \
  - (BLOCKTYPE)PROPNAME { return objc_getAssociatedObject(self, KEYVAR); } \
  - (void)SETTER:(BLOCKTYPE)b { objc_setAssociatedObject(self, KEYVAR, b, OBJC_ASSOCIATION_COPY_NONATOMIC); }

static inline BOOL rn_getFlag(id self, void *key) {
  NSNumber *n = objc_getAssociatedObject(self, key);
  return n.boolValue;
}
static inline void rn_setFlag(id self, void *key, BOOL v) {
  objc_setAssociatedObject(self, key, @(v), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Public properties (blocks)

RN_ASSOC_BLOCK(rn_onWillPop,       setRn_onWillPop,       kWillKey,          RNBackBlock)
RN_ASSOC_BLOCK(rn_onDidPop,        setRn_onDidPop,        kDidKey,           RNBackBlock)
RN_ASSOC_BLOCK(rn_onWillAppear,    setRn_onWillAppear,    kWillAppearKey,    RNLifecycleBlock)
RN_ASSOC_BLOCK(rn_onDidAppear,     setRn_onDidAppear,     kDidAppearKey,     RNLifecycleBlock)
RN_ASSOC_BLOCK(rn_onWillDisappear, setRn_onWillDisappear, kWillDisappearKey, RNLifecycleBlock)
RN_ASSOC_BLOCK(rn_onDidDisappear,  setRn_onDidDisappear,  kDidDisappearKey,  RNLifecycleBlock)

#pragma mark - Swizzled implementations

- (void)rn_viewWillAppear_back:(BOOL)animated
{
  // Gọi original
  [self rn_viewWillAppear_back:animated];

  // Reset guard mỗi lần view sắp xuất hiện
  rn_setFlag(self, kWillPopFiredKey, NO);
  rn_setFlag(self, kDidPopFiredKey,  NO);

  RNLifecycleBlock block = self.rn_onWillAppear;
  if (block) block(animated);
}

- (void)rn_viewDidAppear_back:(BOOL)animated
{
  [self rn_viewDidAppear_back:animated];
  RNLifecycleBlock block = self.rn_onDidAppear;
  if (block) block(animated);
}

- (void)rn_viewWillDisappear_back:(BOOL)animated
{
  [self rn_viewWillDisappear_back:animated];

  // Lifecycle callback
  RNLifecycleBlock life = self.rn_onWillDisappear;
  if (life) life(animated);

  // Chỉ coi là WILL-POP khi rời stack vì pop/dismiss (không phải push)
  BOOL isPoppingOrDismissing = (self.isMovingFromParentViewController || self.isBeingDismissed);
  if (isPoppingOrDismissing && !rn_getFlag(self, kWillPopFiredKey)) {
    rn_setFlag(self, kWillPopFiredKey, YES);
    RNBackBlock will = self.rn_onWillPop;
    if (will) will();
  }
}

- (void)rn_viewDidDisappear_back:(BOOL)animated
{
  [self rn_viewDidDisappear_back:animated];

  // Lifecycle callback
  RNLifecycleBlock life = self.rn_onDidDisappear;
  if (life) life(animated);

  // Xác nhận DID-POP: hoặc bị pop khỏi nav stack, hoặc bị dismiss
  UINavigationController *nav = self.navigationController;
  BOOL poppedFromNav = (nav && ![nav.viewControllers containsObject:self]);
  BOOL dismissed     = self.isBeingDismissed;

  if ((poppedFromNav || dismissed) && !rn_getFlag(self, kDidPopFiredKey)) {
    rn_setFlag(self, kDidPopFiredKey, YES);
    RNBackBlock did = self.rn_onDidPop;
    if (did) did();
  }
}

@end
