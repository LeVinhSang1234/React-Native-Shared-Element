//
//  RCTVideoCache.h
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface RCTVideoCache : NSObject

+ (void)VC_StartProxy;
+ (void)VC_ConfigureCache:(NSUInteger)maxSizeMB;
+ (void)VC_PrefetchHead:(NSURL *) url seconds:(double) seconds bitratebps:(double) bitratebps;
+ (void)trimCacheIfNeeded;
+ (NSURL *)proxyURLWithOriginalURL:(NSURL *)url;

@end
NS_ASSUME_NONNULL_END
