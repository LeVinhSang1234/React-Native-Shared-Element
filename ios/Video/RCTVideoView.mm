//
//  RCTVideo.m
//  ShareVideo
//
//  Created by Sang Le vinh on 8/19/25.
//
#import "RCTVideoView.h"
#import <react/renderer/components/Video/Props.h>
#import <react/renderer/components/Video/ComponentDescriptors.h>
#import "UIView+NearestVC.h"
#import "UIViewController+RNBackLife.h"
#import "UINavigationController+RNPopHook.h"
#import "RNEarlyRegistry.h"

using namespace facebook::react;

@interface RCTVideoView ()

@property (nonatomic, weak) UINavigationController *nav;
@property (nonatomic, assign) BOOL hasGestureTarget;
@property (nonatomic, assign) BOOL backGestureActive;
@property (nonatomic, assign) BOOL isFocused;
@property (nonatomic, assign) BOOL isBlur;


@end

@implementation RCTVideoView

#pragma mark - Lifecycle

- (instancetype)init {
  if(self = [super init]) {
    _videoManager = [[RCTVideoManager alloc] init];
    _videoOverlay = [[RCTVideoOverlay alloc] init];
    [UINavigationController rn_enablePopHookOnce];
  }
  return  self;
}

- (void) initialize {
  [self createPlayerLayerIfNeeded];
  if(_shareTagElement) [self shareElement];
}

-(void)updateEventEmitter:(const facebook::react::EventEmitter::Shared &)eventEmitter
{
  [super updateEventEmitter:eventEmitter];
  auto __eventEmitter = std::static_pointer_cast<const facebook::react::VideoEventEmitter>(eventEmitter);
  [_videoManager updateEventEmitter:__eventEmitter.get()];
}

-(void)layoutSubviews
{
  [super layoutSubviews];
  [self createPlayerLayerIfNeeded];
  if(_videoManager.playerLayer) _videoManager.playerLayer.frame = self.bounds;
}

