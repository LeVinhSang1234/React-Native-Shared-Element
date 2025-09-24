//
//  RCTVideoRouteRegistry.m
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
//

#import "RCTVideoRouteRegistry.h"
#import "RCTVideoView.h"

@implementation RCTVideoRouteRegistry

static NSMutableDictionary<NSString *, NSMutableArray<RCTVideoView *> *> *gRegistry;

+ (void)initialize {
  if (self == [RCTVideoRouteRegistry class] && !gRegistry) {
    gRegistry = [NSMutableDictionary dictionary];
  }
}

+ (void)registerView:(RCTVideoView *)view tag:(NSString *)tag {
  if (!tag.length || !view) return;
  NSMutableArray *arr = gRegistry[tag];
  if (!arr) {
    arr = [NSMutableArray array];
    gRegistry[tag] = arr;
  }
  if (![arr containsObject:view]) {
    [arr addObject:view];
  }
}

+ (void)unregisterView:(RCTVideoView *)view tag:(NSString *)tag {
  if (!tag.length || !view) return;
  NSMutableArray *arr = gRegistry[tag];
  [arr removeObject:view];
  if (arr.count == 0) [gRegistry removeObjectForKey:tag];
}

+ (nullable RCTVideoView *)resolveViewForTag:(NSString *)tag exclude:(RCTVideoView *)excludeView {
  if (!tag.length) return nil;
  NSArray *arr = gRegistry[tag];
  for (RCTVideoView *v in [arr reverseObjectEnumerator]) {
    if (v != excludeView) {
      return v;
    }
  }
  return nil;
}

@end
