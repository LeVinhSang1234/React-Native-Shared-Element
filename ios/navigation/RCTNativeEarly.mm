//
//  RCTNativeEarly.m
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
//

#import <FBReactNativeSpec/FBReactNativeSpec.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "RCTNativeEarly.h"
#import "RNEarlyRegistry.h"

using namespace facebook;
using namespace facebook::react;

static void PrepareEarly() {
  [[RNEarlyRegistry shared] notifyNav];
    
  [CATransaction flush];
}
@implementation RCTNativeEarly

- (id) init {
  if (self = [super init]) {
  }
  return self;
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:(const facebook::react::ObjCTurboModule::InitParams &)params {
  return std::make_shared<facebook::react::NativeEarlySpecJSI>(params);
}

- (NSNumber *)prepareForGoBackSync {
  if (NSThread.isMainThread) {
    PrepareEarly();
  } else {
    dispatch_sync(dispatch_get_main_queue(), ^{ PrepareEarly(); });
  }
  return @(YES);
}

+ (NSString *)moduleName
{
  return @"RCTNativeEarly";
}

@end