- (void)didMoveToWindow
{
  [super didMoveToWindow];
  __weak __typeof__(self) wSelf = self;
  
  // ----- SET NAVIGATION CONTROLLER ----- //
  if (self.window) {
    [[RNEarlyRegistry shared] addView:self];
    
    UIViewController *vc = [self nearestViewController];
    if (!vc) return;
    [UIViewController rn_swizzleBackLifeIfNeeded];
    self.nav = vc.navigationController;
//    __weak UIViewController *wVC = vc;
    
    vc.rn_onWillPop = ^{
      __strong __typeof__(wSelf) self = wSelf;
      if (!self) return;
      [self handleWillPop];
    };
    vc.rn_onDidPop = ^{
      __strong __typeof__(wSelf) self = wSelf;
      if (!self) return;
      NSLog(@"[RNBackLife] rn_onDidPop %@", wSelf.shareTagElement);
      [self handleDidPop];
    };
    
    // Blur (willDisappear) + restore (willAppear)
//    vc.rn_onWillDisappear = ^(BOOL animated){
//      __strong __typeof__(wSelf) self = wSelf;
//      __strong UIViewController *vc = wVC;
//      if (!self || !vc) return;
//      
//      id<UIViewControllerTransitionCoordinator> tc = vc.transitionCoordinator;
//      if (tc) {
//        [tc notifyWhenInteractionChangesUsingBlock:^(id<UIViewControllerTransitionCoordinatorContext> ctx) {
//          BOOL willBlur = !ctx.isCancelled;
//          NSLog(@"[RNBackLife] willDisappear(interactive): blur=%@ %@", willBlur ? @"YES" : @"NO", wSelf.shareTagElement);
//        }];
//        [tc animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> ctx) {
//          if (!ctx.isInteractive) {
//            BOOL willBlur = !ctx.isCancelled;
//            NSLog(@"[RNBackLife] willDisappear(non-interactive): blur=%@ %@", willBlur ? @"YES" : @"NO", wSelf.shareTagElement);
//          }
//        }];
//      } else {
//        NSLog(@"[RNBackLife] willDisappear(no-coordinator): blur=YES %@", wSelf.shareTagElement);
//      }
//    };
    
//    vc.rn_onWillAppear = ^(BOOL animated){
//      __strong __typeof__(wSelf) self = wSelf;
//      __strong UIViewController *vc = wVC;
//      if (!self || !vc) return;
//      
//      id<UIViewControllerTransitionCoordinator> tc = vc.transitionCoordinator;
//      if (tc) {
//        [tc animateAlongsideTransition:nil completion:^(__unused id<UIViewControllerTransitionCoordinatorContext> ctx) {
//          NSLog(@"[RNBackLife] willAppear: restore (unblur) %@", wSelf.shareTagElement);
//        }];
//      } else {
//        NSLog(@"[RNBackLife] willAppear(no-coordinator): restore (unblur) %@", wSelf.shareTagElement);
//      }
//    };
    vc.rn_onDidDisappear = ^(BOOL animated){
      if(!wSelf.isBlur) {
        wSelf.isBlur = YES;
        wSelf.isFocused = NO;
        NSLog(@"[RNBackLife] rn_onDidDisappear %@ %f", wSelf.shareTagElement, wSelf.videoOverlay.sharingAnimatedDuration);
        if (wSelf.nav && wSelf.hasGestureTarget) {
          [wSelf.nav.interactivePopGestureRecognizer removeTarget:wSelf action:@selector(_handlePopGesture:)];
          wSelf.hasGestureTarget = NO;
        }
        wSelf.nav = nil;
        [wSelf handleDidPop];
      }
      //      if (self.nav && self.hasGestureTarget) {
      //        [self.nav.interactivePopGestureRecognizer removeTarget:self action:@selector(_handlePopGesture:)];
      //        self.hasGestureTarget = NO;
      //      }
      //      __strong __typeof__(wSelf) self = wSelf;
      //      __strong UIViewController *vc = wVC;
      //      if (!self || !vc) return;
      //
      //      id<UIViewControllerTransitionCoordinator> tc = vc.transitionCoordinator;
      //      if (tc) {
      //        [tc animateAlongsideTransition:nil completion:^(__unused id<UIViewControllerTransitionCoordinatorContext> ctx) {
      //          NSLog(@"[RNBackLife] rn_onDidDisappear: restore (unblur) %@", wSelf.shareTagElement);
      //        }];
      //      } else {
      //        NSLog(@"[RNBackLife] rn_onDidDisappear(no-coordinator): restore (unblur)");
      //      }
      
    };
    vc.rn_onDidAppear= ^(BOOL animated) {
      if(!wSelf.isFocused) {
        wSelf.isFocused = YES;
        wSelf.isBlur = NO;
        NSLog(@"[RNBackLife] rn_onDidAppear %@", wSelf.shareTagElement);
        // swipe-back %
        UIGestureRecognizer *g = self.nav.interactivePopGestureRecognizer;
        if (g && !self.hasGestureTarget) {
          [g addTarget:self action:@selector(_handlePopGesture:)];
          self.hasGestureTarget = YES;
        }
      }
    };
//    vc.rn_onWillAppear= ^(BOOL animated) {
//      NSLog(@"[RNBackLife] rn_onWillAppear %@", wSelf.shareTagElement);
//    };
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_onWillPopNoti:)
                                                 name:@"RNWillPopViewControllerNotification"
                                               object:self.nav];
  } else if(!_isFocused){
    NSLog(@"_detachFromNavAndVC %f", _videoOverlay.sharingAnimatedDuration);
    [[RNEarlyRegistry shared] removeView:wSelf];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      [wSelf _detachFromNavAndVC];
    });
  };
  // ----- SET NAVIGATION CONTROLLER ----- //
}

