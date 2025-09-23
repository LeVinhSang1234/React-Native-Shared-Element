//
//  RCTVideoView.h
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
//

#import "RCTVideoOverlay.h"
#import <React/RCTViewComponentView.h>

NS_ASSUME_NONNULL_BEGIN
@interface RCTVideoView : RCTViewComponentView
@property (nonatomic, assign) BOOL isShared;
@property (nonatomic, assign) BOOL isSharing;
@property (nonatomic, strong) RCTVideoOverlay *videoOverlay;
@end

NS_ASSUME_NONNULL_END
