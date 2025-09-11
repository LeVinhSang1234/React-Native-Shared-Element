//
//  RCTShareView.h
//  ShareElement
//
//  Created by Sang Le vinh on 9/11/25.
//

#import <React/RCTViewComponentView.h>

@interface RCTShareView : RCTViewComponentView

@property (nonatomic, assign) BOOL sharing;
@property (nonatomic, assign) double headerHeight;

@property (nonatomic, copy, nullable) NSString *shareTagElement;
@property (nonatomic, assign) double sharingAnimatedDuration;
@end
