//
//  RCTShareView.m
//  ShareElement
//
//  Created by Sang Le vinh on 9/11/25.
//

#import "RCTShareView.h"
#import "RCTShareRouteRegistry.h"
#import "RCTVideoHelper.h"

#import <react/renderer/components/ShareElement/Props.h>
#import <react/renderer/components/ShareElement/ComponentDescriptors.h>

#import "UIView+NearestVC.h"
#import "UIViewController+RNBackLife.h"
#import "UINavigationController+RNPopHook.h"

#import "RNEarlyRegistry.h"
#import "UIView+NavTitleCache.h"

typedef NS_ENUM(NSInteger, RCTShareViewTransitionDirection) {
  RCTShareViewTransitionDirectionForward,
  RCTShareViewTransitionDirectionBackward
};

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

// Block tokens để remove khi detach
@property (nonatomic, copy) RNBackBlock willPopBlock;
@property (nonatomic, copy) RNBackBlock didPopBlock;
@property (nonatomic, copy) RNLifecycleBlock willAppearBlock;
@property (nonatomic, copy) RNLifecycleBlock didAppearBlock;
@property (nonatomic, copy) RNLifecycleBlock willDisappearBlock;
@property (nonatomic, copy) RNLifecycleBlock didDisappearBlock;

@end


#ifndef RN_WEAKIFY
#define RN_WEAKIFY(var) __weak __typeof__(var) weak_##var = (var);
#endif
#ifndef RN_STRONGIFY
#define RN_STRONGIFY(var) __strong __typeof__(var) var = weak_##var; if (!(var)) return;
#endif

@implementation RCTShareView

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<ShareViewComponentDescriptor>();
}

#pragma mark - Init / Dealloc

- (instancetype)init {
  if (self = [super init]) {
    self.hidden = YES;
    _shareViewOverlay  = [[RCTShareViewOverlay alloc] init];
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
  _headerHeight = p.headerHeight;
  [super updateProps:props oldProps:oldProps];
}

#pragma mark - Layout / Window

- (void)layoutSubviews {
  [super layoutSubviews];
  if(!self.window) return;
  
  // Tính toán offset so với window để dùng khi animate
  CGRect absFrame = [RCTVideoHelper frameInScreenStable:self];
  CGRect frame = self.frame;
  _windowFrameDelta = CGPointMake(absFrame.origin.x - frame.origin.x,
                                  absFrame.origin.y - frame.origin.y);
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

#pragma mark - Shared element

- (nullable RCTShareView *)getOtherViewForShare {
  if (_shareTagElement.length == 0) return nil;
  RCTShareView *target = [[RCTShareRouteRegistry shared] resolveShareTargetForView:self tag:_shareTagElement];
  if (target == self) target = nil;
  if(target == nil) return _otherView;
  return target;
}

- (NSTimeInterval)_currentNavTransitionDuration {
  id<UIViewControllerTransitionCoordinator> tc =
  self.nav.topViewController.transitionCoordinator ?: self.nav.transitionCoordinator;
  return tc ? tc.transitionDuration : _shareViewOverlay.sharingAnimatedDuration;
}

- (void)performSharedElementTransition {
  [self _tryRegisterRouteIfNeeded];
  _otherView = [self getOtherViewForShare];
  if (_otherView) {
    __weak __typeof__(self) wSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      [wSelf _performSharedTransitionFrom:wSelf.otherView to:wSelf direction:RCTShareViewTransitionDirectionForward];
    });
  } else {
    self.hidden = NO;
  }
}

- (void)_performBackSharedElementIfPossible {
  [self _tryRegisterRouteIfNeeded];
  _otherView = [self getOtherViewForShare];
  if (_otherView) {
    [self _performSharedTransitionFrom:self to:_otherView direction:RCTShareViewTransitionDirectionBackward];
  }
}

- (void)_performSharedTransitionFrom:(RCTShareView *)fromView
                                  to:(RCTShareView *)toView
                           direction:(RCTShareViewTransitionDirection)direction
{
  if (!fromView || !toView || fromView == toView) return;
  
  UIWindow *win = [RCTVideoHelper getTargetWindow];
  if (win) {
    [win layoutIfNeeded];
    [fromView.superview layoutIfNeeded];
    [toView.superview layoutIfNeeded];
  };
  
  CGRect fromFrame = [RCTVideoHelper frameInScreenStable:fromView];
  CGRect toFrame   = [RCTVideoHelper frameInScreenStable:toView];
  
  if(direction == RCTShareViewTransitionDirectionBackward || CGRectIsEmpty(fromFrame) || CGRectIsEmpty(toFrame)) {
    fromFrame = fromView.layer.presentationLayer ? ((CALayer *)fromView.layer.presentationLayer).frame : fromView.frame;
    toFrame   = toView.layer.presentationLayer ? ((CALayer *)toView.layer.presentationLayer).frame : toView.frame;
    
    fromFrame.origin.y += fromView.windowFrameDelta.y;
    fromFrame.origin.x += fromView.windowFrameDelta.x;
    toFrame.origin.y   += toView.windowFrameDelta.y;
    toFrame.origin.x   += toView.windowFrameDelta.x;
  }
  
  fromFrame.origin.y += fromView.headerHeight;
  toFrame.origin.y   += toView.headerHeight;
  
  toView.hidden = YES;
  fromView.hidden = YES;
  
  RN_WEAKIFY(fromView)
  RN_WEAKIFY(toView)
  fromView.sharing = YES;
  toView.sharing = YES;
  [toView.shareViewOverlay moveToOverlay:fromFrame
                             targetFrame:toFrame
                                fromView:fromView
                                toView:toView
                                onTarget:^{
    // Khi ghost đã chạm tới target
    toView.hidden = NO;
  } onCompleted:^{
    RN_STRONGIFY(fromView)
    RN_STRONGIFY(toView)
    if (!fromView || !toView) return;
    
    fromView.hidden  = NO;
    fromView.sharing = NO;
    toView.sharing   = NO;
    
    // Đăng ký lại "cạnh share" cho route
    [[RCTShareRouteRegistry shared] commitShareFromView:fromView
                                                 toView:toView
                                                    tag:toView.shareTagElement];
    
    // Nếu backward → clear old
    if (direction == RCTShareViewTransitionDirectionBackward) {
      [fromView willUnmount];
      [fromView didUnmount];
    }
  }];
}

