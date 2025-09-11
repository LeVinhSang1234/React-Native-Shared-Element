//
//  RNEarlyRegistry.m
//  ShareVideo
//
//  Created by Sang Lv on 23/8/25.
//

#import <Foundation/Foundation.h>
#import "RNEarlyRegistry.h"
#import <objc/message.h>

@interface RNEarlyRegistry ()
@property (nonatomic, strong) NSHashTable<UIView *> *views; // weak
@end

@implementation RNEarlyRegistry
+ (instancetype)shared {
  static RNEarlyRegistry *s; static dispatch_once_t once;
  dispatch_once(&once, ^{ s = [RNEarlyRegistry new];
    s.views = [NSHashTable weakObjectsHashTable];
  }); return s;
}
- (void)addView:(UIView *)v { if (v) [self.views addObject:v]; }
- (void)removeView:(UIView *)v { if (v) [self.views removeObject:v]; }

- (void)notifyNav
{
  SEL sel = NSSelectorFromString(@"rn_onEarlyPopFromNav");
  void (*Send)(id, SEL) = (void(*)(id, SEL))objc_msgSend;
  for (UIView *v in self.views) {
    if (!v.window) continue;
    if (![v respondsToSelector:sel]) continue;
    Send(v, sel);
  }
}
@end
