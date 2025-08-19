//
//  UIView+NearestVC.m
//  ShareVideo
//
//  Created by Sang Lv on 23/8/25.
//

#import "UIView+NearestVC.h"
@implementation UIView (NearestVC)
- (UIViewController *)nearestViewController {
  UIResponder *r = self;
  while (r) {
    if ([r isKindOfClass:[UIViewController class]]) return (UIViewController *)r;
    r = r.nextResponder;
  }
  return nil;
}
@end
