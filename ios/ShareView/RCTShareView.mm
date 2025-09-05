//
//  RCTShareView.m
//  ShareVideo
//
//  Created by Sang Lv on 9/4/25.
//

#import "RCTShareView.h"
#import <react/renderer/components/ShareElement/Props.h>
#import <react/renderer/components/ShareElement/ComponentDescriptors.h>

#import "RCTShareViewRouteRegistry.h"
#import "RCTShareViewOverlay.h"
#import "RCTVideoHelper.h"

#import "UIView+NearestVC.h"
#import "UIViewController+RNBackLife.h"
#import "UINavigationController+RNPopHook.h"
#import "RNEarlyRegistry.h"
#import "UIView+NavTitleCache.h"

using namespace facebook::react;

// Macro weak/strongify để tránh retain cycle khi dùng block
#ifndef RN_WEAKIFY
#define RN_WEAKIFY(var) __weak __typeof__(var) weak_##var = (var);
#endif
#ifndef RN_STRONGIFY
#define RN_STRONGIFY(var) __strong __typeof__(var) var = weak_##var; if (!(var)) return;
#endif

/// Hướng chuyển cảnh của shared element
typedef NS_ENUM(NSInteger, RCTShareTransitionDirection) {
  RCTShareTransitionDirectionForward,   // push sang màn detail (tiến lên)
  RCTShareTransitionDirectionBackward   // back về màn trước (lùi lại)
};

@interface RCTShareView ()
// Cache key đại diện cho màn hình (screen) chứa view
@property (nonatomic, copy,   nullable) NSString *cachedScreenKey;
// Đã được register trong route registry chưa
@property (nonatomic, assign) BOOL isRegisteredInRoute;
// Cache lại navTitle của VC
@property (nonatomic, copy,   nullable) NSString *cachedNavTitle;

// Trạng thái navigation
@property (nonatomic, weak)   UINavigationController *nav;
@property (nonatomic, assign) BOOL hasGestureTarget;   // đã add target gesture chưa
@property (nonatomic, assign) BOOL backGestureActive;  // đang back bằng gesture chưa
@property (nonatomic, assign) BOOL isFocused;          // màn hiện tại đang hiển thị
@property (nonatomic, assign) BOOL isBlur;             // màn hiện tại bị ẩn đi

@property (nonatomic, strong, nullable) RCTShareView *otherView;
@end

@implementation RCTShareView

#pragma mark - Fabric

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<ShareViewComponentDescriptor>();
}

#pragma mark - Init / Dealloc

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    // ContentView: chứa nội dung share được
    self.contentView = [[UIView alloc] initWithFrame:self.bounds];
    self.contentView.userInteractionEnabled = NO; // không intercept touch
    self.contentView.backgroundColor = [UIColor clearColor];
    [self addSubview:self.contentView];
    
    // Overlay phục vụ animation
    _viewOverlay = [[RCTShareViewOverlay alloc] init];
    self.hidden = YES; // ban đầu ẩn đi
    
    // Swizzle navigation hooks
    [UINavigationController rn_enablePopHookOnce];
    [UIViewController rn_swizzleBackLifeIfNeeded];
  }
  return self;
}

#pragma mark - Window lifecycle

- (void)didMoveToWindow {
  [super didMoveToWindow];
  
  if (self.window) {
    // Khi view được add vào window
    [[RNEarlyRegistry shared] addView:self];
    UIViewController *vc = [self nearestViewController];
    if (vc) {
      [self attachLifecycleToViewController:vc];
      [self rn_updateCachedNavTitle];
    }
  } else if (!_isFocused) {
    // Khi view bị remove khỏi window
    [[RNEarlyRegistry shared] removeView:self];
    __weak __typeof__(self) wSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [wSelf detachFromNavAndVC]; });
  }
}

// Khi recycle (Fabric reuse), nếu chưa có navigation thì tự return về
- (void)prepareForRecycle {
  [super prepareForRecycle];
  if (!_sharing) {
    [self _performBackSharedElementIfPossible];
  } else {
    [self willUnmount];
    [self didUnmount];
  }
  RCTLog(self, @"prepareForRecycle");
}

#pragma mark - React Props / Layout

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &p = *std::static_pointer_cast<ShareViewProps const>(props);
  
  // Gán shareTag từ JS → native
  NSString *newTag = p.shareTagElement.empty() ? nil : [NSString stringWithUTF8String:p.shareTagElement.c_str()];
  if (![newTag isEqualToString:_shareTagElement]) {
    _shareTagElement = newTag;
    [self _tryRegisterRouteIfNeeded];
  }
  
  // Gán thời gian animation
  [_viewOverlay applySharingAnimatedDuration:p.sharingAnimatedDuration];
  [super updateProps:props oldProps:oldProps];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  self.contentView.frame = self.bounds;
  if(!self.window) return;
  
  // Tính toán offset so với window để dùng khi animate
  CGRect absFrame = [RCTVideoHelper frameInScreenStable:self];
  CGRect frame = self.frame;
  _windowFrameDelta = CGPointMake(absFrame.origin.x - frame.origin.x,
                                  absFrame.origin.y - frame.origin.y);
}

