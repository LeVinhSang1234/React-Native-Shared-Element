//
//  RCTShareView.h
//  ShareVideo
//
//  Created by Sang Le vinh on 9/4/25.
//

#import <React/RCTViewComponentView.h>
#import <UIKit/UIKit.h>
#import "RCTShareViewOverlay.h"

NS_ASSUME_NONNULL_BEGIN

@interface RCTShareView : RCTViewComponentView
@property (nonatomic, assign) BOOL sharing;
@property (nonatomic, assign) double headerHeight;
@property (nonatomic, copy) NSString *shareTagElement;
@property (nonatomic, strong) RCTShareViewOverlay *viewOverlay;

// Lưu sự khác biệt x, y giữa frame hiện tại so với khung nhìn window
@property (nonatomic, assign) CGPoint windowFrameDelta;
@end

NS_ASSUME_NONNULL_END
