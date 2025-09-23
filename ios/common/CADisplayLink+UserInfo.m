//
//  CADisplayLink+UserInfo.m
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
//

#import <Foundation/Foundation.h>
#import "CADisplayLink+UserInfo.h"
#import <objc/runtime.h>

@implementation CADisplayLink (UserInfo)

- (void)setRn_userInfo:(NSDictionary *)rn_userInfo {
  objc_setAssociatedObject(self, @selector(rn_userInfo), rn_userInfo, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDictionary *)rn_userInfo {
  return objc_getAssociatedObject(self, @selector(rn_userInfo));
}

@end
