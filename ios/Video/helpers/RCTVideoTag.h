//
//  RCTVideoTag.h
//  ShareVideo
//
//  Created by Sang Lv on 20/8/25.
//
#import <Foundation/Foundation.h>

@class RCTVideoView;

NS_ASSUME_NONNULL_BEGIN
@interface RCTVideoTag : NSObject

+(void)registerView:(RCTVideoView *)view withTag:(NSString *)tag;
+(void)removeView:(RCTVideoView *)view withTag:(NSString *)tag;
+(RCTVideoView *)getOtherViewForTag:(RCTVideoView *)view withTag:(NSString *)tag;

@end
NS_ASSUME_NONNULL_END