-(void) dealloc {
  [self beforeUnmount];
  [self unmount];
  [self _detachFromNavAndVC];
}

- (void)prepareForRecycle {
  [super prepareForRecycle];
  
  if(!_sharing) {
    RCTVideoView *otherView = [RCTVideoTag getOtherViewForTag:self withTag:_shareTagElement];
    if(otherView.hidden) {
      otherView.hidden = NO;
      [otherView.videoManager afterTargetShareElement:_videoManager.player isOtherPaused:_videoManager.paused];
    }
    [self beforeUnmount];
    [self unmount];
  }
}

- (void) beforeUnmount {
  [self removeViewShareElement:_shareTagElement];
  [self removeViewShareElement:_shareTagElement];
  [_videoManager beforeUnmount];
  _shareTagElement = nil;
}

- (void) unmount {
  _backGestureActive = false;
  _isBlur = YES;
  _isFocused = NO;
  [_videoManager unmount];
  [_videoOverlay unmount];
}

#pragma mark - React Native Handling Update Props

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &newViewProps = *std::static_pointer_cast<VideoProps const>(props);
  
  // ------ UPDATE - SHARE TAG ELEMENT ----- //
  NSString *shareTagElement = newViewProps.shareTagElement.empty() ? nil : [NSString stringWithUTF8String:newViewProps.shareTagElement.c_str()];
  
  if (shareTagElement && ![shareTagElement isEqualToString:_shareTagElement]) {
    [self removeViewShareElement:_shareTagElement];
    [self addViewShareElement:shareTagElement];
    _shareTagElement = shareTagElement;
  }
  
  // ------ UPDATE - PAUSED ----- //
  [_videoManager applyPaused:newViewProps.paused];
  
  // ------ UPDATE - SOURCE ----- //
  NSString *source = newViewProps.source.empty() ? @"" : [NSString stringWithUTF8String:newViewProps.source.c_str()];
  [_videoManager applySource:source];
  
  // ------ UPDATE - RESIZE MODE ----- //
  NSString *resizeMode = newViewProps.resizeMode.empty() ? @"" : [NSString stringWithUTF8String:newViewProps.resizeMode.c_str()];
  [_videoManager applyResizeMode:resizeMode];
  
  // ------ UPDATE - VOLUME ----- //
  [_videoManager applyVolume:newViewProps.volume];
  
  // ------ UPDATE - MUTED ----- //
  [_videoManager applyMuted:newViewProps.muted];
  
  // ------ UPDATE - SEEK ----- //
  [_videoManager applySeek:newViewProps.seek];
  
  // ------ UPDATE - PROGRESS INTEVAL TIMING ----- //
  [_videoManager applyProgressInterval:newViewProps.progressInterval];
  
  // ------ UPDATE - PROGRESS TRACKING ----- //
  [_videoManager applyProgress:newViewProps.enableProgress];
  
  // ------ UPDATE - ONLOAD TRACKING ----- //
  [_videoManager applyOnLoad:newViewProps.enableOnLoad];
  
  // ------ UPDATE - ONLOAD TRACKING ----- //
  [_videoOverlay applySharingAnimatedDuration:newViewProps.sharingAnimatedDuration];
  
  // ------ UPDATE - HEADER HEIGHT ----- //
  _headerHeight = newViewProps.headerHeight;
  
  [super updateProps:props oldProps:oldProps];
}

#pragma mark - Functional Handling

- (void) addViewShareElement:(NSString *) shareTagElement {
  [RCTVideoTag registerView:self withTag:shareTagElement];
}

-(void) removeViewShareElement:(NSString *) shareTagElement {
  [RCTVideoTag removeView:self withTag:shareTagElement];
}