#pragma mark - Route registry

/// Đăng ký view này vào registry (theo tag + screen)
- (void)_tryRegisterRouteIfNeeded {
  if (_shareTagElement.length == 0) return;
  if (self.isRegisteredInRoute) return;
  
  NSString *newKey = self.cachedScreenKey;
  if (newKey.length == 0) {
    UIViewController *vc = [self nearestViewController];
    if (vc) {
      newKey = [NSString stringWithFormat:@"%p", vc];
      self.cachedScreenKey = newKey;
    }
  }
  if (newKey.length == 0) return;
  
  [[RCTShareViewRouteRegistry shared] registerView:self tag:_shareTagElement screenKey:newKey];
  self.isRegisteredInRoute = YES;
}

/// Unregister view khi unmount
- (void)_unregisterRouteIfNeeded {
  if (!self.isRegisteredInRoute || _shareTagElement.length == 0) return;
  NSString *screenKey = self.cachedScreenKey ?: [[RCTShareViewRouteRegistry shared] screenKeyOfView:self];
  if (screenKey.length == 0) return;
  [[RCTShareViewRouteRegistry shared] unregisterView:self tag:_shareTagElement screenKey:screenKey];
  self.isRegisteredInRoute = NO;
}

#pragma mark - Shared element transition

/// Lấy ra view khác có cùng tag để share
- (nullable RCTShareView *)getOtherViewForShare {
  if (_shareTagElement.length == 0) return nil;
  RCTShareView *target = [[RCTShareViewRouteRegistry shared] resolveShareTargetForView:self tag:_shareTagElement];
  if (target == self) target = nil;
  if(target == nil) return _otherView;
  return target;
}

/// Push: animate từ other → self
- (void)performSharedElementTransition {
  [self _tryRegisterRouteIfNeeded];
  _otherView = [self getOtherViewForShare];
  if (_otherView) {
    [self _performSharedTransitionFrom:_otherView to:self direction:RCTShareTransitionDirectionForward];
  } else {
    self.hidden = NO;
  }
}

/// Back: animate từ self → other
- (void)_performBackSharedElementIfPossible {
  [self _tryRegisterRouteIfNeeded];
  _otherView = [self getOtherViewForShare];
  if (_otherView) {
    [self _performSharedTransitionFrom:self to:_otherView direction:RCTShareTransitionDirectionBackward];
  }
}

/// Thực hiện animation shared element
- (void)_performSharedTransitionFrom:(RCTShareView *)fromView
                                  to:(RCTShareView *)toView
                           direction:(RCTShareTransitionDirection)direction {
  if (!fromView || !toView || fromView == toView) return;
  
  UIWindow *win = [RCTVideoHelper getTargetWindow];
  if (win) {
    [win layoutIfNeeded];
    [fromView.superview layoutIfNeeded];
    [toView.superview layoutIfNeeded];
  };
  
  CGRect fromFrame = [RCTVideoHelper frameInScreenStable:fromView];
  CGRect toFrame   = [RCTVideoHelper frameInScreenStable:toView];
  
  if(direction == RCTShareTransitionDirectionBackward || CGRectIsEmpty(fromFrame) || CGRectIsEmpty(toFrame)) {
    fromFrame = fromView.layer.presentationLayer ? ((CALayer *)fromView.layer.presentationLayer).frame : fromView.frame;
    toFrame   = toView.layer.presentationLayer ? ((CALayer *)toView.layer.presentationLayer).frame : toView.frame;
    
    fromFrame.origin.y += fromView.windowFrameDelta.y;
    fromFrame.origin.x += fromView.windowFrameDelta.x;
    toFrame.origin.y   += toView.windowFrameDelta.y;
    toFrame.origin.x   += toView.windowFrameDelta.x;
  }
  if (CGRectIsEmpty(fromFrame) || CGRectIsEmpty(toFrame)) return;
  fromView.sharing = YES;
  toView.sharing = YES;
  
  fromView.hidden = YES;
  toView.hidden   = YES;
  
  RN_WEAKIFY(fromView)
  RN_WEAKIFY(toView)
  
  [_viewOverlay moveToOverlay:fromFrame
                   tagetFrame:toFrame
                      content:fromView.contentView
      sharingAnimatedDuration:toView.viewOverlay.sharingAnimatedDuration
                      bgColor:fromView.backgroundColor
                     onTarget:^{
    // Có thể xử lý khi snapshot tới target
  }
                  onCompleted:^{
    RN_STRONGIFY(fromView)
    RN_STRONGIFY(toView)
    if (!fromView || !toView) return;
    
    // Kết thúc animation
    toView.hidden = NO;
    fromView.hidden = NO;
    
    fromView.sharing = NO;
    toView.sharing = NO;
    
    [[RCTShareViewRouteRegistry shared] commitShareFromView:fromView
                                                     toView:toView
                                                        tag:toView.shareTagElement];
    
    // Nếu back thì cleanup luôn fromView
    if (direction == RCTShareTransitionDirectionBackward) {
      [fromView willUnmount];
      [fromView didUnmount];
    }
  }];
}

