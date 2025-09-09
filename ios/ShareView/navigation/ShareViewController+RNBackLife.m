//
//  UIViewController+RNBackLife.m
//  ShareVideo
//
//  Created by Sang Lv on 23/8/25.
//  Refactored: thêm will/didPushAppear, full lifecycle + pop hooks, double-fire guards
//

#import "UIViewController+RNBackLife.h"
#import <objc/runtime.h>

/// typedef void (^RNBackBlock)(void);
/// typedef void (^RNLifecycleBlock)(BOOL animated);

#pragma mark - AO Keys

static void *kWillKey            = &kWillKey;
static void *kDidKey             = &kDidKey;
static void *kWillAppearKey      = &kWillAppearKey;
static void *kDidAppearKey       = &kDidAppearKey;
static void *kWillDisappearKey   = &kWillDisappearKey;
static void *kDidDisappearKey    = &kDidDisappearKey;
// 🔥 thêm push
static void *kWillPushAppearKey  = &kWillPushAppearKey;
static void *kDidPushAppearKey   = &kDidPushAppearKey;

// Guards chống bắn lặp
static void *kDidPopFiredKey     = &kDidPopFiredKey;   // BOOL
static void *kWillPopFiredKey    = &kWillPopFiredKey;  // BOOL

static void *kNavTransitionDurationKey = &kNavTransitionDurationKey;

#pragma mark - Swizzle once

@implementation UIViewController (RNBackLife)

+ (void)rn_swizzleBackLifeIfNeeded
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    Class c = [UIViewController class];
    
    method_exchangeImplementations(
                                   class_getInstanceMethod(c, @selector(viewWillAppear:)),
                                   class_getInstanceMethod(c, @selector(rn_viewWillAppear_back:))
                                   );
    
    method_exchangeImplementations(
                                   class_getInstanceMethod(c, @selector(viewDidAppear:)),
                                   class_getInstanceMethod(c, @selector(rn_viewDidAppear_back:))
                                   );
    
    method_exchangeImplementations(
                                   class_getInstanceMethod(c, @selector(viewWillDisappear:)),
                                   class_getInstanceMethod(c, @selector(rn_viewWillDisappear_back:))
                                   );
    
    method_exchangeImplementations(
                                   class_getInstanceMethod(c, @selector(viewDidDisappear:)),
                                   class_getInstanceMethod(c, @selector(rn_viewDidDisappear_back:))
                                   );
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

RN_ASSOC_BLOCK(rn_onWillPop,        setRn_onWillPop,        kWillKey,          RNBackBlock)
RN_ASSOC_BLOCK(rn_onDidPop,         setRn_onDidPop,         kDidKey,           RNBackBlock)
RN_ASSOC_BLOCK(rn_onWillAppear,     setRn_onWillAppear,     kWillAppearKey,    RNLifecycleBlock)
RN_ASSOC_BLOCK(rn_onDidAppear,      setRn_onDidAppear,      kDidAppearKey,     RNLifecycleBlock)
RN_ASSOC_BLOCK(rn_onWillDisappear,  setRn_onWillDisappear,  kWillDisappearKey, RNLifecycleBlock)
RN_ASSOC_BLOCK(rn_onDidDisappear,   setRn_onDidDisappear,   kDidDisappearKey,  RNLifecycleBlock)

#pragma mark - Swizzled implementations

- (void)rn_viewWillAppear_back:(BOOL)animated
{
  [self rn_viewWillAppear_back:animated]; // gọi original
  
  rn_setFlag(self, kWillPopFiredKey, NO);
  rn_setFlag(self, kDidPopFiredKey,  NO);
  
  if (self.rn_onWillAppear) self.rn_onWillAppear(animated);
  
  id<UIViewControllerTransitionCoordinator> tc = self.transitionCoordinator;
   if (tc) {
     NSTimeInterval dur = tc.transitionDuration;
     objc_setAssociatedObject(self, kNavTransitionDurationKey, @(dur), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
   } else {
     objc_setAssociatedObject(self, kNavTransitionDurationKey, @(0.35), OBJC_ASSOCIATION_RETAIN_NONATOMIC); // fallback default
   }
}

- (void)rn_viewDidAppear_back:(BOOL)animated
{
  [self rn_viewDidAppear_back:animated]; // gọi original
  
  if (self.rn_onDidAppear) self.rn_onDidAppear(animated);
}

- (void)rn_viewWillDisappear_back:(BOOL)animated
{
  [self rn_viewWillDisappear_back:animated]; // gọi original
  
  if (self.rn_onWillDisappear) self.rn_onWillDisappear(animated);
  
  BOOL isPoppingOrDismissing = (self.isMovingFromParentViewController || self.isBeingDismissed);
  if (isPoppingOrDismissing && !rn_getFlag(self, kWillPopFiredKey)) {
    rn_setFlag(self, kWillPopFiredKey, YES);
    if (self.rn_onWillPop) self.rn_onWillPop();
  }
}

- (void)rn_viewDidDisappear_back:(BOOL)animated
{
  [self rn_viewDidDisappear_back:animated]; // gọi original
  
  if (self.rn_onDidDisappear) self.rn_onDidDisappear(animated);
  
  UINavigationController *nav = self.navigationController;
  BOOL poppedFromNav = (nav && ![nav.viewControllers containsObject:self]);
  BOOL dismissed     = self.isBeingDismissed;
  
  if ((poppedFromNav || dismissed) && !rn_getFlag(self, kDidPopFiredKey)) {
    rn_setFlag(self, kDidPopFiredKey, YES);
    if (self.rn_onDidPop) self.rn_onDidPop();
  }
}

- (NSTimeInterval)rn_transitionDuration {
  NSNumber *n = objc_getAssociatedObject(self, kNavTransitionDurationKey);
  return n ? n.doubleValue : -1; // default
}

@end