- (void)createPlayerLayerIfNeeded {
  if (CGRectIsEmpty(self.bounds) || _sharing) return;
  if (!_videoManager.playerLayer) {
    [_videoManager createPlayerLayer];
    const auto &props = *std::static_pointer_cast<VideoProps const>(_props);
    NSString *resizeMode = [NSString stringWithUTF8String:props.resizeMode.c_str()];
    [_videoManager applyResizeMode:resizeMode];
  }
  if (self.videoManager.playerLayer.superlayer != self.layer) {
    [self.layer addSublayer:_videoManager.playerLayer];
  }
  [_videoManager setLayerFrame:self.bounds];
}


#pragma mark - Share Element Handling

- (void)shareElement {
  RCTVideoView *otherView = [RCTVideoTag getOtherViewForTag:self withTag:_shareTagElement];
  if(otherView) {
    const auto &otherProps = *std::static_pointer_cast<VideoProps const>(otherView.props);
    
    otherView.sharing = TRUE;
    [otherView.videoManager beforeShareElement];
    [_videoManager beforeTargetShareElement];
    
    self.hidden = YES;
    otherView.hidden = YES;
    
    CGRect toFrame = self.layer.presentationLayer ? self.layer.presentationLayer.frame : self.frame;
    toFrame.origin.y += _headerHeight;
    
    CGRect fromFrame = otherView.layer.presentationLayer ? otherView.layer.presentationLayer.frame : otherView.frame;
    fromFrame.origin.y += otherView.headerHeight;
    
    __weak RCTVideoView *weakSelf = self;
    [_videoOverlay moveToOverlay:fromFrame
                      tagetFrame:toFrame
                          player:otherView.videoManager.player
             aVLayerVideoGravity: otherView.videoManager.aVLayerVideoGravity
                         bgColor:otherView.backgroundColor
                        onTarget:^ {
      self.hidden = NO;
      if(!otherProps.hiddenWhenShareElement) {
        otherView.hidden = NO;
      }
      [weakSelf.videoManager afterTargetShareElement:otherView.videoManager.player isOtherPaused:otherView.videoManager.paused];
    }
                     onCompleted:^ {
      otherView.sharing = FALSE;
      [otherView.videoManager afterShareElementComplete];
      [otherView createPlayerLayerIfNeeded];
    }];
  }
}

- (void)shareElementWhenDealloc {
  RCTVideoView *otherView = [RCTVideoTag getOtherViewForTag:self withTag:_shareTagElement];
  if(otherView) {
    _sharing = TRUE;
    [_videoManager beforeShareElement];
    [otherView.videoManager beforeTargetShareElement];
    
    otherView.hidden = YES;
    
    CGRect fromFrame = self.layer.presentationLayer.frame;
    fromFrame.origin.y += _headerHeight;
    
    CGRect toFrame = otherView.layer.presentationLayer.frame;
    toFrame.origin.y += otherView.headerHeight;
    
    __weak RCTVideoView *weakSelf = self;
    [_videoOverlay moveToOverlay:fromFrame
                      tagetFrame:toFrame
                          player:_videoManager.player
             aVLayerVideoGravity: _videoManager.aVLayerVideoGravity
                         bgColor: self.backgroundColor
                        onTarget:^ {
      otherView.hidden = NO;
      [otherView.videoManager afterTargetShareElement:weakSelf.videoManager.player isOtherPaused:weakSelf.videoManager.paused];
    }
                     onCompleted:^ {
      weakSelf.sharing = FALSE;
      [weakSelf unmount];
    }];
  } else [self unmount];
}

#pragma mark - Fabric Integration - Important!

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<VideoComponentDescriptor>();
}

