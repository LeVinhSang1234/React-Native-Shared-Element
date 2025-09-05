//
//  RCTShareViewRouteRegistry.m
//  ShareVideo
//
//  Created by Sang Le vinh on 9/4/25.
//

#import "RCTShareViewRouteRegistry.h"
#import "RCTShareView.h"
#import "UIView+NearestVC.h"
#import "UIView+RNSScreenCheck.h"
#import "RNWeakBox.h"

@implementation RCTShareViewRouteRegistry {
  NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSMutableArray<RNWeakBox *> *> *> *_tagScreens;
  NSMutableDictionary<NSString *, NSDictionary *> *_currentOwner;
  NSMutableDictionary<NSString *, NSString *> *_pendingTargetTag;
  NSMutableDictionary<NSString *, NSMutableArray<NSDictionary *> *> *_edges;
  NSMutableArray<NSString *> *_recentScreens;
}

+ (instancetype)shared {
  static RCTShareViewRouteRegistry *inst;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ inst = [RCTShareViewRouteRegistry new]; });
  return inst;
}

- (instancetype)init {
  if (self = [super init]) {
    _tagScreens = [NSMutableDictionary new];
    _currentOwner = [NSMutableDictionary new];
    _pendingTargetTag = [NSMutableDictionary new];
    _edges = [NSMutableDictionary new];
    _recentScreens = [NSMutableArray new];
  }
  return self;
}

- (void)registerView:(RCTShareView *)view tag:(NSString *)tag screenKey:(NSString *)screenKey {
  if (!view || tag.length == 0 || screenKey.length == 0) return;
  NSMutableDictionary *screens = _tagScreens[tag];
  if (!screens) { screens = [NSMutableDictionary new]; _tagScreens[tag] = screens; }

  NSMutableArray<RNWeakBox *> *list = screens[screenKey];
  if (!list) { list = [NSMutableArray new]; screens[screenKey] = list; }

  BOOL exists = NO;
  for (RNWeakBox *b in list) {
    if (b.obj == view) { exists = YES; break; }
  }
  if (!exists) [list addObject:[RNWeakBox box:view]];

  [self touchRecentScreen:screenKey];
  if (!_currentOwner[tag]) {
    _currentOwner[tag] = @{@"screen": screenKey,
                           @"view": [NSValue valueWithNonretainedObject:view]};
  }
}

- (void)unregisterView:(RCTShareView *)view tag:(NSString *)tag screenKey:(NSString *)screenKey {
  if (tag.length == 0 || screenKey.length == 0) return;
  NSMutableArray<RNWeakBox *> *list = _tagScreens[tag][screenKey];
  if (!list) return;

  NSMutableArray<RNWeakBox *> *newList = [NSMutableArray new];
  for (RNWeakBox *b in list) {
    if (b.obj && b.obj != view) [newList addObject:b];
  }
  if (newList.count > 0) _tagScreens[tag][screenKey] = newList;
  else [_tagScreens[tag] removeObjectForKey:screenKey];
}

- (nullable RCTShareView *)resolveShareTargetForView:(RCTShareView *)view tag:(NSString *)tag {
  if (!view || tag.length == 0) return nil;
  NSString *srcScreen = [self screenKeyOfView:view];
  if (srcScreen.length == 0) return nil;

  NSString *expectTag = _pendingTargetTag[tag] ?: tag;
  NSDictionary *screens = _tagScreens[expectTag];
  if (screens.count == 0) return nil;

  for (NSString *sk in _recentScreens.reverseObjectEnumerator) {
    if ([sk isEqualToString:srcScreen]) continue;
    NSArray<RNWeakBox *> *boxes = screens[sk];
    for (RNWeakBox *b in boxes.reverseObjectEnumerator) {
      RCTShareView *candidate = (RCTShareView *)b.obj;
      if (candidate && ![candidate rn_isInSameRNSScreenWith:view]) {
        return candidate;
      }
    }
  }

  NSArray<RNWeakBox *> *same = screens[srcScreen];
  for (RNWeakBox *b in same.reverseObjectEnumerator) {
    RCTShareView *candidate = (RCTShareView *)b.obj;
    if (candidate && candidate != view) return candidate;
  }

  return nil;
}

- (void)commitShareFromView:(RCTShareView *)fromView toView:(RCTShareView *)toView tag:(NSString *)tag {
  if (!fromView || !toView || tag.length == 0) return;
  NSString *toScreen = [self screenKeyOfView:toView] ?: @"";
  _currentOwner[tag] = @{@"screen": toScreen,
                         @"view": [NSValue valueWithNonretainedObject:toView]};
  if (toScreen.length) [self touchRecentScreen:toScreen];
}

- (nullable NSString *)screenKeyOfView:(UIView *)view {
  UIViewController *vc = [view nearestViewController];
  if (!vc) return nil;
  return [NSString stringWithFormat:@"%p", vc];
}

- (void)touchRecentScreen:(NSString *)screenKey {
  if (screenKey.length == 0) return;
  [_recentScreens removeObject:screenKey];
  [_recentScreens addObject:screenKey];
  if (_recentScreens.count > 16) {
    [_recentScreens removeObjectAtIndex:0];
  }
}

@end
