//
//  RCTVideoView.m
//  ShareVideo
//

#import "RCTVideoView.h"
#import "RCTVideoHelper.h"

#import "RCTVideoRouteRegistry.h"
#import "RCTVideoHelper.h"

#import <react/renderer/components/ShareElement/Props.h>
#import <react/renderer/components/ShareElement/ComponentDescriptors.h>

#import "UIView+NearestVC.h"
#import "UIView+RNSScreenCheck.h"
#import "UIView+NavTitleCache.h"
#import "UIViewController+RNBackLife.h"
#import "UINavigationController+RNPopHook.h"
#import "RNEarlyRegistry.h"

#ifndef RN_WEAKIFY
#define RN_WEAKIFY(var) __weak __typeof__(var) weak_##var = (var);
#endif
#ifndef RN_STRONGIFY
#define RN_STRONGIFY(var) __strong __typeof__(var) var = weak_##var; if (!(var)) return;
#endif

typedef NS_ENUM(NSInteger, RCTVideoTransitionDirection) {
  RCTVideoTransitionDirectionForward,
  RCTVideoTransitionDirectionBackward
};

using namespace facebook::react;

@interface RCTVideoView ()
// Navigation
@property (nonatomic, weak) UINavigationController *nav;
@property (nonatomic, assign) BOOL hasGestureTarget;
@property (nonatomic, assign) BOOL backGestureActive;

// Focus state
@property (nonatomic, assign) BOOL isFocused;
@property (nonatomic, assign) BOOL isBlur;

// Other refs
@property (nonatomic, strong) UIImageView *posterView;
@property (nonatomic, strong, nullable) RCTVideoView *otherView;

// Routing
@property (nonatomic, copy, nullable) NSString *cachedScreenKey;
@property (nonatomic, assign) BOOL isRegisteredInRoute;
@property (nonatomic, copy, nullable) NSString *cachedNavTitle;

// Block tokens để remove khi detach
@property (nonatomic, copy) RNBackBlock willPopBlock;
@property (nonatomic, copy) RNBackBlock didPopBlock;
@property (nonatomic, copy) RNLifecycleBlock willAppearBlock;
@property (nonatomic, copy) RNLifecycleBlock didAppearBlock;
@property (nonatomic, copy) RNLifecycleBlock willDisappearBlock;
@property (nonatomic, copy) RNLifecycleBlock didDisappearBlock;

@end

@implementation RCTVideoView

#pragma mark - Fabric

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<VideoComponentDescriptor>();
}

#pragma mark - Init / Dealloc

- (instancetype)init {
  if (self = [super init]) {
    _videoManager  = [[RCTVideoManager alloc] init];
    _videoOverlay  = [[RCTVideoOverlay alloc] init];
    [UINavigationController rn_enablePopHookOnce];
    
    _posterView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _posterView.userInteractionEnabled = NO;
    _posterView.contentMode = UIViewContentModeScaleAspectFill;
    _posterView.clipsToBounds = YES;
    _posterView.hidden = YES;
    [self addSubview:_posterView];
    
    RN_WEAKIFY(self)
    _videoManager.onPosterUpdate = ^(UIImage * _Nullable image) {
      RN_STRONGIFY(self)
      if (!self) return;
      self.posterView.image = image;
      
      if (image) {
        BOOL neverPlayed = (CMTimeGetSeconds(self->_videoManager.player.currentTime) <= 0.05);
        BOOL shouldShow = (self->_videoManager.paused && neverPlayed) || !self->_videoManager.player;
        self.posterView.hidden = !shouldShow;
      } else {
        self.posterView.hidden = YES;
      }
    };
    
    _videoManager.onHiddenPoster = ^{
      RN_STRONGIFY(self)
      if (!self) return;
      
      // Nếu paused + chưa từng play → giữ poster, ngược lại ẩn
      self.posterView.hidden = YES;
    };
    self.hidden = YES;
  }
  [UIViewController rn_swizzleBackLifeIfNeeded];
  return self;
}

