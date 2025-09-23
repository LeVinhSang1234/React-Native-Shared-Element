//
//  UIViewController+RNBackLife.m
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
//

#import "UIViewController+RNBackLife.h"
#import <objc/runtime.h>

#pragma mark - AO Keys
static void *kWillPopBlocksKey       = &kWillPopBlocksKey;
static void *kDidPopBlocksKey        = &kDidPopBlocksKey;
static void *kWillAppearBlocksKey    = &kWillAppearBlocksKey;
static void *kDidAppearBlocksKey     = &kDidAppearBlocksKey;
static void *kWillDisappearBlocksKey = &kWillDisappearBlocksKey;
static void *kDidDisappearBlocksKey  = &kDidDisappearBlocksKey;

static void *kNavTransitionDurationKey = &kNavTransitionDurationKey;

// Guards chống double fire
static void *kDidPopFiredKey  = &kDidPopFiredKey;
static void *kWillPopFiredKey = &kWillPopFiredKey;

#pragma mark - Impl

@implementation UIViewController (RNBackLife)

+ (void)rn_swizzleBackLifeIfNeeded {
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

#pragma mark - Helpers

- (NSMutableArray *)rn_arrayForKey:(void *)key {
  NSMutableArray *arr = objc_getAssociatedObject(self, key);
  if (!arr) {
    arr = [NSMutableArray array];
    objc_setAssociatedObject(self, key, arr, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
  return arr;
}

static inline BOOL rn_getFlag(id self, void *key) {
  NSNumber *n = objc_getAssociatedObject(self, key);
  return n.boolValue;
}
static inline void rn_setFlag(id self, void *key, BOOL v) {
  objc_setAssociatedObject(self, key, @(v), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Properties

- (NSMutableArray<RNBackBlock> *)rn_onWillPopBlocks        { return [self rn_arrayForKey:kWillPopBlocksKey]; }
- (NSMutableArray<RNBackBlock> *)rn_onDidPopBlocks         { return [self rn_arrayForKey:kDidPopBlocksKey]; }
- (NSMutableArray<RNLifecycleBlock> *)rn_onWillAppearBlocks{ return [self rn_arrayForKey:kWillAppearBlocksKey]; }
- (NSMutableArray<RNLifecycleBlock> *)rn_onDidAppearBlocks { return [self rn_arrayForKey:kDidAppearBlocksKey]; }
- (NSMutableArray<RNLifecycleBlock> *)rn_onWillDisappearBlocks { return [self rn_arrayForKey:kWillDisappearBlocksKey]; }
- (NSMutableArray<RNLifecycleBlock> *)rn_onDidDisappearBlocks  { return [self rn_arrayForKey:kDidDisappearBlocksKey]; }

#pragma mark - Swizzled methods

- (void)rn_viewWillAppear_back:(BOOL)animated {
  [self rn_viewWillAppear_back:animated]; // original

  rn_setFlag(self, kWillPopFiredKey, NO);
  rn_setFlag(self, kDidPopFiredKey,  NO);

  for (RNLifecycleBlock block in self.rn_onWillAppearBlocks) if (block) block(animated);

  id<UIViewControllerTransitionCoordinator> tc = self.transitionCoordinator;
  NSTimeInterval dur = tc ? tc.transitionDuration : 0.35;
  objc_setAssociatedObject(self, kNavTransitionDurationKey, @(dur), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)rn_viewDidAppear_back:(BOOL)animated {
  [self rn_viewDidAppear_back:animated];
  for (RNLifecycleBlock block in self.rn_onDidAppearBlocks) if (block) block(animated);
}

- (void)rn_viewWillDisappear_back:(BOOL)animated {
  [self rn_viewWillDisappear_back:animated];
  for (RNLifecycleBlock block in self.rn_onWillDisappearBlocks) if (block) block(animated);

  BOOL isPopping = (self.isMovingFromParentViewController || self.isBeingDismissed);
  if (isPopping && !rn_getFlag(self, kWillPopFiredKey)) {
    rn_setFlag(self, kWillPopFiredKey, YES);
    for (RNBackBlock block in self.rn_onWillPopBlocks) if (block) block();
  }
}

- (void)rn_viewDidDisappear_back:(BOOL)animated {
  [self rn_viewDidDisappear_back:animated];
  for (RNLifecycleBlock block in self.rn_onDidDisappearBlocks) if (block) block(animated);

  BOOL popped = (self.navigationController &&
                ![self.navigationController.viewControllers containsObject:self]) ||
                self.isBeingDismissed;
  if (popped && !rn_getFlag(self, kDidPopFiredKey)) {
    rn_setFlag(self, kDidPopFiredKey, YES);
    for (RNBackBlock block in self.rn_onDidPopBlocks) if (block) block();
  }
}

- (NSTimeInterval)rn_transitionDuration {
  NSNumber *n = objc_getAssociatedObject(self, kNavTransitionDurationKey);
  return n ? n.doubleValue : -1;
}

@end
