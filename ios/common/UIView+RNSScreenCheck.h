//
//  UIView+RNSScreenCheck.h
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
//

#import "UIKit/UIKit.h"

@interface UIView (RNSScreenCheck)
- (UIView *)rn_findRNSScreenAncestor;
- (BOOL)rn_isInSameRNSScreenWith:(UIView *)otherView;
@end