- (void)dealloc {
  [self willUnmount];
  [self didUnmount];
  _videoManager.onPosterUpdate = nil;
  _videoManager.onHiddenPoster = nil;
  _posterView.image = nil;
  _posterView.hidden = YES;
  [self detachFromNavAndVC];
}

#pragma mark - React props / events

- (void)updateEventEmitter:(const facebook::react::EventEmitter::Shared &)eventEmitter {
  [super updateEventEmitter:eventEmitter];
  auto __eventEmitter = std::static_pointer_cast<const facebook::react::VideoEventEmitter>(eventEmitter);
  [_videoManager updateEventEmitter:__eventEmitter.get()];
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &p = *std::static_pointer_cast<VideoProps const>(props);
  
  NSString *newTag = p.shareTagElement.empty() ? nil : [NSString stringWithUTF8String:p.shareTagElement.c_str()];
  if (![newTag isEqualToString:_shareTagElement]) {
    if(!_sharing) [self _returnPlayerToOtherIfNeeded];
    _shareTagElement = newTag;
    [self _tryRegisterRouteIfNeeded];
  }
  
  [_videoManager applySource:p.source.empty() ? @"" : [NSString stringWithUTF8String:p.source.c_str()]];
  [_videoManager applyPaused:p.paused];
  [_videoManager applyMuted:p.muted];
  [_videoManager applyVolume:p.volume];
  [_videoManager applySeek:p.seek];
  [_videoManager applyResizeMode:p.resizeMode.empty() ? @"" : [NSString stringWithUTF8String:p.resizeMode.c_str()]];
  [_videoManager applyProgressInterval:p.progressInterval];
  [_videoManager applyProgress:p.enableProgress];
  [_videoManager applyOnLoad:p.enableOnLoad];
  [_videoManager applyLoop:p.loop skipCheck:NO];
  
  NSString *posterStr = p.poster.empty() ? nil : [NSString stringWithUTF8String:p.poster.c_str()];
  [_videoManager applyPoster:posterStr ?: @""];
  
  [_videoOverlay applySharingAnimatedDuration:p.sharingAnimatedDuration];
  _headerHeight = p.headerHeight;
  
  [super updateProps:props oldProps:oldProps];
}

#pragma mark - Layout

- (void)layoutSubviews {
  [super layoutSubviews];
  self.posterView.frame = self.bounds;
  [self createPlayerLayerIfNeeded];
  if (_videoManager.playerLayer) _videoManager.playerLayer.frame = self.bounds;
  [self bringSubviewToFront:self.posterView];
  
  if(!self.window) return;
  // Tính toán offset so với window để dùng khi animate
  CGRect absFrame = [RCTVideoHelper frameInScreenStable:self];
  CGRect frame = self.frame;
  _windowFrameDelta = CGPointMake(absFrame.origin.x - frame.origin.x,
                                  absFrame.origin.y - frame.origin.y);
}

#pragma mark - Window lifecycle

- (void)didMoveToWindow {
  [super didMoveToWindow];
  
  if (self.window) {
    [[RNEarlyRegistry shared] addView:self];
    UIViewController *vc = [self nearestViewController];
    if (!vc) return;
    [self attachLifecycleToViewController:vc];
    [self rn_updateCachedNavTitle];
  } else if (!_isFocused) {
    [[RNEarlyRegistry shared] removeView:self];
    __weak __typeof__(self) wSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      [wSelf detachFromNavAndVC];
    });
  }
}

#pragma mark - Player layer

