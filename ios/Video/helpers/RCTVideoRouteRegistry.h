//
//  RCTVideoRouteRegistry.h
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
//

#import <Foundation/Foundation.h>

@class RCTVideoView;

NS_ASSUME_NONNULL_BEGIN

@interface RCTVideoRouteRegistry : NSObject

+ (void)registerView:(RCTVideoView *)view tag:(NSString *)tag;
+ (void)unregisterView:(RCTVideoView *)view tag:(NSString *)tag;
+ (nullable RCTVideoView *)resolveViewForTag:(NSString *)tag exclude:(RCTVideoView *)excludeView;

@end

NS_ASSUME_NONNULL_END
