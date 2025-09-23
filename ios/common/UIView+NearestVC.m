//
//  UIView+NearestVC.m
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
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
