//
//  RCTVideoTag.m
//  ShareVideo
//
//  Created by Sang Lv on 20/8/25.
//

#import "RCTVideoTag.h"

@implementation RCTVideoTag

static NSMutableDictionary<NSString *, NSMutableArray<RCTVideoView *> *> *tagToViewsMap = [NSMutableDictionary new];

+ (void)registerView:(RCTVideoView *)view withTag:(NSString *)tag {
  if (!view || !tag) return;
  
  NSMutableArray *arr = tagToViewsMap[tag];
  if (!arr) {
    arr = [NSMutableArray new];
    tagToViewsMap[tag] = arr;
  }
  if (![arr containsObject:view]) {
    [arr addObject:view];
  }
}

+ (void)removeView:(RCTVideoView *)view withTag:(NSString *)tag {
  if (!tag) return;
  NSMutableArray *arr = tagToViewsMap[tag];
  if (arr && view) {
    [arr removeObject:view];
    if (arr.count == 0) {
      [tagToViewsMap removeObjectForKey:tag];
    }
  }
}

+ (RCTVideoView *)getOtherViewForTag:(RCTVideoView *)view withTag:(NSString *)tag {
  NSMutableArray *arr = tagToViewsMap[tag];
  NSArray *views = arr ? [arr copy] : @[];
  RCTVideoView *otherView = nil;
  for (NSInteger i = views.count - 1; i >= 0; i--) {
    RCTVideoView *_view = views[i];
    if (_view != view) {
      otherView = _view;
      break;
    }
  }
  return otherView;
}
@end