- (void)createPlayerLayerIfNeeded {
  if (CGRectIsEmpty(self.bounds)) return;
  if (!_videoManager.playerLayer) {
    [_videoManager createPlayerLayer];
    const auto &props = *std::static_pointer_cast<VideoProps const>(_props);
    NSString *resizeMode = [NSString stringWithUTF8String:props.resizeMode.c_str()];
    [_videoManager applyResizeMode:resizeMode];
  }
  if (_videoManager.playerLayer.superlayer != self.layer) {
    [self.layer addSublayer:_videoManager.playerLayer];
  }
  [_videoManager setLayerFrame:self.bounds];
}

#pragma mark - Route registry

- (void)_tryRegisterRouteIfNeeded {
  if (_shareTagElement.length == 0) return;
  
  NSString *newScreenKey = self.cachedScreenKey;
  if (newScreenKey.length == 0) {
    UIViewController *vc = [self nearestViewController];
    if (vc) {
      newScreenKey = [NSString stringWithFormat:@"%p", vc];
      self.cachedScreenKey = newScreenKey;
    }
  }
  if (newScreenKey.length == 0) return;
  
  if (self.isRegisteredInRoute) {
    if (![self.cachedScreenKey isEqualToString:newScreenKey]) {
      NSString *oldKey = self.cachedScreenKey;
      if (oldKey.length > 0) {
        [[RCTVideoRouteRegistry shared] unregisterView:self tag:_shareTagElement screenKey:oldKey];
      }
      [[RCTVideoRouteRegistry shared] registerView:self tag:_shareTagElement screenKey:newScreenKey];
      self.cachedScreenKey = newScreenKey;
    }
    return;
  }
  
  [[RCTVideoRouteRegistry shared] registerView:self tag:_shareTagElement screenKey:newScreenKey];
  self.isRegisteredInRoute = YES;
}

- (void)_unregisterRouteIfNeeded {
  if (!self.isRegisteredInRoute || _shareTagElement.length == 0) return;
  NSString *screenKey = self.cachedScreenKey ?: [[RCTVideoRouteRegistry shared] screenKeyOfView:self];
  if (screenKey.length == 0) return;
  [[RCTVideoRouteRegistry shared] unregisterView:self tag:_shareTagElement screenKey:screenKey];
  self.isRegisteredInRoute = NO;
}

#pragma mark - Cleanup

- (void)prepareForRecycle {
  [super prepareForRecycle];
  // Chỉ auto-trả player nếu KHÔNG có navigation
  if (!_sharing) [self _performBackSharedElementIfPossible];
  [self willUnmount];
  _posterView.image = nil;
  _posterView.hidden = YES;
}

- (void)willUnmount {
  [self _unregisterRouteIfNeeded];
  [_videoManager willUnmount];
  _shareTagElement = nil;
  // reset UI nhẹ để reuse
  _posterView.image = nil;
  _posterView.hidden = YES;
}

- (void)didUnmount {
  _backGestureActive = NO;
  _isBlur = YES;
  _isFocused = NO;
  _otherView = nil;
  _windowFrameDelta = CGPointZero;
  [_videoManager didUnmount];
  [_videoOverlay didUnmount];
}

#pragma mark - Shared element

- (nullable RCTVideoView *)getOtherViewForShare {
  if (_shareTagElement.length == 0) return nil;
  RCTVideoView *target = [[RCTVideoRouteRegistry shared] resolveShareTargetForView:self tag:_shareTagElement];
  if (target == self) target = nil;
  if(target == nil) return _otherView;
  return target;
}

- (NSTimeInterval)_currentNavTransitionDuration {
  id<UIViewControllerTransitionCoordinator> tc =
  self.nav.topViewController.transitionCoordinator ?: self.nav.transitionCoordinator;
  return tc ? tc.transitionDuration : _videoOverlay.sharingAnimatedDuration;
}

- (void)performSharedElementTransition {
  [self _tryRegisterRouteIfNeeded];
  _otherView = [self getOtherViewForShare];
  if (_otherView) {
    __weak __typeof__(self) wSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      [wSelf _performSharedTransitionFrom:wSelf.otherView to:wSelf direction:RCTVideoTransitionDirectionForward];
    });
  } else {
    self.hidden = NO;
  }
}