#pragma mark - Navigation attach/detach

/// Attach lifecycle callback vào ViewController chứa RNView
- (void)attachLifecycleToViewController:(UIViewController *)vc {
  self.nav = vc.navigationController;
  
  // Apply duration transition
  Float64 dur = [vc rn_transitionDuration];
  [_viewOverlay applySharingAnimatedDuration:dur * 1000.0];
  
  __weak __typeof__(self) wSelf = self;
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

/// Detach callback khi view bị unmount
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

#pragma mark - Navigation events

- (void)rn_onEarlyPopFromNav {
  [self _performBackSharedElementIfPossible];
  [self willUnmount];
}
- (void)_onWillPopNoti:(NSNotification *)note {}

- (void)handleWillPop {
  if (_backGestureActive) return;
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
  _isFocused = YES; _isBlur = NO;
  
  self.cachedScreenKey = [[RCTShareViewRouteRegistry shared] screenKeyOfView:self] ?: self.cachedScreenKey;
  [self _tryRegisterRouteIfNeeded];
  
  // Attach gesture pop
  UIGestureRecognizer *g = self.nav.interactivePopGestureRecognizer;
  if (g && !self.hasGestureTarget) {
    [g addTarget:self action:@selector(_handlePopGesture:)];
    self.hasGestureTarget = YES;
  }
}
- (void)handleWillDisappear:(BOOL)animated {}
- (void)handleDidDisappear:(BOOL)animated {
  if (_isBlur) return;
  _isBlur = YES; _isFocused = NO;
  
  if (self.nav && self.hasGestureTarget) {
    [self.nav.interactivePopGestureRecognizer removeTarget:self action:@selector(_handlePopGesture:)];
    self.hasGestureTarget = NO;
  }
  self.nav = nil;
}

#pragma mark - Back swipe

/// Khi gesture back thành công → trả content về view kia
- (void)_returnContentToOtherIfNeeded {
  _otherView = [self getOtherViewForShare];
  if (_otherView && _otherView != self) {
    _otherView.hidden = NO;
    [_otherView setNeedsLayout];
    [_otherView layoutIfNeeded];
    [self willUnmount];
    [self didUnmount];
    [[RCTShareViewRouteRegistry shared] commitShareFromView:self
                                                     toView:_otherView
                                                        tag:_otherView.shareTagElement];
  }
}

/// Lắng nghe gesture back (interactive pop)
- (void)_handlePopGesture:(UIGestureRecognizer *)gr {
  if (_isBlur) return;
  switch (gr.state) {
    case UIGestureRecognizerStateBegan: { _backGestureActive = YES; break; }
    case UIGestureRecognizerStateCancelled:
    case UIGestureRecognizerStateEnded: {
      _backGestureActive = NO;
      id<UIViewControllerTransitionCoordinator> tc =
      self.nav.topViewController.transitionCoordinator ?: self.nav.transitionCoordinator;
      if (tc) {
        [tc notifyWhenInteractionChangesUsingBlock:^(id<UIViewControllerTransitionCoordinatorContext> ctx) {
          if (!ctx.isCancelled) [self _returnContentToOtherIfNeeded];
        }];
        [tc animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> ctx) {
          if (!ctx.isInteractive && !ctx.isCancelled) [self _returnContentToOtherIfNeeded];
        }];
      }
      break;
    }
    default: break;
  }
}

#pragma mark - Cleanup

/// Cập nhật cached nav title
- (void)rn_updateCachedNavTitle {
  UIViewController *vc = [self nearestViewController];
  if (vc) {
    NSString *title = vc.navigationItem.title ?: vc.title;
    if (title.length > 0) self.rn_cachedNavTitle = title;
  }
}

/// Cleanup trước khi unmount
- (void)willUnmount { [self _unregisterRouteIfNeeded]; _shareTagElement = nil; }

/// Cleanup sau khi unmount
- (void)didUnmount {
  _backGestureActive = NO; _isBlur = YES; _isFocused = NO;
  [_viewOverlay didUnmount];
  _windowFrameDelta = CGPointZero;
}

#pragma mark - Commands

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args {
  if ([commandName isEqualToString:@"initialize"]) {
    [self performSharedElementTransition];
  }
}

@end
