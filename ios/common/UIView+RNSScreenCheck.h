//
//  UIView+RNSScreenCheck.h
//  ShareVideo
//
//  Created by Sang Lv on 29/8/25.
//

#import "UIKit/UIKit.h"

@interface UIView (RNSScreenCheck)
- (UIView *)rn_findRNSScreenAncestor;
- (BOOL)rn_isInSameRNSScreenWith:(UIView *)otherView;
@end