#pragma mark - Navigation Attach / Detach

- (void)attachLifecycleToViewController:(UIViewController *)vc {
  __weak __typeof__(self) wSelf = self;
  self.nav = vc.navigationController;
  
  [vc.rn_onWillPopBlocks addObject:^{ [wSelf handleWillPop]; }];
  [vc.rn_onDidPopBlocks addObject:^{ [wSelf handleDidPop]; }];
  
  [vc.rn_onWillAppearBlocks addObject:^(BOOL animated){ [wSelf handleWillAppear:animated]; }];
  [vc.rn_onDidAppearBlocks addObject:^(BOOL animated){ [wSelf handleDidAppear:animated]; }];
  
  [vc.rn_onWillDisappearBlocks addObject:^(BOOL animated){ [wSelf handleWillDisappear:animated]; }];
  [vc.rn_onDidDisappearBlocks addObject:^(BOOL animated){ [wSelf handleDidDisappear:animated]; }];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(_onWillPopNoti:)
                                               name:@"RNWillPopViewControllerNotification"
                                             object:self.nav];
}

- (void)detachFromNavAndVC {
  UIViewController *vc = [self nearestViewController];
  if (vc) {
    if (self.willPopBlock) [vc.rn_onWillPopBlocks removeObject:self.willPopBlock];
    if (self.didPopBlock)  [vc.rn_onDidPopBlocks removeObject:self.didPopBlock];
    if (self.willAppearBlock) [vc.rn_onWillAppearBlocks removeObject:self.willAppearBlock];
    if (self.didAppearBlock)  [vc.rn_onDidAppearBlocks removeObject:self.didAppearBlock];
    if (self.willDisappearBlock) [vc.rn_onWillDisappearBlocks removeObject:self.willDisappearBlock];
    if (self.didDisappearBlock)  [vc.rn_onDidDisappearBlocks removeObject:self.didDisappearBlock];
  }
  
  self.willPopBlock = nil;
  self.didPopBlock = nil;
  self.willAppearBlock = nil;
  self.didAppearBlock = nil;
  self.willDisappearBlock = nil;
  self.didDisappearBlock = nil;
  
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:@"RNWillPopViewControllerNotification"
                                                object:self.nav];
}

#pragma mark - Cleanup

- (void)prepareForRecycle {
  [super prepareForRecycle];
  if (!_sharing) {
    [self _performBackSharedElementIfPossible];
  }
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

- (void)_onWillPopNoti:(NSNotification *)note {
  //  UIViewController *fromVC = note.userInfo[@"from"];
  //  if (fromVC == [self nearestViewController]) {
  //    RCTLog(self, @"Share View");
  //  }
}

- (void)handleWillPop {
  if (_backGestureActive || _sharing) {
    [self willUnmount];
  } else {
    [self _performBackSharedElementIfPossible];
    [self willUnmount];
  };
  
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
    case UIGestureRecognizerStateBegan: {
      _backGestureActive = YES;
      //RCTVideoLog(self, @"gestureBegan");
      break;
    }
    case UIGestureRecognizerStateChanged: {
      break;
    }
    case UIGestureRecognizerStateCancelled:
    case UIGestureRecognizerStateEnded: {
      _backGestureActive = NO;
      
      id<UIViewControllerTransitionCoordinator> tc =
      self.nav.topViewController.transitionCoordinator ?: self.nav.transitionCoordinator;
      
      if (tc) {
        [tc notifyWhenInteractionChangesUsingBlock:^(id<UIViewControllerTransitionCoordinatorContext> ctx) {
          BOOL popped = !ctx.isCancelled;
          //          NSString *mess = popped ? @"debug didPop after swipe-back" : @"debug swipe-back cancelled";
          //          RCTVideoLog(self, @"%@", mess);
          if (popped) {
            // Gesture back thành công → trả player về other
            // [self _returnPlayerToOtherIfNeeded];
          }
        }];
        
        [tc animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> ctx) {
          if (!ctx.isInteractive) {
            BOOL popped = !ctx.isCancelled;
            //            NSString *mess = popped ? @"debug didPop (non-interactive)" : @"debug back cancelled (non-interactive)";
            //            RCTVideoLog(self, @"%@", mess);
            
            if (popped) {
              // Gesture back thành công → trả player về other
              // [self _returnPlayerToOtherIfNeeded];
            }
          }
        }];
      } else {
        dispatch_async(dispatch_get_main_queue(), ^{
          //          UIViewController *vc = [self nearestViewController];
          //          BOOL popped = self.nav && vc && ![self.nav.viewControllers containsObject:vc];
          //          NSString *mess = popped ? @"debug didPop (fallback)" : @"debug back cancelled (fallback)";
          //          RCTVideoLog(self, @"%@", mess);
        });
      }
      break;
    }
    default:
      break;
  }
}

#pragma mark - Commands

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args {
  if ([commandName isEqualToString:@"initialize"]) {
    [self performSharedElementTransition];
  }
}

@end

