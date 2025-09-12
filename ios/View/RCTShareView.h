//
//  RCTShareView.h
//  ShareElement
//
//  Created by Sang Le vinh on 9/11/25.
//

#import <React/RCTViewComponentView.h>
#import "RCTShareViewOverlay.h"

@interface RCTShareView : RCTViewComponentView

@property (nonatomic, assign) BOOL sharing;
@property (nonatomic, assign) double headerHeight;

@property (nonatomic, copy, nullable) NSString *shareTagElement;
@property (nonatomic, assign) double sharingAnimatedDuration;
@property (nonatomic, strong, nonnull) RCTShareViewOverlay *shareViewOverlay;

// Lưu sự khác biệt x, y giữa frame hiện tại so với khung nhìn window
@property (nonatomic, assign) CGPoint windowFrameDelta;

@end
