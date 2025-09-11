//
//  RCTShareView.m
//  ShareElement
//
//  Created by Sang Le vinh on 9/11/25.
//

#import "RCTShareView.h"
#import "RCTShareRouteRegistry.h"

#import <react/renderer/components/ShareElement/Props.h>
#import <react/renderer/components/ShareElement/ComponentDescriptors.h>

#import "UIView+NearestVC.h"
#import "UIViewShareController+RNBackLife.h"
#import "UINavigationShareController+RNPopHook.h"

#import "RNEarlyRegistry.h"
#import "UIView+NavTitleCache.h"

using namespace facebook::react;

@interface RCTShareView ()
// Navigation
@property (nonatomic, weak)   UINavigationController *nav;
@property (nonatomic, assign) BOOL hasGestureTarget;
@property (nonatomic, assign) BOOL backGestureActive;

// Focus state
@property (nonatomic, assign) BOOL isFocused;
@property (nonatomic, assign) BOOL isBlur;

// Routing
@property (nonatomic, strong, nullable) RCTShareView *otherView;
@property (nonatomic, copy,   nullable) NSString *cachedScreenKey;
@property (nonatomic, assign) BOOL isRegisteredInRoute;
@property (nonatomic, copy,   nullable) NSString *cachedNavTitle;
@end

@implementation RCTShareView

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<ShareViewComponentDescriptor>();
}

#pragma mark - Init / Dealloc

- (instancetype)init {
  if (self = [super init]) {
    self.hidden = YES;
    [UINavigationController rn_enablePopHookOnce];
    [UIViewController rn_swizzleBackLifeIfNeeded];
  }
  return self;
}

- (void)dealloc {
  [self willUnmount];
  [self didUnmount];
  [self detachFromNavAndVC];
}

#pragma mark - Props

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &p = *std::static_pointer_cast<ShareViewProps const>(props);

  NSString *newTag = p.shareTagElement.empty()
      ? nil
      : [NSString stringWithUTF8String:p.shareTagElement.c_str()];

  if (![newTag isEqualToString:_shareTagElement]) {
    if(!_sharing) [self _performBackSharedElementIfPossible];
    _shareTagElement = newTag;
    [self _tryRegisterRouteIfNeeded];
  }

  [super updateProps:props oldProps:oldProps];
}

#pragma mark - Layout / Window

- (void)layoutSubviews {
  [super layoutSubviews];
  if(!self.window) return;
}

- (void)didMoveToWindow {
  [super didMoveToWindow];
  
  if (self.window) {
    [[RNEarlyRegistry shared] addView:self];
    UIViewController *vc = [self nearestViewController];
    if (vc) {
      [self attachLifecycleToViewController:vc];
      [self rn_updateCachedNavTitle];
    }
  } else if (!_isFocused) {
    [[RNEarlyRegistry shared] removeView:self];
    __weak __typeof__(self) wSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      [wSelf detachFromNavAndVC];
    });
  }
}

#pragma mark - Share Element

- (void)_performBackSharedElementIfPossible {
  [self _tryRegisterRouteIfNeeded];
  _otherView = [self getOtherViewForShare];
  if (_otherView) {
    // TODO
  }
}

#pragma mark - Route Registry

- (void)_tryRegisterRouteIfNeeded {
  if (_shareTagElement.length == 0) return;

  NSString *newKey = self.cachedScreenKey;
  if (newKey.length == 0) {
    UIViewController *vc = [self nearestViewController];
    if (vc) newKey = [NSString stringWithFormat:@"%p", vc];
    self.cachedScreenKey = newKey;
  }
  if (newKey.length == 0) return;

  if (!self.isRegisteredInRoute) {
    [[RCTShareRouteRegistry shared] registerView:self
                                             tag:_shareTagElement
                                       screenKey:newKey];
    self.isRegisteredInRoute = YES;
  }
}

- (void)_unregisterRouteIfNeeded {
  if (!self.isRegisteredInRoute || _shareTagElement.length == 0) return;
  NSString *screenKey = self.cachedScreenKey
      ?: [[RCTShareRouteRegistry shared] screenKeyOfView:self];
  if (screenKey.length == 0) return;

  [[RCTShareRouteRegistry shared] unregisterView:self
                                             tag:_shareTagElement
                                       screenKey:screenKey];
  self.isRegisteredInRoute = NO;
}

