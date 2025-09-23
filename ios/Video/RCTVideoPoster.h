//
//  RCTVideoPoster.h
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
//
#import "Foundation/Foundation.h"
#import "UIKit/UIKit.h"

NS_ASSUME_NONNULL_BEGIN
@interface RCTVideoPoster : UIImageView
- (void)applyPoster:(NSString *)poster;
- (void)applyPosterResizeMode:(NSString *)posterResizeMode;
@end

NS_ASSUME_NONNULL_END