- (void)_performBackSharedElementIfPossible {
  [self _tryRegisterRouteIfNeeded];
  _otherView = [self getOtherViewForShare];
  if (_otherView) {
    [self _performSharedTransitionFrom:self to:_otherView direction:RCTVideoTransitionDirectionBackward];
  } else {
    [self didUnmount];
  }
}

- (void)_performSharedTransitionFrom:(RCTVideoView *)fromView
                                  to:(RCTVideoView *)toView
                           direction:(RCTVideoTransitionDirection)direction {
  if (!fromView || !toView || fromView == toView) return;
  UIWindow *win = [RCTVideoHelper getTargetWindow];
  if (win) {
    [win layoutIfNeeded];
    [fromView.superview layoutIfNeeded];
    [toView.superview layoutIfNeeded];
  };
  
  CGRect fromFrame = [RCTVideoHelper frameInScreenStable:fromView];
  CGRect toFrame   = [RCTVideoHelper frameInScreenStable:toView];
  
  if(direction == RCTVideoTransitionDirectionBackward || CGRectIsEmpty(fromFrame) || CGRectIsEmpty(toFrame)) {
    fromFrame = fromView.layer.presentationLayer ? ((CALayer *)fromView.layer.presentationLayer).frame : fromView.frame;
    toFrame   = toView.layer.presentationLayer ? ((CALayer *)toView.layer.presentationLayer).frame : toView.frame;
    
    fromFrame.origin.y += fromView.windowFrameDelta.y;
    fromFrame.origin.x += fromView.windowFrameDelta.x;
    toFrame.origin.y   += toView.windowFrameDelta.y;
    toFrame.origin.x   += toView.windowFrameDelta.x;
  }
  
  fromFrame.origin.y += fromView.headerHeight;
  toFrame.origin.y   += toView.headerHeight;
  
  if (CGRectIsEmpty(fromFrame) || CGRectIsEmpty(toFrame)) return;
  
  fromView.sharing = YES;
  toView.sharing = YES;
  
  fromView.hidden  = YES;
  toView.hidden    = YES;
  
  RN_WEAKIFY(fromView)
  RN_WEAKIFY(toView)
  
  [toView.videoOverlay moveToOverlay:fromFrame
                          tagetFrame:toFrame
                              player:fromView.videoManager.player
                 aVLayerVideoGravity:fromView.videoManager.aVLayerVideoGravity
                             bgColor:fromView.backgroundColor
                            onTarget:^{
    RN_STRONGIFY(fromView)
    RN_STRONGIFY(toView)
    if (!fromView || !toView) return;
    
    if(fromView.videoManager.poster) {
      fromView.hidden  = NO;
      fromView.posterView.hidden = NO;
    }
    
    [toView.videoManager adoptPlayerFromManager:fromView.videoManager];
    [fromView.videoManager detachPlayer];
  } onCompleted:^{
    RN_STRONGIFY(fromView)
    RN_STRONGIFY(toView)
    if (!fromView || !toView) return;
    
    toView.hidden = NO;
    [toView createPlayerLayerIfNeeded];
    [toView setNeedsLayout];
    [toView layoutIfNeeded];
    
    fromView.sharing = NO;
    toView.sharing = NO;
    
    
    if (direction == RCTVideoTransitionDirectionBackward) {
      Float64 cur = CMTimeGetSeconds(toView.videoManager.player.currentTime);
      // Nếu video đã từng play → ẩn poster
      if (cur > 0.05 && toView.videoManager.paused) toView.posterView.hidden = YES;
    } else {
      Float64 cur = CMTimeGetSeconds(toView.videoManager.player.currentTime);
      if (cur < 0.05 && toView.videoManager.paused) toView.posterView.hidden = NO;
    }
    
    [[RCTVideoRouteRegistry shared] commitShareFromView:fromView
                                                 toView:toView
                                                    tag:toView.shareTagElement];
    if (direction == RCTVideoTransitionDirectionBackward) {
      [fromView willUnmount];
      [fromView didUnmount];
    }
  }];
}

