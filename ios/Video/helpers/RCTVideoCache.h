//
//  RCTVideoCache.h
//  ShareVideo
//
//  Created by Sang Le vinh on 8/19/25.
//
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface RCTVideoCache : NSObject

+(void)VC_StartProxy;
+(void)VC_PrefetchHead:(NSURL *) url seconds:(double) seconds bitratebps:(double) bitratebps;

@end
NS_ASSUME_NONNULL_END
