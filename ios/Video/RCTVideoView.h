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

NS_ASSUME_NONNULL_BEGIN
@interface RCTVideoView : RCTViewComponentView

@property (nonatomic, assign) BOOL sharing;
@property (nonatomic, assign) BOOL shared;

@property (nonatomic, assign) double headerHeight;

@property (nonatomic, copy) NSString *shareTagElement;
@property (nonatomic, strong) RCTVideoManager *videoManager;
@property (nonatomic, strong) RCTVideoOverlay *videoOverlay;

// Lưu sự khác biệt x, y giữa frame hiện tại so với khung nhìn window
@property (nonatomic, assign) CGPoint windowFrameDelta;
@end

NS_ASSUME_NONNULL_END
