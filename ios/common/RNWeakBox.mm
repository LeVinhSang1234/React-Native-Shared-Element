//
//  RNWeakBox.m
//  ShareVideo
//
//  Created by Sang Le vinh on 9/5/25.
//

#import <Foundation/Foundation.h>
#import "RNWeakBox.h"

@implementation RNWeakBox
+ (instancetype)box:(id)obj {
  RNWeakBox *b = [RNWeakBox new];
  b.obj = obj;
  return b;
}
@end