- (nullable RCTShareView *)getOtherViewForShare {
  if (_shareTagElement.length == 0) return nil;
  RCTShareView *target =
      [[RCTShareRouteRegistry shared] resolveShareTargetForView:self
                                                            tag:_shareTagElement];
  if (target == self) target = nil;
  return target ?: _otherView;
}

#pragma mark - Navigation Attach / Detach

- (void)attachLifecycleToViewController:(UIViewController *)vc {
  __weak __typeof__(self) wSelf = self;
  self.nav = vc.navigationController;
  
  vc.rn_onWillPop       = ^{ [wSelf handleWillPop]; };
  vc.rn_onDidPop        = ^{ [wSelf handleDidPop]; };
  vc.rn_onWillAppear    = ^(BOOL animated){ [wSelf handleWillAppear:animated]; };
  vc.rn_onDidAppear     = ^(BOOL animated){ [wSelf handleDidAppear:animated]; };
  vc.rn_onWillDisappear = ^(BOOL animated){ [wSelf handleWillDisappear:animated]; };
  vc.rn_onDidDisappear  = ^(BOOL animated){ [wSelf handleDidDisappear:animated]; };
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(_onWillPopNoti:)
                                               name:@"RNWillPopViewControllerNotification"
                                             object:self.nav];
}

- (void)detachFromNavAndVC {
  UIViewController *vc = [self nearestViewController];
  if (vc) {
    vc.rn_onWillPop = nil;
    vc.rn_onDidPop  = nil;
    vc.rn_onWillAppear = nil;
    vc.rn_onDidAppear  = nil;
    vc.rn_onWillDisappear = nil;
    vc.rn_onDidDisappear  = nil;
  }
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:@"RNWillPopViewControllerNotification"
                                                object:self.nav];
}

#pragma mark - Cleanup

- (void)prepareForRecycle {
  [super prepareForRecycle];
  if (!_sharing) [self _performBackSharedElementIfPossible];
}

- (void)willUnmount {
  [self _unregisterRouteIfNeeded];
  _shareTagElement = nil;
}

- (void)didUnmount {
  _backGestureActive = NO;
  _isBlur = YES;
  _isFocused = NO;
  _otherView = nil;
}

#pragma mark - Navigation Events

- (void)rn_onEarlyPopFromNav {
  [self _performBackSharedElementIfPossible];
  [self willUnmount];
}

- (void)_onWillPopNoti:(NSNotification *)note {}

- (void)handleWillPop {
  if (_backGestureActive || _sharing) return;
  [self _performBackSharedElementIfPossible];
  [self willUnmount];
}

- (void)handleDidPop {
  [[RNEarlyRegistry shared] removeView:self];
  [self detachFromNavAndVC];
  [self willUnmount];
  [self didUnmount];
}

- (void)handleWillAppear:(BOOL)animated {}

- (void)handleDidAppear:(BOOL)animated {
  if (_isFocused) return;
  _isFocused = YES;
  _isBlur = NO;
  
  self.cachedScreenKey =
      [[RCTShareRouteRegistry shared] screenKeyOfView:self]
      ?: self.cachedScreenKey;
  [self _tryRegisterRouteIfNeeded];
  
  UIGestureRecognizer *g = self.nav.interactivePopGestureRecognizer;
  if (g && !self.hasGestureTarget) {
    [g addTarget:self action:@selector(_handlePopGesture:)];
    self.hasGestureTarget = YES;
  }
}

- (void)handleWillDisappear:(BOOL)animated {}

- (void)handleDidDisappear:(BOOL)animated {
  if (_isBlur) return;
  _isBlur = YES;
  _isFocused = NO;
  
  if (self.nav && self.hasGestureTarget) {
    [self.nav.interactivePopGestureRecognizer removeTarget:self
                                                    action:@selector(_handlePopGesture:)];
    self.hasGestureTarget = NO;
  }
  self.nav = nil;
}

- (void)_handlePopGesture:(UIGestureRecognizer *)gr {
  if (_isBlur) return;
  
  switch (gr.state) {
    case UIGestureRecognizerStateBegan:
      _backGestureActive = YES;
      break;
    case UIGestureRecognizerStateCancelled:
    case UIGestureRecognizerStateEnded:
      _backGestureActive = NO;
      // Sau này: xử lý trả về otherView
      break;
    default:
      break;
  }
}

@end

