//
//  RCTShareRouteRegistry.m
//  ShareElement
//
//  Created by Sang Le vinh on 9/11/25.
//

#import "RCTShareRouteRegistry.h"
#import "RCTShareView.h"
#import "UIView+NearestVC.h"
#import "UIView+RNSScreenCheck.h"
#import "RNWeakBox.h"

@implementation RCTShareRouteRegistry {
  // tag -> { screenKey -> [weak views] }
  NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSMutableArray<RNWeakBox *> *> *> *_tagScreens;

  // tag -> { "screen": screenKey, "view": weak(view) } (owner hiện tại)
  NSMutableDictionary<NSString *, NSDictionary *> *_currentOwner;

  // tag -> targetTag (nếu có)
  NSMutableDictionary<NSString *, NSString *> *_pendingTargetTag;

  // tag -> [{from:..., to:..., ts:...}]
  NSMutableDictionary<NSString *, NSMutableArray<NSDictionary *> *> *_edges;

  // thứ tự màn xuất hiện gần nhất (ưu tiên resolve theo màn mới)
  NSMutableArray<NSString *> *_recentScreens; // giữ gọn ~16
}

+ (instancetype)shared {
  static RCTShareRouteRegistry *inst;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ inst = [RCTShareRouteRegistry new]; });
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

#pragma mark - Public

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

- (void)setPendingTargetTag:(nullable NSString *)targetTag forTag:(NSString *)tag {
  if (tag.length == 0) return;
  if (targetTag.length == 0) [_pendingTargetTag removeObjectForKey:tag];
  else _pendingTargetTag[tag] = targetTag;
}

- (nullable RCTShareView *)resolveShareTargetForView:(RCTShareView *)view tag:(NSString *)tag {
  if (!view || tag.length == 0) return nil;

  NSString *srcScreen = [self screenKeyOfView:view];
  if (srcScreen.length == 0) return nil;

  NSString *expectTag = _pendingTargetTag[tag] ?: tag;
  NSDictionary<NSString *, NSMutableArray<RNWeakBox *> *> *screens = _tagScreens[expectTag];
  if (screens.count == 0) return nil;

  // 1) Ưu tiên khác màn theo thứ tự recent (mới nhất ở cuối mảng)
  NSEnumerator *rev = _recentScreens.reverseObjectEnumerator;
  for (NSString *sk in rev) {
    if ([sk isEqualToString:srcScreen]) continue;
    NSMutableArray<RNWeakBox *> *boxes = screens[sk];
    if (boxes.count == 0) continue;
    for (RNWeakBox *b in boxes.reverseObjectEnumerator) {
      RCTShareView *candidate = (RCTShareView *)b.obj;
      if (candidate && ![candidate rn_isInSameRNSScreenWith:view]) {
        return candidate;
      }
    }
  }

  // 2) Fallback: cùng màn → lấy thằng khác chính nó, ưu tiên được add sau
  NSMutableArray<RNWeakBox *> *same = screens[srcScreen];
  for (RNWeakBox *b in same.reverseObjectEnumerator) {
    RCTShareView *candidate = (RCTShareView *)b.obj;
    if (candidate && candidate != view) return candidate;
  }

  return nil;
}

- (void)commitShareFromView:(RCTShareView *)fromView toView:(RCTShareView *)toView tag:(NSString *)tag {
  if (!fromView || !toView || tag.length == 0) return;

  NSString *fromScreen = [self screenKeyOfView:fromView] ?: @"";
  NSString *toScreen   = [self screenKeyOfView:toView]   ?: @"";

  _currentOwner[tag] = @{@"screen": toScreen,
                         @"view": [NSValue valueWithNonretainedObject:toView]};

  NSMutableArray<NSDictionary *> *arr = _edges[tag];
  if (!arr) { arr = [NSMutableArray new]; _edges[tag] = arr; }
  [arr addObject:@{
    @"from": fromScreen,
    @"to":   toScreen,
    @"ts":   @([NSDate date].timeIntervalSince1970)
  }];

  if (toScreen.length) [self touchRecentScreen:toScreen];
}

- (NSArray<NSDictionary *> *)edgesForTag:(NSString *)tag {
  NSArray *arr = _edges[tag];
  return arr ? [arr copy] : @[];
}

- (nullable NSString *)screenKeyOfView:(UIView *)view {
  UIViewController *vc = [view nearestViewController];
  if (!vc) return nil;
  return [NSString stringWithFormat:@"%p", vc];
}

#pragma mark - Private

- (void)touchRecentScreen:(NSString *)screenKey {
  if (screenKey.length == 0) return;
  [_recentScreens removeObject:screenKey];
  [_recentScreens addObject:screenKey];
  if (_recentScreens.count > 16) {
    [_recentScreens removeObjectAtIndex:0];
  }
}

@end