#pragma mark - Legacy Command Handling
- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args
{
  if ([commandName isEqualToString:@"initialize"]) {
    [self initialize];
  }
  else if ([commandName isEqualToString:@"setSeekCommand"]) {
    if (args.count >= 1) {
      double seek = [args[0] doubleValue];
      [_videoManager seekToTime:seek];
    }
  } else if ([commandName isEqualToString:@"setPausedCommand"]) {
    if (args.count >= 1) {
      bool paused = [args[0] boolValue];
      [_videoManager applyPausedFromCommand:paused];
    }
  } else if ([commandName isEqualToString:@"setVolumeCommand"]) {
    if (args.count >= 1) {
      double volume = [args[0] doubleValue];
      [_videoManager applyVolumeFromCommand:volume];
    }
  }
}

#pragma mark - NAVIGATION BACK HANDLING

- (void)_onWillPopNoti:(NSNotification *)note {
  // WILLPOP FROM NOTIFICATION
}

- (void)handleWillPop
{
  if(_backGestureActive || _sharing) return;
  NSLog(@"[RNBackLife] rn_onWillPop %f", self.videoOverlay.sharingAnimatedDuration);
  self.layer.opacity = 0.f;
  [self shareElementWhenDealloc];
  [self beforeUnmount];
  // NSLog(@"Call Back Button")
}

- (void)rn_onEarlyPopFromNav
{
  self.layer.opacity = 0.f;
  [self shareElementWhenDealloc];
  [self beforeUnmount];
  // NSLog(@"Call thủ công từ react native")
}

- (void)handleDidPop
{
  if(_sharing) return;
  NSLog(@"____ %@", _shareTagElement);
  RCTVideoView *otherView = [RCTVideoTag getOtherViewForTag:self withTag:_shareTagElement];
  if(otherView) {
    NSLog(@"otherView %@",otherView);
    [otherView.videoManager afterTargetShareElement:_videoManager.player isOtherPaused:_videoManager.paused];
  }
  [[RNEarlyRegistry shared] removeView:self];
  [self _detachFromNavAndVC];
  [self beforeUnmount];
  [self unmount];
  // NSLog(@"[RCTVideoView] didPop (nguồn: VC đã rời stack hoặc dismiss hoàn tất)");
}

- (void)_handlePopGesture:(UIGestureRecognizer *)gr
{
  if(_isBlur) return;
  CGFloat progress = 0;
  
  if ([gr isKindOfClass:[UIPanGestureRecognizer class]]) {
    UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gr;
    UIView *view = pan.view;
    if (view) {
      CGPoint translation = [pan translationInView:view];
      progress = translation.x / view.bounds.size.width;
      progress = fmaxf(0.0, fminf(1.0, progress));
    }
  }
  
  switch (gr.state) {
    case UIGestureRecognizerStateBegan: {
      // NSLog(@"[RCTVideoView] gestureBegan");
      _backGestureActive = true;
      break;
    }
    case UIGestureRecognizerStateChanged: {
      // NSLog(@"[RCTVideoView] gestureChanged progress: %.2f%%", progress * 100);
      break;
    }
    case UIGestureRecognizerStateCancelled: {
      break;
    }
    case UIGestureRecognizerStateEnded: {
       NSLog(@"[RCTVideoView] gestureEnded at progress: %.2f%%", progress * 100);
      _backGestureActive = false;
      dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *vc = [self nearestViewController];
        BOOL popped = self.nav && ![self.nav.viewControllers containsObject:vc];
        if (popped) {
           NSLog(@"[RCTVideoView] didPop after swipe-back %@", self.shareTagElement);
//          [self handleDidPop];
        } else {
           NSLog(@"[RCTVideoView] swipe-back not completed (cancelled) %@", self.shareTagElement);
        }
      });
      break;
    }
    default:
      break;
  }
}

// ------- CLEAN ------ //
- (void)_detachFromNavAndVC {
  UIViewController *vc = [self nearestViewController];
  if (vc) {
    vc.rn_onWillPop = nil;
    vc.rn_onDidPop  = nil;
    vc.rn_onWillDisappear = nil;
    vc.rn_onWillAppear = nil;
  }
  
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:@"RNWillPopViewControllerNotification"
                                                object:self.nav];
}

@end