#pragma mark - Navigation attach/detach

- (void)attachLifecycleToViewController:(UIViewController *)vc {
  __weak __typeof__(self) wSelf = self;
  self.nav = vc.navigationController;
  
  Float64 dur = [vc rn_transitionDuration];
  [wSelf.videoOverlay applySharingAnimatedDuration:dur * 1000.0];
  
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

#pragma mark - Navigation events

- (void)rn_onEarlyPopFromNav {
  [self _performBackSharedElementIfPossible];
  [self willUnmount];
}

- (void)_onWillPopNoti:(NSNotification *)note {
//  UIViewController *fromVC = note.userInfo[@"from"];
//  if (fromVC == [self nearestViewController]) {
//    RCTLog(self, @"Video View");
//  }
}

- (void)handleWillPop {
  if (_backGestureActive || _sharing) {
    [self willUnmount];
  } else {
    [self _performBackSharedElementIfPossible];
    [self willUnmount];
  }
}

- (void)handleDidPop {
  [[RNEarlyRegistry shared] removeView:self];
  [self detachFromNavAndVC];
  [self willUnmount];
  [self didUnmount];
}

- (void)handleWillAppear:(BOOL)animated {
  //RCTVideoLog(self, @"handleWillAppear");
}

- (void)handleDidAppear:(BOOL)animated {
  if (_isFocused) return;
  _isFocused = YES;
  _isBlur = NO;
  
  self.cachedScreenKey = [[RCTVideoRouteRegistry shared] screenKeyOfView:self] ?: self.cachedScreenKey;
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
    [self.nav.interactivePopGestureRecognizer removeTarget:self action:@selector(_handlePopGesture:)];
    self.hasGestureTarget = NO;
  }
  self.nav = nil;
}

#pragma mark - Back swipe

- (void)_returnPlayerToOtherIfNeeded {
  _otherView = [self getOtherViewForShare];
  if (_otherView && _otherView != self) {
    [_otherView.videoManager adoptPlayerFromManager:_videoManager];
    [_videoManager detachPlayer];
    
    _otherView.hidden = NO;
    [_otherView createPlayerLayerIfNeeded];
    [_otherView setNeedsLayout];
    [_otherView layoutIfNeeded];
    
    // Nếu video đã từng play → ẩn poster
    Float64 cur = CMTimeGetSeconds(_otherView.videoManager.player.currentTime);
    if (cur > 0.05) {
      _otherView.posterView.hidden = YES;
    }
    
    [self willUnmount];
    [self didUnmount];
    
    [[RCTVideoRouteRegistry shared] commitShareFromView:self
                                                 toView:_otherView
                                                    tag:_otherView.shareTagElement];
  }
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
            [self _returnPlayerToOtherIfNeeded];
          }
        }];
        
        [tc animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> ctx) {
          if (!ctx.isInteractive) {
            BOOL popped = !ctx.isCancelled;
            //            NSString *mess = popped ? @"debug didPop (non-interactive)" : @"debug back cancelled (non-interactive)";
            //            RCTVideoLog(self, @"%@", mess);
            
            if (popped) {
              // Gesture back thành công → trả player về other
              [self _returnPlayerToOtherIfNeeded];
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
  } else if ([commandName isEqualToString:@"setSeekCommand"] && args.count) {
    [_videoManager seekToTime:[args[0] doubleValue]];
  } else if ([commandName isEqualToString:@"setPausedCommand"] && args.count) {
    [_videoManager applyPausedFromCommand:[args[0] boolValue]];
  } else if ([commandName isEqualToString:@"setVolumeCommand"] && args.count) {
    [_videoManager applyVolumeFromCommand:[args[0] doubleValue]];
  }
}

@end
