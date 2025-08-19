//
//  RCTVideoView.h
//  ShareVideo
//
//  Created by Sang Le vinh on 8/19/25.
//
#import <Foundation/Foundation.h>
#import <React/RCTViewComponentView.h>
#import "RCTVideoManager.h"
#import "RCTVideoOverlay.h"
#import "RCTVideoTag.h"

NS_ASSUME_NONNULL_BEGIN
@interface RCTVideoView : RCTViewComponentView

@property (nonatomic, assign) BOOL sharing;
@property (nonatomic, assign) double headerHeight;

@property (nonatomic, copy) NSString *shareTagElement;
@property (nonatomic, strong) RCTVideoManager *videoManager;
@property (nonatomic, strong) RCTVideoOverlay *videoOverlay;
@end

NS_ASSUME_NONNULL_END
