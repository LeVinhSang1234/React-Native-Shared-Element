//
//  RCTVideoHelper.h
//  ShareVideo
//
//  Created by Sang Lv on 20/8/25.
//
#import <Foundation/Foundation.h>
#import "UIKit/UIKit.h"

NS_ASSUME_NONNULL_BEGIN
@interface RCTVideoHelper : NSObject
+(nullable NSURL *)createVideoURL:(NSString *)source;
+(nullable NSURL *)createPosterURL:(NSString *)source;
+(UIWindow *) getTargetWindow;
@end
NS_ASSUME_NONNULL_END
